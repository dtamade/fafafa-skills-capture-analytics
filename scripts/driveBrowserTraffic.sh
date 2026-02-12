#!/usr/bin/env bash
# driveBrowserTraffic.sh - Generate browser traffic through mitmproxy with headed/headless fallback

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  driveBrowserTraffic.sh --url <url> [options]

Options:
  --url <url>              Target URL to open (required)
  -H, --host <host>        Proxy host (default: 127.0.0.1)
  -P, --port <port>        Proxy port (default: 18080)
  --mode <mode>            auto|headed|headless (default: auto)
  --no-fallback-headless   Disable fallback to headless when headed fails
  --timeout-ms <ms>        Navigation timeout in ms (default: 30000)
  --wait-ms <ms>           Wait after actions in ms (default: 2500)
  --input-text <text>      Optional text to input after page load
  --input-selector <css>   CSS selector for input target
  --press-key <key>        Key to press after fill (default: Enter when input-text is set)
  --screenshot <path>      Optional screenshot output path
  --json                   Output final result in JSON
  -h, --help               Show this help

Examples:
  ./driveBrowserTraffic.sh --url https://example.com -P 18080
  ./driveBrowserTraffic.sh --url https://cn.bing.com/translator -P 18080 \
      --mode auto --input-text "hello" --press-key Enter
  ./driveBrowserTraffic.sh --url https://example.com --mode headed --no-fallback-headless
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

URL=""
HOST="127.0.0.1"
PORT="18080"
MODE="auto"
FALLBACK_HEADLESS=true
TIMEOUT_MS="30000"
WAIT_MS="2500"
INPUT_TEXT=""
INPUT_SELECTOR=""
PRESS_KEY=""
SCREENSHOT_PATH=""
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --url)
            require_value_arg "$1" "${2:-}"
            URL="${2:-}"
            shift 2
            ;;
        --url=*)
            URL="${1#*=}"
            [[ -z "$URL" ]] && { echo "[ERROR] --url requires a value" >&2; exit 1; }
            shift
            ;;
        -H|--host)
            require_value_arg "$1" "${2:-}"
            HOST="${2:-}"
            shift 2
            ;;
        -P|--port)
            require_value_arg "$1" "${2:-}"
            PORT="${2:-}"
            shift 2
            ;;
        --mode)
            require_value_arg "$1" "${2:-}"
            MODE="${2:-}"
            shift 2
            ;;
        --no-fallback-headless)
            FALLBACK_HEADLESS=false
            shift
            ;;
        --timeout-ms)
            require_value_arg "$1" "${2:-}"
            TIMEOUT_MS="${2:-}"
            shift 2
            ;;
        --wait-ms)
            require_value_arg "$1" "${2:-}"
            WAIT_MS="${2:-}"
            shift 2
            ;;
        --input-text)
            require_value_arg "$1" "${2:-}"
            INPUT_TEXT="${2:-}"
            shift 2
            ;;
        --input-selector)
            require_value_arg "$1" "${2:-}"
            INPUT_SELECTOR="${2:-}"
            shift 2
            ;;
        --press-key)
            require_value_arg "$1" "${2:-}"
            PRESS_KEY="${2:-}"
            shift 2
            ;;
        --screenshot)
            require_value_arg "$1" "${2:-}"
            SCREENSHOT_PATH="${2:-}"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
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

if [[ -z "$URL" ]]; then
    echo "[ERROR] --url is required" >&2
    usage
    exit 1
fi

if [[ "$MODE" != "auto" && "$MODE" != "headed" && "$MODE" != "headless" ]]; then
    echo "[ERROR] Invalid --mode: $MODE (expected auto|headed|headless)" >&2
    exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
    echo "[ERROR] Invalid port: $PORT" >&2
    exit 1
fi

if ! [[ "$TIMEOUT_MS" =~ ^[0-9]+$ ]] || ! [[ "$WAIT_MS" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] timeout/wait must be positive integers" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] python3 not found" >&2
    exit 1
fi

if ! python3 -c "import playwright" 2>/dev/null; then
    echo "[ERROR] Python Playwright package not found." >&2
    echo "        Install with: pip install playwright && playwright install chromium" >&2
    exit 1
fi

PROXY_URL="http://${HOST}:${PORT}"

python3 - "$URL" "$PROXY_URL" "$MODE" "$FALLBACK_HEADLESS" "$TIMEOUT_MS" "$WAIT_MS" "$INPUT_TEXT" "$INPUT_SELECTOR" "$PRESS_KEY" "$SCREENSHOT_PATH" "$JSON_OUTPUT" <<'PY'
import json
import os
import sys
from typing import Dict, List

from playwright.sync_api import sync_playwright


def likely_headed_runtime_error(message: str) -> bool:
    msg = (message or "").lower()
    tokens = [
        "without having a xserver running",
        "target page, context or browser has been closed",
        "failed to launch the browser process",
        "cannot open display",
        "wayland",
        "x11",
        "headless",
    ]
    return any(token in msg for token in tokens)


def mode_order(requested_mode: str, fallback_headless: bool) -> List[str]:
    has_gui = bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))

    if requested_mode == "auto":
        return ["headed", "headless"] if has_gui else ["headless", "headed"]
    if requested_mode == "headed":
        if fallback_headless:
            return ["headed", "headless"]
        return ["headed"]
    return ["headless"]


def run_once(mode: str, *, url: str, proxy_url: str, timeout_ms: int, wait_ms: int,
             input_text: str, input_selector: str, press_key: str, screenshot_path: str) -> Dict:
    result: Dict = {"mode": mode, "ok": False}
    headless = mode == "headless"

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=headless,
            proxy={"server": proxy_url},
            args=["--disable-dev-shm-usage"],
        )
        context = browser.new_context(ignore_https_errors=True)
        page = context.new_page()

        page.goto(url, wait_until="domcontentloaded", timeout=timeout_ms)
        page.wait_for_timeout(wait_ms)

        if input_text:
            selector = input_selector or "textarea, input[type='text'], input:not([type])"
            locator = page.locator(selector).first
            locator.wait_for(timeout=min(timeout_ms, 10000))
            locator.click()
            locator.fill(input_text)
            if press_key:
                locator.press(press_key)
            elif not input_selector:
                locator.press("Enter")
            page.wait_for_timeout(wait_ms)

        if screenshot_path:
            page.screenshot(path=screenshot_path, full_page=True)

        result.update({
            "ok": True,
            "title": page.title(),
            "finalUrl": page.url,
        })

        context.close()
        browser.close()

    return result


def main() -> int:
    url = sys.argv[1]
    proxy_url = sys.argv[2]
    requested_mode = sys.argv[3]
    fallback_headless = sys.argv[4].lower() == "true"
    timeout_ms = int(sys.argv[5])
    wait_ms = int(sys.argv[6])
    input_text = sys.argv[7]
    input_selector = sys.argv[8]
    press_key = sys.argv[9]
    screenshot_path = sys.argv[10]
    json_output = sys.argv[11].lower() == "true"

    attempts = []

    for mode in mode_order(requested_mode, fallback_headless):
        try:
            out = run_once(
                mode,
                url=url,
                proxy_url=proxy_url,
                timeout_ms=timeout_ms,
                wait_ms=wait_ms,
                input_text=input_text,
                input_selector=input_selector,
                press_key=press_key,
                screenshot_path=screenshot_path,
            )
            attempts.append({"mode": mode, "ok": True})
            payload = {
                "ok": True,
                "selectedMode": mode,
                "proxy": proxy_url,
                "url": url,
                "title": out.get("title", ""),
                "finalUrl": out.get("finalUrl", ""),
                "attempts": attempts,
            }
            if json_output:
                print(json.dumps(payload, ensure_ascii=False))
            else:
                print("[OK] Browser traffic generated")
                print(f"     Mode:   {mode}")
                print(f"     URL:    {payload['finalUrl']}")
                print(f"     Title:  {payload['title']}")
                print(f"     Proxy:  {proxy_url}")
            return 0
        except Exception as exc:
            err = str(exc)
            attempts.append({"mode": mode, "ok": False, "error": err})

            # If mode is headed and this is likely a runtime GUI issue, try next mode.
            if mode == "headed" and likely_headed_runtime_error(err):
                continue

            # For other errors, stop early to avoid masking real failures.
            break

    payload = {
        "ok": False,
        "proxy": proxy_url,
        "url": url,
        "attempts": attempts,
    }
    if json_output:
        print(json.dumps(payload, ensure_ascii=False))
    else:
        print("[ERROR] Failed to generate browser traffic", file=sys.stderr)
        for item in attempts:
            if item.get("ok"):
                print(f"  - {item['mode']}: ok", file=sys.stderr)
            else:
                print(f"  - {item['mode']}: {item.get('error', 'unknown error')}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
PY
