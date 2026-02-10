#!/usr/bin/env python3
"""Regression checks to keep docs aligned with current CLI and test layout."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_capture_session_commands_match_readme_docs() -> None:
    capture_help = _read("scripts/capture-session.sh")
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    expected_commands = [
        "capture-session.sh start <url>",
        "capture-session.sh stop",
        "capture-session.sh status",
        "capture-session.sh progress",
        "capture-session.sh analyze",
        "capture-session.sh doctor",
        "capture-session.sh cleanup",
        "capture-session.sh diff <a> <b>",
    ]

    for command in expected_commands:
        assert command in readme_en, f"README.md missing command: {command}"
        assert command in readme_cn, f"README_CN.md missing command: {command}"

    assert "capture-session.sh validate" not in capture_help
    assert "capture-session.sh validate" not in readme_en
    assert "capture-session.sh validate" not in readme_cn


def test_contributing_examples_reference_existing_tests_and_modules() -> None:
    contributing_en = _read("CONTRIBUTING.md")
    contributing_cn = _read("CONTRIBUTING_CN.md")

    # Current test files that should be referenced by docs
    assert "tests/test_rules.py" in contributing_en
    assert "tests/test_rules.py" in contributing_cn

    # Old files/modules removed from project should not reappear in docs
    stale_tokens = [
        "tests/test_sanitize.py",
        "tests/test_flow_report.py",
        "tests/test_capture.sh",
        "scripts.sanitize",
        "capture-session.sh validate",
    ]

    for token in stale_tokens:
        assert token not in contributing_en, f"CONTRIBUTING.md contains stale token: {token}"
        assert token not in contributing_cn, f"CONTRIBUTING_CN.md contains stale token: {token}"


def test_changelog_does_not_reference_removed_validate_command() -> None:
    changelog = _read("CHANGELOG.md")

    assert "capture-session.sh validate" not in changelog
    assert "capture-session.sh progress" in changelog


def test_release_checklist_uses_release_check_script() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "./scripts/release-check.sh" in checklist
    assert "./scripts/release-check.sh --dry-run" in checklist
    assert "for test in tests/*.sh; do bash \"$test\"; done" not in checklist
    assert "pytest -q" not in checklist
