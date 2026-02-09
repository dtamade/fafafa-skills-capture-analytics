# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Professional open-source documentation (README, CONTRIBUTING, CODE_OF_CONDUCT)
- Chinese documentation (README_CN.md, CONTRIBUTING_CN.md)
- GitHub issue and PR templates
- MIT License

## [0.2.0] - 2025-02-10

### Added
- Smart input collection - AI extracts URLs and goals from natural language
- URL validation with reachability check (`capture-session.sh validate`)
- Pre-flight checklist for AI to confirm required information
- Comprehensive security guidelines documentation

### Changed
- Updated SKILL.md with intelligent input extraction rules
- README now reflects all new features and security measures

### Security
- Address Codex security review findings
- Input validation improvements throughout

## [0.1.0] - 2025-02-09

### Added
- Initial release of capture-analytics skill
- Five-phase workflow: RECON, CAPTURE, EXPLORE, HARVEST, ANALYZE
- mitmproxy-based traffic capture
- Playwright browser automation support
- Multiple output formats: HAR, NDJSON index, AI-friendly briefs
- Unified entry point: `capture-session.sh`
- Environment checker: `install.sh` and `doctor.sh`
- Scope control with `--allow-hosts` and `--policy` options
- Sensitive data sanitization (fail-closed behavior)
- Private network protection (blocks loopback/private IPs by default)
- Navigation logging with `navlog.sh`
- Capture comparison with `diff_captures.py`
- Cleanup utility with retention policies
- Cross-platform support: Linux (GNOME), macOS, program mode
- 120 test cases (79 Python + 41 Shell)

### Security
- Authorization confirmation required for all captures
- Automatic sensitive data sanitization
- Scope control to restrict captured traffic
- Private network protection
- Secure deletion support with `--secure` flag

### Fixed
- Cross-platform compatibility (flock, sha256, shred alternatives)
- Pickle path validation
- Eval injection guards
- File descriptor leak prevention
- Timezone handling
- Resource limits enforcement

## Types of Changes

- `Added` for new features
- `Changed` for changes in existing functionality
- `Deprecated` for soon-to-be removed features
- `Removed` for now removed features
- `Fixed` for any bug fixes
- `Security` for vulnerability fixes

[Unreleased]: https://github.com/dtamade/fafafa-skills-capture-analytics/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/dtamade/fafafa-skills-capture-analytics/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dtamade/fafafa-skills-capture-analytics/releases/tag/v0.1.0
