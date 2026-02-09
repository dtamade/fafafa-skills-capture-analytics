#!/usr/bin/env bash
# startCaptures.sh - Start mitmproxy capture in current directory
# INTERNAL: This script should be called via capture-session.sh, not directly.
#           Direct invocation bypasses authorization checks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<'EOF'
Usage:
  ./startCaptures.sh [options]

Options:
  -p, --program             Program mode (do not modify system proxy)
  -H, --host <host>         Listen host (default: 127.0.0.1)
  -P, --port <port>         Listen port (default: 18080)
  -d, --dir <path>          Target directory to store captures (default: current dir)
      --allow-hosts <list>  Comma-separated allowed hosts (supports wildcards)
      --deny-hosts <list>   Comma-separated denied hosts (supports wildcards)
      --policy <file>       Policy JSON file for scope control
      --force-recover       Clean stale state file automatically
  -h, --help                Show this help

Scope Control:
  By default, all hosts are captured. Use --allow-hosts or --policy to restrict.
  Deny list takes precedence over allow list.

  Examples:
    --allow-hosts "example.com,*.example.com"
    --deny-hosts "*.google.com,accounts.*"
    --policy config/policy.json

Examples:
  ./startCaptures.sh
  ./startCaptures.sh --program --port 18081
  ./startCaptures.sh --dir /path/to/project
  ./startCaptures.sh --allow-hosts "example.com,*.example.com"
EOF
}

# Shared utilities (err, warn, require_value_arg, require_cmd, etc.)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

port_in_use() {
    local port="$1"

    if command -v ss >/dev/null 2>&1; then
        ss -H -ltn "sport = :$port" 2>/dev/null | grep -q .
        return $?
    fi

    if command -v lsof >/dev/null 2>&1; then
        lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
        return $?
    fi

    return 1
}

# Cross-platform proxy management
# shellcheck source=proxy_utils.sh
source "$SCRIPT_DIR/proxy_utils.sh"

PROGRAM_MODE=false
LISTEN_HOST="127.0.0.1"
LISTEN_PORT="18080"
TARGET_DIR="$(pwd)"
FORCE_RECOVER=false
ALLOW_HOSTS=""
DENY_HOSTS=""
POLICY_FILE=""

MITM_PID=""
TMP_ENV_FILE=""
PROXY_APPLIED=false

cleanup_on_error() {
    local exit_code="$?"

    if [[ "$exit_code" -eq 0 ]]; then
        return 0
    fi

    # Release lock on error
    if [[ -n "${LOCK_FILE:-}" ]]; then
        release_lock "$LOCK_FILE"
    fi

    if [[ -n "$TMP_ENV_FILE" ]]; then
        rm -f "$TMP_ENV_FILE" 2>/dev/null || true
    fi

    if [[ -n "$MITM_PID" ]] && kill -0 "$MITM_PID" 2>/dev/null; then
        kill -TERM "$MITM_PID" 2>/dev/null || true
        sleep 0.2
        kill -KILL "$MITM_PID" 2>/dev/null || true
    fi

    if [[ "$PROXY_APPLIED" == "true" && "$PROGRAM_MODE" != "true" ]]; then
        if [[ -f "$ENV_FILE" ]]; then
            restore_system_proxy_from_env "$ENV_FILE" >/dev/null 2>&1 || true
        elif [[ "$PROXY_BACKEND" == "gnome" ]]; then
            restore_gnome_proxy \
                "$PREV_PROXY_MODE" \
                "$PREV_PROXY_HTTP_HOST" \
                "$PREV_PROXY_HTTP_PORT" \
                "$PREV_PROXY_HTTPS_HOST" \
                "$PREV_PROXY_HTTPS_PORT" >/dev/null 2>&1 || true
        elif [[ "$PROXY_BACKEND" == "macos" ]]; then
            restore_macos_proxy \
                "$PREV_PROXY_SERVICE" \
                "$PREV_PROXY_HTTP_ENABLED" \
                "$PREV_PROXY_HTTP_HOST" \
                "$PREV_PROXY_HTTP_PORT" \
                "$PREV_PROXY_HTTPS_ENABLED" \
                "$PREV_PROXY_HTTPS_HOST" \
                "$PREV_PROXY_HTTPS_PORT" >/dev/null 2>&1 || true
        fi
    fi
}

trap cleanup_on_error EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--program)
            PROGRAM_MODE=true
            shift
            ;;
        -H|--host)
            require_value_arg "$1" "${2:-}"
            LISTEN_HOST="${2:-}"
            shift 2
            ;;
        -P|--port)
            require_value_arg "$1" "${2:-}"
            LISTEN_PORT="${2:-}"
            shift 2
            ;;
        -d|--dir)
            require_value_arg "$1" "${2:-}"
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        --force-recover)
            FORCE_RECOVER=true
            shift
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

if [[ -z "$LISTEN_HOST" ]]; then
    err "Listen host cannot be empty"
    exit 1
fi

case "$LISTEN_HOST" in
    127.0.0.1|::1|localhost) ;;
    *)
        warn "Binding to non-localhost address: $LISTEN_HOST"
        warn "This exposes the proxy to the network. Ensure this is intentional."
        ;;
esac

if ! [[ "$LISTEN_PORT" =~ ^[0-9]+$ ]] || (( LISTEN_PORT < 1 || LISTEN_PORT > 65535 )); then
    err "Invalid port: $LISTEN_PORT"
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    err "Target directory does not exist: $TARGET_DIR"
    exit 1
fi

require_cmd mitmdump

if port_in_use "$LISTEN_PORT"; then
    err "Port is already in use: $LISTEN_PORT"
    exit 1
fi

CAPTURES_DIR="$TARGET_DIR/captures"
ENV_FILE="$CAPTURES_DIR/proxy_info.env"
LOCK_FILE="$CAPTURES_DIR/.capture.lock"

mkdir -p "$CAPTURES_DIR"
chmod 700 "$CAPTURES_DIR" 2>/dev/null || true
if ! acquire_lock "$LOCK_FILE"; then
    err "Another capture operation is running. Please retry."
    exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
    ACTIVE_PID="$(read_kv "MITM_PID" "$ENV_FILE")"
    if [[ "$ACTIVE_PID" =~ ^[0-9]+$ ]] && kill -0 "$ACTIVE_PID" 2>/dev/null; then
        err "Capture already running (PID: $ACTIVE_PID). Stop it first."
        exit 1
    fi
    if [[ "$FORCE_RECOVER" == "true" ]]; then
        warn "Removing stale state file: $ENV_FILE"
        rm -f "$ENV_FILE"
    else
        warn "Found stale state file: $ENV_FILE"
        warn "Use --force-recover to clean it automatically"
        exit 1
    fi
fi

RUN_ID="$(date +%Y%m%d_%H%M%S)_$$"
FLOW_FILE="$CAPTURES_DIR/capture_${RUN_ID}.flow"
HAR_FILE="$CAPTURES_DIR/capture_${RUN_ID}.har"
LOG_FILE="$CAPTURES_DIR/capture_${RUN_ID}.log"
MANIFEST_FILE="$CAPTURES_DIR/capture_${RUN_ID}.manifest.json"
INDEX_FILE="$CAPTURES_DIR/capture_${RUN_ID}.index.ndjson"
SUMMARY_FILE="$CAPTURES_DIR/capture_${RUN_ID}.summary.md"
AI_JSON_FILE="$CAPTURES_DIR/capture_${RUN_ID}.ai.json"
AI_MD_FILE="$CAPTURES_DIR/capture_${RUN_ID}.ai.md"
NAVLOG_FILE="$CAPTURES_DIR/capture_${RUN_ID}.navigation.ndjson"

# Initialize empty navlog for browser navigation tracking
: > "$NAVLOG_FILE"

PREV_PROXY_MODE=""
PREV_PROXY_HTTP_HOST=""
PREV_PROXY_HTTP_PORT=""
PREV_PROXY_HTTPS_HOST=""
PREV_PROXY_HTTPS_PORT=""
PREV_PROXY_SERVICE=""
PREV_PROXY_HTTP_ENABLED=""
PREV_PROXY_HTTPS_ENABLED=""
PROXY_BACKEND=""

if [[ "$PROGRAM_MODE" != "true" ]]; then
    PROXY_BACKEND="$(detect_proxy_backend)"
    if [[ "$PROXY_BACKEND" != "none" ]]; then
        # Save current proxy state into variables
        while IFS='=' read -r key value; do
            [[ -z "$key" ]] && continue
            case "$key" in
                PROXY_BACKEND)           PROXY_BACKEND="$value" ;;
                PREV_PROXY_MODE)         PREV_PROXY_MODE="$value" ;;
                PREV_PROXY_HTTP_HOST)    PREV_PROXY_HTTP_HOST="$value" ;;
                PREV_PROXY_HTTP_PORT)    PREV_PROXY_HTTP_PORT="$value" ;;
                PREV_PROXY_HTTPS_HOST)   PREV_PROXY_HTTPS_HOST="$value" ;;
                PREV_PROXY_HTTPS_PORT)   PREV_PROXY_HTTPS_PORT="$value" ;;
                PREV_PROXY_SERVICE)      PREV_PROXY_SERVICE="$value" ;;
                PREV_PROXY_HTTP_ENABLED) PREV_PROXY_HTTP_ENABLED="$value" ;;
                PREV_PROXY_HTTPS_ENABLED) PREV_PROXY_HTTPS_ENABLED="$value" ;;
            esac
        done < <(save_proxy_state)
    else
        warn "No supported proxy backend found (need gsettings or networksetup)"
    fi
fi

# Compile scope policy for mitmproxy
ALLOW_HOSTS_REGEX=""
IGNORE_HOSTS_REGEX=""
SCOPE_POLICY_FILE=""

if [[ -n "$POLICY_FILE" ]]; then
    if [[ ! -f "$POLICY_FILE" ]]; then
        err "Policy file not found: $POLICY_FILE"
        exit 1
    fi
    SCOPE_POLICY_FILE="$POLICY_FILE"
    # Use policy.py to compile regex patterns
    POLICY_OUTPUT="$(python3 "$SCRIPT_DIR/policy.py" compile "$POLICY_FILE" 2>&1)" || {
        err "Failed to compile policy: $POLICY_OUTPUT"
        exit 1
    }
    ALLOW_HOSTS_REGEX="$(echo "$POLICY_OUTPUT" | grep '^allow_hosts=' | cut -d= -f2-)"
    IGNORE_HOSTS_REGEX="$(echo "$POLICY_OUTPUT" | grep '^ignore_hosts=' | cut -d= -f2-)"
elif [[ -n "$ALLOW_HOSTS" || -n "$DENY_HOSTS" ]]; then
    # Generate temp policy from CLI args using Python for safe JSON encoding
    TEMP_POLICY="$CAPTURES_DIR/.policy_${RUN_ID}.json"
    python3 -c "
import json, sys
allow = [h.strip() for h in sys.argv[1].split(',') if h.strip()] if sys.argv[1] else []
deny = [h.strip() for h in sys.argv[2].split(',') if h.strip()] if sys.argv[2] else []
json.dump({'scope': {'allow_hosts': allow, 'deny_hosts': deny}}, sys.stdout, indent=2)
" "$ALLOW_HOSTS" "$DENY_HOSTS" > "$TEMP_POLICY"
    SCOPE_POLICY_FILE="$TEMP_POLICY"
    # P0-2.1 Fix: Fail-closed - abort if policy compilation fails
    if POLICY_OUTPUT="$(python3 "$SCRIPT_DIR/policy.py" compile "$TEMP_POLICY" 2>&1)"; then
        ALLOW_HOSTS_REGEX="$(echo "$POLICY_OUTPUT" | grep '^allow_hosts=' | cut -d= -f2-)"
        IGNORE_HOSTS_REGEX="$(echo "$POLICY_OUTPUT" | grep '^ignore_hosts=' | cut -d= -f2-)"
    else
        err "Failed to compile scope policy (fail-closed): $POLICY_OUTPUT"
        rm -f "$TEMP_POLICY"
        exit 1
    fi
fi

# P0-2.1 Fix: Use array instead of eval to prevent command injection
MITM_CMD=(mitmdump -q --listen-host "$LISTEN_HOST" --listen-port "$LISTEN_PORT")
MITM_CMD+=(--set block_global=false --set flow_detail=0)

if [[ -n "$ALLOW_HOSTS_REGEX" ]]; then
    MITM_CMD+=(--set "allow_hosts=$ALLOW_HOSTS_REGEX")
fi
if [[ -n "$IGNORE_HOSTS_REGEX" ]]; then
    MITM_CMD+=(--set "ignore_hosts=$IGNORE_HOSTS_REGEX")
fi

# Start mitmproxy with scope filtering (no eval)
"${MITM_CMD[@]}" -w "$FLOW_FILE" >"$LOG_FILE" 2>&1 9>&- &
MITM_PID=$!

sleep 0.5
if ! kill -0 "$MITM_PID" 2>/dev/null; then
    err "Failed to start mitmdump"
    [[ -s "$LOG_FILE" ]] && tail -n 20 "$LOG_FILE" >&2
    exit 1
fi

for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
    if ! kill -0 "$MITM_PID" 2>/dev/null; then
        err "mitmdump exited during startup"
        [[ -s "$LOG_FILE" ]] && tail -n 20 "$LOG_FILE" >&2
        exit 1
    fi
    if port_in_use "$LISTEN_PORT"; then
        break
    fi
    sleep 0.2
done

# Final verification: port must be listening after startup loop
if ! port_in_use "$LISTEN_PORT"; then
    err "mitmdump started but port $LISTEN_PORT is not listening after timeout"
    [[ -s "$LOG_FILE" ]] && tail -n 20 "$LOG_FILE" >&2
    kill -TERM "$MITM_PID" 2>/dev/null || true
    exit 1
fi

if [[ "$PROGRAM_MODE" != "true" && "$PROXY_BACKEND" != "none" && -n "$PROXY_BACKEND" ]]; then
    if ! set_system_proxy "$LISTEN_HOST" "$LISTEN_PORT"; then
        warn "Failed to update system proxy ($PROXY_BACKEND)"
    else
        PROXY_APPLIED=true
    fi
fi

STARTED_AT="$(date +%Y-%m-%dT%H:%M:%S)"

TMP_ENV_FILE="$ENV_FILE.tmp.$$"
(umask 077 && cat >"$TMP_ENV_FILE" <<EOF
MITM_PID="$MITM_PID"
PROGRAM_MODE="$PROGRAM_MODE"
TARGET_DIR="$TARGET_DIR"
CAPTURES_DIR="$CAPTURES_DIR"
RUN_ID="$RUN_ID"
FLOW_FILE="$FLOW_FILE"
HAR_FILE="$HAR_FILE"
LOG_FILE="$LOG_FILE"
MANIFEST_FILE="$MANIFEST_FILE"
INDEX_FILE="$INDEX_FILE"
SUMMARY_FILE="$SUMMARY_FILE"
AI_JSON_FILE="$AI_JSON_FILE"
AI_MD_FILE="$AI_MD_FILE"
NAVLOG_FILE="$NAVLOG_FILE"
LISTEN_HOST="$LISTEN_HOST"
LISTEN_PORT="$LISTEN_PORT"
STARTED_AT="$STARTED_AT"
ALLOW_HOSTS="$ALLOW_HOSTS"
DENY_HOSTS="$DENY_HOSTS"
SCOPE_POLICY_FILE="$SCOPE_POLICY_FILE"
PROXY_BACKEND="$PROXY_BACKEND"
PREV_PROXY_MODE="$PREV_PROXY_MODE"
PREV_PROXY_HTTP_HOST="$PREV_PROXY_HTTP_HOST"
PREV_PROXY_HTTP_PORT="$PREV_PROXY_HTTP_PORT"
PREV_PROXY_HTTPS_HOST="$PREV_PROXY_HTTPS_HOST"
PREV_PROXY_HTTPS_PORT="$PREV_PROXY_HTTPS_PORT"
PREV_PROXY_SERVICE="$PREV_PROXY_SERVICE"
PREV_PROXY_HTTP_ENABLED="$PREV_PROXY_HTTP_ENABLED"
PREV_PROXY_HTTPS_ENABLED="$PREV_PROXY_HTTPS_ENABLED"
EOF
)
mv "$TMP_ENV_FILE" "$ENV_FILE"
TMP_ENV_FILE=""

FLOW_SHA256=""
FLOW_SHA256="$(compute_sha256 "$FLOW_FILE" || true)"

python3 -c "
import json, sys
data = {
    'schemaVersion': '1',
    'runId': sys.argv[1],
    'targetDir': sys.argv[2],
    'capturesDir': sys.argv[3],
    'startedAt': sys.argv[4],
    'programMode': sys.argv[5] == 'true',
    'listen': {
        'host': sys.argv[6],
        'port': int(sys.argv[7])
    },
    'process': {
        'pid': int(sys.argv[8]),
        'launcher': 'mitmdump'
    },
    'files': {
        'flow': sys.argv[9],
        'har': sys.argv[10],
        'log': sys.argv[11],
        'index': sys.argv[12],
        'summary': sys.argv[13],
        'aiJson': sys.argv[14],
        'aiMd': sys.argv[15],
        'navlog': sys.argv[16],
        'stateEnv': sys.argv[17],
        'flowSha256AtStart': sys.argv[18]
    },
    'rawDataPolicy': {
        'immutable': True,
        'description': 'Raw capture files are not modified by analysis artifacts'
    }
}
json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
" "$RUN_ID" "$TARGET_DIR" "$CAPTURES_DIR" "$STARTED_AT" "$PROGRAM_MODE" \
  "$LISTEN_HOST" "$LISTEN_PORT" "$MITM_PID" \
  "$FLOW_FILE" "$HAR_FILE" "$LOG_FILE" "$INDEX_FILE" "$SUMMARY_FILE" \
  "$AI_JSON_FILE" "$AI_MD_FILE" "$NAVLOG_FILE" "$ENV_FILE" "$FLOW_SHA256" \
  > "${MANIFEST_FILE}.tmp.$$"
chmod 600 "${MANIFEST_FILE}.tmp.$$" 2>/dev/null || true
mv "${MANIFEST_FILE}.tmp.$$" "$MANIFEST_FILE"

echo "================================================"
echo " mitmproxy capture started"
echo "================================================"
echo " PID:          $MITM_PID"
echo " Listen:       $LISTEN_HOST:$LISTEN_PORT"
echo " Flow file:    $FLOW_FILE"
echo " HAR file:     $HAR_FILE"
echo " Log file:     $LOG_FILE"
echo " Manifest:     $MANIFEST_FILE"
if [[ "$PROGRAM_MODE" == "true" ]]; then
    echo " Proxy mode:   program (system proxy unchanged)"
else
    if [[ "$PROXY_APPLIED" == "true" ]]; then
        echo " Proxy mode:   $PROXY_BACKEND system proxy -> manual"
    else
        echo " Proxy mode:   unchanged (no proxy backend or failed)"
    fi
fi
echo ""
echo " To stop and export HAR:"
echo "   $(cd "$(dirname "$0")" && pwd)/stopCaptures.sh"
echo " Then ask AI directly:"
echo "   $(cd "$(dirname "$0")" && pwd)/ai.sh"
echo "================================================"

release_lock "$LOCK_FILE"
trap - EXIT
