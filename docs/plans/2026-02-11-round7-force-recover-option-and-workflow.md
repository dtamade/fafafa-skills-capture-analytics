# Round 7 Force-Recover Option and Workflow Alignment Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete force-recover option discoverability and align workflow docs to unified `capture-session.sh` entry.

**Architecture:** Add failing docs-consistency tests for option bullets and workflow text, then minimally patch README/README_CN/SKILL.

**Tech Stack:** Markdown docs, Python `pytest`.

---

### Task 1: Document `--force-recover` in option bullet lists

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`
- Modify: `SKILL.md`

**Step 1:** Add failing test `test_docs_include_force_recover_option_bullet` requiring `- \`--force-recover\`` bullet in README, README_CN, SKILL.

**Step 2:** Run `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_force_recover_option_bullet -q` (expect FAIL).

**Step 3:** Add minimal bullet line in option/flags sections.

**Step 4:** Re-run same test (expect PASS).

**Step 5:** Checkpoint `git diff -- README.md README_CN.md SKILL.md tests/test_docs_consistency.py`.

---

### Task 2: Make English workflow reference unified wrapper commands

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`

**Step 1:** Add failing test `test_readme_workflow_uses_wrapper_commands` asserting:
- no `scripts/startCaptures.sh` / `scripts/stopCaptures.sh`
- contains `capture-session.sh start` and `capture-session.sh stop`

**Step 2:** Run `python3 -m pytest tests/test_docs_consistency.py::test_readme_workflow_uses_wrapper_commands -q` (expect FAIL).

**Step 3:** Update workflow lines in README.

**Step 4:** Re-run same test (expect PASS).

**Step 5:** Checkpoint `git diff -- README.md tests/test_docs_consistency.py`.

---

### Task 3: Add wrapper anchors to Chinese workflow

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README_CN.md`

**Step 1:** Add failing test `test_readme_cn_workflow_mentions_wrapper_commands` expecting:
- `capture-session.sh start`
- `capture-session.sh stop`
inside workflow section wording tokenized lines.

**Step 2:** Run `python3 -m pytest tests/test_docs_consistency.py::test_readme_cn_workflow_mentions_wrapper_commands -q` (expect FAIL).

**Step 3:** Update Chinese workflow phase 2/4 lines with wrapper command anchors.

**Step 4:** Re-run same test (expect PASS).

**Step 5:** Checkpoint `git diff -- README_CN.md tests/test_docs_consistency.py`.

---

### Task 4: Full verification

1. `python3 -m pytest tests/test_docs_consistency.py -q`
2. `python3 -m pytest tests/test_capture_session_contract.py -q`
3. `python3 -m pytest tests -q`
4. `for test in tests/test_*.sh; do bash "$test"; done`
5. `./scripts/release-check.sh --dry-run`
6. `git status --short`

