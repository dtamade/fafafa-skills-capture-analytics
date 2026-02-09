#!/usr/bin/env bash
# proxy_utils.sh - Cross-platform system proxy management
# Shared by startCaptures.sh and stopCaptures.sh
#
# Supported platforms:
#   - Linux (GNOME): gsettings
#   - macOS: networksetup
#   - Program mode: no system proxy changes (Playwright uses --proxy-server)

# Detect platform and available proxy tool
detect_proxy_backend() {
    if [[ "$(uname -s)" == "Darwin" ]] && command -v networksetup >/dev/null 2>&1; then
        echo "macos"
    elif command -v gsettings >/dev/null 2>&1; then
        echo "gnome"
    else
        echo "none"
    fi
}

# ── GNOME (gsettings) ────────────────────────────────────────────────

proxy_get_gnome() {
    local schema="$1"
    local key="$2"
    local value

    value="$(gsettings get "$schema" "$key" 2>/dev/null || true)"
    value="${value#\'}"
    value="${value%\'}"
    printf '%s' "$value"
}

save_gnome_proxy_state() {
    # Output: PREV_PROXY_MODE, PREV_PROXY_HTTP_HOST, etc. as key=value pairs
    echo "PREV_PROXY_MODE=$(proxy_get_gnome org.gnome.system.proxy mode)"
    echo "PREV_PROXY_HTTP_HOST=$(proxy_get_gnome org.gnome.system.proxy.http host)"
    echo "PREV_PROXY_HTTP_PORT=$(proxy_get_gnome org.gnome.system.proxy.http port)"
    echo "PREV_PROXY_HTTPS_HOST=$(proxy_get_gnome org.gnome.system.proxy.https host)"
    echo "PREV_PROXY_HTTPS_PORT=$(proxy_get_gnome org.gnome.system.proxy.https port)"
}

set_gnome_proxy_manual() {
    local host="$1"
    local port="$2"

    gsettings set org.gnome.system.proxy mode 'manual' >/dev/null 2>&1 || return 1
    gsettings set org.gnome.system.proxy.http host "$host" >/dev/null 2>&1 || return 1
    gsettings set org.gnome.system.proxy.http port "$port" >/dev/null 2>&1 || return 1
    gsettings set org.gnome.system.proxy.https host "$host" >/dev/null 2>&1 || return 1
    gsettings set org.gnome.system.proxy.https port "$port" >/dev/null 2>&1 || return 1
}

restore_gnome_proxy() {
    local mode="$1"
    local http_host="$2"
    local http_port="$3"
    local https_host="$4"
    local https_port="$5"

    if ! command -v gsettings >/dev/null 2>&1; then
        return 1
    fi

    local effective_mode="$mode"
    if [[ -z "$effective_mode" ]]; then
        effective_mode="none"
    fi

    gsettings set org.gnome.system.proxy mode "$effective_mode" >/dev/null 2>&1 || return 1

    if [[ "$effective_mode" == "manual" ]]; then
        [[ -n "$http_host" ]] && gsettings set org.gnome.system.proxy.http host "$http_host" >/dev/null 2>&1 || true
        [[ "$http_port" =~ ^[0-9]+$ ]] && gsettings set org.gnome.system.proxy.http port "$http_port" >/dev/null 2>&1 || true
        [[ -n "$https_host" ]] && gsettings set org.gnome.system.proxy.https host "$https_host" >/dev/null 2>&1 || true
        [[ "$https_port" =~ ^[0-9]+$ ]] && gsettings set org.gnome.system.proxy.https port "$https_port" >/dev/null 2>&1 || true
    fi

    return 0
}

# ── macOS (networksetup) ─────────────────────────────────────────────

# Find the primary active network service (e.g. "Wi-Fi", "Ethernet")
macos_active_service() {
    local route_output iface service_name
    route_output="$(route -n get default 2>/dev/null || true)"
    iface="$(echo "$route_output" | awk '/interface:/ { print $2 }')"

    if [[ -z "$iface" ]]; then
        # Fallback: try common service names
        for name in "Wi-Fi" "Ethernet" "USB 10/100/1000 LAN"; do
            if networksetup -getinfo "$name" 2>/dev/null | grep -q "IP address"; then
                echo "$name"
                return 0
            fi
        done
        echo "Wi-Fi"
        return 0
    fi

    # Map interface to service name
    while IFS= read -r line; do
        # Lines look like: "(1) Wi-Fi (en0)"
        if echo "$line" | grep -q "$iface"; then
            service_name="$(echo "$line" | sed 's/^([0-9]*) //;s/ (.*$//')"
            echo "$service_name"
            return 0
        fi
    done < <(networksetup -listallhardwareports 2>/dev/null | grep -A1 'Hardware Port:' | paste - - | \
        awk -F'[:\t]' '{gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$4); printf "(%s) %s (%s)\n", NR, $2, $4}')

    echo "Wi-Fi"
}

save_macos_proxy_state() {
    local service
    service="$(macos_active_service)"

    # Parse current HTTP proxy
    local http_info https_info
    http_info="$(networksetup -getwebproxy "$service" 2>/dev/null || true)"
    https_info="$(networksetup -getsecurewebproxy "$service" 2>/dev/null || true)"

    local http_enabled http_host http_port
    http_enabled="$(echo "$http_info" | awk -F': ' '/^Enabled/ { print $2 }')"
    http_host="$(echo "$http_info" | awk -F': ' '/^Server/ { print $2 }')"
    http_port="$(echo "$http_info" | awk -F': ' '/^Port/ { print $2 }')"

    local https_enabled https_host https_port
    https_enabled="$(echo "$https_info" | awk -F': ' '/^Enabled/ { print $2 }')"
    https_host="$(echo "$https_info" | awk -F': ' '/^Server/ { print $2 }')"
    https_port="$(echo "$https_info" | awk -F': ' '/^Port/ { print $2 }')"

    echo "PREV_PROXY_SERVICE=$service"
    echo "PREV_PROXY_HTTP_ENABLED=$http_enabled"
    echo "PREV_PROXY_HTTP_HOST=$http_host"
    echo "PREV_PROXY_HTTP_PORT=$http_port"
    echo "PREV_PROXY_HTTPS_ENABLED=$https_enabled"
    echo "PREV_PROXY_HTTPS_HOST=$https_host"
    echo "PREV_PROXY_HTTPS_PORT=$https_port"
}

set_macos_proxy_manual() {
    local host="$1"
    local port="$2"

    local service
    service="$(macos_active_service)"

    networksetup -setwebproxy "$service" "$host" "$port" >/dev/null 2>&1 || return 1
    networksetup -setsecurewebproxy "$service" "$host" "$port" >/dev/null 2>&1 || return 1
    networksetup -setwebproxystate "$service" on >/dev/null 2>&1 || return 1
    networksetup -setsecurewebproxystate "$service" on >/dev/null 2>&1 || return 1
}

restore_macos_proxy() {
    local service="${1:-}"
    local http_enabled="${2:-No}"
    local http_host="${3:-}"
    local http_port="${4:-}"
    local https_enabled="${5:-No}"
    local https_host="${6:-}"
    local https_port="${7:-}"

    if [[ -z "$service" ]]; then
        service="$(macos_active_service)"
    fi

    if ! command -v networksetup >/dev/null 2>&1; then
        return 1
    fi

    if [[ "$http_enabled" == "Yes" && -n "$http_host" && -n "$http_port" ]]; then
        networksetup -setwebproxy "$service" "$http_host" "$http_port" >/dev/null 2>&1 || true
        networksetup -setwebproxystate "$service" on >/dev/null 2>&1 || true
    else
        networksetup -setwebproxystate "$service" off >/dev/null 2>&1 || true
    fi

    if [[ "$https_enabled" == "Yes" && -n "$https_host" && -n "$https_port" ]]; then
        networksetup -setsecurewebproxy "$service" "$https_host" "$https_port" >/dev/null 2>&1 || true
        networksetup -setsecurewebproxystate "$service" on >/dev/null 2>&1 || true
    else
        networksetup -setsecurewebproxystate "$service" off >/dev/null 2>&1 || true
    fi

    return 0
}

# ── Unified interface ────────────────────────────────────────────────

# Save current proxy state to stdout (key=value lines)
# Caller should capture and write to proxy_info.env
save_proxy_state() {
    local backend
    backend="$(detect_proxy_backend)"
    echo "PROXY_BACKEND=$backend"

    case "$backend" in
        gnome)   save_gnome_proxy_state ;;
        macos)   save_macos_proxy_state ;;
        none)    echo "PREV_PROXY_MODE=none" ;;
    esac
}

# Set system proxy to manual (host:port)
set_system_proxy() {
    local host="$1"
    local port="$2"

    local backend
    backend="$(detect_proxy_backend)"

    case "$backend" in
        gnome)   set_gnome_proxy_manual "$host" "$port" ;;
        macos)   set_macos_proxy_manual "$host" "$port" ;;
        none)    return 1 ;;
    esac
}

# Restore system proxy from saved state
# Takes env file path, reads PROXY_BACKEND and PREV_* keys
restore_system_proxy_from_env() {
    local env_file="$1"

    if [[ ! -f "$env_file" ]]; then
        return 1
    fi

    local backend
    backend="$(read_kv "PROXY_BACKEND" "$env_file")"

    case "$backend" in
        gnome)
            local mode http_host http_port https_host https_port
            mode="$(read_kv "PREV_PROXY_MODE" "$env_file")"
            http_host="$(read_kv "PREV_PROXY_HTTP_HOST" "$env_file")"
            http_port="$(read_kv "PREV_PROXY_HTTP_PORT" "$env_file")"
            https_host="$(read_kv "PREV_PROXY_HTTPS_HOST" "$env_file")"
            https_port="$(read_kv "PREV_PROXY_HTTPS_PORT" "$env_file")"
            restore_gnome_proxy "$mode" "$http_host" "$http_port" "$https_host" "$https_port"
            ;;
        macos)
            local service http_enabled http_host http_port https_enabled https_host https_port
            service="$(read_kv "PREV_PROXY_SERVICE" "$env_file")"
            http_enabled="$(read_kv "PREV_PROXY_HTTP_ENABLED" "$env_file")"
            http_host="$(read_kv "PREV_PROXY_HTTP_HOST" "$env_file")"
            http_port="$(read_kv "PREV_PROXY_HTTP_PORT" "$env_file")"
            https_enabled="$(read_kv "PREV_PROXY_HTTPS_ENABLED" "$env_file")"
            https_host="$(read_kv "PREV_PROXY_HTTPS_HOST" "$env_file")"
            https_port="$(read_kv "PREV_PROXY_HTTPS_PORT" "$env_file")"
            restore_macos_proxy "$service" "$http_enabled" "$http_host" "$http_port" "$https_enabled" "$https_host" "$https_port"
            ;;
        none)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
