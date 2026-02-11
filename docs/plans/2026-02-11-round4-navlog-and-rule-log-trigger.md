# Round 4 Navlog and Rule Log Trigger Hardening Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align SKILL guidance and trigger rules with current CLI capabilities and generated artifacts (`navlog` + `*.log`).

**Architecture:** Add failing tests first in docs/rules test suites, then minimally patch SKILL docs and skill-rules config to satisfy those tests.

**Tech Stack:** Markdown docs, JSON rule config, Python `pytest`.

---

### Task 1: Add navlog guidance to SKILL docs

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `SKILL.md`

**Step 1: Write the failing test**

Add `test_skill_includes_navlog_command_guidance` asserting `capture-session.sh navlog` appears in SKILL docs.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_includes_navlog_command_guidance -q`
Expected: FAIL.

**Step 3: Write minimal implementation**

Add a short navlog usage block in SKILL examples section.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_includes_navlog_command_guidance -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- SKILL.md tests/test_docs_consistency.py`
Expected: navlog doc snippet + one test.

---

### Task 2: Add failing rule test for `.log` trigger coverage

**Files:**
- Modify: `tests/test_rules.py`

**Step 1: Write the failing test change**

Add `.log` to `required_suffixes` in `test_file_trigger_patterns_include_current_outputs`.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_rules.py::test_file_trigger_patterns_include_current_outputs -q`
Expected: FAIL with missing `.log` pattern.

**Step 3: Checkpoint**

Run: `git diff -- tests/test_rules.py`
Expected: only `.log` required suffix addition.

---

### Task 3: Implement `.log` file trigger pattern

**Files:**
- Modify: `skill-rules.json`

**Step 1: Write minimal implementation**

Add `"**/captures/*.log"` to `fileTriggers.pathPatterns`.

**Step 2: Run target test to verify pass**

Run: `python3 -m pytest tests/test_rules.py::test_file_trigger_patterns_include_current_outputs -q`
Expected: PASS.

**Step 3: Checkpoint**

Run: `git diff -- skill-rules.json tests/test_rules.py`
Expected: `.log` pattern + corresponding test expectation.

---

### Task 4: Full verification

**Step 1:** `python3 -m pytest tests/test_docs_consistency.py -q` → PASS

**Step 2:** `python3 -m pytest tests/test_rules.py -q` → PASS

**Step 3:** `python3 -m pytest tests -q` → PASS

**Step 4:** `for test in tests/test_*.sh; do bash "$test"; done` → PASS

**Step 5:** `./scripts/release-check.sh --dry-run` → PASS

**Step 6:** `git status --short` review intended changes.

