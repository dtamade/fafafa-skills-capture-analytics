#!/usr/bin/env bash
# navlog.sh - Record browser navigation events during capture sessions
# Appends structured NDJSON entries to a navigation log file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<'EOF'
Usage:
  navlog.sh <command> [options]

Commands:
  init                  Create empty navlog file for a capture session
  append <json>         Append a navigation event
  show                  Display current navlog contents

Options:
  -d, --dir <path>      Working directory (default: current dir)
  -f, --file <path>     Navlog file path (overrides auto-detect)
  -h, --help            Show this help

Append Shorthand (auto-wraps into JSON):
  navlog.sh append --action navigate --url "https://example.com" --title "Home"
  navlog.sh append --action click --selector "#login" --url "https://example.com/login"
  navlog.sh append --action scroll --url "https://example.com" --note "scroll to footer"
  navlog.sh append --action input --selector "#search" --value "query" --url "https://example.com"
  navlog.sh append --action wait --duration 2000 --note "wait for load"

Raw JSON:
  navlog.sh append '{"action":"navigate","url":"https://example.com","title":"Home"}'

Format (NDJSON, one event per line):
  {"ts":"2026-02-09T10:00:00Z","action":"navigate","url":"https://example.com","title":"Home"}
  {"ts":"2026-02-09T10:00:05Z","action":"click","selector":"#login","url":"https://example.com/login"}
EOF
}

# Shared utilities (err, require_value_arg, read_kv, etc.)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Resolve navlog file path from session state
resolve_navlog() {
    local work_dir="$1"
    local explicit_file="$2"

    if [[ -n "$explicit_file" ]]; then
        echo "$explicit_file"
        return 0
    fi

    local env_file="$work_dir/captures/proxy_info.env"
    if [[ -f "$env_file" ]]; then
        local navlog_path
        navlog_path="$(read_kv "NAVLOG_FILE" "$env_file")"
        if [[ -n "$navlog_path" ]]; then
            echo "$navlog_path"
            return 0
        fi
    fi

    # Fallback: try latest.navigation.ndjson
    local latest="$work_dir/captures/latest.navigation.ndjson"
    if [[ -f "$latest" || -L "$latest" ]]; then
        echo "$latest"
        return 0
    fi

    return 1
}

# ── Parse arguments ──────────────────────────────────────────────────

# Check --help before command extraction
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            usage
            exit 0
            ;;
    esac
done

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

COMMAND="$1"
shift

WORK_DIR="$(pwd)"
NAVLOG_FILE=""

# For append shorthand
ACTION=""
URL=""
TITLE=""
SELECTOR=""
VALUE=""
NOTE=""
DURATION=""
RAW_JSON=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            require_value_arg "$1" "${2:-}"
            WORK_DIR="${2:-}"
            shift 2
            ;;
        --dir=*)
            WORK_DIR="${1#*=}"
            [[ -z "$WORK_DIR" ]] && { err "Option --dir requires a value"; exit 1; }
            shift
            ;;
        -f|--file)
            require_value_arg "$1" "${2:-}"
            NAVLOG_FILE="${2:-}"
            shift 2
            ;;
        --file=*)
            NAVLOG_FILE="${1#*=}"
            [[ -z "$NAVLOG_FILE" ]] && { err "Option --file requires a value"; exit 1; }
            shift
            ;;
        --action)
            require_value_arg "$1" "${2:-}"
            ACTION="${2:-}"
            shift 2
            ;;
        --action=*)
            ACTION="${1#*=}"
            [[ -z "$ACTION" ]] && { err "Option --action requires a value"; exit 1; }
            shift
            ;;
        --url)
            require_value_arg "$1" "${2:-}"
            URL="${2:-}"
            shift 2
            ;;
        --url=*)
            URL="${1#*=}"
            [[ -z "$URL" ]] && { err "Option --url requires a value"; exit 1; }
            shift
            ;;
        --title)
            require_value_arg "$1" "${2:-}"
            TITLE="${2:-}"
            shift 2
            ;;
        --title=*)
            TITLE="${1#*=}"
            [[ -z "$TITLE" ]] && { err "Option --title requires a value"; exit 1; }
            shift
            ;;
        --selector)
            require_value_arg "$1" "${2:-}"
            SELECTOR="${2:-}"
            shift 2
            ;;
        --selector=*)
            SELECTOR="${1#*=}"
            [[ -z "$SELECTOR" ]] && { err "Option --selector requires a value"; exit 1; }
            shift
            ;;
        --value)
            require_value_arg "$1" "${2:-}"
            VALUE="${2:-}"
            shift 2
            ;;
        --value=*)
            VALUE="${1#*=}"
            [[ -z "$VALUE" ]] && { err "Option --value requires a value"; exit 1; }
            shift
            ;;
        --note)
            require_value_arg "$1" "${2:-}"
            NOTE="${2:-}"
            shift 2
            ;;
        --note=*)
            NOTE="${1#*=}"
            [[ -z "$NOTE" ]] && { err "Option --note requires a value"; exit 1; }
            shift
            ;;
        --duration)
            require_value_arg "$1" "${2:-}"
            DURATION="${2:-}"
            shift 2
            ;;
        --duration=*)
            DURATION="${1#*=}"
            [[ -z "$DURATION" ]] && { err "Option --duration requires a value"; exit 1; }
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            # Treat as raw JSON if it starts with {
            if [[ "$1" == "{"* ]]; then
                RAW_JSON="$1"
            fi
            shift
            ;;
    esac
done

# ── Commands ─────────────────────────────────────────────────────────

case "$COMMAND" in
    init)
        # Create navlog for current session or at explicit path
        if [[ -n "$NAVLOG_FILE" ]]; then
            : > "$NAVLOG_FILE"
            echo "Navlog initialized: $NAVLOG_FILE"
        else
            local_env="$WORK_DIR/captures/proxy_info.env"
            if [[ -f "$local_env" ]]; then
                local_navlog="$(read_kv "NAVLOG_FILE" "$local_env")"
                if [[ -n "$local_navlog" ]]; then
                    : > "$local_navlog"
                    echo "Navlog initialized: $local_navlog"
                else
                    err "No NAVLOG_FILE found in proxy_info.env. Specify -f <path>."
                    exit 1
                fi
            else
                err "No active capture session found. Specify -f <path>."
                exit 1
            fi
        fi
        ;;

    append)
        RESOLVED_FILE="$(resolve_navlog "$WORK_DIR" "$NAVLOG_FILE")" || {
            err "Cannot find navlog file. Is a capture session running? Use -f to specify."
            exit 1
        }

        TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

        if [[ -n "$RAW_JSON" ]]; then
            # Inject timestamp into raw JSON
            ENTRY="$(python3 -c "
import json, sys
try:
    obj = json.loads(sys.argv[1])
    if 'ts' not in obj:
        obj['ts'] = sys.argv[2]
    # Reorder: ts first
    ordered = {'ts': obj.pop('ts')}
    ordered.update(obj)
    print(json.dumps(ordered, ensure_ascii=False))
except Exception as e:
    print(f'[ERROR] Invalid JSON: {e}', file=sys.stderr)
    sys.exit(1)
" "$RAW_JSON" "$TS")" || exit 1
        elif [[ -n "$ACTION" ]]; then
            # Build JSON from shorthand flags
            ENTRY="$(python3 -c "
import json, sys
obj = {'ts': sys.argv[1], 'action': sys.argv[2]}
args = sys.argv[3:]
i = 0
while i < len(args):
    key, val = args[i], args[i+1]
    if val:
        obj[key] = val
    i += 2
print(json.dumps(obj, ensure_ascii=False))
" "$TS" "$ACTION" \
    "url" "$URL" \
    "title" "$TITLE" \
    "selector" "$SELECTOR" \
    "value" "$VALUE" \
    "note" "$NOTE" \
    "duration" "$DURATION")" || exit 1
        else
            err "append requires either raw JSON or --action flag"
            exit 1
        fi

        echo "$ENTRY" >> "$RESOLVED_FILE"
        echo "$ENTRY"
        ;;

    show)
        RESOLVED_FILE="$(resolve_navlog "$WORK_DIR" "$NAVLOG_FILE")" || {
            err "Cannot find navlog file. Is a capture session running? Use -f to specify."
            exit 1
        }

        if [[ ! -s "$RESOLVED_FILE" ]]; then
            echo "(navlog is empty)"
            exit 0
        fi

        cat "$RESOLVED_FILE"
        ;;

    *)
        err "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
