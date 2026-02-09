#!/usr/bin/env bash
# Tests for read_kv regex escape fix (M1)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

# Source read_kv from common.sh (single source of truth)
COMMON_SH="$(cd "$SCRIPT_DIR/../scripts" && pwd)/common.sh"
if [[ ! -f "$COMMON_SH" ]]; then
    echo "✗ Cannot find common.sh at $COMMON_SH" >&2
    exit 1
fi
source "$COMMON_SH"

# Test 1: Normal key lookup
test_normal_key() {
    local test_file="$TEMP_DIR/test1.env"
    cat > "$test_file" <<EOF
MITM_PID=12345
LISTEN_PORT=18080
EOF

    local result
    result="$(read_kv "MITM_PID" "$test_file")"
    if [[ "$result" == "12345" ]]; then
        echo "✓ test_normal_key passed"
        return 0
    else
        echo "✗ test_normal_key failed: expected '12345', got '$result'"
        return 1
    fi
}

# Test 2: Key with regex special characters should be escaped
test_regex_special_chars_in_key() {
    local test_file="$TEMP_DIR/test2.env"
    cat > "$test_file" <<EOF
KEY.WITH.DOTS=value1
NORMAL_KEY=value2
EOF

    # Without escaping, "KEY.WITH.DOTS" would match "KEY_WITH_DOTS" etc.
    # With escaping, only exact match should work
    local result
    result="$(read_kv "KEY.WITH.DOTS" "$test_file")"
    if [[ "$result" == "value1" ]]; then
        echo "✓ test_regex_special_chars_in_key passed"
        return 0
    else
        echo "✗ test_regex_special_chars_in_key failed: expected 'value1', got '$result'"
        return 1
    fi
}

# Test 3: Wildcard key should NOT match other keys (regex injection prevention)
test_regex_injection_prevention() {
    local test_file="$TEMP_DIR/test3.env"
    cat > "$test_file" <<EOF
SECRET_KEY=should_not_match
OTHER.*KEY=malicious_pattern
EOF

    # If ".*" is not escaped, it would match any key starting with "OTHER"
    # and containing "KEY". After escaping, it should only match literal "OTHER.*KEY"
    local result
    result="$(read_kv "OTHER.*KEY" "$test_file")"
    if [[ "$result" == "malicious_pattern" ]]; then
        echo "✓ test_regex_injection_prevention passed"
        return 0
    else
        echo "✗ test_regex_injection_prevention failed: expected 'malicious_pattern', got '$result'"
        return 1
    fi
}

# Test 4: Key with brackets should be escaped
test_brackets_in_key() {
    local test_file="$TEMP_DIR/test4.env"
    cat > "$test_file" <<EOF
KEY[0]=first
KEY[1]=second
EOF

    local result
    result="$(read_kv "KEY[0]" "$test_file")"
    if [[ "$result" == "first" ]]; then
        echo "✓ test_brackets_in_key passed"
        return 0
    else
        echo "✗ test_brackets_in_key failed: expected 'first', got '$result'"
        return 1
    fi
}

# Test 5: Non-existent key should return empty
test_missing_key() {
    local test_file="$TEMP_DIR/test5.env"
    cat > "$test_file" <<EOF
EXISTING_KEY=value
EOF

    local result
    result="$(read_kv "NONEXISTENT_KEY" "$test_file")"
    if [[ -z "$result" ]]; then
        echo "✓ test_missing_key passed"
        return 0
    else
        echo "✗ test_missing_key failed: expected empty, got '$result'"
        return 1
    fi
}

# Test 6: Quoted values should be unquoted
test_quoted_values() {
    local test_file="$TEMP_DIR/test6.env"
    cat > "$test_file" <<EOF
DOUBLE_QUOTED="hello world"
SINGLE_QUOTED='hello world'
UNQUOTED=hello
EOF

    local result1 result2 result3
    result1="$(read_kv "DOUBLE_QUOTED" "$test_file")"
    result2="$(read_kv "SINGLE_QUOTED" "$test_file")"
    result3="$(read_kv "UNQUOTED" "$test_file")"

    local passed=true
    if [[ "$result1" != "hello world" ]]; then
        echo "✗ test_quoted_values (double) failed: expected 'hello world', got '$result1'"
        passed=false
    fi
    if [[ "$result2" != "hello world" ]]; then
        echo "✗ test_quoted_values (single) failed: expected 'hello world', got '$result2'"
        passed=false
    fi
    if [[ "$result3" != "hello" ]]; then
        echo "✗ test_quoted_values (unquoted) failed: expected 'hello', got '$result3'"
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        echo "✓ test_quoted_values passed"
        return 0
    fi
    return 1
}

# Run all tests
run_all_tests() {
    echo "Running read_kv tests (M1 regex escape fix)..."
    echo ""

    local failed=0

    test_normal_key || ((failed++))
    test_regex_special_chars_in_key || ((failed++))
    test_regex_injection_prevention || ((failed++))
    test_brackets_in_key || ((failed++))
    test_missing_key || ((failed++))
    test_quoted_values || ((failed++))

    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "✓ All read_kv tests passed!"
        return 0
    else
        echo "✗ $failed test(s) failed"
        return 1
    fi
}

run_all_tests
