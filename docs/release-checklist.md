# Release and Rollback Checklist

Use this checklist before every release.

## 1) Prepare the branch

- Confirm your target branch is clean:

```bash
git status --short --branch
```

- Rebase or merge latest `main` if needed.
- Confirm release notes/changelog updates are ready.

## 2) Verify local quality gates

Run:

```bash
./scripts/release-check.sh
```

Expected outcome:

- All quality gates pass in one run.

Optional (preview only):

```bash
./scripts/release-check.sh --dry-run
```

Optional (partial checks):

```bash
./scripts/release-check.sh --skip-shell-tests --skip-doctor
```

## 3) Run a functional smoke test

Run:

```bash
./scripts/capture-session.sh start https://example.com
./scripts/capture-session.sh status
./scripts/capture-session.sh progress
./scripts/capture-session.sh stop
./scripts/capture-session.sh analyze
```

Then confirm these artifacts exist:

- `captures/latest.flow`
- `captures/latest.har`
- `captures/latest.index.ndjson`
- `captures/latest.summary.md`
- `captures/latest.ai.json`
- `captures/latest.ai.md`

## 4) Verify CI and merge

- Push branch and open PR.
- Confirm GitHub Actions `CI` workflow is green.
- Merge only after CI passes.

## 5) Post-release quick checks

- Re-run `./install.sh --check` in a fresh clone.
- Confirm README badge shows passing CI.
- Confirm release tag/version metadata is visible on GitHub.

---

## Rollback checklist

Use this if the release causes regressions.

### A) Decide rollback target

- Select the last known good commit/tag.
- Record affected release commit SHA.

### B) Revert and validate

Run:

```bash
git revert <bad_commit_sha>
./install.sh --check
pytest -q
for test in tests/*.sh; do bash "$test"; done
```

If multiple commits are involved, revert each in reverse order.

### C) Ship rollback

- Push revert commit(s).
- Confirm CI is green.
- Create an incident note with:
  - what failed,
  - impact scope,
  - rollback SHA,
  - follow-up fix owner.
