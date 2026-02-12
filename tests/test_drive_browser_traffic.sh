#!/usr/bin/env bash
# Tests for driveBrowserTraffic.sh (argument contract only)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DRIVE_SCRIPT="$SCRIPT_DIR/../scripts/driveBrowserTraffic.sh"
PASS=0
FAIL=0

report() {
    local name="$1"
    local result="$2"
    if [[ "$result" == "pass" ]]; then
        PASS=$((PASS + 1))
        echo "✓ $name passed"
    else
        FAIL=$((FAIL + 1))
        echo "✗ $name failed"
    fi
}

test_help() {
    if "$DRIVE_SCRIPT" --help 2>&1 | grep -q "driveBrowserTraffic.sh"; then
        report "test_help" "pass"
    else
        report "test_help" "fail"
    fi
}

test_requires_url() {
    local output
    output="$($DRIVE_SCRIPT 2>&1 || true)"

    if echo "$output" | grep -q -- "--url is required"; then
        report "test_requires_url" "pass"
    else
        report "test_requires_url" "fail"
    fi
}

test_invalid_mode() {
    local output
    output="$($DRIVE_SCRIPT --url https://example.com --mode weird 2>&1 || true)"

    if echo "$output" | grep -q "Invalid --mode"; then
        report "test_invalid_mode" "pass"
    else
        report "test_invalid_mode" "fail"
    fi
}

test_invalid_port() {
    local output
    output="$($DRIVE_SCRIPT --url https://example.com -P abc 2>&1 || true)"

    if echo "$output" | grep -q "Invalid port"; then
        report "test_invalid_port" "pass"
    else
        report "test_invalid_port" "fail"
    fi
}

echo "Running drive-browser-traffic tests..."
echo ""

test_help
test_requires_url
test_invalid_mode
test_invalid_port

echo ""
echo "Results: $PASS passed, $FAIL failed (total $((PASS + FAIL)))"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
