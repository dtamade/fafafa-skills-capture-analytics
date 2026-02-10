#!/usr/bin/env bash
# Tests for release-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_CHECK_SCRIPT="$SCRIPT_DIR/../scripts/release-check.sh"

test_help() {
    if "$RELEASE_CHECK_SCRIPT" --help | grep -q "release-check.sh"; then
        echo "✓ test_help passed"
        return 0
    else
        echo "✗ test_help failed"
        return 1
    fi
}

test_dry_run() {
    local out
    out="$($RELEASE_CHECK_SCRIPT --dry-run 2>&1)"

    if echo "$out" | grep -q "Dry-run complete." &&
       echo "$out" | grep -q "\[STEP\] Install check" &&
       echo "$out" | grep -q "\[STEP\] Python tests" &&
       echo "$out" | grep -q "\[STEP\] Shell tests" &&
       echo "$out" | grep -q "\[STEP\] Doctor"; then
        echo "✓ test_dry_run passed"
        return 0
    else
        echo "✗ test_dry_run failed"
        echo "--- output ---"
        echo "$out"
        echo "--------------"
        return 1
    fi
}

test_skip_flags() {
    local out
    out="$($RELEASE_CHECK_SCRIPT --dry-run --skip-install-check --skip-python-tests --skip-shell-tests --skip-doctor 2>&1)"

    if echo "$out" | grep -q "\[SKIP\] Install check" &&
       echo "$out" | grep -q "\[SKIP\] Python tests" &&
       echo "$out" | grep -q "\[SKIP\] Shell tests" &&
       echo "$out" | grep -q "\[SKIP\] Doctor"; then
        echo "✓ test_skip_flags passed"
        return 0
    else
        echo "✗ test_skip_flags failed"
        echo "--- output ---"
        echo "$out"
        echo "--------------"
        return 1
    fi
}

test_unknown_option_fails() {
    if "$RELEASE_CHECK_SCRIPT" --not-a-real-option >/dev/null 2>&1; then
        echo "✗ test_unknown_option_fails failed"
        return 1
    else
        echo "✓ test_unknown_option_fails passed"
        return 0
    fi
}

test_nullglob_guard_present() {
    if grep -q 'shopt -s nullglob' "$RELEASE_CHECK_SCRIPT" &&
       grep -q 'No shell tests found in tests/test_\*\.sh' "$RELEASE_CHECK_SCRIPT"; then
        echo "✓ test_nullglob_guard_present passed"
        return 0
    else
        echo "✗ test_nullglob_guard_present failed"
        return 1
    fi
}

run_all_tests() {
    echo "Running release-check.sh tests..."
    echo ""

    local failed=0

    test_help || ((failed++))
    test_dry_run || ((failed++))
    test_skip_flags || ((failed++))
    test_unknown_option_fails || ((failed++))
    test_nullglob_guard_present || ((failed++))

    echo ""
    if [[ "$failed" -eq 0 ]]; then
        echo "✓ All release-check tests passed!"
        return 0
    else
        echo "✗ $failed test(s) failed"
        return 1
    fi
}

run_all_tests
