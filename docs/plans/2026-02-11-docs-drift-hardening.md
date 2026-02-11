# Docs Drift Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate CLI/docs drift for `capture-session.sh` public commands and generated artifacts, then lock the behavior with regression tests.

**Architecture:** Drive documentation updates through tests first. Expand `tests/test_docs_consistency.py` to assert the real public surface and artifact outputs, then minimally update README/README_CN/SKILL/release checklist to satisfy those assertions. Keep scope to docs + tests only.

**Tech Stack:** Bash scripts, Markdown docs, Python `pytest` test suite.

---

### Task 1: Expose `navlog` command in both READMEs

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1: Write the failing test**

Add `capture-session.sh navlog <cmd>` to `expected_commands` in `test_capture_session_commands_match_readme_docs`.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_capture_session_commands_match_readme_docs -q`
Expected: FAIL with missing `capture-session.sh navlog <cmd>` in README files.

**Step 3: Write minimal implementation**

Add one command reference line to `README.md` and `README_CN.md` command blocks:
- `capture-session.sh navlog <cmd>   # Manage navigation log ...`

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_capture_session_commands_match_readme_docs -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- README.md README_CN.md tests/test_docs_consistency.py`
Expected: Only navlog command references and test expectation change.

---

### Task 2: Document generated artifact set in READMEs + release checklist

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`
- Modify: `docs/release-checklist.md`

**Step 1: Write the failing test**

Add new test `test_docs_list_current_generated_artifacts` asserting these tokens exist in docs:
- `captures/latest.manifest.json`
- `captures/latest.scope_audit.json`
- `captures/latest.navigation.ndjson`

and in release checklist artifact section.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_list_current_generated_artifacts -q`
Expected: FAIL because docs don’t list all files yet.

**Step 3: Write minimal implementation**

Update output file tables in both READMEs and artifact checklist in `docs/release-checklist.md` to include the three files above.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_list_current_generated_artifacts -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- README.md README_CN.md docs/release-checklist.md tests/test_docs_consistency.py`
Expected: Artifact lists and new test only.

---

### Task 3: Keep SKILL output-file docs aligned with pipeline artifacts

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `SKILL.md`

**Step 1: Write the failing test**

Add new test `test_skill_output_table_lists_navigation_artifact` asserting SKILL docs include:
- `*.navigation.ndjson`
- `*.manifest.json`
- `*.scope_audit.json`

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_output_table_lists_navigation_artifact -q`
Expected: FAIL because navigation artifact is not listed.

**Step 3: Write minimal implementation**

Add one row for `*.navigation.ndjson` in SKILL output file table.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_output_table_lists_navigation_artifact -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- SKILL.md tests/test_docs_consistency.py`
Expected: One table-row addition + new test.

---

### Task 4: Full verification

**Files:**
- Verify only

**Step 1: Run focused docs consistency tests**

Run: `python3 -m pytest tests/test_docs_consistency.py -q`
Expected: PASS.

**Step 2: Run full Python tests**

Run: `python3 -m pytest tests -q`
Expected: PASS.

**Step 3: Run shell tests**

Run: `for test in tests/test_*.sh; do bash "$test"; done`
Expected: PASS.

**Step 4: Run release-check dry-run**

Run: `./scripts/release-check.sh --dry-run`
Expected: Dry-run complete.

**Step 5: Final checkpoint**

Run: `git status --short`
Expected: Only intended docs/tests/planning files changed.

