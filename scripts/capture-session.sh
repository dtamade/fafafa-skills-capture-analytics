#!/usr/bin/env bash
# capture-session.sh - One-shot capture session wrapper for AI use
# Usage: capture-session.sh <command> [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<'EOF'
Usage:
  capture-session.sh <command> [options]

Commands:
  start <url>         Start capture for target URL
  stop                Stop capture and generate analysis
  status              Check if capture is running
  analyze             Generate AI analysis bundle
  doctor              Check environment prerequisites
  cleanup             Clean up old capture sessions
  diff <a> <b>        Compare two capture index files
  navlog <cmd>        Manage navigation log (init/append/show)

Options:
  -d, --dir <path>       Working directory (default: current dir)
  -P, --port <port>      Proxy port (default: 18080)
  --allow-hosts <list>   Comma-separated allowed hosts
  --deny-hosts <list>    Comma-separated denied hosts
  --policy <file>        Policy JSON file for scope control
  --confirm <phrase>     Authorization confirmation phrase
  --keep-days <N>        Cleanup: keep captures from last N days
  --keep-size <SIZE>     Cleanup: keep latest captures up to SIZE
  --secure               Cleanup: securely delete (shred)
  --dry-run              Cleanup: preview without deleting
  -h, --help             Show this help

Scope Control:
  Use --allow-hosts to restrict capture to specific domains.
  Default policy auto-generates from target URL domain.

Examples:
  capture-session.sh doctor
  capture-session.sh start https://example.com
  capture-session.sh start https://example.com --allow-hosts "example.com,*.example.com"
  capture-session.sh stop
  capture-session.sh analyze
  capture-session.sh cleanup --keep-days 7
  capture-session.sh cleanup --keep-size 1G --dry-run
  capture-session.sh cleanup --secure --keep-days 3
  capture-session.sh diff captures/a.index.ndjson captures/b.index.ndjson
  capture-session.sh navlog append --action navigate --url "https://example.com"

For AI Automation:
  1. AI calls: capture-session.sh doctor (verify environment)
  2. AI calls: capture-session.sh start <url> --confirm YES_I_HAVE_AUTHORIZATION
  3. AI uses Playwright with proxy 127.0.0.1:18080
  4. AI calls: capture-session.sh stop
  5. AI reads: captures/latest.ai.json
EOF
}

err() {
    echo "[ERROR] $*" >&2
}

require_value_arg() {
    local opt="$1"
    local value="${2:-}"
    if [[ -z "$value" || "$value" == -* ]]; then
        err "Option $opt requires a value"
        exit 1
    fi
}

# Safe key-value reader (whitelist approach, no code execution)
# Shared utilities
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# P1-2 Fix: Check --help BEFORE extracting command
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            usage
            exit 0
            ;;
    esac
done

COMMAND=""
TARGET_URL=""
WORK_DIR="$(pwd)"
PROXY_PORT="18080"
ALLOW_HOSTS=""
DENY_HOSTS=""
POLICY_FILE=""
CONFIRM_PHRASE=""
KEEP_DAYS=""
KEEP_SIZE=""
SECURE_DELETE=""
DRY_RUN=""
EXTRA_ARGS=()

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

COMMAND="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            require_value_arg "$1" "${2:-}"
            WORK_DIR="${2:-}"
            shift 2
            ;;
        -P|--port)
            require_value_arg "$1" "${2:-}"
            PROXY_PORT="${2:-}"
            shift 2
            ;;
        --allow-hosts)
            require_value_arg "$1" "${2:-}"
            ALLOW_HOSTS="${2:-}"
            shift 2
            ;;
        --deny-hosts)
            require_value_arg "$1" "${2:-}"
            DENY_HOSTS="${2:-}"
            shift 2
            ;;
        --policy)
            require_value_arg "$1" "${2:-}"
            POLICY_FILE="${2:-}"
            shift 2
            ;;
        --confirm)
            require_value_arg "$1" "${2:-}"
            CONFIRM_PHRASE="${2:-}"
            shift 2
            ;;
        --keep-days)
            require_value_arg "$1" "${2:-}"
            KEEP_DAYS="${2:-}"
            shift 2
            ;;
        --keep-size)
            require_value_arg "$1" "${2:-}"
            KEEP_SIZE="${2:-}"
            shift 2
            ;;
        --secure)
            SECURE_DELETE="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        http://*|https://*)
            TARGET_URL="$1"
            shift
            ;;
        *)
            if [[ -z "$TARGET_URL" && "$1" =~ ^https?:// ]]; then
                TARGET_URL="$1"
            elif [[ -z "$TARGET_URL" && "$1" =~ ^[a-zA-Z][a-zA-Z0-9.-]*\.[a-zA-Z]{2,} && ! -f "$1" ]]; then
                TARGET_URL="https://$1"
            else
                EXTRA_ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

case "$COMMAND" in
    start)
        if [[ -z "$TARGET_URL" ]]; then
            err "Target URL required for start command"
            exit 1
        fi

        # Generate default scope from target URL if not specified
        TARGET_HOST="$(python3 "$SCRIPT_DIR/policy.py" generate "$TARGET_URL" 2>/dev/null | python3 -c "import sys,json; p=json.load(sys.stdin); print(','.join(p['scope']['allow_hosts']))" 2>/dev/null || echo "")"

        if [[ -z "$ALLOW_HOSTS" && -z "$POLICY_FILE" && -n "$TARGET_HOST" ]]; then
            ALLOW_HOSTS="$TARGET_HOST"
            echo "[Auto-scope] Restricting capture to: $ALLOW_HOSTS"
        fi

        echo "=== Starting Capture Session ==="
        echo "Target: $TARGET_URL"
        echo "Proxy:  127.0.0.1:$PROXY_PORT"
        echo "Dir:    $WORK_DIR"
        if [[ -n "$ALLOW_HOSTS" ]]; then
            echo "Scope:  $ALLOW_HOSTS"
        fi
        echo ""

        # P0-2.1 Fix: Use array instead of eval to prevent command injection
        START_CMD=("$SCRIPT_DIR/startCaptures.sh" --program -d "$WORK_DIR" -P "$PROXY_PORT")
        [[ -n "$ALLOW_HOSTS" ]] && START_CMD+=(--allow-hosts "$ALLOW_HOSTS")
        [[ -n "$DENY_HOSTS" ]] && START_CMD+=(--deny-hosts "$DENY_HOSTS")
        [[ -n "$POLICY_FILE" ]] && START_CMD+=(--policy "$POLICY_FILE")

        "${START_CMD[@]}"

        echo ""
        echo "=== Next Steps for AI ==="
        echo "1. Configure Playwright to use proxy: 127.0.0.1:$PROXY_PORT"
        echo "2. Navigate to: $TARGET_URL"
        echo "3. Explore the site as needed"
        echo "4. Run: capture-session.sh stop -d $WORK_DIR"
        ;;

    stop)
        echo "=== Stopping Capture Session ==="
        "$SCRIPT_DIR/stopCaptures.sh" -d "$WORK_DIR"

        echo ""
        echo "=== Analysis Files Ready ==="
        if [[ -f "$WORK_DIR/captures/latest.ai.json" ]]; then
            echo "AI JSON:   $WORK_DIR/captures/latest.ai.json"
            echo "AI MD:     $WORK_DIR/captures/latest.ai.md"
            echo "Summary:   $WORK_DIR/captures/latest.summary.md"
            echo "HAR:       $WORK_DIR/captures/latest.har"
        fi
        ;;

    status)
        ENV_FILE="$WORK_DIR/captures/proxy_info.env"
        if [[ -f "$ENV_FILE" ]]; then
            # P0-1 Fix: Use safe read_kv instead of source (prevents command injection)
            MITM_PID="$(read_kv "MITM_PID" "$ENV_FILE")"
            LISTEN_HOST="$(read_kv "LISTEN_HOST" "$ENV_FILE")"
            LISTEN_PORT="$(read_kv "LISTEN_PORT" "$ENV_FILE")"
            STARTED_AT="$(read_kv "STARTED_AT" "$ENV_FILE")"

            if [[ "$MITM_PID" =~ ^[0-9]+$ ]] && kill -0 "$MITM_PID" 2>/dev/null; then
                echo "Capture RUNNING"
                echo "  PID:    $MITM_PID"
                echo "  Proxy:  ${LISTEN_HOST:-127.0.0.1}:${LISTEN_PORT:-18080}"
                echo "  Since:  ${STARTED_AT:-unknown}"
                exit 0
            else
                echo "Capture NOT RUNNING (stale state file)"
                exit 1
            fi
        else
            echo "Capture NOT RUNNING"
            exit 1
        fi
        ;;

    analyze)
        "$SCRIPT_DIR/analyzeLatest.sh" -d "$WORK_DIR" --stdout
        ;;

    doctor)
        # Build doctor command arguments
        DOCTOR_CMD=("$SCRIPT_DIR/doctor.sh" -P "$PROXY_PORT")
        [[ -n "$POLICY_FILE" ]] && DOCTOR_CMD+=(--policy "$POLICY_FILE")

        "${DOCTOR_CMD[@]}"
        ;;

    cleanup)
        # Build cleanup command arguments
        CLEANUP_CMD=("$SCRIPT_DIR/cleanupCaptures.sh" -d "$WORK_DIR")
        [[ -n "$KEEP_DAYS" ]] && CLEANUP_CMD+=(--keep-days "$KEEP_DAYS")
        [[ -n "$KEEP_SIZE" ]] && CLEANUP_CMD+=(--keep-size "$KEEP_SIZE")
        [[ "$SECURE_DELETE" == "true" ]] && CLEANUP_CMD+=(--secure)
        [[ "$DRY_RUN" == "true" ]] && CLEANUP_CMD+=(--dry-run)

        "${CLEANUP_CMD[@]}"
        ;;

    diff)
        # Diff requires two index file paths as positional args
        if [[ ${#EXTRA_ARGS[@]} -lt 2 ]]; then
            err "diff requires two index.ndjson file paths"
            echo "Usage: capture-session.sh diff <baseline.index.ndjson> <current.index.ndjson> [--json <out>] [--md <out>]" >&2
            exit 1
        fi

        DIFF_CMD=(python3 "$SCRIPT_DIR/diff_captures.py" "${EXTRA_ARGS[0]}" "${EXTRA_ARGS[1]}")

        # Pass through remaining extra args (e.g. --json, --md, --stdout)
        if [[ ${#EXTRA_ARGS[@]} -gt 2 ]]; then
            DIFF_CMD+=("${EXTRA_ARGS[@]:2}")
        fi

        "${DIFF_CMD[@]}"
        ;;

    navlog)
        # Forward to navlog.sh with work dir and extra args
        NAVLOG_CMD=("$SCRIPT_DIR/navlog.sh")

        if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
            NAVLOG_CMD+=("${EXTRA_ARGS[@]}")
        fi

        NAVLOG_CMD+=(-d "$WORK_DIR")

        "${NAVLOG_CMD[@]}"
        ;;

    *)
        err "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
