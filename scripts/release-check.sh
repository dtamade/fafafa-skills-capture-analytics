#!/usr/bin/env bash
# release-check.sh - Run local release readiness checks in one command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=false
SKIP_INSTALL_CHECK=false
SKIP_PYTHON_TESTS=false
SKIP_SHELL_TESTS=false
SKIP_DOCTOR=false

usage() {
    cat <<'EOF'
Usage:
  release-check.sh [options]

Options:
      --dry-run             Print steps without executing
      --skip-install-check  Skip ./install.sh --check
      --skip-python-tests   Skip python3 -m pytest tests/ -q
      --skip-shell-tests    Skip tests/test_*.sh
      --skip-doctor         Skip capture-session.sh doctor
  -h, --help                Show this help

Default steps:
  1) ./install.sh --check
  2) python3 -m pytest tests/ -q
  3) for test in tests/test_*.sh; do bash "$test"; done
  4) ./scripts/capture-session.sh doctor

Examples:
  ./scripts/release-check.sh
  ./scripts/release-check.sh --dry-run
  ./scripts/release-check.sh --skip-shell-tests --skip-doctor
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-install-check)
            SKIP_INSTALL_CHECK=true
            shift
            ;;
        --skip-python-tests)
            SKIP_PYTHON_TESTS=true
            shift
            ;;
        --skip-shell-tests)
            SKIP_SHELL_TESTS=true
            shift
            ;;
        --skip-doctor)
            SKIP_DOCTOR=true
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

cd "$ROOT_DIR"

echo "========================================"
echo " release-check"
echo " root: $ROOT_DIR"
echo "========================================"

run_step() {
    local title="$1"
    local preview="$2"
    shift 2

    echo ""
    echo "[STEP] $title"
    echo "       $preview"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "       (dry-run)"
        return 0
    fi

    "$@"
}

run_shell_tests() {
    local test
    for test in tests/test_*.sh; do
        bash "$test"
    done
}

if [[ "$SKIP_INSTALL_CHECK" != "true" ]]; then
    run_step "Install check" "./install.sh --check" ./install.sh --check
else
    echo "[SKIP] Install check"
fi

if [[ "$SKIP_PYTHON_TESTS" != "true" ]]; then
    run_step "Python tests" "python3 -m pytest tests/ -q" python3 -m pytest tests/ -q
else
    echo "[SKIP] Python tests"
fi

if [[ "$SKIP_SHELL_TESTS" != "true" ]]; then
    run_step "Shell tests" 'for test in tests/test_*.sh; do bash "$test"; done' run_shell_tests
else
    echo "[SKIP] Shell tests"
fi

if [[ "$SKIP_DOCTOR" != "true" ]]; then
    run_step "Doctor" "./scripts/capture-session.sh doctor" ./scripts/capture-session.sh doctor
else
    echo "[SKIP] Doctor"
fi

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Dry-run complete."
else
    echo "All release checks passed."
fi

