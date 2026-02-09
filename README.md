<p align="center">
  <img src="https://raw.githubusercontent.com/dtamade/fafafa-skills-capture-analytics/main/assets/logo.png" alt="Capture Analytics Logo" width="120" height="120">
</p>

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
  <a href="#security">Security</a> |
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
- **Security First** - Authorization confirmation, data sanitization, scope control
- **Cross-platform** - Linux (GNOME), macOS, and manual proxy mode
- **Comprehensive Analysis** - Performance, security, debugging, and API discovery
- **120 Test Cases** - Robust test coverage (79 Python + 41 Shell)

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

### Install as User-Level Skill

```bash
# Clone to skills directory
git clone https://github.com/dtamade/fafafa-skills-capture-analytics.git \
  ~/.claude/skills/capture-analytics

# Or symlink from existing location
ln -s /path/to/capture-analytics ~/.claude/skills/capture-analytics
```

### Install as Project-Level Skill

```bash
# In your project directory
mkdir -p .claude/skills
git clone https://github.com/dtamade/fafafa-skills-capture-analytics.git \
  .claude/skills/capture-analytics
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
1. Ask for authorization confirmation (security check)
2. Start mitmproxy capture
3. Open browser via Playwright
4. Navigate and explore the site
5. Stop capture and process data
6. Present analysis findings

### Smart Input Collection

The skill intelligently extracts information from your request:

| You Say | AI Understands |
|---------|----------------|
| "Analyze example.com performance" | URL=example.com, Goal=performance |
| "Check mysite.com, I have permission" | URL=mysite.com, Auth=confirmed |
| "Start capture" | AI asks for URL and authorization |

### Manual Mode

```bash
# Start capture (requires authorization confirmation)
./scripts/capture-session.sh start https://example.com \
  --confirm YES_I_HAVE_AUTHORIZATION

# (Operate browser manually with proxy at 127.0.0.1:18080)

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

### Commands Reference

```bash
capture-session.sh start <url>      # Start capture (requires --confirm)
capture-session.sh stop             # Stop capture and generate analysis
capture-session.sh status           # Check if capture is running
capture-session.sh validate <url>   # Validate URL format and reachability
capture-session.sh analyze          # Generate AI analysis bundle
capture-session.sh doctor           # Check environment prerequisites
scripts/git-doctor.sh               # Diagnose git sync/auth/connectivity
capture-session.sh cleanup          # Clean up old capture sessions
capture-session.sh diff <a> <b>     # Compare two capture sessions
```

## Output Files

After capture, you'll find these files:

| File | Description |
|------|-------------|
| `captures/latest.flow` | Raw mitmproxy capture |
| `captures/latest.har` | HAR 1.2 archive |
| `captures/latest.index.ndjson` | Per-request structured index |
| `captures/latest.summary.md` | Quick statistics |
| `captures/latest.ai.json` | Structured analysis input |
| `captures/latest.ai.md` | AI-friendly brief |

## Five-Phase Workflow

```
Phase 1: RECON      → Understand target and choose strategy
Phase 2: CAPTURE    → Start mitmproxy (scripts/startCaptures.sh)
Phase 3: EXPLORE    → Browse with Playwright through proxy
Phase 4: HARVEST    → Stop capture (scripts/stopCaptures.sh)
Phase 5: ANALYZE    → Read outputs, generate report
```

## Security

### Authorization Required

- Capture requires explicit authorization: `--confirm YES_I_HAVE_AUTHORIZATION`
- AI must confirm authorization before starting capture
- Direct invocation of internal scripts is blocked

### Sensitive Data Protection

- Sensitive data (tokens, passwords, cookies) is automatically sanitized
- Sanitization is **fail-closed**: if sanitize module fails, capture aborts
- Use `--allow-no-sanitize` only in controlled test environments

### Scope Control

- Use `--allow-hosts` or `--policy` to restrict capture scope
- Default: auto-generates scope from target URL domain
- Out-of-scope traffic is logged to `*.scope_audit.json`

### Private Network Protection

- URL validation blocks private/loopback IPs by default
- Use `--allow-private` to override (for local development)

See [SECURITY_GUIDELINES.md](references/SECURITY_GUIDELINES.md) for full details.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Missing command: mitmdump` | mitmproxy not installed | `pip install mitmproxy` |
| `Port is already in use: 18080` | Another capture running | `./scripts/stopCaptures.sh` or use `-P <port>` |
| `Found stale state file` | Previous capture crashed | `./scripts/startCaptures.sh --force-recover` |
| HAR status: `failed` | mitmdump HAR export error | Try `--har-backend python` |

## Project Structure

```
capture-analytics/
├── SKILL.md                    # Main skill file
├── skill-rules.json            # Trigger configuration
├── install.sh                  # Environment check & installer
├── requirements.txt            # Python dependencies
├── scripts/                    # Shell & Python scripts
│   ├── capture-session.sh      # Unified entry point
│   ├── startCaptures.sh        # Start mitmproxy
│   ├── stopCaptures.sh         # Stop & process pipeline
│   └── ...                     # Analysis utilities
├── references/                 # Detailed documentation
├── templates/                  # Report templates
└── tests/                      # Test suite (120 tests)
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
