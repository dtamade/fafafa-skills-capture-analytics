#!/usr/bin/env python3
"""Tests for the diff_captures module."""

import sys
import os
import json
import tempfile

# Add scripts directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

from diff_captures import (
    load_index,
    endpoint_key,
    aggregate_endpoints,
    compute_diff,
    render_diff_json,
    render_diff_markdown,
)


def make_entry(method="GET", host="api.example.com", path="/users", status=200,
               duration_ms=100, status_bucket="2xx"):
    """Create a minimal index entry for testing."""
    return {
        "id": 1,
        "method": method,
        "host": host,
        "path": path,
        "url": f"https://{host}{path}",
        "status": status,
        "statusBucket": status_bucket,
        "durationMs": duration_ms,
        "requestBytes": 100,
        "responseBytes": 500,
    }


def write_ndjson(entries, path):
    """Write entries as NDJSON to a file."""
    with open(path, 'w') as f:
        for entry in entries:
            f.write(json.dumps(entry) + '\n')


def test_endpoint_key():
    """Test endpoint key generation."""
    entry = make_entry(method="POST", host="api.com", path="/login")
    key = endpoint_key(entry)
    assert key == "POST api.com/login", f"Expected 'POST api.com/login', got '{key}'"
    print('✓ test_endpoint_key passed')


def test_aggregate_endpoints():
    """Test endpoint aggregation."""
    entries = [
        make_entry(duration_ms=100),
        make_entry(duration_ms=200),
        make_entry(duration_ms=300),
    ]
    agg = aggregate_endpoints(entries)
    key = "GET api.example.com/users"
    assert key in agg
    assert agg[key]["count"] == 3
    assert agg[key]["avg_ms"] == 200  # (100+200+300)/3
    assert agg[key]["error_count"] == 0
    print('✓ test_aggregate_endpoints passed')


def test_aggregate_with_errors():
    """Test aggregation counts errors correctly."""
    entries = [
        make_entry(status=200, status_bucket="2xx"),
        make_entry(status=404, status_bucket="4xx"),
        make_entry(status=500, status_bucket="5xx"),
    ]
    agg = aggregate_endpoints(entries)
    key = "GET api.example.com/users"
    assert agg[key]["error_count"] == 2
    print('✓ test_aggregate_with_errors passed')


def test_diff_added_endpoints():
    """Test detection of newly added endpoints."""
    baseline = [
        make_entry(path="/users"),
    ]
    current = [
        make_entry(path="/users"),
        make_entry(path="/orders"),
    ]

    b_agg = aggregate_endpoints(baseline)
    c_agg = aggregate_endpoints(current)
    result = compute_diff(b_agg, c_agg)

    assert result["summary"]["added"] == 1
    assert result["summary"]["removed"] == 0
    assert result["added"][0]["endpoint"] == "GET api.example.com/orders"
    print('✓ test_diff_added_endpoints passed')


def test_diff_removed_endpoints():
    """Test detection of removed endpoints."""
    baseline = [
        make_entry(path="/users"),
        make_entry(path="/legacy"),
    ]
    current = [
        make_entry(path="/users"),
    ]

    b_agg = aggregate_endpoints(baseline)
    c_agg = aggregate_endpoints(current)
    result = compute_diff(b_agg, c_agg)

    assert result["summary"]["removed"] == 1
    assert result["removed"][0]["endpoint"] == "GET api.example.com/legacy"
    print('✓ test_diff_removed_endpoints passed')


def test_diff_status_change():
    """Test detection of status code changes."""
    baseline = [
        make_entry(status=200, status_bucket="2xx"),
    ]
    current = [
        make_entry(status=500, status_bucket="5xx"),
    ]

    b_agg = aggregate_endpoints(baseline)
    c_agg = aggregate_endpoints(current)
    result = compute_diff(b_agg, c_agg)

    assert result["summary"]["changed"] == 1
    change = result["changed"][0]
    assert "status-changed" in change["flags"]
    assert "more-errors" in change["flags"]
    print('✓ test_diff_status_change passed')


def test_diff_latency_regression():
    """Test detection of latency regression (>20%)."""
    baseline = [
        make_entry(duration_ms=100),
    ]
    current = [
        make_entry(duration_ms=150),  # 50% increase
    ]

    b_agg = aggregate_endpoints(baseline)
    c_agg = aggregate_endpoints(current)
    result = compute_diff(b_agg, c_agg)

    assert result["summary"]["changed"] == 1
    change = result["changed"][0]
    assert "regression" in change["flags"]
    assert change["deltas"]["latency_pct"] == 50.0
    print('✓ test_diff_latency_regression passed')


def test_diff_latency_improvement():
    """Test detection of latency improvement (>20% decrease)."""
    baseline = [
        make_entry(duration_ms=200),
    ]
    current = [
        make_entry(duration_ms=100),  # 50% decrease
    ]

    b_agg = aggregate_endpoints(baseline)
    c_agg = aggregate_endpoints(current)
    result = compute_diff(b_agg, c_agg)

    assert result["summary"]["changed"] == 1
    change = result["changed"][0]
    assert "improvement" in change["flags"]
    print('✓ test_diff_latency_improvement passed')


def test_diff_no_change():
    """Test identical captures produce no changes."""
    entries = [
        make_entry(duration_ms=100),
    ]

    agg = aggregate_endpoints(entries)
    result = compute_diff(agg, agg)

    assert result["summary"]["added"] == 0
    assert result["summary"]["removed"] == 0
    assert result["summary"]["changed"] == 0
    assert result["summary"]["unchanged"] == 1
    print('✓ test_diff_no_change passed')


def test_diff_small_latency_change_ignored():
    """Test that small latency changes (<20%) are not flagged."""
    baseline = [
        make_entry(duration_ms=100),
    ]
    current = [
        make_entry(duration_ms=115),  # 15% increase - under threshold
    ]

    b_agg = aggregate_endpoints(baseline)
    c_agg = aggregate_endpoints(current)
    result = compute_diff(b_agg, c_agg)

    # No latency flag, but still might show as unchanged if nothing else changed
    assert result["summary"]["unchanged"] == 1 or (
        result["summary"]["changed"] == 0
    )
    print('✓ test_diff_small_latency_change_ignored passed')


def test_render_json():
    """Test JSON rendering includes required fields."""
    baseline = [make_entry(path="/a")]
    current = [make_entry(path="/b")]

    b_agg = aggregate_endpoints(baseline)
    c_agg = aggregate_endpoints(current)
    diff_result = compute_diff(b_agg, c_agg)

    report = render_diff_json(diff_result, "a.ndjson", "b.ndjson")
    assert report["schemaVersion"] == "1"
    assert report["baseline"] == "a.ndjson"
    assert report["current"] == "b.ndjson"
    assert "summary" in report
    assert "added" in report
    assert "removed" in report
    print('✓ test_render_json passed')


def test_render_markdown():
    """Test Markdown rendering is valid and contains key sections."""
    baseline = [make_entry(path="/old", duration_ms=100)]
    current = [
        make_entry(path="/new", duration_ms=200),
        make_entry(path="/old", duration_ms=200, status=500, status_bucket="5xx"),
    ]

    b_agg = aggregate_endpoints(baseline)
    c_agg = aggregate_endpoints(current)
    diff_result = compute_diff(b_agg, c_agg)

    md = render_diff_markdown(diff_result, "baseline.ndjson", "current.ndjson")
    assert "# Capture Diff Report" in md
    assert "## Summary" in md
    assert "Added Endpoints" in md
    assert "Changed Endpoints" in md
    print('✓ test_render_markdown passed')


def test_load_and_diff_files():
    """Integration test: write NDJSON files, load, and diff."""
    baseline_entries = [
        make_entry(method="GET", host="api.com", path="/users", duration_ms=100, status=200, status_bucket="2xx"),
        make_entry(method="POST", host="api.com", path="/login", duration_ms=50, status=200, status_bucket="2xx"),
    ]
    current_entries = [
        make_entry(method="GET", host="api.com", path="/users", duration_ms=300, status=200, status_bucket="2xx"),
        make_entry(method="GET", host="api.com", path="/products", duration_ms=80, status=200, status_bucket="2xx"),
    ]

    with tempfile.NamedTemporaryFile(mode='w', suffix='.ndjson', delete=False) as bf:
        for e in baseline_entries:
            bf.write(json.dumps(e) + '\n')
        bf_path = bf.name

    with tempfile.NamedTemporaryFile(mode='w', suffix='.ndjson', delete=False) as cf:
        for e in current_entries:
            cf.write(json.dumps(e) + '\n')
        cf_path = cf.name

    try:
        b_entries = load_index(bf_path)
        c_entries = load_index(cf_path)

        assert len(b_entries) == 2
        assert len(c_entries) == 2

        b_agg = aggregate_endpoints(b_entries)
        c_agg = aggregate_endpoints(c_entries)
        result = compute_diff(b_agg, c_agg)

        # POST /login was removed
        assert result["summary"]["removed"] == 1
        # GET /products was added
        assert result["summary"]["added"] == 1
        # GET /users latency went from 100 to 300 (200% increase)
        assert result["summary"]["changed"] == 1
        change = result["changed"][0]
        assert "regression" in change["flags"]

        print('✓ test_load_and_diff_files passed')
    finally:
        os.unlink(bf_path)
        os.unlink(cf_path)


def test_empty_captures():
    """Test handling of empty captures."""
    result = compute_diff({}, {})
    assert result["summary"]["added"] == 0
    assert result["summary"]["removed"] == 0
    assert result["summary"]["changed"] == 0
    assert result["summary"]["unchanged"] == 0
    print('✓ test_empty_captures passed')


if __name__ == "__main__":
    print("Running diff_captures module tests...")
    print()

    test_endpoint_key()
    test_aggregate_endpoints()
    test_aggregate_with_errors()
    test_diff_added_endpoints()
    test_diff_removed_endpoints()
    test_diff_status_change()
    test_diff_latency_regression()
    test_diff_latency_improvement()
    test_diff_no_change()
    test_diff_small_latency_change_ignored()
    test_render_json()
    test_render_markdown()
    test_load_and_diff_files()
    test_empty_captures()

    print()
    print("✓ All diff_captures tests passed!")
