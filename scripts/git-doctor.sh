#!/usr/bin/env bash
# git-doctor.sh - Diagnose common Git sync/auth/connectivity issues
# Usage: git-doctor.sh [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<'EOF'
Usage:
  git-doctor.sh [options]

Options:
  -r, --remote <name>     Remote name (default: origin)
  -b, --branch <name>     Branch name (default: main)
  -t, --timeout <sec>     Network timeout seconds (default: 20)
      --json              Output JSON
      --strict            Treat warnings as failures
  -h, --help              Show this help

Checks:
  [FAIL] git             Git CLI availability
  [FAIL] repo            Running inside a Git repository
  [WARN] index-lock      Existing .git/index.lock (possible stale lock)
  [FAIL] remote          Remote exists and has URL
  [FAIL] remote-reach    Can reach remote via git ls-remote
  [WARN] remote-sync     Local tracking ref differs from remote tip
  [WARN] gh-auth         gh auth status health

Exit codes:
  0 - All required checks passed
  1 - One or more failures (or warnings in --strict)
EOF
}

# Colors (disabled if not TTY)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

REMOTE_NAME="origin"
BRANCH_NAME="main"
TIMEOUT_SECONDS="20"
JSON_OUTPUT=false
STRICT_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--remote)
            require_value_arg "$1" "${2:-}"
            REMOTE_NAME="${2:-}"
            shift 2
            ;;
        -b|--branch)
            require_value_arg "$1" "${2:-}"
            BRANCH_NAME="${2:-}"
            shift 2
            ;;
        -t|--timeout)
            require_value_arg "$1" "${2:-}"
            TIMEOUT_SECONDS="${2:-20}"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --strict)
            STRICT_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            err "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || (( TIMEOUT_SECONDS < 1 || TIMEOUT_SECONDS > 300 )); then
    err "--timeout must be an integer between 1 and 300"
    exit 1
fi

declare -a RESULTS=()
FAIL_COUNT=0
WARN_COUNT=0
PASS_COUNT=0
REMOTE_SHA=""

add_result() {
    local name="$1"
    local status="$2" # pass, fail, warn
    local message="$3"
    local detail="${4:-}"

    RESULTS+=("$name|$status|$message|$detail")

    case "$status" in
        pass) ((PASS_COUNT++)) || true ;;
        fail) ((FAIL_COUNT++)) || true ;;
        warn) ((WARN_COUNT++)) || true ;;
    esac
}

run_with_timeout() {
    local seconds="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$seconds" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$seconds" "$@"
    else
        "$@"
    fi
}

check_git() {
    if command -v git >/dev/null 2>&1; then
        local version
        version="$(git --version 2>/dev/null || echo unknown)"
        add_result "git" "pass" "Installed" "$version"
    else
        add_result "git" "fail" "Not installed" "Install Git to continue"
    fi
}

check_repo() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        add_result "repo" "pass" "Inside git repository" ""
    else
        add_result "repo" "fail" "Not a git repository" "Run from a repository root"
    fi
}

check_index_lock() {
    local git_dir
    git_dir="$(git rev-parse --git-dir 2>/dev/null || true)"
    if [[ -z "$git_dir" ]]; then
        return
    fi
    local lock_file="$git_dir/index.lock"
    if [[ -f "$lock_file" ]]; then
        add_result "index-lock" "warn" "Found index lock" "$lock_file (possible stale lock)"
    else
        add_result "index-lock" "pass" "No index lock" ""
    fi
}

check_remote() {
    local remote_url
    if ! remote_url="$(git remote get-url "$REMOTE_NAME" 2>/dev/null)"; then
        add_result "remote" "fail" "Remote not found" "Missing remote: $REMOTE_NAME"
        return 1
    fi

    if [[ -z "$remote_url" ]]; then
        add_result "remote" "fail" "Remote URL is empty" "$REMOTE_NAME"
        return 1
    fi

    add_result "remote" "pass" "Configured" "$REMOTE_NAME -> $remote_url"
    return 0
}

check_remote_reachability() {
    local output
    if output="$(run_with_timeout "$TIMEOUT_SECONDS" git ls-remote --heads "$REMOTE_NAME" "$BRANCH_NAME" 2>&1)"; then
        REMOTE_SHA="$(echo "$output" | awk 'NR==1 {print $1}')"
        if [[ -n "$REMOTE_SHA" ]]; then
            add_result "remote-reach" "pass" "Reachable" "$REMOTE_NAME/$BRANCH_NAME -> ${REMOTE_SHA:0:12}"
        else
            add_result "remote-reach" "warn" "Reachable but branch missing" "$REMOTE_NAME/$BRANCH_NAME"
        fi
        return 0
    fi

    local code=$?
    if [[ "$code" -eq 124 ]]; then
        add_result "remote-reach" "fail" "Network timeout" "git ls-remote timed out after ${TIMEOUT_SECONDS}s"
    else
        local first_line
        first_line="$(echo "$output" | head -n 1)"
        add_result "remote-reach" "fail" "Remote check failed" "$first_line"
    fi
    return 1
}

check_tracking_sync() {
    local local_ref="refs/remotes/${REMOTE_NAME}/${BRANCH_NAME}"
    local local_sha
    local_sha="$(git rev-parse "$local_ref" 2>/dev/null || true)"

    if [[ -z "$local_sha" ]]; then
        add_result "remote-sync" "warn" "No local tracking ref" "Run: git fetch $REMOTE_NAME $BRANCH_NAME"
        return
    fi

    if [[ -z "$REMOTE_SHA" ]]; then
        add_result "remote-sync" "warn" "Remote SHA unavailable" "Run remote check first"
        return
    fi

    if [[ "$local_sha" == "$REMOTE_SHA" ]]; then
        add_result "remote-sync" "pass" "Tracking ref up to date" "${local_sha:0:12}"
    else
        add_result "remote-sync" "warn" "Tracking ref differs" "local ${local_sha:0:12}, remote ${REMOTE_SHA:0:12}"
    fi
}

check_gh_auth() {
    if ! command -v gh >/dev/null 2>&1; then
        add_result "gh-auth" "warn" "gh not installed" "Install GitHub CLI for easier auth diagnosis"
        return
    fi

    if gh auth status >/tmp/git_doctor_gh_auth.$$ 2>&1; then
        add_result "gh-auth" "pass" "Authenticated" "gh auth status OK"
    else
        local first_line
        first_line="$(head -n 1 /tmp/git_doctor_gh_auth.$$ 2>/dev/null || true)"
        add_result "gh-auth" "warn" "Authentication issue" "$first_line"
    fi
    rm -f /tmp/git_doctor_gh_auth.$$ 2>/dev/null || true
}

print_human() {
    echo "========================================"
    echo " git-doctor"
    echo "========================================"
    echo ""

    local row name status message detail icon color
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r name status message detail <<< "$row"
        case "$status" in
            pass)
                icon="✓"
                color="$GREEN"
                ;;
            warn)
                icon="!"
                color="$YELLOW"
                ;;
            *)
                icon="✗"
                color="$RED"
                ;;
        esac
        echo -e " ${color}[${icon}]${NC} ${name}    ${message}"
        if [[ -n "$detail" ]]; then
            echo "     └─ $detail"
        fi
    done

    local total=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
    echo ""
    echo "----------------------------------------"
    echo " Total: $total | Pass: $PASS_COUNT | Fail: $FAIL_COUNT | Warn: $WARN_COUNT"
    echo "========================================"
}

print_json() {
    python3 - "$FAIL_COUNT" "$WARN_COUNT" "$PASS_COUNT" "${RESULTS[@]}" <<'PY'
import json
import sys

fail = int(sys.argv[1])
warn = int(sys.argv[2])
passed = int(sys.argv[3])
rows = sys.argv[4:]

checks = []
for row in rows:
    name, status, message, detail = (row.split("|", 3) + ["", "", "", ""])[:4]
    checks.append(
        {
            "name": name,
            "status": status,
            "message": message,
            "detail": detail,
        }
    )

print(
    json.dumps(
        {
            "checks": checks,
            "summary": {
                "total": len(checks),
                "pass": passed,
                "fail": fail,
                "warn": warn,
            },
        },
        indent=2,
        ensure_ascii=False,
    )
)
PY
}

# Run checks in order
check_git
check_repo

if [[ "$FAIL_COUNT" -eq 0 ]]; then
    check_index_lock
    if check_remote; then
        check_remote_reachability || true
    fi
    check_tracking_sync
    check_gh_auth
fi

if [[ "$JSON_OUTPUT" == "true" ]]; then
    print_json
else
    print_human
fi

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi

if [[ "$STRICT_MODE" == "true" && "$WARN_COUNT" -gt 0 ]]; then
    exit 1
fi

exit 0
