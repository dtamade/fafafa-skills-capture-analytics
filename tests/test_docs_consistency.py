#!/usr/bin/env python3
"""Regression checks to keep docs aligned with current CLI and test layout."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def _project_structures() -> tuple[str, str]:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    structure_en = readme_en.split("## Project Structure", 1)[1].split("## Contributing", 1)[0]
    structure_cn = readme_cn.split("## 项目结构", 1)[1].split("## 贡献", 1)[0]
    return structure_en, structure_cn


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
        "capture-session.sh navlog <cmd>",
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


def test_release_checklist_includes_localhost_start_example() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "./scripts/capture-session.sh start http://localhost:3000" in checklist


def test_release_checklist_includes_allow_hosts_start_example() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "./scripts/capture-session.sh start https://example.com --allow-hosts 'api\\.example\\.com'" in checklist


def test_release_checklist_includes_cleanup_keep_days_example() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "./scripts/capture-session.sh cleanup --keep-days 7" in checklist


def test_release_checklist_includes_cleanup_keep_size_dry_run_example() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "./scripts/capture-session.sh cleanup --keep-size 1G --dry-run" in checklist


def test_release_checklist_includes_cleanup_secure_example() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "./scripts/capture-session.sh cleanup --secure --keep-days 3" in checklist


def test_release_checklist_includes_diff_example() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "./scripts/capture-session.sh diff captures/a.index.ndjson captures/b.index.ndjson" in checklist


def test_release_checklist_mentions_allow_hosts_option() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "Scope note: use `--allow-hosts` to capture only matching hosts." in checklist


def test_release_checklist_mentions_deny_hosts_option() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "Scope note: use `--deny-hosts` to exclude noisy or third-party hosts." in checklist


def test_release_checklist_mentions_policy_option() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "Scope note: use `--policy <file>` to load a JSON scope policy." in checklist



def test_release_checklist_mentions_keep_days_option() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "Cleanup note: use `--keep-days <N>` to retain recent captures." in checklist



def test_release_checklist_mentions_keep_size_option() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "Cleanup note: use `--keep-size <SIZE>` to cap retained data volume." in checklist



def test_release_checklist_mentions_secure_option() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "Cleanup note: use `--secure` to shred files during deletion." in checklist



def test_release_checklist_mentions_help_option() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "Help note: run `./scripts/capture-session.sh --help` for full CLI reference." in checklist



def test_release_checklist_mentions_dir_option() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "Path note: use `-d, --dir <path>` to select working directory." in checklist



def test_release_checklist_mentions_port_option() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "Port note: use `-P, --port <port>` to change proxy listener port." in checklist


def test_docs_list_current_generated_artifacts() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")
    checklist = _read("docs/release-checklist.md")

    artifact_tokens = [
        "captures/latest.manifest.json",
        "captures/latest.scope_audit.json",
        "captures/latest.navigation.ndjson",
    ]

    for token in artifact_tokens:
        assert token in readme_en, f"README.md missing artifact: {token}"
        assert token in readme_cn, f"README_CN.md missing artifact: {token}"
        assert token in checklist, f"release-checklist missing artifact: {token}"


def test_skill_output_table_lists_navigation_artifact() -> None:
    skill_doc = _read("SKILL.md")

    required_tokens = [
        "*.manifest.json",
        "*.scope_audit.json",
        "*.navigation.ndjson",
    ]

    for token in required_tokens:
        assert token in skill_doc, f"SKILL.md missing output artifact token: {token}"


def test_readme_lists_ai_bundle_artifact() -> None:
    readme_en = _read("README.md")

    assert "captures/latest.ai.bundle.txt" in readme_en



def test_readme_cn_lists_ai_bundle_artifact() -> None:
    readme_cn = _read("README_CN.md")

    assert "captures/latest.ai.bundle.txt" in readme_cn



def test_skill_output_table_lists_ai_bundle_artifact() -> None:
    skill_doc = _read("SKILL.md")

    assert "*.ai.bundle.txt" in skill_doc



def test_release_checklist_lists_ai_bundle_artifact() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "captures/latest.ai.bundle.txt" in checklist


def test_docs_include_policy_option() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    assert "--policy" in readme_en, "README.md missing --policy option docs"
    assert "--policy" in readme_cn, "README_CN.md missing --policy option docs"


def test_docs_include_cleanup_flags() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")
    skill_doc = _read("SKILL.md")

    flags = ["--keep-days", "--keep-size", "--secure", "--dry-run"]

    for flag in flags:
        assert flag in readme_en, f"README.md missing cleanup flag docs: {flag}"
        assert flag in readme_cn, f"README_CN.md missing cleanup flag docs: {flag}"
        assert flag in skill_doc, f"SKILL.md missing cleanup flag docs: {flag}"


def test_docs_list_latest_log_artifact() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")
    checklist = _read("docs/release-checklist.md")
    skill_doc = _read("SKILL.md")

    assert "captures/latest.log" in readme_en, "README.md missing captures/latest.log"
    assert "captures/latest.log" in readme_cn, "README_CN.md missing captures/latest.log"
    assert "captures/latest.log" in checklist, "release-checklist missing captures/latest.log"
    assert "*.log" in skill_doc, "SKILL.md missing *.log output artifact"


def test_docs_include_dir_option() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    assert "--dir" in readme_en, "README.md missing --dir option docs"
    assert "--dir" in readme_cn, "README_CN.md missing --dir option docs"


def test_docs_include_port_option() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    assert "--port" in readme_en, "README.md missing --port option docs"
    assert "--port" in readme_cn, "README_CN.md missing --port option docs"


def test_docs_include_custom_dir_port_example() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    assert "capture-session.sh start https://example.com -d" in readme_en
    assert "capture-session.sh start https://example.com -P" in readme_en
    assert "capture-session.sh start https://example.com -d" in readme_cn
    assert "capture-session.sh start https://example.com -P" in readme_cn


def test_skill_includes_navlog_command_guidance() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh navlog" in skill_doc, "SKILL.md missing navlog command guidance"


def test_docs_include_help_option() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    assert "--help" in readme_en, "README.md missing --help option docs"
    assert "--help" in readme_cn, "README_CN.md missing --help option docs"


def test_docs_include_navlog_append_example() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    token = 'capture-session.sh navlog append --action navigate --url "https://example.com"'
    assert token in readme_en, "README.md missing navlog append example"
    assert token in readme_cn, "README_CN.md missing navlog append example"


def test_docs_include_help_command_example() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    assert "capture-session.sh --help" in readme_en, "README.md missing help command example"
    assert "capture-session.sh --help" in readme_cn, "README_CN.md missing help command example"


def test_readme_uses_capture_session_force_recover() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    expected = "capture-session.sh start https://example.com --force-recover"

    assert expected in readme_en, "README.md missing unified force-recover command"
    assert expected in readme_cn, "README_CN.md missing unified force-recover command"

    assert "./scripts/startCaptures.sh --force-recover" not in readme_en
    assert "./scripts/startCaptures.sh --force-recover" not in readme_cn


def test_skill_includes_force_recover_guidance() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh start https://example.com --force-recover" in skill_doc, (
        "SKILL.md missing unified stale-state recovery guidance"
    )


def test_docs_include_force_recover_option_bullet() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")
    skill_doc = _read("SKILL.md")

    token = "- `--force-recover`"

    assert token in readme_en, "README.md missing --force-recover bullet option"
    assert token in readme_cn, "README_CN.md missing --force-recover bullet option"
    assert token in skill_doc, "SKILL.md missing --force-recover bullet option"


def test_skill_includes_long_form_common_options() -> None:
    skill_doc = _read("SKILL.md")

    for option in ["--dir", "--port", "--help"]:
        assert option in skill_doc, f"SKILL.md missing long-form option docs: {option}"


def test_release_checklist_includes_doctor_preflight() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "./scripts/capture-session.sh doctor" in checklist, (
        "release-checklist missing doctor preflight smoke command"
    )


def test_release_checklist_includes_force_recover_and_navlog_smoke() -> None:
    checklist = _read("docs/release-checklist.md")

    assert "./scripts/capture-session.sh start https://example.com --force-recover" in checklist, (
        "release-checklist missing force-recover smoke command"
    )
    assert './scripts/capture-session.sh navlog append --action navigate --url "https://example.com"' in checklist, (
        "release-checklist missing navlog append smoke command"
    )


def test_readmes_include_cleanup_command_examples() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    examples = [
        "capture-session.sh cleanup --keep-days 7",
        "capture-session.sh cleanup --keep-size 1G --dry-run",
        "capture-session.sh cleanup --secure --keep-days 3",
    ]

    for example in examples:
        assert example in readme_en, f"README.md missing cleanup example: {example}"
        assert example in readme_cn, f"README_CN.md missing cleanup example: {example}"


def test_skill_quick_commands_include_doctor_example() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh doctor" in skill_doc, (
        "SKILL.md quick commands missing doctor example"
    )


def test_skill_quick_commands_include_localhost_start_example() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh start http://localhost:3000" in skill_doc, (
        "SKILL.md quick commands missing localhost start example"
    )


def test_skill_quick_commands_include_analyze_example() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh analyze" in skill_doc, (
        "SKILL.md quick commands missing analyze example"
    )


def test_skill_quick_commands_include_cleanup_keep_days_example() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh cleanup --keep-days 7" in skill_doc, (
        "SKILL.md quick commands missing cleanup keep-days example"
    )


def test_skill_quick_commands_include_cleanup_keep_size_dry_run_example() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh cleanup --keep-size 1G --dry-run" in skill_doc, (
        "SKILL.md quick commands missing cleanup keep-size dry-run example"
    )


def test_skill_quick_commands_include_cleanup_secure_example() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh cleanup --secure --keep-days 3" in skill_doc, (
        "SKILL.md quick commands missing cleanup secure example"
    )


def test_skill_quick_commands_include_diff_example() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh diff captures/a.index.ndjson captures/b.index.ndjson" in skill_doc, (
        "SKILL.md quick commands missing diff example"
    )


def test_skill_quick_commands_include_status_example() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh status" in skill_doc, (
        "SKILL.md quick commands missing status example"
    )


def test_skill_quick_commands_include_help_example() -> None:
    skill_doc = _read("SKILL.md")

    assert "capture-session.sh --help" in skill_doc, (
        "SKILL.md quick commands missing help example"
    )


def test_skill_file_structure_lists_cleanup_py() -> None:
    skill_doc = _read("SKILL.md")

    assert "cleanup.py" in skill_doc, (
        "SKILL.md file structure missing cleanup.py"
    )


def test_skill_file_structure_lists_common_sh() -> None:
    skill_doc = _read("SKILL.md")

    assert "common.sh" in skill_doc, (
        "SKILL.md file structure missing common.sh"
    )


def test_skill_file_structure_lists_git_doctor_sh() -> None:
    skill_doc = _read("SKILL.md")

    assert "git-doctor.sh" in skill_doc, (
        "SKILL.md file structure missing git-doctor.sh"
    )


def test_skill_file_structure_lists_policy_py() -> None:
    skill_doc = _read("SKILL.md")

    assert "policy.py" in skill_doc, (
        "SKILL.md file structure missing policy.py"
    )


def test_skill_file_structure_lists_proxy_utils_sh() -> None:
    skill_doc = _read("SKILL.md")

    assert "proxy_utils.sh" in skill_doc, (
        "SKILL.md file structure missing proxy_utils.sh"
    )


def test_skill_file_structure_lists_release_check_sh() -> None:
    skill_doc = _read("SKILL.md")

    assert "release-check.sh" in skill_doc, (
        "SKILL.md file structure missing release-check.sh"
    )


def test_skill_file_structure_lists_scope_audit_py() -> None:
    skill_doc = _read("SKILL.md")

    assert "scope_audit.py" in skill_doc, (
        "SKILL.md file structure missing scope_audit.py"
    )


def test_skill_file_structure_lists_operational_helper_scripts() -> None:
    skill_doc = _read("SKILL.md")

    for script_name in ["doctor.sh", "cleanupCaptures.sh", "diff_captures.py", "navlog.sh"]:
        assert script_name in skill_doc, (
            f"SKILL.md file structure missing helper script: {script_name}"
        )


def test_readmes_project_structure_lists_doctor_sh() -> None:
    structure_en, structure_cn = _project_structures()

    assert "doctor.sh" in structure_en
    assert "doctor.sh" in structure_cn



def test_readmes_project_structure_lists_cleanup_captures_sh() -> None:
    structure_en, structure_cn = _project_structures()

    assert "cleanupCaptures.sh" in structure_en
    assert "cleanupCaptures.sh" in structure_cn



def test_readmes_project_structure_lists_navlog_sh() -> None:
    structure_en, structure_cn = _project_structures()

    assert "navlog.sh" in structure_en
    assert "navlog.sh" in structure_cn



def test_readmes_project_structure_lists_diff_captures_py() -> None:
    structure_en, structure_cn = _project_structures()

    assert "diff_captures.py" in structure_en
    assert "diff_captures.py" in structure_cn



def test_readmes_project_structure_lists_policy_py() -> None:
    structure_en, structure_cn = _project_structures()

    assert "policy.py" in structure_en
    assert "policy.py" in structure_cn



def test_readmes_project_structure_lists_analyze_latest_sh() -> None:
    structure_en, structure_cn = _project_structures()

    assert "analyzeLatest.sh" in structure_en
    assert "analyzeLatest.sh" in structure_cn



def test_readmes_project_structure_lists_ai_sh() -> None:
    structure_en, structure_cn = _project_structures()

    assert "ai.sh" in structure_en
    assert "ai.sh" in structure_cn



def test_readmes_project_structure_lists_flow2har_py() -> None:
    structure_en, structure_cn = _project_structures()

    assert "flow2har.py" in structure_en
    assert "flow2har.py" in structure_cn



def test_readmes_project_structure_lists_flow_report_py() -> None:
    structure_en, structure_cn = _project_structures()

    assert "flow_report.py" in structure_en
    assert "flow_report.py" in structure_cn



def test_readmes_project_structure_lists_ai_brief_py() -> None:
    structure_en, structure_cn = _project_structures()

    assert "ai_brief.py" in structure_en
    assert "ai_brief.py" in structure_cn



def test_readmes_project_structure_lists_scope_audit_py() -> None:
    structure_en, structure_cn = _project_structures()

    assert "scope_audit.py" in structure_en
    assert "scope_audit.py" in structure_cn


def test_readme_troubleshooting_uses_wrapper_stop_command() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    assert "./scripts/stopCaptures.sh" not in readme_en
    assert "./scripts/stopCaptures.sh" not in readme_cn
    assert "capture-session.sh stop" in readme_en
    assert "capture-session.sh stop" in readme_cn


def test_readme_workflow_uses_wrapper_commands() -> None:
    readme_en = _read("README.md")

    workflow = readme_en.split("## Five-Phase Workflow", 1)[1].split("## Scope Control", 1)[0]

    assert "scripts/startCaptures.sh" not in workflow
    assert "scripts/stopCaptures.sh" not in workflow
    assert "capture-session.sh start" in workflow
    assert "capture-session.sh stop" in workflow


def test_readme_cn_workflow_mentions_wrapper_commands() -> None:
    readme_cn = _read("README_CN.md")

    workflow = readme_cn.split("## 五阶段工作流", 1)[1].split("## 范围控制", 1)[0]

    assert "capture-session.sh start" in workflow
    assert "capture-session.sh stop" in workflow


def test_docs_include_drive_browser_traffic_helper() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")
    skill_doc = _read("SKILL.md")
    checklist = _read("docs/release-checklist.md")

    token = "driveBrowserTraffic.sh"
    assert token in readme_en, "README.md missing driveBrowserTraffic helper docs"
    assert token in readme_cn, "README_CN.md missing driveBrowserTraffic helper docs"
    assert token in skill_doc, "SKILL.md missing driveBrowserTraffic helper docs"
    assert token in checklist, "release-checklist missing driveBrowserTraffic smoke command"


def test_readmes_troubleshooting_include_xserver_fallback_helper() -> None:
    readme_en = _read("README.md")
    readme_cn = _read("README_CN.md")

    assert "driveBrowserTraffic.sh --mode auto" in readme_en, (
        "README.md troubleshooting should reference driveBrowserTraffic fallback"
    )
    assert "driveBrowserTraffic.sh --mode auto" in readme_cn, (
        "README_CN.md troubleshooting should reference driveBrowserTraffic fallback"
    )
