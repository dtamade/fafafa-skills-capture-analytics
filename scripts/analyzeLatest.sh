#!/usr/bin/env bash
# analyzeLatest.sh - Build a single AI-ready text bundle from latest artifacts

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./analyzeLatest.sh [options]

Options:
  -d, --dir <path>      Target directory (default: current project root)
  -o, --out <path>      Output file path (default: captures/latest.ai.bundle.txt)
      --stdout          Print bundle to stdout after writing
  -h, --help            Show help

Examples:
  ./analyzeLatest.sh
  ./analyzeLatest.sh --stdout
  ./analyzeLatest.sh --dir /path/to/project
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_BASE_DIR="$(pwd)"
if command -v git >/dev/null 2>&1; then
    GIT_TOPLEVEL="$(git -C "$DEFAULT_BASE_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$GIT_TOPLEVEL" ]]; then
        DEFAULT_BASE_DIR="$GIT_TOPLEVEL"
    fi
fi

# Shared utilities (err, require_value_arg, etc.)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

TARGET_DIR="$DEFAULT_BASE_DIR"
OUT_FILE=""
PRINT_STDOUT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            require_value_arg "$1" "${2:-}"
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        -o|--out)
            require_value_arg "$1" "${2:-}"
            OUT_FILE="${2:-}"
            shift 2
            ;;
        --stdout)
            PRINT_STDOUT=true
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

CAPTURES_DIR="$TARGET_DIR/captures"
AI_MD_FILE="$CAPTURES_DIR/latest.ai.md"
AI_JSON_FILE="$CAPTURES_DIR/latest.ai.json"
SUMMARY_FILE="$CAPTURES_DIR/latest.summary.md"
MANIFEST_FILE="$CAPTURES_DIR/latest.manifest.json"

if [[ -z "$OUT_FILE" ]]; then
    OUT_FILE="$CAPTURES_DIR/latest.ai.bundle.txt"
fi

if [[ ! -f "$AI_MD_FILE" ]]; then
    err "Missing file: $AI_MD_FILE"
    err "Run start/stop capture first to generate AI artifacts."
    exit 1
fi

if [[ ! -f "$AI_JSON_FILE" ]]; then
    err "Missing file: $AI_JSON_FILE"
    err "Run start/stop capture first to generate AI artifacts."
    exit 1
fi

mkdir -p "$(dirname "$OUT_FILE")"
TMP_FILE="${OUT_FILE}.tmp.$$"

(umask 077; {
    echo "# AI Analysis Bundle"
    echo
    echo "GeneratedAt: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "TargetDir: $TARGET_DIR"
    echo "CapturesDir: $CAPTURES_DIR"
    echo "Manifest: $MANIFEST_FILE"
    echo "Summary: $SUMMARY_FILE"
    echo "AiMd: $AI_MD_FILE"
    echo "AiJson: $AI_JSON_FILE"
    echo
    echo "## Suggested Use"
    echo
    echo "1) Paste this entire file to your AI assistant"
    echo "2) Ask for: root cause hypotheses, endpoint error table, latency bottlenecks, next verification steps"
    echo
    echo "## AI_MD"
    echo
    cat "$AI_MD_FILE"
    echo
    echo "## AI_JSON"
    echo
    if command -v jq >/dev/null 2>&1; then
        jq . "$AI_JSON_FILE"
    else
        cat "$AI_JSON_FILE"
    fi
    echo
    if [[ -f "$SUMMARY_FILE" ]]; then
        echo "## SUMMARY_MD"
        echo
        cat "$SUMMARY_FILE"
        echo
    fi
} >"$TMP_FILE")

mv "$TMP_FILE" "$OUT_FILE"
chmod 600 "$OUT_FILE" 2>/dev/null || true

echo "AI bundle ready: $OUT_FILE"

if [[ "$PRINT_STDOUT" == "true" ]]; then
    echo ""
    cat "$OUT_FILE"
fi

