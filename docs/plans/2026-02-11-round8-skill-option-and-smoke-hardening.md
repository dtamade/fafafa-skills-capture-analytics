# Round 8 SKILL Option and Smoke Checklist Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close Round 8 docs drift by aligning `SKILL.md` option docs with wrapper long-form flags and strengthening smoke-test checklist commands with regression tests.

**Architecture:** Add focused failing tests in `tests/test_docs_consistency.py` for missing long-form option tokens and missing smoke-test commands in `docs/release-checklist.md`, then minimally patch `SKILL.md` and release checklist to satisfy those contracts. Keep changes scoped to docs + tests only; no runtime logic changes.

**Tech Stack:** Python `pytest`, Markdown docs, Bash CLI contract (`capture-session.sh --help`).

---

### Task 1: Add long-form common options to `SKILL.md`

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `SKILL.md`

**Step 1: Write the failing test**

Add `test_skill_includes_long_form_common_options` asserting `--dir`, `--port`, and `--help` appear in `SKILL.md`.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_includes_long_form_common_options -q`
Expected: FAIL because long-form tokens are missing.

**Step 3: Write minimal implementation**

Update the key flags section in `SKILL.md` to include long-form tokens (`--dir`, `--port`) and add `--help` option guidance.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_skill_includes_long_form_common_options -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- SKILL.md tests/test_docs_consistency.py`
Expected: only long-form option docs + one test.

---

### Task 2: Add doctor preflight smoke command to release checklist

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `docs/release-checklist.md`

**Step 1: Write the failing test**

Add `test_release_checklist_includes_doctor_preflight` asserting the smoke-test block includes `./scripts/capture-session.sh doctor`.

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_doctor_preflight -q`
Expected: FAIL because command is currently missing.

**Step 3: Write minimal implementation**

Insert `./scripts/capture-session.sh doctor` at the top of the smoke-test command block.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_doctor_preflight -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- docs/release-checklist.md tests/test_docs_consistency.py`
Expected: doctor preflight command + one test.

---

### Task 3: Add stale-state recovery and navlog smoke commands to release checklist

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `docs/release-checklist.md`

**Step 1: Write the failing test**

Add `test_release_checklist_includes_force_recover_and_navlog_smoke` asserting smoke-test commands include:
- `./scripts/capture-session.sh start https://example.com --force-recover`
- `./scripts/capture-session.sh navlog append --action navigate --url "https://example.com"`

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_force_recover_and_navlog_smoke -q`
Expected: FAIL because both commands are currently missing.

**Step 3: Write minimal implementation**

Replace start command with `--force-recover` version and add one navlog append command before stop.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_force_recover_and_navlog_smoke -q`
Expected: PASS.

**Step 5: Checkpoint**

Run: `git diff -- docs/release-checklist.md tests/test_docs_consistency.py`
Expected: only force-recover/navlog smoke docs + one test.

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
Expected: only intended docs/tests/planning file changes.
