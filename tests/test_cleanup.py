#!/usr/bin/env python3
"""Tests for cleanup.py module."""

import json
import os
import sys
import tempfile
from datetime import datetime, timedelta

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
from cleanup import (
    compute_cutoff,
    discover_sessions,
    format_size,
    is_latest_target,
    parse_size,
    run_cleanup,
    session_files,
    update_latest_links,
)


def create_session(captures_dir, run_id, file_size=100):
    """Create a fake capture session with a given RUN_ID."""
    parts = run_id.split("_")
    date_part, time_part = parts[0], parts[1]
    started_at = (
        f"{date_part[:4]}-{date_part[4:6]}-{date_part[6:8]}"
        f"T{time_part[:2]}:{time_part[2:4]}:{time_part[4:6]}"
    )

    for ext in ["flow", "har", "log", "index.ndjson", "summary.md",
                "ai.json", "ai.md", "scope_audit.json"]:
        path = os.path.join(captures_dir, f"capture_{run_id}.{ext}")
        with open(path, "wb") as f:
            f.write(b"\x00" * file_size)

    manifest = os.path.join(captures_dir, f"capture_{run_id}.manifest.json")
    with open(manifest, "w") as f:
        json.dump({
            "schemaVersion": "1",
            "runId": run_id,
            "startedAt": started_at,
        }, f)

    # Create latest.* symlinks
    for ext in ["flow", "har", "log", "manifest.json", "index.ndjson",
                "summary.md", "ai.json", "ai.md"]:
        src = os.path.join(captures_dir, f"capture_{run_id}.{ext}")
        link = os.path.join(captures_dir, f"latest.{ext}")
        try:
            os.symlink(src, link + ".tmp")
            os.replace(link + ".tmp", link)
        except OSError:
            pass


# ── parse_size tests ─────────────────────────────────────────────────


def test_parse_size_bytes():
    assert parse_size("1024") == 1024


def test_parse_size_kilobytes():
    assert parse_size("1K") == 1024
    assert parse_size("1k") == 1024
    assert parse_size("1KB") == 1024


def test_parse_size_megabytes():
    assert parse_size("1M") == 1024 * 1024
    assert parse_size("500M") == 500 * 1024 * 1024


def test_parse_size_gigabytes():
    assert parse_size("1G") == 1024 ** 3
    assert parse_size("2g") == 2 * 1024 ** 3


def test_parse_size_fractional():
    assert parse_size("1.5G") == int(1.5 * 1024 ** 3)


def test_parse_size_invalid():
    with pytest.raises(ValueError):
        parse_size("abc")


# ── format_size tests ────────────────────────────────────────────────


def test_format_size_bytes():
    assert format_size(100) == "100B"


def test_format_size_kilobytes():
    assert format_size(2048) == "2.0K"


def test_format_size_megabytes():
    assert format_size(5 * 1024 * 1024) == "5.0M"


def test_format_size_gigabytes():
    assert format_size(3 * 1024 ** 3) == "3.0G"


# ── discover_sessions tests ──────────────────────────────────────────


def test_discover_sessions_empty():
    with tempfile.TemporaryDirectory() as tmpdir:
        sessions = discover_sessions(tmpdir)
        assert sessions == []


def test_discover_sessions_finds_manifest():
    with tempfile.TemporaryDirectory() as tmpdir:
        create_session(tmpdir, "20260101_120000_111")
        sessions = discover_sessions(tmpdir)
        assert len(sessions) == 1
        assert sessions[0]["run_id"] == "20260101_120000_111"
        assert sessions[0]["timestamp"] == "2026-01-01T12:00:00"


def test_discover_sessions_finds_orphan_flow():
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create flow file without manifest
        flow_path = os.path.join(tmpdir, "capture_20260101_120000_222.flow")
        with open(flow_path, "w") as f:
            f.write("data")
        sessions = discover_sessions(tmpdir)
        assert len(sessions) == 1
        assert sessions[0]["run_id"] == "20260101_120000_222"


def test_discover_sessions_sorted_oldest_first():
    with tempfile.TemporaryDirectory() as tmpdir:
        create_session(tmpdir, "20260301_120000_333")
        create_session(tmpdir, "20260101_120000_111")
        create_session(tmpdir, "20260201_120000_222")
        sessions = discover_sessions(tmpdir)
        ids = [s["run_id"] for s in sessions]
        assert ids == [
            "20260101_120000_111",
            "20260201_120000_222",
            "20260301_120000_333",
        ]


# ── session_files tests ──────────────────────────────────────────────


def test_session_files():
    with tempfile.TemporaryDirectory() as tmpdir:
        create_session(tmpdir, "20260101_120000_111")
        files = session_files(tmpdir, "20260101_120000_111")
        # 8 data files + 1 manifest = 9
        assert len(files) == 9


# ── is_latest_target / update_latest_links tests ─────────────────────


def test_is_latest_target():
    with tempfile.TemporaryDirectory() as tmpdir:
        create_session(tmpdir, "20260101_120000_111")
        assert is_latest_target(tmpdir, "20260101_120000_111") is True
        assert is_latest_target(tmpdir, "20260101_120000_999") is False


def test_update_latest_links():
    with tempfile.TemporaryDirectory() as tmpdir:
        create_session(tmpdir, "20260101_120000_111")
        create_session(tmpdir, "20260201_120000_222")
        # Remove the newer session's files but keep symlinks pointing to it
        for ext in ["flow", "har", "log", "index.ndjson", "summary.md",
                    "ai.json", "ai.md", "scope_audit.json", "manifest.json"]:
            path = os.path.join(tmpdir, f"capture_20260201_120000_222.{ext}")
            if os.path.exists(path):
                os.remove(path)

        update_latest_links(tmpdir)
        link = os.path.join(tmpdir, "latest.flow")
        target = os.readlink(link)
        assert "20260101_120000_111" in target


# ── compute_cutoff tests ─────────────────────────────────────────────


def test_compute_cutoff_format():
    cutoff = compute_cutoff(7)
    # Should be ISO format without timezone
    assert "T" in cutoff
    assert len(cutoff) == 19  # YYYY-MM-DDTHH:MM:SS


# ── run_cleanup integration tests ────────────────────────────────────


def test_cleanup_empty_dir():
    with tempfile.TemporaryDirectory() as tmpdir:
        result = run_cleanup(tmpdir, keep_days=7)
        assert result["status"] == "empty"
        assert result["deleted"] == 0


def test_cleanup_no_dir():
    result = run_cleanup("/nonexistent/path", keep_days=7)
    assert result["status"] == "no-dir"


def test_cleanup_keep_days_deletes_old():
    with tempfile.TemporaryDirectory() as tmpdir:
        # Old session (2020)
        create_session(tmpdir, "20200101_120000_111")
        # Recent session (1 hour ago — dynamically computed)
        recent = datetime.now() - timedelta(hours=1)
        recent_id = recent.strftime("%Y%m%d_%H%M%S") + "_222"
        create_session(tmpdir, recent_id)

        result = run_cleanup(tmpdir, keep_days=7)
        assert result["status"] == "ok"
        assert result["deleted"] == 1
        assert result["kept"] == 1

        # Old session files should be gone
        old_files = [f for f in os.listdir(tmpdir) if "20200101" in f]
        assert len(old_files) == 0

        # Recent session files should remain
        new_files = [f for f in os.listdir(tmpdir) if recent_id in f]
        assert len(new_files) > 0


def test_cleanup_dry_run():
    with tempfile.TemporaryDirectory() as tmpdir:
        create_session(tmpdir, "20200101_120000_111")

        result = run_cleanup(tmpdir, keep_days=7, dry_run=True)
        assert result["status"] == "ok"
        assert result["dry_run"] is True
        assert result["deleted"] == 1

        # Files should still exist (dry run)
        files = [f for f in os.listdir(tmpdir) if "20200101" in f]
        assert len(files) > 0


def test_cleanup_keep_size():
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create 3 sessions of ~900 bytes each (100 * 8 + ~60 manifest)
        create_session(tmpdir, "20260101_120000_111", 100)
        create_session(tmpdir, "20260102_120000_222", 100)
        create_session(tmpdir, "20260103_120000_333", 100)

        # Keep only enough for ~1 session
        result = run_cleanup(tmpdir, keep_size="1K")
        assert result["status"] == "ok"
        assert result["deleted"] >= 1

        # Newest should remain
        newest_files = [f for f in os.listdir(tmpdir)
                        if "20260103_120000_333" in f]
        assert len(newest_files) > 0


def test_cleanup_nothing_to_delete():
    with tempfile.TemporaryDirectory() as tmpdir:
        create_session(tmpdir, "20260201_120000_111")

        result = run_cleanup(tmpdir, keep_days=365)
        assert result["status"] == "nothing"
        assert result["deleted"] == 0
