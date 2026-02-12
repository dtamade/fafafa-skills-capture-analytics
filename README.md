<h1 align="center">Capture Analytics</h1>

<p align="center">
  <strong>AI-driven autonomous network traffic capture and deep analysis skill for Claude Code</strong>
</p>

<p align="center">
  <a href="https://github.com/dtamade/fafafa-skills-capture-analytics/actions"><img src="https://img.shields.io/github/actions/workflow/status/dtamade/fafafa-skills-capture-analytics/ci.yml?branch=main&style=flat-square&logo=github" alt="CI Status"></a>
  <a href="https://github.com/dtamade/fafafa-skills-capture-analytics/releases"><img src="https://img.shields.io/github/v/release/dtamade/fafafa-skills-capture-analytics?style=flat-square&logo=github" alt="Release"></a>
  <a href="https://github.com/dtamade/fafafa-skills-capture-analytics/blob/main/LICENSE"><img src="https://img.shields.io/github/license/dtamade/fafafa-skills-capture-analytics?style=flat-square" alt="License"></a>
  <a href="https://github.com/dtamade/fafafa-skills-capture-analytics"><img src="https://img.shields.io/github/stars/dtamade/fafafa-skills-capture-analytics?style=flat-square&logo=github" alt="Stars"></a>
</p>

<p align="center">
  <a href="#features">Features</a> |
  <a href="#quick-start">Quick Start</a> |
  <a href="#installation">Installation</a> |
  <a href="#usage">Usage</a> |
  <a href="docs/release-checklist.md">Release Checklist</a> |
  <a href="README_CN.md">中文文档</a>
</p>

---

## What is Capture Analytics?

Capture Analytics is a Claude Code skill that empowers AI to **autonomously** capture and analyze network traffic. Unlike traditional tools that require manual operation, this skill enables the AI to:

1. **Start** mitmproxy to intercept HTTP/HTTPS/WebSocket traffic
2. **Drive** Playwright browser to navigate target websites
3. **Process** captured data through an automated pipeline
4. **Analyze** structured output and generate comprehensive reports

**This is not just documentation** — it's an **action-oriented skill** that lets AI execute the complete capture-analyze workflow end-to-end.

## Features

- **Autonomous Capture** - AI-driven traffic interception using mitmproxy
- **Smart Browser Automation** - Playwright-powered website exploration
- **Intelligent Input Collection** - Extracts URLs and goals from natural language
- **Multi-format Output** - HAR, NDJSON index, AI-friendly briefs
- **Scope Control** - Restrict capture to specific hosts
- **Cross-platform** - Linux (GNOME), macOS, and manual proxy mode
- **Comprehensive Analysis** - Performance, security, debugging, and API discovery

## Quick Start

```bash
# 1. Verify environment (no changes made)
./install.sh --check

# 2. Install dependencies (if needed)
./install.sh

# 3. Tell Claude Code:
#    "Capture and analyze traffic from https://example.com"
#    or: "帮我分析 https://example.com 的网络请求"
```

That's it. Claude handles the rest: start proxy, drive browser, stop capture, analyze results.

## Installation

### Prerequisites

- Python 3.8+
- mitmproxy 10.0+
- Bash 4.0+
- Claude Code with Playwright MCP

```bash
# Install mitmproxy
pip install mitmproxy

# Verify installation
mitmdump --version
python3 -c "from mitmproxy.io import FlowReader; print('OK')"
```

### Install as User-Level Skill (Recommended)

```bash
# Clone repository anywhere
git clone https://github.com/dtamade/fafafa-skills-capture-analytics.git \
  ~/src/fafafa-skills-capture-analytics
cd ~/src/fafafa-skills-capture-analytics

# Dependency diagnosis
./install.sh --check
./install.sh --doctor

# Install skill as LOCAL COPY (default, no external symlink dependency)
./install.sh --install-to ~/.claude/skills/capture-analytics
```

Optional (external dependency mode):

```bash
# Only if you explicitly want linked mode
./install.sh --symlink --install-to ~/.claude/skills/capture-analytics
```

### Install as Project-Level Skill

```bash
# Install into project-scoped .claude/skills
./install.sh --install-to /path/to/your-project/.claude/skills/capture-analytics
```

### Supported Platforms

| Platform | Proxy Backend | Notes |
|----------|---------------|-------|
| Linux (GNOME) | gsettings | Auto-detected |
| macOS | networksetup | Auto-detected |
| Any (program mode) | None | Use `--program` flag; configure proxy manually |

## Usage

### AI-Driven Mode (Recommended)

Simply tell Claude Code what you want to analyze:

```
"Analyze the network requests from https://example.com"
"帮我分析 https://api.example.com 的性能问题"
"Capture traffic and find slow API calls on https://mysite.com"
```

Claude will:
1. Start mitmproxy capture
2. Open browser via Playwright
3. Navigate and explore the site
4. Stop capture and process data
5. Present analysis findings

### Smart Input Collection

The skill intelligently extracts information from your request:

| You Say | AI Understands |
|---------|----------------|
| "Analyze example.com performance" | URL=example.com, Goal=performance |
| "抓包 localhost:3000" | URL=https://localhost:3000 |
| "分析 192.168.1.1 的请求" | URL=https://192.168.1.1 |

### Manual Mode

```bash
# Start capture
./scripts/capture-session.sh start https://example.com

# (Operate browser manually with proxy at 127.0.0.1:18080)

# Stop and analyze
./scripts/capture-session.sh stop
```

### Program Mode (Non-Browser Traffic)

```bash
# Start capture
./scripts/capture-session.sh start https://example.com

# Run target program with temporary proxy env vars
./scripts/runWithProxyEnv.sh -P 18080 -- <your_program_command>

# Stop and analyze
./scripts/capture-session.sh stop
```

### With Scope Control

```bash
# Only capture traffic to specific hosts
./scripts/capture-session.sh start https://example.com \
  --allow-hosts "example.com,*.example.com"
```

### Custom Dir/Port Examples

```bash
# Use a custom working directory
capture-session.sh start https://example.com -d /tmp/capture-demo

# Use a custom proxy port
capture-session.sh start https://example.com -P 28080
```

### Navlog Example

```bash
capture-session.sh navlog append --action navigate --url "https://example.com"
# Alternative equals syntax (more robust in some shells)
capture-session.sh navlog append --action navigate --url "https://example.com"
```

### Help Command

```bash
capture-session.sh --help
```

### Commands Reference

```bash
capture-session.sh start <url>      # Start capture
capture-session.sh stop             # Stop capture and generate analysis
capture-session.sh status           # Check if capture is running
capture-session.sh progress         # Show capture progress (requests, size, duration)
capture-session.sh analyze          # Generate AI analysis bundle
capture-session.sh doctor           # Check environment prerequisites
capture-session.sh cleanup          # Clean up old capture sessions
capture-session.sh diff <a> <b>     # Compare two capture sessions
capture-session.sh navlog <cmd>     # Manage navigation log (init/append/show)
```

### Global Options

- `-d, --dir <path>` set a custom working directory for capture artifacts
- `-P, --port <port>` set a custom proxy port (default 18080)
- `-h, --help` show CLI help and available commands
- `--force-recover` clean stale state file before start

### Cleanup Options

- `--keep-days <N>` keep recent capture days
- `--keep-size <SIZE>` cap retained capture size
- `--secure` securely delete old files
- `--dry-run` preview cleanup changes only

### Cleanup Command Examples

```bash
capture-session.sh cleanup --keep-days 7
capture-session.sh cleanup --keep-size 1G --dry-run
capture-session.sh cleanup --secure --keep-days 3
```

## Output Files

After capture, you'll find these files:

| File | Description |
|------|-------------|
| `captures/latest.flow` | Raw mitmproxy capture |
| `captures/latest.har` | HAR 1.2 archive |
| `captures/latest.log` | Capture runtime log for troubleshooting |
| `captures/latest.index.ndjson` | Per-request structured index |
| `captures/latest.summary.md` | Quick statistics |
| `captures/latest.ai.json` | Structured analysis input |
| `captures/latest.ai.md` | AI-friendly brief |
| `captures/latest.ai.bundle.txt` | Consolidated AI-ready text bundle |
| `captures/latest.manifest.json` | Session manifest metadata |
| `captures/latest.scope_audit.json` | Out-of-scope traffic audit report |
| `captures/latest.navigation.ndjson` | Browser navigation event log |

## Five-Phase Workflow

```
Phase 1: RECON      → Understand target and choose strategy
Phase 2: CAPTURE    → Start capture-session wrapper (capture-session.sh start)
Phase 3: EXPLORE    → Browse with Playwright through proxy
Phase 4: HARVEST    → Stop capture-session wrapper (capture-session.sh stop)
Phase 5: ANALYZE    → Read outputs, generate report
```

## Scope Control

- Use `--allow-hosts` or `--deny-hosts` to restrict capture scope
- Default: auto-generates scope from target URL domain
- Out-of-scope traffic is logged to `*.scope_audit.json`
- Use `--policy <file>` to load a custom JSON scope policy

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Missing command: mitmdump` | mitmproxy not installed | `pip install mitmproxy` |
| `Port is already in use: 18080` | Another capture running | `capture-session.sh stop` or use `-P <port>` |
| `Found stale state file` | Previous capture crashed | `capture-session.sh start https://example.com --force-recover` |
| HAR status: `failed` | mitmdump HAR export error | Try `--har-backend python` |
| `Looks like you launched a headed browser without having a XServer running` | Headed Playwright in non-GUI environment | Retry in headless mode or run with `xvfb-run`; fallback to program mode helper |

## Project Structure

```
capture-analytics/
├── SKILL.md                    # Main skill file
├── skill-rules.json            # Trigger configuration
├── install.sh                  # Environment check & installer
├── requirements.txt            # Python dependencies
├── scripts/                    # Shell & Python scripts
│   ├── capture-session.sh      # Unified entry point
│   ├── release-check.sh        # One-command release readiness check
│   ├── startCaptures.sh        # Start mitmproxy
│   ├── stopCaptures.sh         # Stop & process pipeline
│   ├── doctor.sh               # Environment diagnostics
│   ├── cleanupCaptures.sh      # Capture retention cleanup
│   ├── navlog.sh               # Navigation log helper
│   ├── runWithProxyEnv.sh      # Run command with temporary proxy env vars
│   ├── diff_captures.py        # Capture index diff utility
│   ├── policy.py               # Scope policy helper
│   ├── analyzeLatest.sh        # Generate latest analysis outputs
│   ├── ai.sh                   # AI bundle shortcut command
│   ├── flow2har.py             # Convert flow to HAR
│   ├── flow_report.py          # Build index and summary
│   ├── ai_brief.py             # Build AI analysis brief
│   └── scope_audit.py          # Scope audit report generator
├── references/                 # Detailed documentation
├── templates/                  # Report templates
└── tests/                      # Test suite
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md) before submitting issues or pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

- **QQ Group**: 685403987
- **Email**: dtamade@gmail.com
- **Studio**: fafafa studio
- **GitHub Issues**: [Report a bug](https://github.com/dtamade/fafafa-skills-capture-analytics/issues)

---

<p align="center">
  Made with care by <a href="https://github.com/dtamade">dtamade</a> · fafafa studio
</p>
