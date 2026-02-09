#!/usr/bin/env bash
# stopCaptures.sh - Stop mitmproxy capture in current directory
# INTERNAL: Prefer capture-session.sh stop for consistent workflow.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./stopCaptures.sh [options]

Options:
  -d, --dir <path>          Target directory (default: current dir)
      --keep-env            Keep proxy_info.env for debugging
      --har-backend <name>  HAR backend: auto|mitmdump|python (default: auto)
      --no-har              Skip HAR conversion
  -h, --help                Show this help

Examples:
  ./stopCaptures.sh
  ./stopCaptures.sh --har-backend python
  ./stopCaptures.sh --har-backend python --no-har
EOF
}

# Cross-platform proxy management
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Shared utilities (err, warn, require_value_arg, etc.)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

set_latest_link() {
    local src="$1"
    local link="$2"

    if [[ -n "$src" && -f "$src" ]]; then
        ln -sfn "$src" "$link" 2>/dev/null || true
    else
        rm -f "$link" 2>/dev/null || true
    fi
}

# shellcheck source=proxy_utils.sh
source "$SCRIPT_DIR/proxy_utils.sh"

stop_pid() {
    local pid="$1"
    if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
        return 2
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
        return 1
    fi

    kill -TERM "$pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8; do
        if ! kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        sleep 0.3
    done

    kill -KILL "$pid" 2>/dev/null || true
    sleep 0.2
    if kill -0 "$pid" 2>/dev/null; then
        return 3
    fi
    return 0
}

har_convert_with_mitmdump() {
    local flow_file="$1"
    local har_file="$2"

    mitmdump -q -n -r "$flow_file" --set hardump="$har_file" 9>&- >/dev/null 2>&1
}

har_convert_with_python() {
    local flow_file="$1"
    local har_file="$2"
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"

    python3 "$script_dir/flow2har.py" "$flow_file" "$har_file" 9>&- >/dev/null 2>&1
}

TARGET_DIR="$(pwd)"
KEEP_ENV=false
HAR_BACKEND="auto"
DO_HAR=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            require_value_arg "$1" "${2:-}"
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        --keep-env)
            KEEP_ENV=true
            shift
            ;;
        --har-backend)
            require_value_arg "$1" "${2:-}"
            HAR_BACKEND="${2:-}"
            shift 2
            ;;
        --no-har)
            DO_HAR=false
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

if [[ ! -d "$TARGET_DIR" ]]; then
    err "Target directory does not exist: $TARGET_DIR"
    exit 1
fi

if [[ "$HAR_BACKEND" != "auto" && "$HAR_BACKEND" != "mitmdump" && "$HAR_BACKEND" != "python" ]]; then
    err "Invalid --har-backend: $HAR_BACKEND"
    exit 1
fi

CAPTURES_DIR="$TARGET_DIR/captures"
ENV_FILE="$CAPTURES_DIR/proxy_info.env"
LOCK_FILE="$CAPTURES_DIR/.capture.lock"

# Cleanup on any exit (including Ctrl+C)
_stop_cleanup() {
    # Attempt proxy restoration if not yet done
    if [[ "${_PROXY_RESTORED:-}" != "true" && -f "$ENV_FILE" ]]; then
        local pm
        pm="$(read_kv "PROGRAM_MODE" "$ENV_FILE")"
        if [[ "$pm" != "true" ]]; then
            restore_system_proxy_from_env "$ENV_FILE" 2>/dev/null || true
        fi
    fi
    release_lock "$LOCK_FILE" 2>/dev/null || true
}
trap _stop_cleanup EXIT

mkdir -p "$CAPTURES_DIR"
if ! acquire_lock "$LOCK_FILE"; then
    err "Another capture operation is running. Please retry."
    exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
    warn "No active capture metadata found: $ENV_FILE"
    warn "Nothing to stop."
    exit 0
fi

MITM_PID="$(read_kv "MITM_PID" "$ENV_FILE")"
PROGRAM_MODE="$(read_kv "PROGRAM_MODE" "$ENV_FILE")"
RUN_ID="$(read_kv "RUN_ID" "$ENV_FILE")"
FLOW_FILE="$(read_kv "FLOW_FILE" "$ENV_FILE")"
HAR_FILE="$(read_kv "HAR_FILE" "$ENV_FILE")"
LOG_FILE="$(read_kv "LOG_FILE" "$ENV_FILE")"
MANIFEST_FILE="$(read_kv "MANIFEST_FILE" "$ENV_FILE")"
INDEX_FILE="$(read_kv "INDEX_FILE" "$ENV_FILE")"
SUMMARY_FILE="$(read_kv "SUMMARY_FILE" "$ENV_FILE")"
AI_JSON_FILE="$(read_kv "AI_JSON_FILE" "$ENV_FILE")"
AI_MD_FILE="$(read_kv "AI_MD_FILE" "$ENV_FILE")"
NAVLOG_FILE="$(read_kv "NAVLOG_FILE" "$ENV_FILE")"
LISTEN_HOST="$(read_kv "LISTEN_HOST" "$ENV_FILE")"
LISTEN_PORT="$(read_kv "LISTEN_PORT" "$ENV_FILE")"
STARTED_AT="$(read_kv "STARTED_AT" "$ENV_FILE")"
ALLOW_HOSTS="$(read_kv "ALLOW_HOSTS" "$ENV_FILE")"
DENY_HOSTS="$(read_kv "DENY_HOSTS" "$ENV_FILE")"
SCOPE_POLICY_FILE="$(read_kv "SCOPE_POLICY_FILE" "$ENV_FILE")"
PREV_PROXY_MODE="$(read_kv "PREV_PROXY_MODE" "$ENV_FILE")"
PREV_PROXY_HTTP_HOST="$(read_kv "PREV_PROXY_HTTP_HOST" "$ENV_FILE")"
PREV_PROXY_HTTP_PORT="$(read_kv "PREV_PROXY_HTTP_PORT" "$ENV_FILE")"
PREV_PROXY_HTTPS_HOST="$(read_kv "PREV_PROXY_HTTPS_HOST" "$ENV_FILE")"
PREV_PROXY_HTTPS_PORT="$(read_kv "PREV_PROXY_HTTPS_PORT" "$ENV_FILE")"

BASE_NO_EXT=""
if [[ -n "$FLOW_FILE" ]]; then
    BASE_NO_EXT="${FLOW_FILE%.flow}"
fi
if [[ -z "$BASE_NO_EXT" ]]; then
    BASE_NO_EXT="$CAPTURES_DIR/capture_$(date +%Y%m%d_%H%M%S)_stop"
fi

if [[ -z "$RUN_ID" ]]; then
    flow_name="$(basename "$BASE_NO_EXT")"
    RUN_ID="${flow_name#capture_}"
fi
if [[ -z "$MANIFEST_FILE" ]]; then
    MANIFEST_FILE="${BASE_NO_EXT}.manifest.json"
fi
if [[ -z "$INDEX_FILE" ]]; then
    INDEX_FILE="${BASE_NO_EXT}.index.ndjson"
fi
if [[ -z "$SUMMARY_FILE" ]]; then
    SUMMARY_FILE="${BASE_NO_EXT}.summary.md"
fi
if [[ -z "$AI_JSON_FILE" ]]; then
    AI_JSON_FILE="${BASE_NO_EXT}.ai.json"
fi
if [[ -z "$AI_MD_FILE" ]]; then
    AI_MD_FILE="${BASE_NO_EXT}.ai.md"
fi

STOP_STATUS="not-running"
STOP_RC=0
stop_pid "$MITM_PID" || STOP_RC=$?
case "$STOP_RC" in
    0) STOP_STATUS="stopped" ;;
    1) STOP_STATUS="not-running" ;;
    2) STOP_STATUS="invalid-pid" ;;
    3) STOP_STATUS="kill-failed" ;;
    *) STOP_STATUS="unknown" ;;
esac

PROXY_STATUS="unchanged"
if [[ "$PROGRAM_MODE" != "true" ]]; then
    if restore_system_proxy_from_env "$ENV_FILE"; then
        PROXY_STATUS="restored"
        _PROXY_RESTORED="true"
    else
        PROXY_STATUS="restore-failed"
        _PROXY_RESTORED="true"
    fi
fi

HAR_STATUS="skipped"
HAR_BACKEND_USED="none"

if [[ "$DO_HAR" == "true" ]]; then
    if [[ -n "$FLOW_FILE" && -f "$FLOW_FILE" && -s "$FLOW_FILE" ]]; then
        if [[ -z "$HAR_FILE" ]]; then
            HAR_FILE="$CAPTURES_DIR/capture_$(date +%Y%m%d_%H%M%S)_stop.har"
        fi

        case "$HAR_BACKEND" in
            mitmdump)
                HAR_BACKEND_USED="mitmdump"
                if har_convert_with_mitmdump "$FLOW_FILE" "$HAR_FILE"; then
                    HAR_STATUS="ok"
                else
                    HAR_STATUS="failed"
                fi
                ;;
            python)
                HAR_BACKEND_USED="python"
                if har_convert_with_python "$FLOW_FILE" "$HAR_FILE"; then
                    HAR_STATUS="ok"
                else
                    HAR_STATUS="failed"
                fi
                ;;
            auto)
                if command -v mitmdump >/dev/null 2>&1; then
                    HAR_BACKEND_USED="mitmdump"
                    if har_convert_with_mitmdump "$FLOW_FILE" "$HAR_FILE"; then
                        HAR_STATUS="ok"
                    elif command -v python3 >/dev/null 2>&1; then
                        HAR_BACKEND_USED="python"
                        if har_convert_with_python "$FLOW_FILE" "$HAR_FILE"; then
                            HAR_STATUS="ok"
                        else
                            HAR_STATUS="failed"
                        fi
                    else
                        HAR_STATUS="failed"
                    fi
                elif command -v python3 >/dev/null 2>&1; then
                    HAR_BACKEND_USED="python"
                    if har_convert_with_python "$FLOW_FILE" "$HAR_FILE"; then
                        HAR_STATUS="ok"
                    else
                        HAR_STATUS="failed"
                    fi
                else
                    HAR_STATUS="failed"
                fi
                ;;
        esac
    else
        HAR_STATUS="no-flow"
    fi
fi

REPORT_STATUS="skipped"
REPORT_ERROR_LOG="$CAPTURES_DIR/report_error.log"
if [[ -n "$FLOW_FILE" && -f "$FLOW_FILE" && -s "$FLOW_FILE" ]]; then
    if command -v python3 >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/flow_report.py" ]]; then
        # P1-3: Check Python mitmproxy module
        if ! python3 -c "from mitmproxy.io import FlowReader" 9>&- 2>/dev/null; then
            REPORT_STATUS="missing-mitmproxy-module"
            echo "Python mitmproxy module not found. Install with: pip install mitmproxy" > "$REPORT_ERROR_LOG"
        # P1-4: Preserve error output for debugging
        elif python3 "$SCRIPT_DIR/flow_report.py" "$FLOW_FILE" "$INDEX_FILE" "$SUMMARY_FILE" 9>&- 2>"$REPORT_ERROR_LOG"; then
            REPORT_STATUS="ok"
            rm -f "$REPORT_ERROR_LOG"
        else
            REPORT_STATUS="failed"
        fi
    else
        REPORT_STATUS="missing-tool"
    fi
else
    REPORT_STATUS="no-flow"
fi

AI_BRIEF_STATUS="skipped"
AI_BRIEF_ERROR_LOG="$CAPTURES_DIR/ai_brief_error.log"
if [[ "$REPORT_STATUS" == "ok" && -f "$MANIFEST_FILE" && -f "$INDEX_FILE" ]]; then
    if command -v python3 >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/ai_brief.py" ]]; then
        # P1-4: Preserve error output for debugging
        if python3 "$SCRIPT_DIR/ai_brief.py" "$MANIFEST_FILE" "$INDEX_FILE" "$AI_JSON_FILE" "$AI_MD_FILE" 9>&- 2>"$AI_BRIEF_ERROR_LOG"; then
            AI_BRIEF_STATUS="ok"
            rm -f "$AI_BRIEF_ERROR_LOG"
        else
            AI_BRIEF_STATUS="failed"
        fi
    else
        AI_BRIEF_STATUS="missing-tool"
    fi
elif [[ "$REPORT_STATUS" == "failed" || "$REPORT_STATUS" == "missing-tool" || "$REPORT_STATUS" == "missing-mitmproxy-module" ]]; then
    AI_BRIEF_STATUS="blocked-by-report"
else
    AI_BRIEF_STATUS="no-index"
fi

# P0-2.1 Fix: Run scope audit independently of report status
# Audit can run directly on flow file if index is missing
SCOPE_AUDIT_STATUS="skipped"
SCOPE_AUDIT_FILE="${BASE_NO_EXT}.scope_audit.json"
SCOPE_AUDIT_VIOLATIONS=0

if [[ -n "$ALLOW_HOSTS" || -n "$DENY_HOSTS" || -n "$SCOPE_POLICY_FILE" ]]; then
    if command -v python3 >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/scope_audit.py" ]]; then
        # Try to use index file if available, otherwise skip audit
        if [[ -f "$INDEX_FILE" ]]; then
            # P0-2.1 Fix: Use array instead of eval to prevent command injection
            AUDIT_CMD=(python3 "$SCRIPT_DIR/scope_audit.py" "$INDEX_FILE" -o "$SCOPE_AUDIT_FILE")
            if [[ -n "$SCOPE_POLICY_FILE" && -f "$SCOPE_POLICY_FILE" ]]; then
                AUDIT_CMD+=(--policy "$SCOPE_POLICY_FILE")
            else
                [[ -n "$ALLOW_HOSTS" ]] && AUDIT_CMD+=(--allow-hosts "$ALLOW_HOSTS")
                [[ -n "$DENY_HOSTS" ]] && AUDIT_CMD+=(--deny-hosts "$DENY_HOSTS")
            fi

            if "${AUDIT_CMD[@]}" 9>&- 2>/dev/null; then
                SCOPE_AUDIT_STATUS="pass"
            else
                SCOPE_AUDIT_STATUS="violation"
                # Count violations from audit file
                if [[ -f "$SCOPE_AUDIT_FILE" ]]; then
                    SCOPE_AUDIT_VIOLATIONS="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['outOfScopeCount'])" "$SCOPE_AUDIT_FILE" 9>&- 2>/dev/null || echo 0)"
                fi
            fi
        else
            SCOPE_AUDIT_STATUS="no-index"
        fi
    else
        SCOPE_AUDIT_STATUS="missing-tool"
    fi
else
    SCOPE_AUDIT_STATUS="no-policy"
fi

STOPPED_AT="$(date +%Y-%m-%dT%H:%M:%S)"

FLOW_SHA256=""
if [[ -n "$FLOW_FILE" && -f "$FLOW_FILE" ]]; then
    FLOW_SHA256="$(compute_sha256 "$FLOW_FILE" || true)"
fi

MANIFEST_STATUS="ok"
MANIFEST_TMP="${MANIFEST_FILE}.tmp.$$"
if ! python3 -c "
import json, sys
data = {
    'schemaVersion': '1',
    'runId': sys.argv[1],
    'targetDir': sys.argv[2],
    'capturesDir': sys.argv[3],
    'startedAt': sys.argv[4],
    'stoppedAt': sys.argv[5],
    'programMode': sys.argv[6] == 'true',
    'listen': {'host': sys.argv[7], 'port': int(sys.argv[8]) if sys.argv[8].isdigit() else sys.argv[8]},
    'process': {'pid': int(sys.argv[9]) if sys.argv[9].isdigit() else sys.argv[9], 'stopStatus': sys.argv[10]},
    'scope': {
        'allowHosts': sys.argv[11],
        'denyHosts': sys.argv[12],
        'policyFile': sys.argv[13],
        'auditStatus': sys.argv[14],
        'auditFile': sys.argv[15],
        'violations': int(sys.argv[16])
    },
    'artifacts': {
        'flow': sys.argv[17], 'flowSha256': sys.argv[18],
        'har': sys.argv[19], 'harStatus': sys.argv[20], 'harBackend': sys.argv[21],
        'log': sys.argv[22], 'manifest': sys.argv[23],
        'index': sys.argv[24], 'summary': sys.argv[25], 'reportStatus': sys.argv[26],
        'aiJson': sys.argv[27], 'aiMd': sys.argv[28], 'aiBriefStatus': sys.argv[29],
        'navlog': sys.argv[30], 'scopeAudit': sys.argv[31]
    },
    'rawDataPolicy': {
        'immutable': True,
        'description': 'Raw capture files are not modified by analysis artifacts'
    }
}
json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
" "$RUN_ID" "$TARGET_DIR" "$CAPTURES_DIR" "$STARTED_AT" "$STOPPED_AT" \
  "$PROGRAM_MODE" "$LISTEN_HOST" "$LISTEN_PORT" "$MITM_PID" "$STOP_STATUS" \
  "$ALLOW_HOSTS" "$DENY_HOSTS" "$SCOPE_POLICY_FILE" "$SCOPE_AUDIT_STATUS" "$SCOPE_AUDIT_FILE" "$SCOPE_AUDIT_VIOLATIONS" \
  "$FLOW_FILE" "$FLOW_SHA256" "$HAR_FILE" "$HAR_STATUS" "$HAR_BACKEND_USED" \
  "$LOG_FILE" "$MANIFEST_FILE" "$INDEX_FILE" "$SUMMARY_FILE" "$REPORT_STATUS" \
  "$AI_JSON_FILE" "$AI_MD_FILE" "$AI_BRIEF_STATUS" "$NAVLOG_FILE" "$SCOPE_AUDIT_FILE" \
  9>&- > "$MANIFEST_TMP"
then
    MANIFEST_STATUS="failed"
else
    chmod 600 "$MANIFEST_TMP" 2>/dev/null || true
    mv "$MANIFEST_TMP" "$MANIFEST_FILE" 2>/dev/null || MANIFEST_STATUS="failed"
fi
rm -f "$MANIFEST_TMP" 2>/dev/null || true

LATEST_FLOW_LINK="$CAPTURES_DIR/latest.flow"
LATEST_HAR_LINK="$CAPTURES_DIR/latest.har"
LATEST_LOG_LINK="$CAPTURES_DIR/latest.log"
LATEST_MANIFEST_LINK="$CAPTURES_DIR/latest.manifest.json"
LATEST_INDEX_LINK="$CAPTURES_DIR/latest.index.ndjson"
LATEST_SUMMARY_LINK="$CAPTURES_DIR/latest.summary.md"
LATEST_AI_JSON_LINK="$CAPTURES_DIR/latest.ai.json"
LATEST_AI_MD_LINK="$CAPTURES_DIR/latest.ai.md"
LATEST_NAVLOG_LINK="$CAPTURES_DIR/latest.navigation.ndjson"

set_latest_link "$FLOW_FILE" "$LATEST_FLOW_LINK"
set_latest_link "$HAR_FILE" "$LATEST_HAR_LINK"
set_latest_link "$LOG_FILE" "$LATEST_LOG_LINK"
set_latest_link "$MANIFEST_FILE" "$LATEST_MANIFEST_LINK"
set_latest_link "$INDEX_FILE" "$LATEST_INDEX_LINK"
set_latest_link "$SUMMARY_FILE" "$LATEST_SUMMARY_LINK"
set_latest_link "$AI_JSON_FILE" "$LATEST_AI_JSON_LINK"
set_latest_link "$AI_MD_FILE" "$LATEST_AI_MD_LINK"
set_latest_link "$NAVLOG_FILE" "$LATEST_NAVLOG_LINK"

if [[ "$KEEP_ENV" != "true" ]]; then
    rm -f "$ENV_FILE"
fi

echo "================================================"
echo " mitmproxy capture stop summary"
echo "================================================"
echo " PID:            ${MITM_PID:-<unknown>}"
echo " Stop status:    $STOP_STATUS"
if [[ -n "$LISTEN_HOST" || -n "$LISTEN_PORT" ]]; then
    echo " Listen:         ${LISTEN_HOST:-?}:${LISTEN_PORT:-?}"
fi
echo " Flow file:      ${FLOW_FILE:-<unknown>}"
echo " HAR file:       ${HAR_FILE:-<none>}"
echo " HAR status:     $HAR_STATUS"
echo " HAR backend:    $HAR_BACKEND_USED"
echo " Index status:   $REPORT_STATUS"
echo " Index file:     $INDEX_FILE"
echo " Summary file:   $SUMMARY_FILE"
echo " AI JSON file:   $AI_JSON_FILE"
echo " AI MD file:     $AI_MD_FILE"
echo " AI brief:       $AI_BRIEF_STATUS"
echo " Scope audit:    $SCOPE_AUDIT_STATUS"
if [[ "$SCOPE_AUDIT_STATUS" == "violation" ]]; then
    echo " [!] Violations:  $SCOPE_AUDIT_VIOLATIONS out-of-scope requests detected!"
fi
echo " Manifest file:  $MANIFEST_FILE"
echo " Manifest:       $MANIFEST_STATUS"
echo " Latest flow:    $LATEST_FLOW_LINK"
echo " Latest summary: $LATEST_SUMMARY_LINK"
echo " Latest AI brief:$LATEST_AI_MD_LINK"
if [[ -n "$LOG_FILE" ]]; then
    echo " Log file:       $LOG_FILE"
fi
if [[ "$PROGRAM_MODE" != "true" ]]; then
    echo " Proxy restore:  $PROXY_STATUS"
fi
echo ""
if [[ -n "$FLOW_FILE" && -f "$FLOW_FILE" ]]; then
    echo " To inspect flow:"
    echo "   mitmweb -r $FLOW_FILE"
fi
if [[ "$HAR_STATUS" == "ok" ]]; then
    echo " HAR ready for AI:"
    echo "   $HAR_FILE"
fi
echo ""
echo " Quick use (Human):"
if [[ -f "$LATEST_SUMMARY_LINK" ]]; then
    echo "   less $LATEST_SUMMARY_LINK"
fi
if [[ -f "$LATEST_FLOW_LINK" ]]; then
    echo "   mitmweb -r $LATEST_FLOW_LINK"
fi
echo " Quick use (AI):"
if [[ -f "$LATEST_AI_MD_LINK" ]]; then
    echo "   cat $LATEST_AI_MD_LINK"
fi
if [[ -f "$LATEST_AI_JSON_LINK" ]]; then
    echo "   cat $LATEST_AI_JSON_LINK"
fi
if [[ -f "$SCRIPT_DIR/analyzeLatest.sh" && -x "$SCRIPT_DIR/analyzeLatest.sh" ]]; then
    echo "   $SCRIPT_DIR/analyzeLatest.sh"
fi
if [[ -f "$SCRIPT_DIR/ai.sh" && -x "$SCRIPT_DIR/ai.sh" ]]; then
    echo "   $SCRIPT_DIR/ai.sh"
fi
echo "================================================"

if [[ "$STOP_STATUS" == "kill-failed" || "$PROXY_STATUS" == "restore-failed" || "$HAR_STATUS" == "failed" || "$REPORT_STATUS" == "failed" || "$AI_BRIEF_STATUS" == "failed" || "$MANIFEST_STATUS" == "failed" ]]; then
    exit 2
fi

# Exit with code 3 if scope violations detected (partial success)
if [[ "$SCOPE_AUDIT_STATUS" == "violation" ]]; then
    echo ""
    echo "[!] WARNING: Out-of-scope traffic detected! Review $SCOPE_AUDIT_FILE"
    exit 3
fi

exit 0
