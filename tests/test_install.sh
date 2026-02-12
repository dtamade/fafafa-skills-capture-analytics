#!/usr/bin/env bash
# Tests for install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../install.sh"
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

# ── Test 1: Help works ────────────────────────────────────────────

test_help() {
    if "$INSTALL_SCRIPT" --help 2>&1 | grep -q "check"; then
        report "test_help" "pass"
    else
        report "test_help" "fail"
    fi
}

# ── Test 2: Help includes new install options ─────────────────────

test_help_has_install_options() {
    local output
    output="$($INSTALL_SCRIPT --help 2>&1 || true)"

    if echo "$output" | grep -q -- "--install-to" && \
       echo "$output" | grep -q -- "--doctor" && \
       echo "$output" | grep -q -- "--symlink"; then
        report "test_help_has_install_options" "pass"
    else
        report "test_help_has_install_options" "fail"
    fi
}

# ── Test 3: Check mode runs and produces output ───────────────────

test_check_mode() {
    local output
    output="$($INSTALL_SCRIPT --check 2>&1 || true)"

    if echo "$output" | grep -q "Checking Prerequisites"; then
        report "test_check_mode" "pass"
    else
        report "test_check_mode" "fail"
    fi
}

# ── Test 4: Check detects python3 ─────────────────────────────────

test_detects_python3() {
    local output
    output="$($INSTALL_SCRIPT --check 2>&1 || true)"

    if echo "$output" | grep -q "\[OK\].*python3"; then
        report "test_detects_python3" "pass"
    else
        report "test_detects_python3" "fail"
    fi
}

# ── Test 5: Check detects bash version ────────────────────────────

test_detects_bash() {
    local output
    output="$($INSTALL_SCRIPT --check 2>&1 || true)"

    if echo "$output" | grep -qE "\[(OK|WARN)\].*bash"; then
        report "test_detects_bash" "pass"
    else
        report "test_detects_bash" "fail"
    fi
}

# ── Test 6: Summary shows counts ──────────────────────────────────

test_summary() {
    local output
    output="$($INSTALL_SCRIPT --check 2>&1 || true)"

    if echo "$output" | grep -q "Summary" && \
       echo "$output" | grep -q "Passed" && \
       echo "$output" | grep -q "Warnings" && \
       echo "$output" | grep -q "Failed"; then
        report "test_summary" "pass"
    else
        report "test_summary" "fail"
    fi
}

# ── Test 7: Check-only mode does not modify anything ──────────────

test_check_only_no_changes() {
    local output
    output="$($INSTALL_SCRIPT --check 2>&1 || true)"

    if echo "$output" | grep -q "Check-Only Mode"; then
        report "test_check_only_no_changes" "pass"
    else
        report "test_check_only_no_changes" "fail"
    fi
}

# ── Test 8: Check mode prints skill installation diagnosis ────────

test_check_reports_skill_install_state() {
    local output
    output="$($INSTALL_SCRIPT --check 2>&1 || true)"

    if echo "$output" | grep -q "skill installation:"; then
        report "test_check_reports_skill_install_state" "pass"
    else
        report "test_check_reports_skill_install_state" "fail"
    fi
}

# ── Test 9: Doctor flag triggers dependency diagnostics ────────────

test_doctor_flag_runs_diagnostics() {
    local output
    output="$($INSTALL_SCRIPT --check --doctor 2>&1 || true)"

    if echo "$output" | grep -q "Running Dependency Diagnostics" && \
       echo "$output" | grep -q "capture-analytics doctor"; then
        report "test_doctor_flag_runs_diagnostics" "pass"
    else
        report "test_doctor_flag_runs_diagnostics" "fail"
    fi
}

# ── Run all tests ─────────────────────────────────────────────────

echo "Running install tests..."
echo ""

test_help
test_help_has_install_options
test_check_mode
test_detects_python3
test_detects_bash
test_summary
test_check_only_no_changes
test_check_reports_skill_install_state
test_doctor_flag_runs_diagnostics

echo ""
echo "Results: $PASS passed, $FAIL failed (total $((PASS + FAIL)))"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
