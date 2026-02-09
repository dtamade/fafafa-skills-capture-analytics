#!/usr/bin/env bash
# common.sh - Shared utility functions for capture-analytics scripts
# Source this file: source "$SCRIPT_DIR/common.sh"

# Read a key=value pair from an env-style file.
# Escapes regex special characters in the key to prevent injection.
read_kv() {
    local key="$1"
    local file="$2"
    local line
    local escaped_key

    escaped_key="$(printf '%s' "$key" | sed 's/[][\.*^$()+?{}|]/\\&/g')"
    line="$(grep -E "^${escaped_key}=" "$file" 2>/dev/null | tail -n 1 || true)"
    line="${line#*=}"
    line="${line%$'\r'}"
    line="${line#\"}"
    line="${line%\"}"
    line="${line#\'}"
    line="${line%\'}"
    printf '%s' "$line"
}
