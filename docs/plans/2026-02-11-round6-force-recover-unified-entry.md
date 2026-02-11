# Round 6 Force-Recover Unified Entry Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `capture-session.sh` the true unified entry for stale-state recovery by adding `--force-recover` support and aligning docs.

**Architecture:** Add failing contract/doc tests first, implement minimal parser+forwarding changes in `capture-session.sh`, then patch README/CN/SKILL guidance to use the unified entry command.

**Tech Stack:** Bash scripts, Markdown docs, Python `pytest`.

---

### Task 1: Add and satisfy capture-session force-recover contract

**Files:**
- Create: `tests/test_capture_session_contract.py`
- Modify: `scripts/capture-session.sh`

**Step 1:** Write failing contract tests checking:
- help/options include `--force-recover`
- parser handles `--force-recover`
- `start` forwards it to `startCaptures.sh`

**Step 2:** Run `python3 -m pytest tests/test_capture_session_contract.py -q` (expect FAIL).

**Step 3:** Minimal implementation in `capture-session.sh`:
- add option text
- parse flag
- append to `START_CMD`

**Step 4:** Re-run `python3 -m pytest tests/test_capture_session_contract.py -q` (expect PASS).

**Step 5:** Checkpoint `git diff -- scripts/capture-session.sh tests/test_capture_session_contract.py`.

---

### Task 2: Align README and README_CN stale-state fix to unified entry

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `README.md`
- Modify: `README_CN.md`

**Step 1:** Add failing docs test `test_readme_uses_capture_session_force_recover` asserting:
- contains `capture-session.sh start https://example.com --force-recover`
- does not contain `./scripts/startCaptures.sh --force-recover`

**Step 2:** Run `python3 -m pytest tests/test_docs_consistency.py::test_readme_uses_capture_session_force_recover -q` (expect FAIL).

**Step 3:** Update troubleshooting row in both READMEs to unified entry command.

**Step 4:** Re-run same test (expect PASS).

**Step 5:** Checkpoint `git diff -- README.md README_CN.md tests/test_docs_consistency.py`.

---

### Task 3: Add SKILL stale-state recovery guidance and guard

**Files:**
- Modify: `tests/test_docs_consistency.py`
- Modify: `SKILL.md`

**Step 1:** Add failing test `test_skill_includes_force_recover_guidance` expecting `capture-session.sh start https://example.com --force-recover` in SKILL docs.

**Step 2:** Run `python3 -m pytest tests/test_docs_consistency.py::test_skill_includes_force_recover_guidance -q` (expect FAIL).

**Step 3:** Add one troubleshooting row in `SKILL.md` for stale state recovery via unified entry.

**Step 4:** Re-run same test (expect PASS).

**Step 5:** Checkpoint `git diff -- SKILL.md tests/test_docs_consistency.py`.

---

### Task 4: Full verification

1. `python3 -m pytest tests/test_capture_session_contract.py -q`
2. `python3 -m pytest tests/test_docs_consistency.py -q`
3. `python3 -m pytest tests -q`
4. `for test in tests/test_*.sh; do bash "$test"; done`
5. `./scripts/release-check.sh --dry-run`
6. `git status --short`

