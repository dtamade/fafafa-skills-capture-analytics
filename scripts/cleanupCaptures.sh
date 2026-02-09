#!/usr/bin/env bash
# cleanupCaptures.sh - Manage capture data lifecycle
# Thin Bash entry: argument parsing + human-friendly output.
# Core logic delegated to cleanup.py for cross-platform compatibility.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<'EOF'
Usage:
  cleanupCaptures.sh [options]

Options:
  -d, --dir <path>       Working directory (default: current dir)
  --keep-days <N>        Keep captures from the last N days (default: 7)
  --keep-size <SIZE>     Keep latest captures up to SIZE (e.g. 500M, 1G)
  --secure               Securely delete files (shred before rm)
  --dry-run              Preview what would be deleted without acting
  -h, --help             Show this help

Size suffixes: K (kilobytes), M (megabytes), G (gigabytes)
Without suffix, bytes are assumed.

Cleanup Logic:
  - Files are grouped by RUN_ID (capture session)
  - A session is expired when its timestamp is older than --keep-days
  - --keep-size removes oldest sessions first until total fits
  - When both --keep-days and --keep-size are used, a session is deleted
    if EITHER policy marks it for removal
  - --secure uses shred (3 passes) before unlinking
  - latest.* symlinks are updated after cleanup

Examples:
  cleanupCaptures.sh --keep-days 7
  cleanupCaptures.sh --keep-size 1G --dry-run
  cleanupCaptures.sh --secure --keep-days 3
  cleanupCaptures.sh -d /path/to/project --keep-days 0   # delete ALL
EOF
}

err() {
    echo "[ERROR] $*" >&2
}

info() {
    echo "[cleanup] $*"
}

# ── Parse arguments ──────────────────────────────────────────────────

WORK_DIR="$(pwd)"
KEEP_DAYS=""
KEEP_SIZE=""
SECURE_DELETE="false"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            WORK_DIR="${2:-}"
            [[ -z "$WORK_DIR" ]] && { err "--dir requires a path"; exit 1; }
            shift 2
            ;;
        --keep-days)
            KEEP_DAYS="${2:-}"
            [[ -z "$KEEP_DAYS" ]] && { err "--keep-days requires a number"; exit 1; }
            if ! [[ "$KEEP_DAYS" =~ ^[0-9]+$ ]]; then
                err "--keep-days must be a non-negative integer"
                exit 1
            fi
            shift 2
            ;;
        --keep-size)
            KEEP_SIZE="${2:-}"
            [[ -z "$KEEP_SIZE" ]] && { err "--keep-size requires a size value"; exit 1; }
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
        *)
            err "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# At least one retention policy required
if [[ -z "$KEEP_DAYS" && -z "$KEEP_SIZE" ]]; then
    err "At least one of --keep-days or --keep-size is required"
    usage
    exit 1
fi

CAPTURES_DIR="$WORK_DIR/captures"

if [[ ! -d "$CAPTURES_DIR" ]]; then
    info "No captures directory found at $CAPTURES_DIR"
    exit 0
fi

# ── Delegate to Python ───────────────────────────────────────────────

PY_CMD=(python3 "$SCRIPT_DIR/cleanup.py" "$CAPTURES_DIR")
[[ -n "$KEEP_DAYS" ]] && PY_CMD+=(--keep-days "$KEEP_DAYS")
[[ -n "$KEEP_SIZE" ]] && PY_CMD+=(--keep-size "$KEEP_SIZE")
[[ "$SECURE_DELETE" == "true" ]] && PY_CMD+=(--secure)
[[ "$DRY_RUN" == "true" ]] && PY_CMD+=(--dry-run)

RESULT="$("${PY_CMD[@]}" 2>&1)" || {
    err "cleanup.py failed: $RESULT"
    exit 1
}

# ── Parse JSON result and render human-friendly output ───────────────

STATUS="$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))")"

case "$STATUS" in
    no-dir|empty|nothing)
        MSG="$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))")"
        info "$MSG"
        exit 0
        ;;
esac

# Render details for each deleted session
DELETE_COUNT="$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['deleted'])")"
KEPT_COUNT="$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['kept'])")"
DELETE_FILES="$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['files_removed'])")"
FREED_HUMAN="$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['bytes_freed_human'])")"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "=== DRY RUN - No files will be deleted ==="
    echo ""
fi

# Print per-session details
python3 -c "
import sys, json
data = json.load(sys.stdin)
dry = data.get('dry_run', False)
for d in data.get('details', []):
    rid = d['run_id']
    ts = d['timestamp']
    sz = d['size_human']
    fc = d['files']
    if dry:
        print(f'  [DELETE] session={rid}  time={ts}  size={sz}  files={fc}')
    else:
        print(f'[cleanup] Deleted session={rid}  time={ts}  size={sz}  files={fc}')
" <<< "$RESULT"

# Symlinks update message
NEEDS_UPDATE="$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('needs_latest_update', False))")"
if [[ "$DRY_RUN" != "true" && "$NEEDS_UPDATE" == "True" ]]; then
    info "Updated latest.* symlinks"
fi

# Summary
echo ""
echo "=== Cleanup Summary ==="
if [[ "$DRY_RUN" == "true" ]]; then
    echo "  Mode:     DRY RUN (no files deleted)"
fi
if [[ "$SECURE_DELETE" == "true" ]]; then
    echo "  Method:   Secure delete (shred)"
fi
echo "  Sessions: ${DELETE_COUNT} deleted, ${KEPT_COUNT} kept"
echo "  Files:    ${DELETE_FILES} removed"
echo "  Freed:    ${FREED_HUMAN}"
if [[ -n "$KEEP_DAYS" ]]; then
    echo "  Policy:   keep-days=$KEEP_DAYS"
fi
if [[ -n "$KEEP_SIZE" ]]; then
    echo "  Policy:   keep-size=$KEEP_SIZE"
fi
echo "========================"
