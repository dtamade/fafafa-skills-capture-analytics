#!/usr/bin/env python3
"""Compare two capture index files and report differences.

Reads two index.ndjson files (baseline and current), aggregates by endpoint,
and outputs added/removed endpoints, status code changes, and latency shifts.
"""

import json
import sys
import os
from collections import Counter, defaultdict
from datetime import datetime, timezone


def load_index(path):
    """Load an index.ndjson file into a list of dicts (capped at 100000 entries)."""
    MAX_ENTRIES = 100000
    entries = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            text = line.strip()
            if not text:
                continue
            entries.append(json.loads(text))
            if len(entries) >= MAX_ENTRIES:
                break
    return entries


def endpoint_key(entry):
    """Produce a stable key for an endpoint: METHOD host+path."""
    method = entry.get("method") or ""
    host = entry.get("host") or ""
    path = entry.get("path") or ""
    return f"{method} {host}{path}"


def aggregate_endpoints(entries):
    """Aggregate entries by endpoint key.

    Returns dict: endpoint_key -> {
        count, methods, hosts, statuses, durations,
        avg_ms, p95_ms, status_buckets, error_count
    }
    """
    groups = defaultdict(lambda: {
        "count": 0,
        "durations": [],
        "statuses": [],
        "status_buckets": Counter(),
    })

    for entry in entries:
        key = endpoint_key(entry)
        g = groups[key]
        g["count"] += 1

        duration = entry.get("durationMs")
        if isinstance(duration, (int, float)):
            g["durations"].append(duration)

        status = entry.get("status")
        if status is not None:
            g["statuses"].append(status)

        bucket = entry.get("statusBucket") or "unknown"
        g["status_buckets"][bucket] += 1

    result = {}
    for key, g in groups.items():
        durations = g["durations"]
        avg_ms = int(sum(durations) / len(durations)) if durations else 0
        p95_ms = 0
        if durations:
            sorted_d = sorted(durations)
            p95_idx = int((len(sorted_d) - 1) * 0.95)
            p95_ms = sorted_d[p95_idx]

        error_count = g["status_buckets"].get("4xx", 0) + g["status_buckets"].get("5xx", 0)

        result[key] = {
            "count": g["count"],
            "avg_ms": avg_ms,
            "p95_ms": p95_ms,
            "error_count": error_count,
            "status_buckets": dict(g["status_buckets"]),
        }

    return result


def compute_diff(baseline_agg, current_agg, latency_threshold=0.20):
    """Compute the diff between two aggregated endpoint dictionaries.

    Args:
        baseline_agg: aggregated endpoints from the baseline capture
        current_agg: aggregated endpoints from the current capture
        latency_threshold: fractional change to flag (default 20%)

    Returns a dict with:
        added, removed, changed, unchanged counts and details.
    """
    baseline_keys = set(baseline_agg.keys())
    current_keys = set(current_agg.keys())

    added_keys = sorted(current_keys - baseline_keys)
    removed_keys = sorted(baseline_keys - current_keys)
    common_keys = sorted(baseline_keys & current_keys)

    added = []
    for key in added_keys:
        c = current_agg[key]
        added.append({
            "endpoint": key,
            "count": c["count"],
            "avg_ms": c["avg_ms"],
            "status_buckets": c["status_buckets"],
        })

    removed = []
    for key in removed_keys:
        b = baseline_agg[key]
        removed.append({
            "endpoint": key,
            "count": b["count"],
            "avg_ms": b["avg_ms"],
            "status_buckets": b["status_buckets"],
        })

    changed = []
    unchanged_count = 0

    for key in common_keys:
        b = baseline_agg[key]
        c = current_agg[key]

        # Detect status bucket changes
        status_changed = b["status_buckets"] != c["status_buckets"]

        # Detect latency regression/improvement
        latency_flag = ""
        latency_delta_pct = 0.0
        if b["avg_ms"] > 0:
            latency_delta_pct = (c["avg_ms"] - b["avg_ms"]) / b["avg_ms"]
            if latency_delta_pct > latency_threshold:
                latency_flag = "regression"
            elif latency_delta_pct < -latency_threshold:
                latency_flag = "improvement"

        # Detect error count changes
        error_delta = c["error_count"] - b["error_count"]

        # Detect request count changes
        count_delta = c["count"] - b["count"]

        has_change = status_changed or latency_flag or error_delta != 0

        if has_change:
            change = {
                "endpoint": key,
                "baseline": {
                    "count": b["count"],
                    "avg_ms": b["avg_ms"],
                    "p95_ms": b["p95_ms"],
                    "error_count": b["error_count"],
                    "status_buckets": b["status_buckets"],
                },
                "current": {
                    "count": c["count"],
                    "avg_ms": c["avg_ms"],
                    "p95_ms": c["p95_ms"],
                    "error_count": c["error_count"],
                    "status_buckets": c["status_buckets"],
                },
                "deltas": {
                    "count": count_delta,
                    "avg_ms": c["avg_ms"] - b["avg_ms"],
                    "error_count": error_delta,
                    "latency_pct": round(latency_delta_pct * 100, 1),
                },
                "flags": [],
            }
            if latency_flag:
                change["flags"].append(latency_flag)
            if status_changed:
                change["flags"].append("status-changed")
            if error_delta > 0:
                change["flags"].append("more-errors")
            elif error_delta < 0:
                change["flags"].append("fewer-errors")
            changed.append(change)
        else:
            unchanged_count += 1

    # Sort changed by severity: regressions first, then by absolute latency delta
    changed.sort(key=lambda c: (
        "regression" not in c["flags"],
        "more-errors" not in c["flags"],
        -abs(c["deltas"]["avg_ms"]),
    ))

    return {
        "added": added,
        "removed": removed,
        "changed": changed,
        "summary": {
            "baseline_endpoints": len(baseline_keys),
            "current_endpoints": len(current_keys),
            "added": len(added),
            "removed": len(removed),
            "changed": len(changed),
            "unchanged": unchanged_count,
        },
    }


def render_diff_json(diff_result, baseline_path, current_path):
    """Wrap diff_result in a full JSON report."""
    return {
        "schemaVersion": "1",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "baseline": baseline_path,
        "current": current_path,
        "summary": diff_result["summary"],
        "added": diff_result["added"],
        "removed": diff_result["removed"],
        "changed": diff_result["changed"],
    }


def render_diff_markdown(diff_result, baseline_path, current_path):
    """Render diff_result as a human/AI-readable Markdown string."""
    lines = []
    s = diff_result["summary"]

    lines.append("# Capture Diff Report")
    lines.append("")
    lines.append(f"- Baseline: `{baseline_path}`")
    lines.append(f"- Current:  `{current_path}`")
    lines.append(f"- Generated: `{datetime.now(timezone.utc).isoformat()}`")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"| Metric | Count |")
    lines.append(f"| --- | --- |")
    lines.append(f"| Baseline endpoints | {s['baseline_endpoints']} |")
    lines.append(f"| Current endpoints | {s['current_endpoints']} |")
    lines.append(f"| Added | {s['added']} |")
    lines.append(f"| Removed | {s['removed']} |")
    lines.append(f"| Changed | {s['changed']} |")
    lines.append(f"| Unchanged | {s['unchanged']} |")
    lines.append("")

    if diff_result["added"]:
        lines.append("## Added Endpoints")
        lines.append("")
        lines.append("| Endpoint | Count | Avg ms | Status |")
        lines.append("| --- | --- | --- | --- |")
        for item in diff_result["added"]:
            buckets = ", ".join(f"{k}:{v}" for k, v in sorted(item["status_buckets"].items()))
            lines.append(f"| `{item['endpoint']}` | {item['count']} | {item['avg_ms']} | {buckets} |")
        lines.append("")

    if diff_result["removed"]:
        lines.append("## Removed Endpoints")
        lines.append("")
        lines.append("| Endpoint | Count | Avg ms | Status |")
        lines.append("| --- | --- | --- | --- |")
        for item in diff_result["removed"]:
            buckets = ", ".join(f"{k}:{v}" for k, v in sorted(item["status_buckets"].items()))
            lines.append(f"| `{item['endpoint']}` | {item['count']} | {item['avg_ms']} | {buckets} |")
        lines.append("")

    if diff_result["changed"]:
        lines.append("## Changed Endpoints")
        lines.append("")
        lines.append("| Endpoint | Flags | Avg ms (B→C) | Latency Δ% | Errors (B→C) |")
        lines.append("| --- | --- | --- | --- | --- |")
        for item in diff_result["changed"]:
            flags = ", ".join(item["flags"]) if item["flags"] else "-"
            b_avg = item["baseline"]["avg_ms"]
            c_avg = item["current"]["avg_ms"]
            delta_pct = item["deltas"]["latency_pct"]
            b_err = item["baseline"]["error_count"]
            c_err = item["current"]["error_count"]

            # Add visual indicator for regressions
            pct_str = f"{delta_pct:+.1f}%"
            if "regression" in item["flags"]:
                pct_str = f"**{pct_str}** ⚠"
            elif "improvement" in item["flags"]:
                pct_str = f"**{pct_str}** ✓"

            lines.append(f"| `{item['endpoint']}` | {flags} | {b_avg}→{c_avg} | {pct_str} | {b_err}→{c_err} |")
        lines.append("")

    if not diff_result["added"] and not diff_result["removed"] and not diff_result["changed"]:
        lines.append("**No differences detected.** The two captures have identical endpoint profiles.")
        lines.append("")

    return "\n".join(lines)


def main(argv):
    if len(argv) < 3 or "--help" in argv or "-h" in argv:
        print(f"Usage: {argv[0]} <baseline.index.ndjson> <current.index.ndjson> [--json <out.json>] [--md <out.md>] [--stdout]")
        print()
        print("Compares two capture index files and reports endpoint differences.")
        print()
        print("Options:")
        print("  --json <path>   Write JSON diff report to file")
        print("  --md <path>     Write Markdown diff report to file")
        print("  --stdout        Print Markdown report to stdout (default if no output specified)")
        return 0 if "--help" in argv or "-h" in argv else 1

    baseline_path = argv[1]
    current_path = argv[2]

    json_out = None
    md_out = None
    to_stdout = False

    i = 3
    while i < len(argv):
        if argv[i] == "--json" and i + 1 < len(argv):
            json_out = argv[i + 1]
            i += 2
        elif argv[i] == "--md" and i + 1 < len(argv):
            md_out = argv[i + 1]
            i += 2
        elif argv[i] == "--stdout":
            to_stdout = True
            i += 1
        else:
            print(f"Unknown option: {argv[i]}", file=sys.stderr)
            return 1

    # Default to stdout if no output specified
    if not json_out and not md_out:
        to_stdout = True

    # Validate inputs
    for path in (baseline_path, current_path):
        if not os.path.isfile(path):
            print(f"[ERROR] File not found: {path}", file=sys.stderr)
            return 1

    # Load and process
    baseline_entries = load_index(baseline_path)
    current_entries = load_index(current_path)

    baseline_agg = aggregate_endpoints(baseline_entries)
    current_agg = aggregate_endpoints(current_entries)

    diff_result = compute_diff(baseline_agg, current_agg)

    # Output
    if json_out:
        report = render_diff_json(diff_result, baseline_path, current_path)
        fd = os.open(json_out, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        print(f"JSON diff report: {json_out}", file=sys.stderr)

    md_text = render_diff_markdown(diff_result, baseline_path, current_path)

    if md_out:
        fd = os.open(md_out, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(md_text)
        print(f"Markdown diff report: {md_out}", file=sys.stderr)

    if to_stdout:
        print(md_text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
