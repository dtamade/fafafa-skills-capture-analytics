# Round 3 Dir/Port Docs Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Document `-d/--dir` and `-P/--port` options in user-facing docs and add regression tests preventing drift.

**Architecture:** Add targeted failing docs-consistency tests first, then minimally patch README/README_CN command guidance and examples. Keep scope docs + tests only.

**Tech Stack:** Markdown docs, Python `pytest`.

---

### Task 1: Cover `-d, --dir` option in READMEs

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1: Write the failing test**

Add `test_docs_include_dir_option` asserting `--dir` appears in README and README_CN.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_dir_option -q`
Expected: FAIL.

**Step 3: Write minimal implementation**

Add one concise line in both READMEs documenting `-d, --dir <path>`.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_dir_option -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- README.md README_CN.md tests/test_docs_consistency.py`
Expected: dir-option docs + test.

---

### Task 2: Cover `-P, --port` option in READMEs

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1: Write the failing test**

Add `test_docs_include_port_option` asserting `--port` appears in README and README_CN.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_port_option -q`
Expected: FAIL.

**Step 3: Write minimal implementation**

Add one concise line in both READMEs documenting `-P, --port <port>`.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_port_option -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- README.md README_CN.md tests/test_docs_consistency.py`
Expected: port-option docs + test.

---

### Task 3: Add explicit custom dir/port command examples

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1: Write the failing test**

Add `test_docs_include_custom_dir_port_example` asserting both READMEs contain:
- `capture-session.sh start https://example.com -d`
- `capture-session.sh start https://example.com -P`

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_custom_dir_port_example -q`
Expected: FAIL.

**Step 3: Write minimal implementation**

Add two short example lines in each README showing custom directory and custom port usage.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_custom_dir_port_example -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- README.md README_CN.md tests/test_docs_consistency.py`
Expected: example lines + test.

---

### Task 4: Full verification

**Files:**
- Verify only

**Step 1:** `python3 -m pytest tests/test_docs_consistency.py -q` → PASS

**Step 2:** `python3 -m pytest tests -q` → PASS

**Step 3:** `for test in tests/test_*.sh; do bash "$test"; done` → PASS

**Step 4:** `./scripts/release-check.sh --dry-run` → PASS

**Step 5:** `git status --short` review intended changes.

