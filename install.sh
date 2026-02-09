#!/usr/bin/env bash
# install.sh - Verify environment and install dependencies for capture-analytics
#
# Usage:
#   ./install.sh           Full install (check + pip install)
#   ./install.sh --check   Check-only mode (no changes)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --check|-c) CHECK_ONLY=true ;;
        -h|--help)
            echo "Usage: install.sh [--check]"
            echo ""
            echo "Options:"
            echo "  --check, -c   Check-only mode (verify prerequisites without installing)"
            echo "  -h, --help    Show this help"
            exit 0
            ;;
    esac
done

PASS=0
FAIL=0
WARN=0

ok() {
    PASS=$((PASS + 1))
    echo "  [OK]   $*"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  [FAIL] $*"
}

warn() {
    WARN=$((WARN + 1))
    echo "  [WARN] $*"
}

# ── Check prerequisites ─────────────────────────────────────────────

echo "=== Checking Prerequisites ==="
echo ""

# Python 3
if command -v python3 >/dev/null 2>&1; then
    PY_VERSION="$(python3 --version 2>&1)"
    ok "python3: $PY_VERSION"
else
    fail "python3 not found (required)"
fi

# Bash version
BASH_VERSION_NUM="${BASH_VERSION%%(*}"
BASH_MAJOR="${BASH_VERSION_NUM%%.*}"
if [[ "$BASH_MAJOR" -ge 4 ]]; then
    ok "bash: $BASH_VERSION (>= 4.0)"
else
    warn "bash: $BASH_VERSION (< 4.0 — most features work, but consider upgrading)"
fi

# mitmdump
if command -v mitmdump >/dev/null 2>&1; then
    MITM_VERSION="$(mitmdump --version 2>&1 | head -n1)"
    ok "mitmdump: $MITM_VERSION"
else
    fail "mitmdump not found (required for capture)"
fi

# mitmproxy Python module
if python3 -c "from mitmproxy.io import FlowReader" 2>/dev/null; then
    ok "mitmproxy Python module: available"
else
    fail "mitmproxy Python module: not found (required for flow analysis)"
fi

# sha256sum
if command -v sha256sum >/dev/null 2>&1; then
    ok "sha256sum: available"
elif command -v shasum >/dev/null 2>&1; then
    ok "shasum: available (macOS fallback)"
else
    warn "sha256sum/shasum: not found (flow integrity check will be skipped)"
fi

# flock
if command -v flock >/dev/null 2>&1; then
    ok "flock: available"
else
    warn "flock: not found (concurrent capture protection unavailable)"
fi

# shred (optional)
if command -v shred >/dev/null 2>&1; then
    ok "shred: available (secure delete supported)"
else
    warn "shred: not found (--secure cleanup will fall back to normal rm)"
fi

echo ""

# ── Check scripts are executable ─────────────────────────────────────

echo "=== Checking Script Permissions ==="
echo ""

SCRIPTS_OK=true
for script in "$SCRIPT_DIR/scripts/"*.sh; do
    if [[ -x "$script" ]]; then
        ok "$(basename "$script"): executable"
    else
        warn "$(basename "$script"): not executable"
        SCRIPTS_OK=false
    fi
done

echo ""

# ── Install (if not check-only) ─────────────────────────────────────

if [[ "$CHECK_ONLY" == "true" ]]; then
    echo "=== Check-Only Mode (no changes made) ==="
else
    echo "=== Installing ==="
    echo ""

    # Make scripts executable
    if [[ "$SCRIPTS_OK" != "true" ]]; then
        echo "  Setting script permissions..."
        chmod +x "$SCRIPT_DIR/scripts/"*.sh 2>/dev/null || true
        chmod +x "$SCRIPT_DIR/scripts/"*.py 2>/dev/null || true
        ok "Script permissions set"
    else
        ok "Script permissions already correct"
    fi

    # Install Python dependencies
    if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
        echo "  Installing Python dependencies..."
        if pip3 install -r "$SCRIPT_DIR/requirements.txt" --quiet 2>&1; then
            ok "Python dependencies installed"
        else
            fail "Failed to install Python dependencies"
            echo "  Try: pip3 install -r requirements.txt"
        fi
    fi

    echo ""
fi

# ── Summary ──────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "  Passed:   $PASS"
echo "  Warnings: $WARN"
echo "  Failed:   $FAIL"
echo "==============="

if [[ "$FAIL" -gt 0 ]]; then
    echo ""
    echo "Some checks failed. Fix the issues above and re-run."
    exit 1
fi

if [[ "$WARN" -gt 0 ]]; then
    echo ""
    echo "All required checks passed. Some optional features may be limited."
    exit 0
fi

echo ""
echo "All checks passed. Ready to use!"
exit 0
