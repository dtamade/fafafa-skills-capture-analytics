#!/usr/bin/env bash
# doctor.sh - Environment self-check for capture-analytics skill
# Usage: doctor.sh [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<'EOF'
Usage:
  doctor.sh [options]

Options:
  -P, --port <port>       Port to check availability (default: 18080)
      --policy <file>     Policy file to validate
      --json              Output in JSON format
      --strict            Treat warnings as failures
  -h, --help              Show this help

Checks:
  [FAIL] mitmdump        - Must be installed and version >= 10
  [FAIL] python3         - Must be installed
  [FAIL] mitmproxy-py    - Python mitmproxy module must be importable
  [FAIL] port            - Port must be available
  [FAIL] policy          - Policy file must be valid (if specified)
  [WARN] ca-cert         - CA certificate status
  [WARN] playwright-mcp  - Playwright MCP availability

Exit codes:
  0 - All checks passed (or only warnings without --strict)
  1 - One or more checks failed
EOF
}

# Colors (disabled if not TTY)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

CHECK_PORT="18080"
POLICY_FILE=""
JSON_OUTPUT=false
STRICT_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -P|--port)
            CHECK_PORT="${2:-18080}"
            shift 2
            ;;
        --policy)
            POLICY_FILE="${2:-}"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --strict)
            STRICT_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Results storage
declare -a RESULTS=()
FAIL_COUNT=0
WARN_COUNT=0

add_result() {
    local name="$1"
    local status="$2"  # pass, fail, warn
    local message="$3"
    local detail="${4:-}"

    RESULTS+=("$name|$status|$message|$detail")

    if [[ "$status" == "fail" ]]; then
        ((FAIL_COUNT++)) || true
    elif [[ "$status" == "warn" ]]; then
        ((WARN_COUNT++)) || true
    fi
}

# Check: mitmdump
check_mitmdump() {
    if ! command -v mitmdump >/dev/null 2>&1; then
        add_result "mitmdump" "fail" "Not installed" "Install with: pip install mitmproxy"
        return
    fi

    local version
    version="$(mitmdump --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "0.0")"
    local major="${version%%.*}"

    if [[ "$major" -ge 10 ]]; then
        add_result "mitmdump" "pass" "Installed" "Version: $version"
    else
        add_result "mitmdump" "fail" "Version too old" "Found $version, need >= 10.0"
    fi
}

# Check: python3
check_python() {
    if ! command -v python3 >/dev/null 2>&1; then
        add_result "python3" "fail" "Not installed" "Install Python 3.8+"
        return
    fi

    local version
    version="$(python3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "0.0")"
    add_result "python3" "pass" "Installed" "Version: $version"
}

# Check: mitmproxy Python module
check_mitmproxy_py() {
    if ! command -v python3 >/dev/null 2>&1; then
        add_result "mitmproxy-py" "fail" "Python3 not available" ""
        return
    fi

    if python3 -c "from mitmproxy.io import FlowReader" 2>/dev/null; then
        add_result "mitmproxy-py" "pass" "Module importable" ""
    else
        add_result "mitmproxy-py" "fail" "Module not found" "Install with: pip install mitmproxy"
    fi
}

# Check: port availability
check_port() {
    local port="$1"

    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        add_result "port-$port" "fail" "Invalid port number" ""
        return
    fi

    local in_use=false

    if command -v ss >/dev/null 2>&1; then
        if ss -H -ltn "sport = :$port" 2>/dev/null | grep -q .; then
            in_use=true
        fi
    elif command -v lsof >/dev/null 2>&1; then
        if lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
            in_use=true
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            in_use=true
        fi
    fi

    if [[ "$in_use" == "true" ]]; then
        add_result "port-$port" "fail" "Port in use" "Choose a different port with -P"
    else
        add_result "port-$port" "pass" "Port available" ""
    fi
}

# Check: CA certificate
check_ca_cert() {
    local ca_file="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"

    if [[ ! -f "$ca_file" ]]; then
        add_result "ca-cert" "warn" "Not generated" "Run mitmdump once to generate"
        return
    fi

    # Check if trusted (Linux)
    local trusted="unknown"
    if command -v trust >/dev/null 2>&1; then
        if trust list 2>/dev/null | grep -qi "mitmproxy"; then
            trusted="yes"
        else
            trusted="no"
        fi
    elif command -v security >/dev/null 2>&1; then
        # macOS
        if security find-certificate -c "mitmproxy" /Library/Keychains/System.keychain >/dev/null 2>&1; then
            trusted="yes"
        else
            trusted="no"
        fi
    fi

    if [[ "$trusted" == "yes" ]]; then
        add_result "ca-cert" "pass" "Generated and trusted" "$ca_file"
    elif [[ "$trusted" == "no" ]]; then
        add_result "ca-cert" "warn" "Generated but not trusted" "Import $ca_file to system trust store"
    else
        add_result "ca-cert" "warn" "Generated, trust status unknown" "$ca_file"
    fi
}

# Check: policy file
check_policy() {
    local policy="$1"

    if [[ ! -f "$policy" ]]; then
        add_result "policy" "fail" "File not found" "$policy"
        return
    fi

    if python3 "$SCRIPT_DIR/policy.py" compile "$policy" >/dev/null 2>&1; then
        add_result "policy" "pass" "Valid" "$policy"
    else
        add_result "policy" "fail" "Invalid or malformed" "Check JSON syntax and schema"
    fi
}

# Check: Playwright MCP
check_playwright_mcp() {
    # Try to detect Playwright MCP availability
    # This is best-effort since we can't easily probe MCP servers

    local status="unknown"
    local detail=""

    # Check if playwright is in PATH (npm global)
    if command -v playwright >/dev/null 2>&1; then
        status="likely-available"
        detail="Playwright CLI found"
    elif [[ -d "$HOME/.cache/ms-playwright" ]] || [[ -d "$HOME/Library/Caches/ms-playwright" ]]; then
        status="likely-available"
        detail="Playwright browsers found"
    else
        status="unknown"
        detail="Cannot detect Playwright MCP status"
    fi

    if [[ "$status" == "likely-available" ]]; then
        add_result "playwright-mcp" "pass" "Likely available" "$detail"
    else
        add_result "playwright-mcp" "warn" "Status unknown" "Ensure Playwright MCP server is configured"
    fi
}

# Run all checks
run_checks() {
    check_mitmdump
    check_python
    check_mitmproxy_py
    check_port "$CHECK_PORT"
    check_ca_cert
    check_playwright_mcp

    if [[ -n "$POLICY_FILE" ]]; then
        check_policy "$POLICY_FILE"
    fi
}

# Output: human-readable
output_human() {
    echo "========================================"
    echo " capture-analytics doctor"
    echo "========================================"
    echo ""

    for result in "${RESULTS[@]}"; do
        IFS='|' read -r name status message detail <<< "$result"

        local icon
        case "$status" in
            pass) icon="${GREEN}✓${NC}" ;;
            fail) icon="${RED}✗${NC}" ;;
            warn) icon="${YELLOW}!${NC}" ;;
        esac

        printf " [%b] %-15s %s\n" "$icon" "$name" "$message"
        if [[ -n "$detail" ]]; then
            printf "     └─ %s\n" "$detail"
        fi
    done

    echo ""
    echo "----------------------------------------"
    local total=${#RESULTS[@]}
    local pass=$((total - FAIL_COUNT - WARN_COUNT))
    printf " Total: %d | Pass: %d | Fail: %d | Warn: %d\n" "$total" "$pass" "$FAIL_COUNT" "$WARN_COUNT"
    echo "========================================"
}

# Output: JSON (uses python3 for safe escaping)
output_json() {
    local items=()
    for result in "${RESULTS[@]}"; do
        items+=("$result")
    done

    python3 -c "
import json, sys

items = sys.argv[1:-2]
fail_count = int(sys.argv[-2])
warn_count = int(sys.argv[-1])

checks = []
for item in items:
    parts = item.split('|', 3)
    name = parts[0] if len(parts) > 0 else ''
    status = parts[1] if len(parts) > 1 else ''
    message = parts[2] if len(parts) > 2 else ''
    detail = parts[3] if len(parts) > 3 else ''
    checks.append({'name': name, 'status': status, 'message': message, 'detail': detail})

data = {
    'checks': checks,
    'summary': {
        'total': len(checks),
        'fail': fail_count,
        'warn': warn_count
    }
}
json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
print()
" "${items[@]}" "$FAIL_COUNT" "$WARN_COUNT"
}

# Main
run_checks

if [[ "$JSON_OUTPUT" == "true" ]]; then
    output_json
else
    output_human
fi

# Exit code
if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi

if [[ "$STRICT_MODE" == "true" && $WARN_COUNT -gt 0 ]]; then
    exit 1
fi

exit 0
