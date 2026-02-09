#!/usr/bin/env bash
# Tests for doctor.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCTOR_SCRIPT="$SCRIPT_DIR/../scripts/doctor.sh"

# Test 1: Help works
test_help() {
    if "$DOCTOR_SCRIPT" --help | grep -q "doctor.sh"; then
        echo "✓ test_help passed"
        return 0
    else
        echo "✗ test_help failed"
        return 1
    fi
}

# Test 2: JSON output is valid
test_json_output() {
    local json
    json="$("$DOCTOR_SCRIPT" --json 2>/dev/null || true)"

    if echo "$json" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        echo "✓ test_json_output passed"
        return 0
    else
        echo "✗ test_json_output failed: invalid JSON"
        return 1
    fi
}

# Test 3: JSON has required fields
test_json_structure() {
    local json
    json="$("$DOCTOR_SCRIPT" --json 2>/dev/null || true)"

    local has_checks has_summary
    has_checks="$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print('checks' in d)")"
    has_summary="$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print('summary' in d)")"

    if [[ "$has_checks" == "True" && "$has_summary" == "True" ]]; then
        echo "✓ test_json_structure passed"
        return 0
    else
        echo "✗ test_json_structure failed: missing checks or summary"
        return 1
    fi
}

# Test 4: Exit code reflects failures
test_exit_code() {
    # This test depends on environment, so we just verify it runs
    "$DOCTOR_SCRIPT" >/dev/null 2>&1
    local exit_code=$?

    # Exit code should be 0 or 1 (not crash)
    if [[ $exit_code -le 1 ]]; then
        echo "✓ test_exit_code passed (code: $exit_code)"
        return 0
    else
        echo "✗ test_exit_code failed: unexpected exit code $exit_code"
        return 1
    fi
}

# Test 5: Invalid port handling
test_invalid_port() {
    local json
    json="$("$DOCTOR_SCRIPT" --json -P 99999999 2>/dev/null || true)"

    if echo "$json" | grep -q '"status": "fail"'; then
        echo "✓ test_invalid_port passed"
        return 0
    else
        echo "✗ test_invalid_port failed"
        return 1
    fi
}

# Test 6: Policy validation
test_policy_validation() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap "rm -rf $temp_dir" RETURN

    # Valid policy
    echo '{"scope":{"allow_hosts":["test.com"]}}' > "$temp_dir/valid.json"

    local json
    json="$("$DOCTOR_SCRIPT" --json --policy "$temp_dir/valid.json" 2>/dev/null || true)"

    if echo "$json" | grep -q '"name": "policy"'; then
        echo "✓ test_policy_validation passed"
        return 0
    else
        echo "✗ test_policy_validation failed"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    echo "Running doctor.sh tests..."
    echo ""

    local failed=0

    test_help || ((failed++))
    test_json_output || ((failed++))
    test_json_structure || ((failed++))
    test_exit_code || ((failed++))
    test_invalid_port || ((failed++))
    test_policy_validation || ((failed++))

    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "✓ All doctor tests passed!"
        return 0
    else
        echo "✗ $failed test(s) failed"
        return 1
    fi
}

run_all_tests
