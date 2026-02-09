#!/usr/bin/env bash
# Tests for git-doctor.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_DOCTOR_SCRIPT="$SCRIPT_DIR/../scripts/git-doctor.sh"

test_help() {
    if "$GIT_DOCTOR_SCRIPT" --help | grep -q "git-doctor.sh"; then
        echo "✓ test_help passed"
        return 0
    else
        echo "✗ test_help failed"
        return 1
    fi
}

test_json_output() {
    local json
    json="$($GIT_DOCTOR_SCRIPT --json --timeout 10 2>/dev/null || true)"

    if echo "$json" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        echo "✓ test_json_output passed"
        return 0
    else
        echo "✗ test_json_output failed"
        return 1
    fi
}

test_json_structure() {
    local json
    json="$($GIT_DOCTOR_SCRIPT --json --timeout 10 2>/dev/null || true)"

    local has_checks has_summary
    has_checks="$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print('checks' in d)")"
    has_summary="$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print('summary' in d)")"

    if [[ "$has_checks" == "True" && "$has_summary" == "True" ]]; then
        echo "✓ test_json_structure passed"
        return 0
    else
        echo "✗ test_json_structure failed"
        return 1
    fi
}

test_invalid_timeout() {
    if "$GIT_DOCTOR_SCRIPT" --timeout 0 >/dev/null 2>&1; then
        echo "✗ test_invalid_timeout failed"
        return 1
    else
        echo "✓ test_invalid_timeout passed"
        return 0
    fi
}

test_missing_remote_fails() {
    local json
    local exit_code

    set +e
    json="$($GIT_DOCTOR_SCRIPT --json --remote __missing_remote__ --timeout 10 2>/dev/null)"
    exit_code=$?
    set -e

    if [[ "$exit_code" -eq 1 ]] && echo "$json" | grep -q '"name": "remote"'; then
        echo "✓ test_missing_remote_fails passed"
        return 0
    else
        echo "✗ test_missing_remote_fails failed"
        return 1
    fi
}

test_strict_mode_behavior() {
    local code_without_strict=0
    local code_with_strict=0

    set +e
    "$GIT_DOCTOR_SCRIPT" --remote origin --branch does-not-exist --timeout 10 >/dev/null 2>&1
    code_without_strict=$?
    "$GIT_DOCTOR_SCRIPT" --remote origin --branch does-not-exist --timeout 10 --strict >/dev/null 2>&1
    code_with_strict=$?
    set -e

    if [[ "$code_without_strict" -eq 0 && "$code_with_strict" -eq 1 ]]; then
        echo "✓ test_strict_mode_behavior passed"
        return 0
    else
        echo "✗ test_strict_mode_behavior failed (no_strict=$code_without_strict strict=$code_with_strict)"
        return 1
    fi
}

run_all_tests() {
    echo "Running git-doctor.sh tests..."
    echo ""

    local failed=0

    test_help || ((failed++))
    test_json_output || ((failed++))
    test_json_structure || ((failed++))
    test_invalid_timeout || ((failed++))
    test_missing_remote_fails || ((failed++))
    test_strict_mode_behavior || ((failed++))

    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "✓ All git-doctor tests passed!"
        return 0
    else
        echo "✗ $failed test(s) failed"
        return 1
    fi
}

run_all_tests
