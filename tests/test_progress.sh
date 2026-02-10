#!/usr/bin/env bash
# Regression tests for capture-session progress command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CAPTURE_SCRIPT="$SCRIPT_DIR/../scripts/capture-session.sh"
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

test_progress_uses_flow_file_from_env() {
    local temp_dir real_flow legacy_flow output
    temp_dir="$(mktemp -d)"

    mkdir -p "$temp_dir/captures"
    real_flow="$temp_dir/captures/capture_20260210_000000_1.flow"
    legacy_flow="$temp_dir/captures/capture.flow"

    # real flow file should be used by progress
    printf 'non-empty-flow' > "$real_flow"
    # legacy path kept empty to detect wrong file selection
    : > "$legacy_flow"

    cat > "$temp_dir/captures/proxy_info.env" <<EOF
MITM_PID="$$"
STARTED_AT="$(date +%Y-%m-%dT%H:%M:%S)"
LISTEN_PORT="18080"
FLOW_FILE="$real_flow"
EOF

    output="$($CAPTURE_SCRIPT progress -d "$temp_dir" 2>&1 || true)"
    rm -rf "$temp_dir"

    if echo "$output" | grep -q "Status:    RUNNING" && ! echo "$output" | grep -q "Data Size: 0"; then
        report "test_progress_uses_flow_file_from_env" "pass"
    else
        echo "--- output ---"
        echo "$output"
        echo "--------------"
        report "test_progress_uses_flow_file_from_env" "fail"
    fi
}

echo "Running progress command tests..."
echo ""

test_progress_uses_flow_file_from_env

echo ""
echo "Results: $PASS passed, $FAIL failed (total $((PASS + FAIL)))"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi

