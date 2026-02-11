# Round 5 Help and Navlog Example Hardening Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure user-facing docs expose `--help` and practical `navlog append` usage with regression guards.

**Architecture:** Add failing tests in docs consistency suite first, then minimally patch README/README_CN sections with exact tokens.

**Tech Stack:** Markdown docs, Python `pytest`.

---

### Task 1: Document `--help` option in README and README_CN

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1:** Add failing test `test_docs_include_help_option`.

**Step 2:** Run `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_help_option -q` (expect FAIL).

**Step 3:** Add `-h, --help` line under global options in README and README_CN.

**Step 4:** Re-run same test (expect PASS).

**Step 5:** Checkpoint with `git diff -- README.md README_CN.md tests/test_docs_consistency.py`.

---

### Task 2: Add navlog append example to README and README_CN

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1:** Add failing test `test_docs_include_navlog_append_example`.

**Step 2:** Run `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_navlog_append_example -q` (expect FAIL).

**Step 3:** Add one navlog example snippet containing `--action` and `--url` to README and README_CN.

**Step 4:** Re-run same test (expect PASS).

**Step 5:** Checkpoint with `git diff -- README.md README_CN.md tests/test_docs_consistency.py`.

---

### Task 3: Add explicit `capture-session.sh --help` usage example

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1:** Add failing test `test_docs_include_help_command_example`.

**Step 2:** Run `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_help_command_example -q` (expect FAIL).

**Step 3:** Add one command example `capture-session.sh --help` in both READMEs.

**Step 4:** Re-run same test (expect PASS).

**Step 5:** Checkpoint with `git diff -- README.md README_CN.md tests/test_docs_consistency.py`.

---

### Task 4: Full verification

1. `python3 -m pytest tests/test_docs_consistency.py -q`
2. `python3 -m pytest tests -q`
3. `for test in tests/test_*.sh; do bash "$test"; done`
4. `./scripts/release-check.sh --dry-run`
5. `git status --short`

