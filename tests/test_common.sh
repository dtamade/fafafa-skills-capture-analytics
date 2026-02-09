#!/usr/bin/env bash
# Tests for common.sh: acquire_lock/release_lock, compute_sha256, read_kv edge cases

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

COMMON_SH="$(cd "$SCRIPT_DIR/../scripts" && pwd)/common.sh"
if [[ ! -f "$COMMON_SH" ]]; then
    echo "✗ Cannot find common.sh at $COMMON_SH" >&2
    exit 1
fi
source "$COMMON_SH"

PASSED=0
FAILED=0

pass() {
    echo "✓ $1 passed"
    ((PASSED++)) || true
}

fail() {
    echo "✗ $1 failed: $2"
    ((FAILED++)) || true
}

# ── acquire_lock / release_lock tests ────────────────────────

# Force mkdir backend for deterministic testing regardless of platform
_COMMON_LOCK_BACKEND="mkdir"

test_lock_acquire_release() {
    local lock="$TEMP_DIR/test1.lock"

    if acquire_lock "$lock"; then
        # Lock dir should exist
        if [[ -d "${lock}.d" ]]; then
            release_lock "$lock"
            if [[ ! -d "${lock}.d" ]]; then
                pass "test_lock_acquire_release"
            else
                fail "test_lock_acquire_release" "lock dir still exists after release"
            fi
        else
            fail "test_lock_acquire_release" "lock dir not created"
        fi
    else
        fail "test_lock_acquire_release" "acquire_lock returned non-zero"
    fi
}

test_lock_blocks_second_acquire() {
    local lock="$TEMP_DIR/test2.lock"

    acquire_lock "$lock"
    # Second acquire from same process should fail (lock dir already exists,
    # PID matches current process so kill -0 succeeds -> locked)
    if acquire_lock "$lock"; then
        fail "test_lock_blocks_second_acquire" "second acquire should fail"
        release_lock "$lock"
    else
        pass "test_lock_blocks_second_acquire"
        release_lock "$lock"
    fi
}

test_lock_stale_recovery() {
    local lock="$TEMP_DIR/test3.lock"
    local lock_dir="${lock}.d"

    # Simulate a stale lock from a dead PID
    mkdir -p "$lock_dir"
    echo "99999999" > "$lock_dir/pid"

    # acquire_lock should detect stale PID and recover
    if acquire_lock "$lock"; then
        local written_pid
        written_pid="$(cat "$lock_dir/pid")"
        if [[ "$written_pid" == "$$" ]]; then
            pass "test_lock_stale_recovery"
        else
            fail "test_lock_stale_recovery" "PID not updated: got '$written_pid', expected '$$'"
        fi
        release_lock "$lock"
    else
        fail "test_lock_stale_recovery" "failed to recover stale lock"
    fi
}

test_lock_pid_written() {
    local lock="$TEMP_DIR/test4.lock"
    local lock_dir="${lock}.d"

    acquire_lock "$lock"

    if [[ -f "$lock_dir/pid" ]]; then
        local pid_content
        pid_content="$(cat "$lock_dir/pid")"
        if [[ "$pid_content" == "$$" ]]; then
            pass "test_lock_pid_written"
        else
            fail "test_lock_pid_written" "expected PID '$$', got '$pid_content'"
        fi
    else
        fail "test_lock_pid_written" "pid file not created"
    fi
    release_lock "$lock"
}

test_lock_no_pid_file_blocks() {
    local lock="$TEMP_DIR/test5.lock"
    local lock_dir="${lock}.d"

    # Create lock dir without pid file (corrupted lock)
    mkdir -p "$lock_dir"

    # Should fail -- no pid file means we can't determine if stale
    if acquire_lock "$lock"; then
        fail "test_lock_no_pid_file_blocks" "should fail when lock dir exists without pid"
        release_lock "$lock"
    else
        pass "test_lock_no_pid_file_blocks"
    fi
    rm -rf "$lock_dir"
}

test_release_nonexistent_is_safe() {
    local lock="$TEMP_DIR/test6_nonexistent.lock"

    # Releasing a lock that was never acquired should not error
    release_lock "$lock"
    pass "test_release_nonexistent_is_safe"
}

# ── compute_sha256 tests ─────────────────────────────────────

test_sha256_known_value() {
    local test_file="$TEMP_DIR/sha_test.txt"
    printf 'hello\n' > "$test_file"

    local hash
    hash="$(compute_sha256 "$test_file")"

    # SHA-256 of "hello\n"
    local expected="5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03"
    if [[ "$hash" == "$expected" ]]; then
        pass "test_sha256_known_value"
    else
        fail "test_sha256_known_value" "expected '$expected', got '$hash'"
    fi
}

test_sha256_empty_file() {
    local test_file="$TEMP_DIR/sha_empty.txt"
    : > "$test_file"

    local hash
    hash="$(compute_sha256 "$test_file")"

    local expected="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    if [[ "$hash" == "$expected" ]]; then
        pass "test_sha256_empty_file"
    else
        fail "test_sha256_empty_file" "expected '$expected', got '$hash'"
    fi
}

test_sha256_missing_file() {
    if compute_sha256 "$TEMP_DIR/nonexistent_file" 2>/dev/null; then
        fail "test_sha256_missing_file" "should return non-zero for missing file"
    else
        pass "test_sha256_missing_file"
    fi
}

test_sha256_is_64_hex_chars() {
    local test_file="$TEMP_DIR/sha_len.txt"
    echo "test content for length check" > "$test_file"

    local hash
    hash="$(compute_sha256 "$test_file")"

    if [[ ${#hash} -eq 64 && "$hash" =~ ^[0-9a-f]+$ ]]; then
        pass "test_sha256_is_64_hex_chars"
    else
        fail "test_sha256_is_64_hex_chars" "hash='${hash}' (len=${#hash}), expected 64 hex chars"
    fi
}

test_sha256_binary_file() {
    local test_file="$TEMP_DIR/sha_binary.bin"
    printf '\x00\x01\x02\xff' > "$test_file"

    local hash
    hash="$(compute_sha256 "$test_file")"

    if [[ ${#hash} -eq 64 && "$hash" =~ ^[0-9a-f]+$ ]]; then
        pass "test_sha256_binary_file"
    else
        fail "test_sha256_binary_file" "failed on binary input: '$hash'"
    fi
}

# ── read_kv edge case tests ──────────────────────────────────

test_read_kv_empty_file_path() {
    local result
    result="$(read_kv "KEY" "")"
    if [[ -z "$result" ]]; then
        pass "test_read_kv_empty_file_path"
    else
        fail "test_read_kv_empty_file_path" "expected empty, got '$result'"
    fi
}

test_read_kv_nonexistent_file() {
    local result
    result="$(read_kv "KEY" "$TEMP_DIR/does_not_exist.env")"
    if [[ -z "$result" ]]; then
        pass "test_read_kv_nonexistent_file"
    else
        fail "test_read_kv_nonexistent_file" "expected empty, got '$result'"
    fi
}

test_read_kv_duplicate_keys_takes_last() {
    local test_file="$TEMP_DIR/dup.env"
    cat > "$test_file" <<EOF
KEY=first
KEY=second
EOF

    local result
    result="$(read_kv "KEY" "$test_file")"
    if [[ "$result" == "second" ]]; then
        pass "test_read_kv_duplicate_keys_takes_last"
    else
        fail "test_read_kv_duplicate_keys_takes_last" "expected 'second', got '$result'"
    fi
}

test_read_kv_value_with_equals() {
    local test_file="$TEMP_DIR/eq.env"
    cat > "$test_file" <<EOF
URL=https://example.com?a=1&b=2
EOF

    local result
    result="$(read_kv "URL" "$test_file")"
    if [[ "$result" == "https://example.com?a=1&b=2" ]]; then
        pass "test_read_kv_value_with_equals"
    else
        fail "test_read_kv_value_with_equals" "expected full URL, got '$result'"
    fi
}

# ── Run all ──────────────────────────────────────────────────

echo "Running common.sh tests..."
echo ""

echo "-- acquire_lock / release_lock (mkdir backend) --"
test_lock_acquire_release
test_lock_blocks_second_acquire
test_lock_stale_recovery
test_lock_pid_written
test_lock_no_pid_file_blocks
test_release_nonexistent_is_safe

echo ""
echo "-- compute_sha256 --"
test_sha256_known_value
test_sha256_empty_file
test_sha256_missing_file
test_sha256_is_64_hex_chars
test_sha256_binary_file

echo ""
echo "-- read_kv edge cases --"
test_read_kv_empty_file_path
test_read_kv_nonexistent_file
test_read_kv_duplicate_keys_takes_last
test_read_kv_value_with_equals

echo ""
echo "Results: $PASSED passed, $FAILED failed (total $((PASSED + FAILED)))"
[[ $FAILED -eq 0 ]]
