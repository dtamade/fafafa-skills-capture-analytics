#!/usr/bin/env bash
# install.sh - Verify environment, install dependencies, and install capture-analytics skill
#
# Usage:
#   ./install.sh                         Full install (check + pip install + skill copy install)
#   ./install.sh --check                 Check-only mode (no changes)
#   ./install.sh --doctor                Run dependency diagnostics (doctor.sh)
#   ./install.sh --install-to <path>     Install skill to custom target
#   ./install.sh --symlink               Install skill as symlink (opt-in)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK_ONLY=false
RUN_DOCTOR=false
INSTALL_SKILL=true
LINK_MODE=false
SKILL_TARGET_DIR="${HOME}/.claude/skills/capture-analytics"

PYTHON_BIN="python3"
PROJECT_VENV="$SCRIPT_DIR/.venv"
PROJECT_VENV_PY="$PROJECT_VENV/bin/python3"
PROJECT_VENV_PIP="$PROJECT_VENV/bin/pip"

if [[ -x "$PROJECT_VENV_PY" ]]; then
    PYTHON_BIN="$PROJECT_VENV_PY"
fi

usage() {
    cat <<'USAGE'
Usage: install.sh [options]

Options:
  --check, -c            Check-only mode (verify prerequisites without installing)
  --doctor               Run dependency diagnostics via scripts/doctor.sh
  --install-to, -t PATH  Skill target path (default: ~/.claude/skills/capture-analytics)
  --no-skill-install     Skip skill installation (dependency setup only)
  --symlink              Install skill as symlink (default is copy install)
  -h, --help             Show this help

Examples:
  ./install.sh --check
  ./install.sh --doctor
  ./install.sh
  ./install.sh --install-to ~/.claude/skills/capture-analytics
  ./install.sh --symlink --install-to ~/.claude/skills/capture-analytics
USAGE
}

require_value_arg() {
    local opt="$1"
    local value="${2:-}"
    if [[ -z "$value" || "$value" == -* ]]; then
        echo "[ERROR] Option $opt requires a value" >&2
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check|-c)
            CHECK_ONLY=true
            shift
            ;;
        --doctor)
            RUN_DOCTOR=true
            shift
            ;;
        --install-to|-t)
            require_value_arg "$1" "${2:-}"
            SKILL_TARGET_DIR="${2:-}"
            shift 2
            ;;
        --no-skill-install)
            INSTALL_SKILL=false
            shift
            ;;
        --symlink)
            LINK_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            usage
            exit 1
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

realpath_safe() {
    local path="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$path" 2>/dev/null || echo "$path"
    else
        echo "$path"
    fi
}

describe_skill_install_state() {
    local target="$1"

    if [[ -L "$target" ]]; then
        local link_target
        link_target="$(readlink "$target" 2>/dev/null || echo "<unknown>")"
        warn "skill installation: symlink at $target -> $link_target (external dependency mode)"
        return
    fi

    if [[ -d "$target" ]]; then
        if [[ -f "$target/SKILL.md" ]]; then
            ok "skill installation: local directory at $target"
        else
            warn "skill installation: directory exists but SKILL.md missing at $target"
        fi
        return
    fi

    warn "skill installation: not installed at $target"
}

copy_skill_tree() {
    local src="$1"
    local dst="$2"
    local tmp="${dst}.tmp.$$"

    rm -rf "$tmp"
    mkdir -p "$tmp"

    if command -v rsync >/dev/null 2>&1; then
        rsync -a \
            --exclude '.git' \
            --exclude '.venv' \
            --exclude '.pytest_cache' \
            --exclude '__pycache__' \
            --exclude 'captures' \
            "$src/" "$tmp/"
    else
        cp -a "$src/." "$tmp/"
        rm -rf \
            "$tmp/.git" \
            "$tmp/.venv" \
            "$tmp/.pytest_cache" \
            "$tmp/captures"
        find "$tmp" -type d -name '__pycache__' -prune -exec rm -rf {} + >/dev/null 2>&1 || true
    fi

    rm -rf "$dst"
    mv "$tmp" "$dst"
}

install_skill_artifacts() {
    local src="$1"
    local dst="$2"

    if [[ -z "$dst" || "$dst" == "/" ]]; then
        fail "Invalid skill install target: $dst"
        return
    fi

    mkdir -p "$(dirname "$dst")"

    local src_real dst_real
    src_real="$(realpath_safe "$src")"
    dst_real="$(realpath_safe "$dst")"

    if [[ "$LINK_MODE" == "true" ]]; then
        if [[ "$src_real" == "$dst_real" ]]; then
            ok "skill installation: source already at target ($dst)"
            return
        fi
        rm -rf "$dst"
        ln -s "$src" "$dst"
        ok "skill installation: symlink created at $dst"
        return
    fi

    if [[ -L "$dst" ]]; then
        local current_link
        current_link="$(readlink "$dst" 2>/dev/null || true)"
        rm -f "$dst"
        copy_skill_tree "$src" "$dst"
        ok "skill installation: replaced symlink ($current_link) with local copy at $dst"
    elif [[ "$src_real" == "$dst_real" ]]; then
        ok "skill installation: source already at target ($dst)"
    else
        copy_skill_tree "$src" "$dst"
        ok "skill installation: copied to $dst"
    fi

    chmod +x "$dst/scripts/"*.sh 2>/dev/null || true
    chmod +x "$dst/scripts/"*.py 2>/dev/null || true

    if [[ -f "$dst/SKILL.md" ]]; then
        ok "skill installation: SKILL.md detected at target"
    else
        fail "skill installation: SKILL.md missing at target"
    fi
}

run_doctor_diagnostics() {
    if [[ ! -x "$SCRIPT_DIR/scripts/doctor.sh" ]]; then
        fail "doctor diagnostics unavailable: scripts/doctor.sh not executable"
        return
    fi

    echo ""
    echo "=== Running Dependency Diagnostics ==="
    echo ""

    if "$SCRIPT_DIR/scripts/doctor.sh"; then
        ok "doctor diagnostics: pass"
    else
        fail "doctor diagnostics: failed"
    fi
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
if "$PYTHON_BIN" -c "from mitmproxy.io import FlowReader" 2>/dev/null; then
    ok "mitmproxy Python module: available"
else
    if [[ "$CHECK_ONLY" == "true" ]]; then
        fail "mitmproxy Python module: not found (required for flow analysis)"
    else
        warn "mitmproxy Python module: not found yet (will install into .venv)"
    fi
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

# Installation state diagnosis
if [[ "$INSTALL_SKILL" == "true" ]]; then
    describe_skill_install_state "$SKILL_TARGET_DIR"
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

    # Ensure project-local virtual environment
    if [[ ! -x "$PROJECT_VENV_PY" ]]; then
        echo "  Creating project virtualenv at $PROJECT_VENV..."
        if python3 -m venv "$PROJECT_VENV" >/dev/null 2>&1; then
            ok "Project virtualenv created"
        else
            fail "Failed to create virtualenv"
            echo "  Try: sudo apt install python3-venv"
        fi
    else
        ok "Project virtualenv already exists"
    fi

    # Install Python dependencies
    if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
        echo "  Installing Python dependencies..."
        if [[ -x "$PROJECT_VENV_PIP" ]] && "$PROJECT_VENV_PIP" install -r "$SCRIPT_DIR/requirements.txt" --quiet 2>&1; then
            ok "Python dependencies installed"
        else
            fail "Failed to install Python dependencies"
            echo "  Try: $PROJECT_VENV_PIP install -r requirements.txt"
        fi

        if [[ -x "$PROJECT_VENV_PY" ]] && "$PROJECT_VENV_PY" -c "from mitmproxy.io import FlowReader" 2>/dev/null; then
            ok "mitmproxy Python module: available in .venv"
        else
            fail "mitmproxy Python module: still unavailable after install"
        fi
    fi

    if [[ "$INSTALL_SKILL" == "true" ]]; then
        install_skill_artifacts "$SCRIPT_DIR" "$SKILL_TARGET_DIR"
    fi

    echo ""
fi

if [[ "$RUN_DOCTOR" == "true" ]]; then
    run_doctor_diagnostics
fi

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "=== Summary ==="
echo "  Passed:   $PASS"
echo "  Warnings: $WARN"
echo "  Failed:   $FAIL"
echo "==============="

if [[ "$INSTALL_SKILL" == "true" ]]; then
    echo "  Skill target: $SKILL_TARGET_DIR"
    if [[ "$LINK_MODE" == "true" ]]; then
        echo "  Skill mode:   symlink"
    else
        echo "  Skill mode:   copy"
    fi
fi

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
