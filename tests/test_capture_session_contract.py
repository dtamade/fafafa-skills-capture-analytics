#!/usr/bin/env python3
"""Contract tests for capture-session.sh option wiring."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parent.parent


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_capture_session_force_recover_contract() -> None:
    script = _read("scripts/capture-session.sh")

    assert "--force-recover" in script, "capture-session.sh missing --force-recover option"
    assert re.search(r"--force-recover\)\n\s*FORCE_RECOVER=\"true\"", script), (
        "capture-session.sh missing --force-recover parser branch"
    )
    assert "START_CMD+=(--force-recover)" in script, (
        "capture-session.sh start command does not forward --force-recover"
    )


def test_capture_session_allow_hosts_forwarding_contract() -> None:
    script = _read("scripts/capture-session.sh")

    assert "--allow-hosts)" in script, (
        "capture-session.sh missing --allow-hosts parser branch"
    )
    assert 'ALLOW_HOSTS="${2:-}"' in script, (
        "capture-session.sh missing --allow-hosts assignment"
    )
    assert 'START_CMD+=(--allow-hosts "$ALLOW_HOSTS")' in script, (
        "capture-session.sh start command does not forward --allow-hosts"
    )


def test_capture_session_deny_hosts_forwarding_contract() -> None:
    script = _read("scripts/capture-session.sh")

    assert "--deny-hosts)" in script, (
        "capture-session.sh missing --deny-hosts parser branch"
    )
    assert 'DENY_HOSTS="${2:-}"' in script, (
        "capture-session.sh missing --deny-hosts assignment"
    )
    assert 'START_CMD+=(--deny-hosts "$DENY_HOSTS")' in script, (
        "capture-session.sh start command does not forward --deny-hosts"
    )


def test_capture_session_policy_forwarding_contract() -> None:
    script = _read("scripts/capture-session.sh")

    assert "--policy)" in script, (
        "capture-session.sh missing --policy parser branch"
    )
    assert 'POLICY_FILE="${2:-}"' in script, (
        "capture-session.sh missing --policy assignment"
    )
    assert 'START_CMD+=(--policy "$POLICY_FILE")' in script, (
        "capture-session.sh start command does not forward --policy"
    )
    assert 'DOCTOR_CMD+=(--policy "$POLICY_FILE")' in script, (
        "capture-session.sh doctor command does not forward --policy"
    )


def test_capture_session_cleanup_flags_forwarding_contract() -> None:
    script = _read("scripts/capture-session.sh")

    assert "--keep-days)" in script, (
        "capture-session.sh missing --keep-days parser branch"
    )
    assert "--keep-size)" in script, (
        "capture-session.sh missing --keep-size parser branch"
    )
    assert "--secure)" in script, "capture-session.sh missing --secure parser branch"
    assert "--dry-run)" in script, "capture-session.sh missing --dry-run parser branch"

    assert 'CLEANUP_CMD+=(--keep-days "$KEEP_DAYS")' in script, (
        "capture-session.sh cleanup command does not forward --keep-days"
    )
    assert 'CLEANUP_CMD+=(--keep-size "$KEEP_SIZE")' in script, (
        "capture-session.sh cleanup command does not forward --keep-size"
    )
    assert "CLEANUP_CMD+=(--secure)" in script, (
        "capture-session.sh cleanup command does not forward --secure"
    )
    assert "CLEANUP_CMD+=(--dry-run)" in script, (
        "capture-session.sh cleanup command does not forward --dry-run"
    )



def test_capture_session_default_work_dir_is_project_root() -> None:
    script = _read("scripts/capture-session.sh")

    assert 'DEFAULT_BASE_DIR="$(pwd)"' in script, (
        "capture-session.sh missing caller directory default"
    )
    assert 'git -C "$DEFAULT_BASE_DIR" rev-parse --show-toplevel' in script, (
        "capture-session.sh should resolve current git project root"
    )
    assert 'WORK_DIR="$DEFAULT_BASE_DIR"' in script, (
        "capture-session.sh should default WORK_DIR to current project root"
    )


def test_start_captures_default_target_dir_is_project_root() -> None:
    script = _read("scripts/startCaptures.sh")

    assert 'DEFAULT_BASE_DIR="$(pwd)"' in script, (
        "startCaptures.sh missing caller directory default"
    )
    assert 'git -C "$DEFAULT_BASE_DIR" rev-parse --show-toplevel' in script, (
        "startCaptures.sh should resolve current git project root"
    )
    assert 'TARGET_DIR="$DEFAULT_BASE_DIR"' in script, (
        "startCaptures.sh should default TARGET_DIR to current project root"
    )


def test_stop_captures_default_target_dir_is_project_root() -> None:
    script = _read("scripts/stopCaptures.sh")

    assert 'DEFAULT_BASE_DIR="$(pwd)"' in script, (
        "stopCaptures.sh missing caller directory default"
    )
    assert 'git -C "$DEFAULT_BASE_DIR" rev-parse --show-toplevel' in script, (
        "stopCaptures.sh should resolve current git project root"
    )
    assert 'TARGET_DIR="$DEFAULT_BASE_DIR"' in script, (
        "stopCaptures.sh should default TARGET_DIR to current project root"
    )


def test_analyze_latest_default_target_dir_is_project_root() -> None:
    script = _read("scripts/analyzeLatest.sh")

    assert 'DEFAULT_BASE_DIR="$(pwd)"' in script, (
        "analyzeLatest.sh missing caller directory default"
    )
    assert 'git -C "$DEFAULT_BASE_DIR" rev-parse --show-toplevel' in script, (
        "analyzeLatest.sh should resolve current git project root"
    )
    assert 'TARGET_DIR="$DEFAULT_BASE_DIR"' in script, (
        "analyzeLatest.sh should default TARGET_DIR to current project root"
    )


def test_capture_scripts_include_no_flow_diagnostics_contract() -> None:
    capture_script = _read("scripts/capture-session.sh")
    stop_script = _read("scripts/stopCaptures.sh")

    assert "Smoke test (must produce traffic through proxy)" in capture_script, (
        "capture-session.sh should print proxy smoke-test guidance after start"
    )
    assert "curl -x http://127.0.0.1:$PROXY_PORT http://example.com/" in capture_script, (
        "capture-session.sh should show explicit proxy traffic example"
    )
    assert "No traffic captured (flow file is empty)." in stop_script, (
        "stopCaptures.sh should explain empty flow condition"
    )
    assert "Traffic must pass through proxy" in stop_script, (
        "stopCaptures.sh should include proxy-routing hint when no flow"
    )


def test_install_script_copy_mode_and_doctor_contract() -> None:
    script = _read("install.sh")

    assert 'SKILL_TARGET_DIR="${HOME}/.claude/skills/capture-analytics"' in script, (
        "install.sh should default to Claude skill directory target"
    )
    assert "INSTALL_SKILL=true" in script, (
        "install.sh should enable skill installation by default"
    )
    assert "LINK_MODE=false" in script, (
        "install.sh should default to copy install mode"
    )
    assert "--install-to" in script and "--symlink" in script, (
        "install.sh should expose install target and symlink options"
    )
    assert "--doctor" in script, (
        "install.sh should expose dependency diagnostics option"
    )
    assert "describe_skill_install_state" in script, (
        "install.sh should diagnose skill installation state"
    )
    assert "copy_skill_tree" in script, (
        "install.sh should include copy-based skill installation path"
    )


def test_doctor_script_playwright_detection_contract() -> None:
    script = _read("scripts/doctor.sh")

    assert "playwright skill + plugin detected" in script, (
        "doctor.sh should report strong Playwright detection when both skill and plugin exist"
    )
    assert "Not detected" in script and "playwright-mcp" in script, (
        "doctor.sh should fail clearly when Playwright MCP is missing"
    )
    assert "verify MCP tool permissions" in script, (
        "doctor.sh should include remediation hint for skipped browser actions"
    )


def test_install_script_replaces_symlink_with_copy_contract() -> None:
    script = _read("install.sh")

    assert 'if [[ -L "$dst" ]]; then' in script, (
        "install.sh should detect symlink target in copy mode"
    )
    assert 'replaced symlink' in script, (
        "install.sh should explicitly replace symlink with local copy"
    )


def test_doctor_script_headed_runtime_hint_contract() -> None:
    script = _read("scripts/doctor.sh")

    assert "headed-ui" in script, (
        "doctor.sh should include headed UI runtime diagnostics"
    )
    assert "Headed Playwright may fail. Use headless or install xvfb-run" in script, (
        "doctor.sh should explain headed Playwright fallback"
    )


def test_run_with_proxy_env_helper_contract() -> None:
    script = _read("scripts/runWithProxyEnv.sh")

    assert "HTTP_PROXY" in script and "HTTPS_PROXY" in script, (
        "runWithProxyEnv.sh should set proxy env variables"
    )
    assert "ALL_PROXY" in script, (
        "runWithProxyEnv.sh should support ALL_PROXY"
    )
    assert "--no-proxy" in script and "--print-env" in script, (
        "runWithProxyEnv.sh should expose operational diagnostics flags"
    )


def test_drive_browser_traffic_helper_contract() -> None:
    script = _read("scripts/driveBrowserTraffic.sh")

    assert "--url <url>" in script, (
        "driveBrowserTraffic.sh should require target URL"
    )
    assert "--mode <mode>" in script, (
        "driveBrowserTraffic.sh should expose mode selection"
    )
    assert "--no-fallback-headless" in script, (
        "driveBrowserTraffic.sh should allow disabling headless fallback"
    )
    assert "mode_order" in script and "likely_headed_runtime_error" in script, (
        "driveBrowserTraffic.sh should implement headed/headless fallback logic"
    )


def test_capture_session_help_mentions_browser_fallback_helper() -> None:
    script = _read("scripts/capture-session.sh")

    assert "driveBrowserTraffic.sh --url https://example.com -P 18080" in script, (
        "capture-session.sh help should mention browser fallback helper"
    )
