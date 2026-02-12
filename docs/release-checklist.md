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
./scripts/capture-session.sh doctor
./scripts/capture-session.sh start https://example.com --force-recover
./scripts/capture-session.sh start http://localhost:3000
./scripts/capture-session.sh start https://example.com --allow-hosts 'api\.example\.com'
./scripts/capture-session.sh status
./scripts/capture-session.sh progress
./scripts/capture-session.sh navlog append --action navigate --url "https://example.com"
./scripts/driveBrowserTraffic.sh --url https://example.com -P 18080 --mode auto
./scripts/capture-session.sh stop
./scripts/capture-session.sh analyze
./scripts/capture-session.sh cleanup --keep-days 7
./scripts/capture-session.sh cleanup --keep-size 1G --dry-run
./scripts/capture-session.sh cleanup --secure --keep-days 3
./scripts/capture-session.sh diff captures/a.index.ndjson captures/b.index.ndjson
```

Scope note: use `--allow-hosts` to capture only matching hosts.

Scope note: use `--deny-hosts` to exclude noisy or third-party hosts.

Scope note: use `--policy <file>` to load a JSON scope policy.

Cleanup note: use `--keep-days <N>` to retain recent captures.

Cleanup note: use `--keep-size <SIZE>` to cap retained data volume.

Cleanup note: use `--secure` to shred files during deletion.

Help note: run `./scripts/capture-session.sh --help` for full CLI reference.

Path note: use `-d, --dir <path>` to select working directory.

Port note: use `-P, --port <port>` to change proxy listener port.

Then confirm these artifacts exist:

- `captures/latest.flow`
- `captures/latest.har`
- `captures/latest.log`
- `captures/latest.index.ndjson`
- `captures/latest.summary.md`
- `captures/latest.ai.json`
- `captures/latest.ai.md`
- `captures/latest.ai.bundle.txt`
- `captures/latest.manifest.json`
- `captures/latest.scope_audit.json`
- `captures/latest.navigation.ndjson`

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
./scripts/release-check.sh
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
