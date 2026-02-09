#!/usr/bin/env python3
"""Capture session cleanup module.

Discovers capture sessions, applies retention policies (keep-days, keep-size),
and deletes expired sessions. Outputs JSON summary to stdout for the Bash
wrapper to consume.
"""

import glob
import re
import json
import os
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path


def parse_size(size_str: str) -> int:
    """Parse human-readable size string to bytes.

    Supports: 500M, 1G, 1024K, 1024 (bytes).
    """
    size_str = size_str.strip()
    if not size_str:
        raise ValueError("Empty size string")

    suffix = ""
    num_str = size_str

    if size_str[-1].lower() == "b":
        size_str = size_str[:-1]

    if size_str and size_str[-1].lower() in ("k", "m", "g"):
        suffix = size_str[-1].lower()
        num_str = size_str[:-1]
    else:
        num_str = size_str

    try:
        num = float(num_str)
    except ValueError:
        raise ValueError(f"Invalid size format: {size_str}")

    multipliers = {"k": 1024, "m": 1024**2, "g": 1024**3}
    return int(num * multipliers.get(suffix, 1))


def format_size(num_bytes: int) -> str:
    """Format bytes to human-readable size."""
    if num_bytes >= 1024**3:
        return f"{num_bytes / 1024**3:.1f}G"
    if num_bytes >= 1024**2:
        return f"{num_bytes / 1024**2:.1f}M"
    if num_bytes >= 1024:
        return f"{num_bytes / 1024:.1f}K"
    return f"{num_bytes}B"


def discover_sessions(captures_dir: str) -> list:
    """Discover all capture sessions in the captures directory.

    Returns list of dicts: [{"run_id", "timestamp", "total_size"}, ...]
    Sorted by timestamp ascending (oldest first).
    """
    seen = set()
    sessions = []

    def emit_session(rid: str):
        # Validate run_id format (digits and underscores only) to prevent glob injection
        if not re.match(r'^[0-9_]+$', rid):
            return
        # Parse timestamp from RUN_ID: YYYYMMDD_HHMMSS_PID
        started_at = ""
        parts = rid.split("_")
        if len(parts) >= 2:
            date_part, time_part = parts[0], parts[1]
            if len(date_part) == 8 and date_part.isdigit() and len(time_part) == 6 and time_part.isdigit():
                started_at = (
                    f"{date_part[:4]}-{date_part[4:6]}-{date_part[6:8]}"
                    f"T{time_part[:2]}:{time_part[2:4]}:{time_part[4:6]}"
                )

        # Try to get more accurate time from manifest
        manifest = os.path.join(captures_dir, f"capture_{rid}.manifest.json")
        if os.path.isfile(manifest):
            try:
                with open(manifest, "r", encoding="utf-8") as f:
                    d = json.load(f)
                ts = d.get("startedAt", d.get("started_at", ""))
                if ts:
                    started_at = ts
            except Exception:
                pass

        # Calculate total size
        total_size = 0
        pattern = os.path.join(captures_dir, f"capture_{rid}.*")
        for fpath in glob.glob(pattern):
            if os.path.isfile(fpath):
                total_size += os.path.getsize(fpath)

        sessions.append({
            "run_id": rid,
            "timestamp": started_at,
            "total_size": total_size,
        })

    # Find sessions via manifest files
    manifest_pattern = os.path.join(captures_dir, "capture_*.manifest.json")
    for manifest_path in sorted(glob.glob(manifest_pattern)):
        bname = os.path.basename(manifest_path)
        rid = bname.removeprefix("capture_").removesuffix(".manifest.json")
        if not rid:
            continue
        seen.add(rid)
        emit_session(rid)

    # Find orphan sessions (have .flow but no manifest)
    flow_pattern = os.path.join(captures_dir, "capture_*.flow")
    for flow_path in sorted(glob.glob(flow_pattern)):
        bname = os.path.basename(flow_path)
        rid = bname.removeprefix("capture_").removesuffix(".flow")
        if not rid or rid in seen:
            continue
        seen.add(rid)
        emit_session(rid)

    # Sort by timestamp ascending (oldest first)
    sessions.sort(key=lambda s: s["timestamp"] or "0000")
    return sessions


def session_files(captures_dir: str, run_id: str) -> list:
    """Get all files belonging to a session."""
    files = []
    pattern = os.path.join(captures_dir, f"capture_{run_id}.*")
    for fpath in glob.glob(pattern):
        if os.path.isfile(fpath):
            files.append(fpath)

    # Also include temp policy files
    policy_tmp = os.path.join(captures_dir, f".policy_{run_id}.json")
    if os.path.isfile(policy_tmp):
        files.append(policy_tmp)

    return files


def is_latest_target(captures_dir: str, run_id: str) -> bool:
    """Check if a RUN_ID is the target of any latest.* symlink."""
    pattern = os.path.join(captures_dir, "latest.*")
    for link_path in glob.glob(pattern):
        if not os.path.islink(link_path):
            continue
        target = os.readlink(link_path)
        if f"capture_{run_id}." in target:
            return True
    return False


def update_latest_links(captures_dir: str):
    """Update latest.* symlinks to point to the newest remaining session."""
    exts = [
        "flow", "har", "log", "manifest.json", "index.ndjson",
        "summary.md", "ai.json", "ai.md", "navigation.ndjson",
    ]
    link_names = [
        "latest.flow", "latest.har", "latest.log", "latest.manifest.json",
        "latest.index.ndjson", "latest.summary.md", "latest.ai.json",
        "latest.ai.md", "latest.navigation.ndjson",
    ]

    for ext, link_name in zip(exts, link_names):
        link_path = os.path.join(captures_dir, link_name)
        pattern = os.path.join(captures_dir, f"capture_*.{ext}")
        candidates = sorted(glob.glob(pattern))

        if candidates and os.path.isfile(candidates[-1]):
            # ln -sfn equivalent
            tmp_link = link_path + ".tmp"
            try:
                os.symlink(candidates[-1], tmp_link)
                os.replace(tmp_link, link_path)
            except OSError:
                try:
                    os.remove(tmp_link)
                except OSError:
                    pass
                try:
                    if os.path.islink(link_path):
                        os.remove(link_path)
                    os.symlink(candidates[-1], link_path)
                except OSError:
                    pass
        else:
            try:
                os.remove(link_path)
            except OSError:
                pass


def delete_file(filepath: str, secure: bool):
    """Delete a single file, optionally with shred."""
    if secure:
        try:
            subprocess.run(
                ["shred", "-n", "3", "-z", "-u", filepath],
                check=True, capture_output=True,
            )
            return
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass
    try:
        os.remove(filepath)
    except OSError:
        pass


def compute_cutoff(keep_days: int) -> str:
    """Compute the ISO timestamp cutoff for keep-days policy.

    Uses local time (no timezone) to match RUN_ID timestamps which are
    generated with local `date +%Y%m%d_%H%M%S`.
    """
    cutoff = datetime.now() - timedelta(days=keep_days)
    return cutoff.strftime("%Y-%m-%dT%H:%M:%S")


def run_cleanup(captures_dir: str, keep_days=None, keep_size=None,
                secure=False, dry_run=False) -> dict:
    """Run cleanup and return summary dict.

    Returns JSON-serializable dict with cleanup results.
    """
    if not os.path.isdir(captures_dir):
        return {
            "status": "no-dir",
            "message": f"No captures directory found at {captures_dir}",
            "deleted": 0, "kept": 0, "files_removed": 0, "bytes_freed": 0,
        }

    sessions = discover_sessions(captures_dir)
    if not sessions:
        return {
            "status": "empty",
            "message": f"No capture sessions found in {captures_dir}",
            "deleted": 0, "kept": len(sessions), "files_removed": 0, "bytes_freed": 0,
        }

    # Build lookup maps
    ts_map = {s["run_id"]: s["timestamp"] for s in sessions}
    sz_map = {s["run_id"]: s["total_size"] for s in sessions}
    sorted_ids = [s["run_id"] for s in sessions]

    to_delete = set()

    # Apply keep-days filter
    if keep_days is not None:
        cutoff_ts = compute_cutoff(keep_days)
        for rid in sorted_ids:
            ts = ts_map[rid]
            if not ts:
                to_delete.add(rid)
                continue
            # <= comparison: not strictly after cutoff means delete
            if not (ts > cutoff_ts):
                to_delete.add(rid)

    # Apply keep-size filter
    if keep_size is not None:
        max_bytes = parse_size(keep_size)
        cumulative = 0
        budget_exceeded = False

        # Walk from newest to oldest
        for rid in reversed(sorted_ids):
            sz = sz_map[rid]
            if budget_exceeded:
                to_delete.add(rid)
                continue
            cumulative += sz
            if cumulative > max_bytes:
                to_delete.add(rid)
                budget_exceeded = True

    if not to_delete:
        return {
            "status": "nothing",
            "message": f"Nothing to clean up ({len(sorted_ids)} sessions within retention policy)",
            "deleted": 0, "kept": len(sorted_ids), "files_removed": 0, "bytes_freed": 0,
        }

    # Execute cleanup
    delete_count = 0
    delete_files = 0
    delete_bytes = 0
    kept_count = 0
    needs_latest_update = False
    details = []

    for rid in sorted_ids:
        if rid not in to_delete:
            kept_count += 1
            continue

        ts = ts_map[rid] or "unknown"
        sz = sz_map[rid]

        if is_latest_target(captures_dir, rid):
            needs_latest_update = True

        files = session_files(captures_dir, rid)
        file_count = len(files)

        if not dry_run:
            for f in files:
                delete_file(f, secure)

        details.append({
            "run_id": rid,
            "timestamp": ts,
            "size": sz,
            "size_human": format_size(sz),
            "files": file_count,
        })

        delete_count += 1
        delete_files += file_count
        delete_bytes += sz

    # Update symlinks
    if not dry_run and needs_latest_update:
        update_latest_links(captures_dir)

    return {
        "status": "ok",
        "dry_run": dry_run,
        "secure": secure,
        "deleted": delete_count,
        "kept": kept_count,
        "files_removed": delete_files,
        "bytes_freed": delete_bytes,
        "bytes_freed_human": format_size(delete_bytes),
        "needs_latest_update": needs_latest_update,
        "details": details,
    }


def main():
    """CLI entry point: called by cleanupCaptures.sh.

    Usage: cleanup.py <captures_dir> [--keep-days N] [--keep-size SIZE]
                      [--secure] [--dry-run]

    Outputs JSON summary to stdout.
    """
    import argparse

    parser = argparse.ArgumentParser(description="Cleanup capture sessions")
    parser.add_argument("captures_dir", help="Path to captures directory")
    parser.add_argument("--keep-days", type=int, default=None)
    parser.add_argument("--keep-size", default=None)
    parser.add_argument("--secure", action="store_true")
    parser.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()

    result = run_cleanup(
        captures_dir=args.captures_dir,
        keep_days=args.keep_days,
        keep_size=args.keep_size,
        secure=args.secure,
        dry_run=args.dry_run,
    )

    json.dump(result, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")

    # Exit code based on status
    if result["status"] in ("no-dir", "empty", "nothing"):
        sys.exit(0)
    if result["status"] == "ok":
        sys.exit(0)
    sys.exit(1)


if __name__ == "__main__":
    main()
