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

    assert 'ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"' in script, (
        "capture-session.sh missing ROOT_DIR resolution"
    )
    assert 'WORK_DIR="$ROOT_DIR"' in script, (
        "capture-session.sh should default WORK_DIR to project root"
    )


def test_start_captures_default_target_dir_is_project_root() -> None:
    script = _read("scripts/startCaptures.sh")

    assert 'ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"' in script, (
        "startCaptures.sh missing ROOT_DIR resolution"
    )
    assert 'TARGET_DIR="$ROOT_DIR"' in script, (
        "startCaptures.sh should default TARGET_DIR to project root"
    )


def test_stop_captures_default_target_dir_is_project_root() -> None:
    script = _read("scripts/stopCaptures.sh")

    assert 'ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"' in script, (
        "stopCaptures.sh missing ROOT_DIR resolution"
    )
    assert 'TARGET_DIR="$ROOT_DIR"' in script, (
        "stopCaptures.sh should default TARGET_DIR to project root"
    )


def test_analyze_latest_default_target_dir_is_project_root() -> None:
    script = _read("scripts/analyzeLatest.sh")

    assert 'ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"' in script, (
        "analyzeLatest.sh missing ROOT_DIR resolution"
    )
    assert 'TARGET_DIR="$ROOT_DIR"' in script, (
        "analyzeLatest.sh should default TARGET_DIR to project root"
    )
