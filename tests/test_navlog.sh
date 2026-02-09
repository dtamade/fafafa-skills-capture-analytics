#!/usr/bin/env bash
# Tests for navlog.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAVLOG_SCRIPT="$SCRIPT_DIR/../scripts/navlog.sh"
WRAPPER_SCRIPT="$SCRIPT_DIR/../scripts/capture-session.sh"
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

# ── Test 1: Help works ──────────────────────────────────────────────

test_help() {
    if "$NAVLOG_SCRIPT" --help 2>&1 | grep -q "navlog.sh"; then
        report "test_help" "pass"
    else
        report "test_help" "fail"
    fi
}

# ── Test 2: Init creates empty file ─────────────────────────────────

test_init() {
    local tmpfile
    tmpfile="$(mktemp /tmp/navlog_test.XXXXXX.ndjson)"
    rm -f "$tmpfile"

    "$NAVLOG_SCRIPT" init -f "$tmpfile" >/dev/null 2>&1

    if [[ -f "$tmpfile" && ! -s "$tmpfile" ]]; then
        report "test_init" "pass"
    else
        report "test_init" "fail"
    fi

    rm -f "$tmpfile"
}

# ── Test 3: Append with shorthand flags ─────────────────────────────

test_append_shorthand() {
    local tmpfile
    tmpfile="$(mktemp /tmp/navlog_test.XXXXXX.ndjson)"

    local output
    output="$("$NAVLOG_SCRIPT" append -f "$tmpfile" --action navigate --url "https://example.com" --title "Home" 2>&1)"

    local has_ts has_action has_url
    has_ts="$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ts' in d)")"
    has_action="$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('action'))")"
    has_url="$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('url'))")"

    if [[ "$has_ts" == "True" && "$has_action" == "navigate" && "$has_url" == "https://example.com" ]]; then
        report "test_append_shorthand" "pass"
    else
        report "test_append_shorthand" "fail"
    fi

    rm -f "$tmpfile"
}

# ── Test 4: Append with raw JSON ────────────────────────────────────

test_append_raw_json() {
    local tmpfile
    tmpfile="$(mktemp /tmp/navlog_test.XXXXXX.ndjson)"

    local output
    output="$("$NAVLOG_SCRIPT" append -f "$tmpfile" '{"action":"click","selector":"#btn"}' 2>&1)"

    local action selector has_ts
    action="$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin).get('action'))")"
    selector="$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin).get('selector'))")"
    has_ts="$(echo "$output" | python3 -c "import sys,json; print('ts' in json.load(sys.stdin))")"

    if [[ "$action" == "click" && "$selector" == "#btn" && "$has_ts" == "True" ]]; then
        report "test_append_raw_json" "pass"
    else
        report "test_append_raw_json" "fail"
    fi

    rm -f "$tmpfile"
}

# ── Test 5: Show displays navlog contents ───────────────────────────

test_show() {
    local tmpfile
    tmpfile="$(mktemp /tmp/navlog_test.XXXXXX.ndjson)"

    "$NAVLOG_SCRIPT" append -f "$tmpfile" --action navigate --url "https://a.com" >/dev/null 2>&1
    "$NAVLOG_SCRIPT" append -f "$tmpfile" --action click --selector "#x" >/dev/null 2>&1

    local line_count
    line_count="$("$NAVLOG_SCRIPT" show -f "$tmpfile" 2>/dev/null | wc -l)"

    if [[ "$line_count" -eq 2 ]]; then
        report "test_show" "pass"
    else
        report "test_show" "fail (lines=$line_count)"
    fi

    rm -f "$tmpfile"
}

# ── Test 6: Show empty navlog ───────────────────────────────────────

test_show_empty() {
    local tmpfile
    tmpfile="$(mktemp /tmp/navlog_test.XXXXXX.ndjson)"

    local output
    output="$("$NAVLOG_SCRIPT" show -f "$tmpfile" 2>&1)"

    if [[ "$output" == *"empty"* ]]; then
        report "test_show_empty" "pass"
    else
        report "test_show_empty" "fail"
    fi

    rm -f "$tmpfile"
}

# ── Test 7: Append requires action or JSON ──────────────────────────

test_append_requires_input() {
    local tmpfile
    tmpfile="$(mktemp /tmp/navlog_test.XXXXXX.ndjson)"

    local output
    output="$("$NAVLOG_SCRIPT" append -f "$tmpfile" 2>&1 || true)"

    if [[ "$output" == *"requires"* ]]; then
        report "test_append_requires_input" "pass"
    else
        report "test_append_requires_input" "fail"
    fi

    rm -f "$tmpfile"
}

# ── Test 8: Timestamp is auto-injected and first ────────────────────

test_auto_timestamp() {
    local tmpfile
    tmpfile="$(mktemp /tmp/navlog_test.XXXXXX.ndjson)"

    local output
    output="$("$NAVLOG_SCRIPT" append -f "$tmpfile" '{"action":"navigate","url":"https://x.com"}' 2>&1)"

    local ts first_key
    ts="$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ts',''))")"
    first_key="$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(list(d.keys())[0])")"

    if [[ "$first_key" == "ts" && "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
        report "test_auto_timestamp" "pass"
    else
        report "test_auto_timestamp" "fail (first=$first_key, ts=$ts)"
    fi

    rm -f "$tmpfile"
}

# ── Test 9: File written is valid NDJSON ────────────────────────────

test_valid_ndjson() {
    local tmpfile
    tmpfile="$(mktemp /tmp/navlog_test.XXXXXX.ndjson)"

    "$NAVLOG_SCRIPT" append -f "$tmpfile" --action navigate --url "https://a.com" >/dev/null 2>&1
    "$NAVLOG_SCRIPT" append -f "$tmpfile" --action click --selector "#b" >/dev/null 2>&1
    "$NAVLOG_SCRIPT" append -f "$tmpfile" '{"action":"wait","duration":"1000"}' >/dev/null 2>&1

    local valid
    valid="$(python3 -c "
import json, sys
ok = True
with open(sys.argv[1]) as f:
    for i, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        try:
            json.loads(line)
        except Exception as e:
            print(f'Line {i}: {e}', file=sys.stderr)
            ok = False
print('ok' if ok else 'fail')
" "$tmpfile")"

    if [[ "$valid" == "ok" ]]; then
        report "test_valid_ndjson" "pass"
    else
        report "test_valid_ndjson" "fail"
    fi

    rm -f "$tmpfile"
}

# ── Test 10: Resolves from proxy_info.env ───────────────────────────

test_resolve_from_env() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    mkdir -p "$tmpdir/captures"

    local navlog_path="$tmpdir/captures/capture_test.navigation.ndjson"
    : > "$navlog_path"

    echo "NAVLOG_FILE=$navlog_path" > "$tmpdir/captures/proxy_info.env"

    local output
    output="$("$NAVLOG_SCRIPT" append -d "$tmpdir" --action navigate --url "https://test.com" 2>&1)"

    local line_count
    line_count="$(wc -l < "$navlog_path")"

    if [[ "$line_count" -ge 1 && "$output" == *"navigate"* ]]; then
        report "test_resolve_from_env" "pass"
    else
        report "test_resolve_from_env" "fail (lines=$line_count)"
    fi

    rm -rf "$tmpdir"
}

# ── Run all tests ───────────────────────────────────────────────────

echo "Running navlog module tests..."
echo ""

test_help
test_init
test_append_shorthand
test_append_raw_json
test_show
test_show_empty
test_append_requires_input
test_auto_timestamp
test_valid_ndjson
test_resolve_from_env

echo ""
echo "Results: $PASS passed, $FAIL failed (total $((PASS + FAIL)))"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
