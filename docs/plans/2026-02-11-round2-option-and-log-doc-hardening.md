# Round 2 Option and Log Docs Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close remaining docs drift by documenting key CLI options and `latest.log` artifact, with regression tests to prevent future drift.

**Architecture:** Add focused failing tests in `tests/test_docs_consistency.py` for option-token and artifact-token presence, then minimally patch README/README_CN/SKILL/release checklist to satisfy tests. Keep implementation purely documentation + tests.

**Tech Stack:** Markdown docs, Bash CLI help contract, Python `pytest`.

---

### Task 1: Document `--policy` option in README/README_CN

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1: Write the failing test**

Add `test_docs_include_policy_option` asserting `--policy` appears in both READMEs.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_policy_option -q`
Expected: FAIL because token is missing in README docs.

**Step 3: Write minimal implementation**

Add minimal `--policy <file>` mention in scope-control section for both README languages.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_policy_option -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- README.md README_CN.md tests/test_docs_consistency.py`
Expected: only policy-option doc + test.

---

### Task 2: Document cleanup flags (`--keep-days/--keep-size/--secure/--dry-run`)

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`
- Modify: `SKILL.md`

**Step 1: Write the failing test**

Add `test_docs_include_cleanup_flags` asserting all four flags appear in README + README_CN + SKILL.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_cleanup_flags -q`
Expected: FAIL because tokens are currently missing.

**Step 3: Write minimal implementation**

Add one concise cleanup-options subsection in README and README_CN; add one concise cleanup note in SKILL command docs.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_cleanup_flags -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- README.md README_CN.md SKILL.md tests/test_docs_consistency.py`
Expected: cleanup-options docs + test only.

---

### Task 3: Document `latest.log` artifact everywhere users verify outputs

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`
- Modify: `docs/release-checklist.md`
- Modify: `SKILL.md`

**Step 1: Write the failing test**

Add `test_docs_list_latest_log_artifact` asserting these tokens exist:
- `captures/latest.log` in README, README_CN, release checklist
- `*.log` in SKILL output table

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_list_latest_log_artifact -q`
Expected: FAIL because docs currently omit log artifact.

**Step 3: Write minimal implementation**

Add one output-file row/list item to each doc location above.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_list_latest_log_artifact -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- README.md README_CN.md docs/release-checklist.md SKILL.md tests/test_docs_consistency.py`
Expected: log-artifact docs + test only.

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
Expected: only intended doc/test/planning changes.

