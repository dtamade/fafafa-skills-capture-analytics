#!/usr/bin/env bash
# common.sh - Shared utility functions for capture-analytics scripts
# Source this file: source "$SCRIPT_DIR/common.sh"

# ── Logging helpers ──────────────────────────────────────────
# err "message"   - Print error to stderr
# warn "message"  - Print warning to stderr
err() {
    echo "[ERROR] $*" >&2
}

warn() {
    echo "[WARN] $*" >&2
}

# ── Argument validation ──────────────────────────────────────
# require_value_arg <option> <value>
#   Exit with error if value is empty or looks like another option
require_value_arg() {
    local opt="$1"
    local value="${2:-}"
    if [[ -z "$value" || "$value" == -* ]]; then
        err "Option $opt requires a value"
        exit 1
    fi
}

# require_cmd <command>
#   Exit with error if command is not in PATH
require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        err "Missing command: $1"
        exit 1
    fi
}

# ── Cross-platform file locking ──────────────────────────────
# acquire_lock <lock_path> [fd_number]
#   Acquires an exclusive non-blocking lock.
#   Uses flock if available (Linux), otherwise mkdir atomic fallback (macOS/POSIX).
#   fd_number defaults to 9 (matching existing usage).
#   Returns 0 on success, 1 if already locked.
#
# release_lock <lock_path> [fd_number]
#   Releases a previously acquired lock.
_COMMON_LOCK_BACKEND=""

_detect_lock_backend() {
    if [[ -n "$_COMMON_LOCK_BACKEND" ]]; then
        return
    fi
    if command -v flock >/dev/null 2>&1; then
        _COMMON_LOCK_BACKEND="flock"
    else
        _COMMON_LOCK_BACKEND="mkdir"
    fi
}

acquire_lock() {
    local lock_path="$1"
    local fd="${2:-9}"

    # Validate fd is a safe integer (prevent eval injection)
    if ! [[ "$fd" =~ ^[0-9]+$ ]] || (( fd < 3 || fd > 255 )); then
        echo "acquire_lock: invalid fd: $fd" >&2
        return 1
    fi

    # Validate lock_path: reject dangerous characters that could enable injection
    # Disallow: $, `, newline, carriage return, null byte patterns
    if [[ "$lock_path" =~ [\$\`\"\'\(\)\{\}\;\&\|\<\>] ]] || \
       [[ "$lock_path" == *$'\n'* ]] || \
       [[ "$lock_path" == *$'\r'* ]]; then
        echo "acquire_lock: unsafe characters in path: $lock_path" >&2
        return 1
    fi

    # Reject empty path
    if [[ -z "$lock_path" ]]; then
        echo "acquire_lock: empty lock path" >&2
        return 1
    fi

    _detect_lock_backend

    if [[ "$_COMMON_LOCK_BACKEND" == "flock" ]]; then
        eval "exec ${fd}>\"${lock_path}\""
        if ! flock -n "$fd"; then
            return 1
        fi
    else
        # mkdir is atomic on all POSIX systems
        local lock_dir="${lock_path}.d"
        if ! mkdir "$lock_dir" 2>/dev/null; then
            # Check for stale lock (PID file inside)
            local stale_pid=""
            if [[ -f "$lock_dir/pid" ]]; then
                stale_pid="$(cat "$lock_dir/pid" 2>/dev/null || true)"
            fi
            if [[ -n "$stale_pid" && "$stale_pid" =~ ^[0-9]+$ ]]; then
                if ! kill -0 "$stale_pid" 2>/dev/null; then
                    # Stale lock — remove and retry once
                    rm -rf "$lock_dir" 2>/dev/null || true
                    if ! mkdir "$lock_dir" 2>/dev/null; then
                        return 1
                    fi
                else
                    return 1
                fi
            else
                return 1
            fi
        fi
        echo "$$" > "$lock_dir/pid"
    fi
    return 0
}

release_lock() {
    local lock_path="$1"
    local fd="${2:-9}"

    if ! [[ "$fd" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    _detect_lock_backend

    if [[ "$_COMMON_LOCK_BACKEND" == "flock" ]]; then
        eval "exec ${fd}>&-" 2>/dev/null || true
    else
        local lock_dir="${lock_path}.d"
        rm -rf "$lock_dir" 2>/dev/null || true
    fi
}

# ── Cross-platform SHA-256 ───────────────────────────────────
# compute_sha256 <file>
#   Prints the SHA-256 hex digest of a file.
#   Uses sha256sum (Linux) or shasum -a 256 (macOS) or openssl.
#   Returns empty string and rc=1 if no tool is available.
compute_sha256() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" 2>/dev/null | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" 2>/dev/null | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" 2>/dev/null | awk '{print $NF}'
    else
        return 1
    fi
}

# ── Key-value reader ─────────────────────────────────────────
# Read a key=value pair from an env-style file.
# Escapes regex special characters in the key to prevent injection.
read_kv() {
    local key="$1"
    local file="$2"
    local line
    local escaped_key

    # Defensive: empty file path or missing file
    [[ -z "$file" || ! -f "$file" ]] && return 0

    escaped_key="$(printf '%s' "$key" | sed 's/[][\.*^$()+?{}|]/\\&/g')"
    line="$(grep -E "^${escaped_key}=" "$file" 2>/dev/null | tail -n 1 || true)"
    line="${line#*=}"
    line="${line%$'\r'}"
    # Only strip quotes if they appear symmetrically (both ends match)
    if [[ "${line:0:1}" == '"' && "${line: -1}" == '"' ]]; then
        line="${line:1:-1}"
    elif [[ "${line:0:1}" == "'" && "${line: -1}" == "'" ]]; then
        line="${line:1:-1}"
    fi
    printf '%s' "$line"
}

# ── Path boundary validation ─────────────────────────────────
# validate_path_within <path> <allowed_base>
#   Validates that <path> resolves to a location within <allowed_base>.
#   Rejects symlinks, path traversal, and paths outside boundary.
#   Returns 0 if valid, 1 if invalid.
validate_path_within() {
    local path="$1"
    local allowed_base="$2"

    # Empty path is invalid
    if [[ -z "$path" ]]; then
        echo "validate_path_within: empty path" >&2
        return 1
    fi

    # Empty base is invalid
    if [[ -z "$allowed_base" ]]; then
        echo "validate_path_within: empty allowed_base" >&2
        return 1
    fi

    # Get canonical base (must exist)
    local canonical_base
    canonical_base="$(cd "$allowed_base" 2>/dev/null && pwd -P)" || {
        echo "validate_path_within: allowed_base does not exist: $allowed_base" >&2
        return 1
    }

    # For existing paths, use realpath; for new paths, validate parent
    local canonical_path
    if [[ -e "$path" ]]; then
        # Reject symlinks pointing outside
        if [[ -L "$path" ]]; then
            local link_target
            link_target="$(readlink -f "$path" 2>/dev/null)" || {
                echo "validate_path_within: cannot resolve symlink: $path" >&2
                return 1
            }
            canonical_path="$link_target"
        else
            canonical_path="$(cd "$(dirname "$path")" 2>/dev/null && pwd -P)/$(basename "$path")" || {
                echo "validate_path_within: cannot resolve path: $path" >&2
                return 1
            }
        fi
    else
        # Path doesn't exist yet - validate parent directory
        local parent_dir
        parent_dir="$(dirname "$path")"
        if [[ ! -d "$parent_dir" ]]; then
            echo "validate_path_within: parent directory does not exist: $parent_dir" >&2
            return 1
        fi
        canonical_path="$(cd "$parent_dir" 2>/dev/null && pwd -P)/$(basename "$path")" || {
            echo "validate_path_within: cannot resolve parent: $parent_dir" >&2
            return 1
        }
    fi

    # Check if path starts with base (with trailing slash to prevent prefix attacks)
    if [[ "$canonical_path" != "$canonical_base"/* && "$canonical_path" != "$canonical_base" ]]; then
        echo "validate_path_within: path outside boundary: $path (resolved: $canonical_path, base: $canonical_base)" >&2
        return 1
    fi

    return 0
}
