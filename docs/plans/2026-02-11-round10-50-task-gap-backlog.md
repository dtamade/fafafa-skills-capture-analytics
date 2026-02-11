# Round 10 50-Task Gap Backlog and Execution Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete a 50-task hardening backlog by closing documentation drift and missing regression guards across `SKILL.md`, `README.md`, `README_CN.md`, `docs/release-checklist.md`, and `tests/*`.

**Architecture:** Build a prioritized queue from full-repo scan findings. For each task, run strict TDD: write failing test first, verify RED, apply minimal doc/code change, verify GREEN, then checkpoint. Execute in batches of 3 tasks per loop and re-scan between loops.

**Tech Stack:** Python `pytest`, Markdown docs, Bash wrapper contracts.

---

## Priority Summary

- **P0 (Tasks 1-22):** `SKILL.md` and release checklist command-example parity with `capture-session.sh --help`
- **P1 (Tasks 23-42):** option discoverability + project-structure visibility in README/CN
- **P2 (Tasks 43-50):** AI bundle artifact coverage + wrapper contract guard expansion

---

### Task 1: SKILL quick commands include `capture-session.sh doctor`

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `SKILL.md`

**Step 1: Write the failing test**
- Add `test_skill_quick_commands_include_doctor_example`.

**Step 2: Run test to verify it fails**
- Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_doctor_example -q`
- Expected: FAIL (`SKILL.md` missing token).

**Step 3: Write minimal implementation**
- Add `capture-session.sh doctor` command snippet in `SKILL.md` quick command area.

**Step 4: Run test to verify it passes**
- Run same command.
- Expected: PASS.

**Step 5: Checkpoint**
- Run: `git diff -- SKILL.md tests/test_docs_consistency.py`

---

### Task 2: SKILL quick commands include localhost start example

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `SKILL.md`

**Step 1: Write the failing test**
- Add `test_skill_quick_commands_include_localhost_start_example`.

**Step 2: Run test to verify it fails**
- Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_localhost_start_example -q`
- Expected: FAIL.

**Step 3: Write minimal implementation**
- Add `capture-session.sh start http://localhost:3000` example in `SKILL.md`.

**Step 4: Run test to verify it passes**
- Run same command.
- Expected: PASS.

**Step 5: Checkpoint**
- Run: `git diff -- SKILL.md tests/test_docs_consistency.py`

---

### Task 3: SKILL quick commands include analyze example

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `SKILL.md`

**Step 1: Write the failing test**
- Add `test_skill_quick_commands_include_analyze_example`.

**Step 2: Run test to verify it fails**
- Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_analyze_example -q`
- Expected: FAIL.

**Step 3: Write minimal implementation**
- Add `capture-session.sh analyze` example in `SKILL.md`.

**Step 4: Run test to verify it passes**
- Run same command.
- Expected: PASS.

**Step 5: Checkpoint**
- Run: `git diff -- SKILL.md tests/test_docs_consistency.py`

---

## Backlog Tasks 4-50 (Prioritized Queue)

| ID | Priority | Task | Primary Files | RED Command (target) |
|---|---|---|---|---|
| T04 | P0 | SKILL add cleanup keep-days example | `tests/test_docs_consistency.py`, `SKILL.md` | `pytest ...::test_skill_quick_commands_include_cleanup_keep_days_example -q` |
| T05 | P0 | SKILL add cleanup keep-size dry-run example | same | `pytest ...::test_skill_quick_commands_include_cleanup_keep_size_dry_run_example -q` |
| T06 | P0 | SKILL add cleanup secure example | same | `pytest ...::test_skill_quick_commands_include_cleanup_secure_example -q` |
| T07 | P0 | SKILL add diff example | same | `pytest ...::test_skill_quick_commands_include_diff_example -q` |
| T08 | P0 | SKILL add status command example | same | `pytest ...::test_skill_quick_commands_include_status_example -q` |
| T09 | P0 | SKILL add help command example | same | `pytest ...::test_skill_quick_commands_include_help_example -q` |
| T10 | P0 | SKILL file structure add `cleanup.py` | same | `pytest ...::test_skill_file_structure_lists_cleanup_py -q` |
| T11 | P0 | SKILL file structure add `common.sh` | same | `pytest ...::test_skill_file_structure_lists_common_sh -q` |
| T12 | P0 | SKILL file structure add `git-doctor.sh` | same | `pytest ...::test_skill_file_structure_lists_git_doctor -q` |
| T13 | P0 | SKILL file structure add `policy.py` | same | `pytest ...::test_skill_file_structure_lists_policy_py -q` |
| T14 | P0 | SKILL file structure add `proxy_utils.sh` | same | `pytest ...::test_skill_file_structure_lists_proxy_utils_sh -q` |
| T15 | P0 | SKILL file structure add `release-check.sh` | same | `pytest ...::test_skill_file_structure_lists_release_check_sh -q` |
| T16 | P0 | SKILL file structure add `scope_audit.py` | same | `pytest ...::test_skill_file_structure_lists_scope_audit_py -q` |
| T17 | P0 | release-checklist add localhost start example | `tests/test_docs_consistency.py`, `docs/release-checklist.md` | `pytest ...::test_release_checklist_includes_localhost_start_example -q` |
| T18 | P0 | release-checklist add allow-hosts start example | same | `pytest ...::test_release_checklist_includes_allow_hosts_start_example -q` |
| T19 | P0 | release-checklist add cleanup keep-days example | same | `pytest ...::test_release_checklist_includes_cleanup_keep_days_example -q` |
| T20 | P0 | release-checklist add cleanup keep-size dry-run example | same | `pytest ...::test_release_checklist_includes_cleanup_keep_size_dry_run_example -q` |
| T21 | P0 | release-checklist add cleanup secure example | same | `pytest ...::test_release_checklist_includes_cleanup_secure_example -q` |
| T22 | P0 | release-checklist add diff example | same | `pytest ...::test_release_checklist_includes_diff_example -q` |
| T23 | P1 | release-checklist add `--allow-hosts` discoverability note | same | `pytest ...::test_release_checklist_mentions_allow_hosts_option -q` |
| T24 | P1 | release-checklist add `--deny-hosts` note | same | `pytest ...::test_release_checklist_mentions_deny_hosts_option -q` |
| T25 | P1 | release-checklist add `--policy` note | same | `pytest ...::test_release_checklist_mentions_policy_option -q` |
| T26 | P1 | release-checklist add `--keep-days` note | same | `pytest ...::test_release_checklist_mentions_keep_days_option -q` |
| T27 | P1 | release-checklist add `--keep-size` note | same | `pytest ...::test_release_checklist_mentions_keep_size_option -q` |
| T28 | P1 | release-checklist add `--secure` note | same | `pytest ...::test_release_checklist_mentions_secure_option -q` |
| T29 | P1 | release-checklist add `--help` note | same | `pytest ...::test_release_checklist_mentions_help_option -q` |
| T30 | P1 | release-checklist add `--dir` note | same | `pytest ...::test_release_checklist_mentions_dir_option -q` |
| T31 | P1 | release-checklist add `--port` note | same | `pytest ...::test_release_checklist_mentions_port_option -q` |
| T32 | P1 | README/CN project structure include `doctor.sh` | `tests/test_docs_consistency.py`, `README.md`, `README_CN.md` | `pytest ...::test_readmes_project_structure_lists_doctor_sh -q` |
| T33 | P1 | README/CN project structure include `cleanupCaptures.sh` | same | `pytest ...::test_readmes_project_structure_lists_cleanup_captures_sh -q` |
| T34 | P1 | README/CN project structure include `navlog.sh` | same | `pytest ...::test_readmes_project_structure_lists_navlog_sh -q` |
| T35 | P1 | README/CN project structure include `diff_captures.py` | same | `pytest ...::test_readmes_project_structure_lists_diff_captures_py -q` |
| T36 | P1 | README/CN project structure include `policy.py` | same | `pytest ...::test_readmes_project_structure_lists_policy_py -q` |
| T37 | P1 | README/CN project structure include `analyzeLatest.sh` | same | `pytest ...::test_readmes_project_structure_lists_analyze_latest_sh -q` |
| T38 | P1 | README/CN project structure include `ai.sh` | same | `pytest ...::test_readmes_project_structure_lists_ai_sh -q` |
| T39 | P1 | README/CN project structure include `flow2har.py` | same | `pytest ...::test_readmes_project_structure_lists_flow2har_py -q` |
| T40 | P1 | README/CN project structure include `flow_report.py` | same | `pytest ...::test_readmes_project_structure_lists_flow_report_py -q` |
| T41 | P1 | README/CN project structure include `ai_brief.py` | same | `pytest ...::test_readmes_project_structure_lists_ai_brief_py -q` |
| T42 | P1 | README/CN project structure include `scope_audit.py` | same | `pytest ...::test_readmes_project_structure_lists_scope_audit_py -q` |
| T43 | P2 | README output files include `captures/latest.ai.bundle.txt` | `tests/test_docs_consistency.py`, `README.md` | `pytest ...::test_readme_lists_ai_bundle_artifact -q` |
| T44 | P2 | README_CN output files include `captures/latest.ai.bundle.txt` | `tests/test_docs_consistency.py`, `README_CN.md` | `pytest ...::test_readme_cn_lists_ai_bundle_artifact -q` |
| T45 | P2 | SKILL output table include `*.ai.bundle.txt` | `tests/test_docs_consistency.py`, `SKILL.md` | `pytest ...::test_skill_output_table_lists_ai_bundle_artifact -q` |
| T46 | P2 | release-checklist artifact list include `captures/latest.ai.bundle.txt` | `tests/test_docs_consistency.py`, `docs/release-checklist.md` | `pytest ...::test_release_checklist_lists_ai_bundle_artifact -q` |
| T47 | P2 | contract test: `--allow-hosts` forwarding in wrapper | `tests/test_capture_session_contract.py` | `pytest tests/test_capture_session_contract.py::test_capture_session_allow_hosts_forwarding_contract -q` |
| T48 | P2 | contract test: `--deny-hosts` forwarding in wrapper | same | `pytest tests/test_capture_session_contract.py::test_capture_session_deny_hosts_forwarding_contract -q` |
| T49 | P2 | contract test: `--policy` forwarding in wrapper | same | `pytest tests/test_capture_session_contract.py::test_capture_session_policy_forwarding_contract -q` |
| T50 | P2 | contract test: cleanup flags forwarding in wrapper | same | `pytest tests/test_capture_session_contract.py::test_capture_session_cleanup_flags_forwarding_contract -q` |

---

### Verification Gate (run after each 3-task batch)

1. `python3 -m pytest tests/test_docs_consistency.py -q`
2. `python3 -m pytest tests/test_capture_session_contract.py -q`
3. `python3 -m pytest tests -q`
4. `for test in tests/test_*.sh; do bash "$test"; done`
5. `./scripts/release-check.sh --dry-run`

---

## Execution Status (2026-02-11)

- ✅ Tasks 1-50 completed.
- ✅ TDD evidence recorded in `progress.md` and `findings.md`.
- ✅ Final validation gates passed (`pytest docs/test suite`, `tests/test_*.sh`, `release-check --dry-run`).
