# capture-analytics

> AI-driven autonomous network traffic capture and deep analysis skill for Claude Code.

## What is this?

A Claude Code skill that gives AI the ability to **autonomously** capture and analyze network traffic. The AI can:

1. Start mitmproxy to intercept HTTP/HTTPS traffic
2. Drive Playwright browser through target websites
3. Stop capture and process the data pipeline
4. Read and analyze the structured output
5. Generate comprehensive analysis reports

**This is not just documentation** — it's an **action-oriented skill** that lets AI execute the full capture-analyze workflow.

## Quick Success Path

```bash
# 1. Verify environment (no changes made)
./install.sh --check

# 2. Install dependencies (if needed)
./install.sh

# 3. Tell Claude Code:
#    "帮我分析 https://example.com 的网络请求"
#    or: "Capture and analyze traffic from https://api.example.com"
```

That's it. Claude handles the rest: start proxy, drive browser, stop capture, analyze results.

## Prerequisites

```bash
# mitmproxy (required)
pip install mitmproxy
# or: apt install mitmproxy / brew install mitmproxy

# Verify installation
mitmdump --version
python3 -c "from mitmproxy.io import FlowReader; print('OK')"

# Or use the built-in checker
./install.sh --check
```

### Supported Platforms

| Platform | Proxy Backend | Notes |
|----------|---------------|-------|
| Linux (GNOME) | gsettings | Auto-detected |
| macOS | networksetup | Auto-detected |
| Any (program mode) | None | Use `--program` flag; configure proxy manually |

## Quick Start

### For Users (AI-Driven)

Tell Claude Code something like:
- "帮我分析 https://example.com 的网络请求"
- "Capture and analyze traffic from https://api.example.com"
- "抓包看看这个网站的性能问题"

Claude will:
1. Ask for confirmation (security check)
2. Start mitmproxy capture
3. Open browser via Playwright
4. Navigate and explore the site
5. Stop capture and analyze
6. Present findings

### Manual Mode

```bash
# Start capture
./scripts/capture-session.sh start https://example.com

# (User operates browser manually with proxy 127.0.0.1:18080)

# Stop and analyze
./scripts/capture-session.sh stop
```

### With Scope Control

```bash
# Only capture traffic to specific hosts
./scripts/capture-session.sh start https://example.com \
  --allow-hosts "example.com,*.example.com"

# Or use a policy file
./scripts/capture-session.sh start https://example.com \
  --policy config/policy.json
```

## Installation

### Quick Install

```bash
# Clone and install
git clone https://github.com/your-repo/fafafa-skills-capture-analytics.git
cd fafafa-skills-capture-analytics
./install.sh
```

### As User-Level Skill

```bash
# Clone to skills directory
git clone https://github.com/your-repo/fafafa-skills-capture-analytics.git \
  ~/.claude/skills/capture-analytics

# Or symlink from project
ln -s /path/to/fafafa-skills-capture-analytics ~/.claude/skills/capture-analytics
```

### As Project-Level Skill

```bash
# In your project
mkdir -p .claude/skills
git clone https://github.com/your-repo/fafafa-skills-capture-analytics.git \
  .claude/skills/capture-analytics
```

## File Structure

```
fafafa-skills-capture-analytics/
├── SKILL.md                    # Main skill file (< 500 lines)
├── skill-rules.json            # Trigger configuration
├── install.sh                  # Environment check & dependency installer
├── requirements.txt            # Python dependencies
├── references/
│   ├── CAPTURE_OPERATIONS.md   # Capture operation details
│   ├── ANALYSIS_PATTERNS.md    # Analysis strategies
│   ├── BROWSER_EXPLORATION.md  # Playwright exploration guide
│   └── SECURITY_GUIDELINES.md  # Security & compliance
├── scripts/
│   ├── startCaptures.sh        # Start mitmproxy
│   ├── stopCaptures.sh         # Stop & process pipeline
│   ├── proxy_utils.sh          # Cross-platform proxy management
│   ├── capture-session.sh      # One-shot wrapper (start/stop/status/analyze/doctor/cleanup/diff/navlog)
│   ├── analyzeLatest.sh        # Generate AI bundle from latest capture
│   ├── ai.sh                   # Quick analysis entry point
│   ├── doctor.sh               # Environment self-check
│   ├── cleanupCaptures.sh      # Manage capture data lifecycle
│   ├── cleanup.py              # Cleanup logic (Python)
│   ├── navlog.sh               # Browser navigation event logger
│   ├── diff_captures.py        # Compare two capture sessions
│   ├── flow2har.py             # Flow → HAR converter
│   ├── flow_report.py          # Index & summary generator
│   ├── ai_brief.py             # AI brief builder
│   ├── policy.py               # Scope policy compiler
│   ├── scope_audit.py          # Out-of-scope traffic detector
│   └── sanitize.py             # Sensitive data sanitizer
├── templates/
│   ├── analysis-report.md      # Report template
│   └── exploration-strategies.json
└── tests/
    ├── test_rules.py           # Trigger rule tests
    ├── test_cleanup.py         # Cleanup logic tests
    ├── test_doctor.sh          # Doctor self-check tests
    ├── test_install.sh         # Install script tests
    ├── test_navlog.sh          # Navigation log tests
    └── test_read_kv.sh         # Key-value parser tests
```

## Five-Phase Workflow

```
Phase 1: RECON      → Understand target and choose strategy
Phase 2: CAPTURE    → Start mitmproxy (scripts/startCaptures.sh)
Phase 3: EXPLORE    → Browse with Playwright through proxy
Phase 4: HARVEST    → Stop capture (scripts/stopCaptures.sh)
Phase 5: ANALYZE    → Read outputs, generate report
```

## Output Files

After capture:

| File | Description |
|------|-------------|
| `captures/latest.flow` | Raw mitmproxy capture |
| `captures/latest.har` | HAR 1.2 archive |
| `captures/latest.index.ndjson` | Per-request structured index |
| `captures/latest.summary.md` | Quick statistics |
| `captures/latest.ai.json` | Structured analysis input |
| `captures/latest.ai.md` | AI-friendly brief |
| `captures/latest.navigation.ndjson` | Browser navigation events |
| `captures/latest.manifest.json` | Session metadata and artifact paths |

## Commands Reference

### capture-session.sh (Unified Entry)

```bash
capture-session.sh start <url>      # Start capture for target URL
capture-session.sh stop             # Stop capture and generate analysis
capture-session.sh status           # Check if capture is running
capture-session.sh analyze          # Generate AI analysis bundle
capture-session.sh doctor           # Check environment prerequisites
capture-session.sh cleanup          # Clean up old capture sessions
capture-session.sh diff <a> <b>     # Compare two capture index files
capture-session.sh navlog <cmd>     # Manage navigation log (init/append/show)
```

### Standalone Scripts

```bash
# Start/stop
./scripts/startCaptures.sh [--program] [-P port] [--allow-hosts "..."]
./scripts/stopCaptures.sh [--har-backend auto|mitmdump|python]

# Maintenance
./scripts/doctor.sh [--json] [--strict]
./scripts/cleanupCaptures.sh [--keep-days 7] [--keep-size 500M] [--dry-run]

# Analysis
./scripts/analyzeLatest.sh
./scripts/ai.sh

# Navigation logging
./scripts/navlog.sh init
./scripts/navlog.sh append --action navigate --url "https://example.com"
./scripts/navlog.sh show

# Diff two captures
python3 scripts/diff_captures.py captures/a.index.ndjson captures/b.index.ndjson
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Missing command: mitmdump` | mitmproxy not installed | `pip install mitmproxy` or `brew install mitmproxy` |
| `Port is already in use: 18080` | Another capture running or port conflict | `./scripts/stopCaptures.sh` or use `-P <port>` |
| `Another capture operation is running` | Lock file held | Wait for other operation, or check stale locks |
| `Found stale state file` | Previous capture crashed | `./scripts/startCaptures.sh --force-recover` |
| HAR status: `failed` | mitmdump HAR export error | Try `--har-backend python` |
| Index status: `missing-mitmproxy-module` | Python mitmproxy not importable | `pip install mitmproxy` |
| Index status: `missing-tool` | flow_report.py not found | Reinstall or check scripts/ directory |
| Scope audit: `violation` | Out-of-scope traffic detected | Review `*.scope_audit.json`, tighten `--allow-hosts` |
| Proxy not restored | Stop script failed midway | Manually reset system proxy or run `stopCaptures.sh` again |
| `No supported proxy backend found` | No gsettings (Linux) or networksetup (macOS) | Use `--program` mode and set proxy manually |

## Security

- Only capture traffic from **authorized** targets
- Never capture credentials without explicit consent
- Use `--allow-hosts` or `--policy` to restrict capture scope
- Use `--secure` flag in cleanup for shred-based deletion
- Sanitize sensitive data before sharing reports
- See [SECURITY_GUIDELINES.md](references/SECURITY_GUIDELINES.md)

## Triggers

The skill activates on keywords like:
- 抓包, 流量分析, 网络分析, 性能分析, 安全分析
- capture, traffic analysis, mitmproxy, HAR
- debug network, slow requests, API analysis
- websocket, tls, ssl

## Contributing

Issues and PRs welcome!

## License

MIT
