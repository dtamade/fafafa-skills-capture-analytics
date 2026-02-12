#!/usr/bin/env bash
# runWithProxyEnv.sh - Run a command with temporary proxy env vars for program-mode capture

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  runWithProxyEnv.sh [options] -- <command> [args...]

Options:
  -H, --host <host>        Proxy host (default: 127.0.0.1)
  -P, --port <port>        Proxy port (default: 18080)
      --no-all-proxy       Do not set ALL_PROXY/all_proxy
      --no-proxy <list>    NO_PROXY/no_proxy value (default: 127.0.0.1,localhost,::1)
      --print-env          Print exported proxy env vars before execution
  -h, --help               Show this help

Examples:
  ./runWithProxyEnv.sh -P 18080 -- curl -sS https://example.com
  ./runWithProxyEnv.sh --no-proxy "127.0.0.1,localhost,.internal" -- python app.py
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

HOST="127.0.0.1"
PORT="18080"
SET_ALL_PROXY=true
NO_PROXY_VALUE="127.0.0.1,localhost,::1"
PRINT_ENV=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -H|--host)
            require_value_arg "$1" "${2:-}"
            HOST="${2:-}"
            shift 2
            ;;
        --host=*)
            HOST="${1#*=}"
            [[ -z "$HOST" ]] && { echo "[ERROR] --host requires a value" >&2; exit 1; }
            shift
            ;;
        -P|--port)
            require_value_arg "$1" "${2:-}"
            PORT="${2:-}"
            shift 2
            ;;
        --port=*)
            PORT="${1#*=}"
            [[ -z "$PORT" ]] && { echo "[ERROR] --port requires a value" >&2; exit 1; }
            shift
            ;;
        --no-all-proxy)
            SET_ALL_PROXY=false
            shift
            ;;
        --no-proxy)
            require_value_arg "$1" "${2:-}"
            NO_PROXY_VALUE="${2:-}"
            shift 2
            ;;
        --no-proxy=*)
            NO_PROXY_VALUE="${1#*=}"
            shift
            ;;
        --print-env)
            PRINT_ENV=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [[ $# -eq 0 ]]; then
    echo "[ERROR] Missing command after --" >&2
    usage
    exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
    echo "[ERROR] Invalid port: $PORT" >&2
    exit 1
fi

PROXY_URL="http://${HOST}:${PORT}"

if [[ "$PRINT_ENV" == "true" ]]; then
    echo "HTTP_PROXY=$PROXY_URL"
    echo "HTTPS_PROXY=$PROXY_URL"
    if [[ "$SET_ALL_PROXY" == "true" ]]; then
        echo "ALL_PROXY=$PROXY_URL"
    fi
    echo "NO_PROXY=$NO_PROXY_VALUE"
fi

if [[ "$SET_ALL_PROXY" == "true" ]]; then
    env \
        HTTP_PROXY="$PROXY_URL" HTTPS_PROXY="$PROXY_URL" ALL_PROXY="$PROXY_URL" NO_PROXY="$NO_PROXY_VALUE" \
        http_proxy="$PROXY_URL" https_proxy="$PROXY_URL" all_proxy="$PROXY_URL" no_proxy="$NO_PROXY_VALUE" \
        "$@"
else
    env \
        HTTP_PROXY="$PROXY_URL" HTTPS_PROXY="$PROXY_URL" NO_PROXY="$NO_PROXY_VALUE" \
        http_proxy="$PROXY_URL" https_proxy="$PROXY_URL" no_proxy="$NO_PROXY_VALUE" \
        "$@"
fi
