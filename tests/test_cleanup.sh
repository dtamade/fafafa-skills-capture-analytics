#!/usr/bin/env bash
# Tests for cleanupCaptures.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLEANUP_SCRIPT="$SCRIPT_DIR/../scripts/cleanupCaptures.sh"
WRAPPER_SCRIPT="$SCRIPT_DIR/../scripts/capture-session.sh"
PASS=0
FAIL=0

# Create a temporary test directory
setup_test_dir() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    mkdir -p "$tmpdir/captures"
    echo "$tmpdir"
}

# Create a fake capture session with a given RUN_ID
# Usage: create_session <captures_dir> <run_id> [file_size_bytes]
create_session() {
    local captures_dir="$1"
    local run_id="$2"
    local file_size="${3:-100}"

    # Parse date from RUN_ID for manifest startedAt
    local date_part="${run_id%%_*}"
    local rest="${run_id#*_}"
    local time_part="${rest%%_*}"
    local started_at="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}T${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"

    # Create files of specified size
    for ext in flow har log index.ndjson summary.md ai.json ai.md scope_audit.json; do
        dd if=/dev/zero of="$captures_dir/capture_${run_id}.${ext}" bs=1 count="$file_size" 2>/dev/null
    done

    # Create manifest with startedAt
    cat > "$captures_dir/capture_${run_id}.manifest.json" <<EOF
{
  "schemaVersion": "1",
  "runId": "$run_id",
  "startedAt": "$started_at"
}
EOF

    # Create latest.* symlinks pointing to this session
    for ext in flow har log manifest.json index.ndjson summary.md ai.json ai.md; do
        ln -sfn "$captures_dir/capture_${run_id}.${ext}" "$captures_dir/latest.${ext}" 2>/dev/null || true
    done
}

cleanup_test_dir() {
    local tmpdir="$1"
    rm -rf "$tmpdir"
}

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

# ── Test 1: Help works ──────────────────────────────────────────────

test_help() {
    if "$CLEANUP_SCRIPT" --help 2>&1 | grep -q "cleanupCaptures.sh"; then
        report "test_help" "pass"
    else
        report "test_help" "fail"
    fi
}

# ── Test 2: Requires at least one policy ────────────────────────────

test_requires_policy() {
    local output
    output="$("$CLEANUP_SCRIPT" 2>&1 || true)"
    if echo "$output" | grep -q "At least one of"; then
        report "test_requires_policy" "pass"
    else
        report "test_requires_policy" "fail"
    fi
}

# ── Test 3: Dry-run does not delete files ───────────────────────────

test_dry_run_no_delete() {
    local tmpdir
    tmpdir="$(setup_test_dir)"

    # Create an old session (30 days ago)
    local old_date
    old_date="$(date -d '-30 days' +%Y%m%d_%H%M%S 2>/dev/null || date -v-30d +%Y%m%d_%H%M%S 2>/dev/null)"
    create_session "$tmpdir/captures" "${old_date}_99999"

    # Count files before
    local before
    before="$(find "$tmpdir/captures" -name 'capture_*' -type f | wc -l)"

    # Run with dry-run
    "$CLEANUP_SCRIPT" -d "$tmpdir" --keep-days 7 --dry-run >/dev/null 2>&1

    # Count files after
    local after
    after="$(find "$tmpdir/captures" -name 'capture_*' -type f | wc -l)"

    if [[ "$before" -eq "$after" && "$before" -gt 0 ]]; then
        report "test_dry_run_no_delete" "pass"
    else
        report "test_dry_run_no_delete" "fail"
    fi

    cleanup_test_dir "$tmpdir"
}

# ── Test 4: Keep-days correctly deletes old sessions ────────────────

test_keep_days_deletes_old() {
    local tmpdir
    tmpdir="$(setup_test_dir)"

    # Create an old session (30 days ago)
    local old_date
    old_date="$(date -d '-30 days' +%Y%m%d_%H%M%S 2>/dev/null || date -v-30d +%Y%m%d_%H%M%S 2>/dev/null)"
    create_session "$tmpdir/captures" "${old_date}_11111"

    # Create a recent session (1 hour ago)
    local new_date
    new_date="$(date -d '-1 hour' +%Y%m%d_%H%M%S 2>/dev/null || date -v-1H +%Y%m%d_%H%M%S 2>/dev/null)"
    create_session "$tmpdir/captures" "${new_date}_22222"

    # Run cleanup: keep last 7 days
    "$CLEANUP_SCRIPT" -d "$tmpdir" --keep-days 7 >/dev/null 2>&1

    # Old session should be gone
    local old_files
    old_files="$(find "$tmpdir/captures" -name "capture_${old_date}_11111.*" -type f | wc -l)"

    # New session should remain
    local new_files
    new_files="$(find "$tmpdir/captures" -name "capture_${new_date}_22222.*" -type f | wc -l)"

    if [[ "$old_files" -eq 0 && "$new_files" -gt 0 ]]; then
        report "test_keep_days_deletes_old" "pass"
    else
        report "test_keep_days_deletes_old" "fail (old=$old_files, new=$new_files)"
    fi

    cleanup_test_dir "$tmpdir"
}

# ── Test 5: Keep-size removes oldest sessions first ─────────────────

test_keep_size() {
    local tmpdir
    tmpdir="$(setup_test_dir)"

    # Create 3 sessions of 500 bytes each
    local date1 date2 date3
    date1="$(date -d '-3 days' +%Y%m%d_%H%M%S 2>/dev/null || date -v-3d +%Y%m%d_%H%M%S 2>/dev/null)"
    date2="$(date -d '-2 days' +%Y%m%d_%H%M%S 2>/dev/null || date -v-2d +%Y%m%d_%H%M%S 2>/dev/null)"
    date3="$(date -d '-1 day' +%Y%m%d_%H%M%S 2>/dev/null || date -v-1d +%Y%m%d_%H%M%S 2>/dev/null)"

    create_session "$tmpdir/captures" "${date1}_11111" 500
    create_session "$tmpdir/captures" "${date2}_22222" 500
    create_session "$tmpdir/captures" "${date3}_33333" 500

    # Keep only 6K (enough for ~1 session with 9 files x 500 bytes + manifest ≈ 4.5K + manifest)
    "$CLEANUP_SCRIPT" -d "$tmpdir" --keep-size 6K >/dev/null 2>&1

    # Newest session should remain, oldest should be gone
    local newest_files oldest_files
    newest_files="$(find "$tmpdir/captures" -name "capture_${date3}_33333.*" -type f | wc -l)"
    oldest_files="$(find "$tmpdir/captures" -name "capture_${date1}_11111.*" -type f | wc -l)"

    if [[ "$newest_files" -gt 0 && "$oldest_files" -eq 0 ]]; then
        report "test_keep_size" "pass"
    else
        report "test_keep_size" "fail (newest=$newest_files, oldest=$oldest_files)"
    fi

    cleanup_test_dir "$tmpdir"
}

# ── Test 6: Latest symlinks are updated after deleting latest target ─

test_latest_links_updated() {
    local tmpdir
    tmpdir="$(setup_test_dir)"

    # Create old session and new session
    local old_date new_date
    old_date="$(date -d '-30 days' +%Y%m%d_%H%M%S 2>/dev/null || date -v-30d +%Y%m%d_%H%M%S 2>/dev/null)"
    new_date="$(date -d '-1 hour' +%Y%m%d_%H%M%S 2>/dev/null || date -v-1H +%Y%m%d_%H%M%S 2>/dev/null)"

    create_session "$tmpdir/captures" "${old_date}_11111"
    create_session "$tmpdir/captures" "${new_date}_22222"

    # Point latest.* to the OLD session (simulating it was the most recent when created)
    for ext in flow har log manifest.json index.ndjson summary.md ai.json ai.md; do
        ln -sfn "$tmpdir/captures/capture_${old_date}_11111.${ext}" "$tmpdir/captures/latest.${ext}" 2>/dev/null || true
    done

    # Run cleanup: delete old session
    "$CLEANUP_SCRIPT" -d "$tmpdir" --keep-days 7 >/dev/null 2>&1

    # latest.flow should now point to the new session
    local target
    target="$(readlink "$tmpdir/captures/latest.flow" 2>/dev/null || true)"

    if [[ "$target" == *"${new_date}_22222"* ]]; then
        report "test_latest_links_updated" "pass"
    else
        report "test_latest_links_updated" "fail (target=$target)"
    fi

    cleanup_test_dir "$tmpdir"
}

# ── Test 7: Empty captures dir handled gracefully ───────────────────

test_empty_dir() {
    local tmpdir
    tmpdir="$(setup_test_dir)"

    local output
    output="$("$CLEANUP_SCRIPT" -d "$tmpdir" --keep-days 7 2>&1)"

    if [[ "$output" == *"No capture sessions"* ]]; then
        report "test_empty_dir" "pass"
    else
        report "test_empty_dir" "fail"
    fi

    cleanup_test_dir "$tmpdir"
}

# ── Test 8: Keep-days 0 deletes everything ──────────────────────────

test_keep_days_zero() {
    local tmpdir
    tmpdir="$(setup_test_dir)"

    # Create a very recent session
    local recent_date
    recent_date="$(date +%Y%m%d_%H%M%S)"
    create_session "$tmpdir/captures" "${recent_date}_99999"

    # Keep 0 days = delete everything
    "$CLEANUP_SCRIPT" -d "$tmpdir" --keep-days 0 >/dev/null 2>&1

    local remaining
    remaining="$(find "$tmpdir/captures" -name 'capture_*' -type f | wc -l)"

    if [[ "$remaining" -eq 0 ]]; then
        report "test_keep_days_zero" "pass"
    else
        report "test_keep_days_zero" "fail (remaining=$remaining)"
    fi

    cleanup_test_dir "$tmpdir"
}

# ── Test 9: Wrapper cleanup subcommand works ────────────────────────

test_wrapper_cleanup() {
    local tmpdir
    tmpdir="$(setup_test_dir)"

    local old_date
    old_date="$(date -d '-30 days' +%Y%m%d_%H%M%S 2>/dev/null || date -v-30d +%Y%m%d_%H%M%S 2>/dev/null)"
    create_session "$tmpdir/captures" "${old_date}_11111"

    local output
    output="$("$WRAPPER_SCRIPT" cleanup -d "$tmpdir" --keep-days 7 --dry-run 2>&1)"

    if [[ "$output" == *"DRY RUN"* && "$output" == *"DELETE"* ]]; then
        report "test_wrapper_cleanup" "pass"
    else
        report "test_wrapper_cleanup" "fail"
    fi

    cleanup_test_dir "$tmpdir"
}

# ── Test 10: Secure flag passes through ─────────────────────────────

test_secure_flag() {
    local tmpdir
    tmpdir="$(setup_test_dir)"

    local old_date
    old_date="$(date -d '-30 days' +%Y%m%d_%H%M%S 2>/dev/null || date -v-30d +%Y%m%d_%H%M%S 2>/dev/null)"
    create_session "$tmpdir/captures" "${old_date}_11111"

    local output
    output="$("$CLEANUP_SCRIPT" -d "$tmpdir" --keep-days 7 --secure 2>&1)"

    # Verify the summary mentions secure delete and files are actually gone
    local remaining
    remaining="$(find "$tmpdir/captures" -name "capture_${old_date}_11111.*" -type f | wc -l)"

    if [[ "$remaining" -eq 0 && "$output" == *"Secure delete"* ]]; then
        report "test_secure_flag" "pass"
    else
        report "test_secure_flag" "fail (remaining=$remaining)"
    fi

    cleanup_test_dir "$tmpdir"
}

# ── Run all tests ───────────────────────────────────────────────────

echo "Running cleanup module tests..."
echo ""

test_help
test_requires_policy
test_dry_run_no_delete
test_keep_days_deletes_old
test_keep_size
test_latest_links_updated
test_empty_dir
test_keep_days_zero
test_wrapper_cleanup
test_secure_flag

echo ""
echo "Results: $PASS passed, $FAIL failed (total $((PASS + FAIL)))"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
