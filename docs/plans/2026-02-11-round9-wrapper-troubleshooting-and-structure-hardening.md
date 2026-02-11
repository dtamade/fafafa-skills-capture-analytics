# Round 9 Wrapper Troubleshooting and Structure Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate Round 9 docs drift by enforcing unified wrapper troubleshooting guidance and syncing README/SKILL operational docs with current helper scripts and cleanup command usage.

**Architecture:** Add three focused failing tests in `tests/test_docs_consistency.py` for the identified gaps, then minimally patch `README.md`, `README_CN.md`, and `SKILL.md` to satisfy those contracts. Keep scope strictly to docs + tests; no runtime script logic changes.

**Tech Stack:** Python `pytest`, Markdown docs, Bash CLI public contract.

---

### Task 1: Enforce wrapper-only troubleshooting stop guidance in both READMEs

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1: Write the failing test**

Add `test_readme_troubleshooting_uses_wrapper_stop_command` asserting:
- `./scripts/stopCaptures.sh` does **not** appear in `README.md` and `README_CN.md`
- `capture-session.sh stop` appears in both docs

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_readme_troubleshooting_uses_wrapper_stop_command -q`
Expected: FAIL because both READMEs still reference `./scripts/stopCaptures.sh`.

**Step 3: Write minimal implementation**

Update troubleshooting table row (`Port is already in use: 18080`) in both READMEs to use wrapper guidance:
- `capture-session.sh stop` (and keep `-P <port>` fallback)

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_readme_troubleshooting_uses_wrapper_stop_command -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- README.md README_CN.md tests/test_docs_consistency.py`
Expected: troubleshooting row update + one new test only.

---

### Task 2: Add cleanup command examples to both READMEs

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1: Write the failing test**

Add `test_readmes_include_cleanup_command_examples` asserting both READMEs include:
- `capture-session.sh cleanup --keep-days 7`
- `capture-session.sh cleanup --keep-size 1G --dry-run`
- `capture-session.sh cleanup --secure --keep-days 3`

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_readmes_include_cleanup_command_examples -q`
Expected: FAIL because cleanup examples are currently absent.

**Step 3: Write minimal implementation**

Add one concise cleanup examples block under cleanup options in both README languages.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_readmes_include_cleanup_command_examples -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- README.md README_CN.md tests/test_docs_consistency.py`
Expected: cleanup examples + one new test.

---

### Task 3: Sync SKILL file-structure scripts with current operational helpers

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `SKILL.md`

**Step 1: Write the failing test**

Add `test_skill_file_structure_lists_operational_helper_scripts` asserting `SKILL.md` mentions:
- `doctor.sh`
- `cleanupCaptures.sh`
- `diff_captures.py`
- `navlog.sh`

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_file_structure_lists_operational_helper_scripts -q`
Expected: FAIL because these helper scripts are not listed in SKILL file structure tree.

**Step 3: Write minimal implementation**

Expand SKILL file structure script list with the four helper scripts and brief comments.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_file_structure_lists_operational_helper_scripts -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- SKILL.md tests/test_docs_consistency.py`
Expected: file-structure rows + one new test.

---

### Task 4: Full verification

**Files:**
- Verify only

**Step 1: Run docs consistency suite**

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
Expected: only intended docs/tests/planning updates.
