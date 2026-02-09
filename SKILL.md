---
name: capture-analytics
description: >
  Autonomous network traffic capture and analysis skill. Lets AI self-drive
  mitmproxy + Playwright to capture, explore, and analyze HTTP/HTTPS/WebSocket
  traffic from any target URL. Triggers on keywords: capture, traffic analysis,
  packet capture, mitmproxy, HTTP analysis, request analysis, network analysis,
  performance analysis, security analysis, HAR, replay, compare requests,
  website analysis, API analysis, debug network, slow requests, error requests.
  Chinese triggers: 抓包, 流量分析, 网络分析, 请求分析, 协议分析, 性能分析,
  安全分析, 网站分析, 接口分析, 请求重放, 流量对比, 网络调试.
---

# Capture Analytics

> AI-driven autonomous network traffic capture and deep analysis.

## ⚠️ CRITICAL: Pre-flight Checklist

**STOP. Before executing ANY capture command, AI MUST confirm these items:**

| Required Info | How to Get It | Default If Missing |
|---------------|---------------|-------------------|
| **Target URL** | Ask user: "请提供要分析的目标 URL" | ❌ **MUST ASK** - never guess |
| **Analysis Goal** | Ask: "分析目的是什么？(性能/安全/调试/API发现/通用)" | `general` |
| **Scope Restriction** | Ask if URL looks like internal/enterprise site | Auto-generate from domain |
| **Authorization** | User must confirm they have permission to capture | ❌ **MUST CONFIRM** |

**If user says vague things like "帮我抓包" or "analyze traffic":**
```
AI MUST respond:
"好的，我可以帮你进行网络流量抓包分析。请告诉我：
1. 目标 URL 是什么？
2. 分析目的是什么？（性能分析/安全检查/API发现/调试错误/通用分析）
3. 你是否有权限对该网站进行流量捕获？"
```

**NEVER:**
- Guess or assume a URL
- Start capture without explicit URL from user
- Proceed without authorization confirmation

---

## Purpose

This skill gives Claude Code the ability to **autonomously** capture and analyze
network traffic. Instead of just providing guidance, the AI itself:

1. Starts mitmproxy to intercept traffic
2. Drives Playwright browser through the target site
3. Stops capture and processes the data pipeline
4. Reads and analyzes the structured output
5. Generates comprehensive reports

## Prerequisites

- `mitmproxy` installed (`pip install mitmproxy` or system package)
- `python3` with mitmproxy Python bindings
- Playwright MCP server connected (for browser exploration)
- Bash shell environment

Verify with:
```bash
which mitmdump && mitmdump --version
python3 -c "from mitmproxy import io; print('OK')"
```

## Five-Phase Workflow

### Phase 1: RECON (Reconnaissance)

Understand the user's goal before touching anything.

**AI Actions:**
1. Clarify target URL(s) and scope
2. Determine analysis focus (performance / security / debugging / general)
3. Choose exploration strategy (see [BROWSER_EXPLORATION.md](references/BROWSER_EXPLORATION.md))
4. Check prerequisites (mitmproxy installed? Playwright available?)

**Decision Matrix:**

| User Says | Focus | Strategy |
|-----------|-------|----------|
| "分析这个网站的性能" | Performance | Full-site crawl, measure timings |
| "看看这个API有什么请求" | API Discovery | Navigate key flows, catalog endpoints |
| "检查安全问题" | Security | Probe forms, check headers, test inputs |
| "调试这个页面的错误" | Debugging | Target specific page, capture errors |
| "对比两次部署的差异" | Comparison | Capture twice, diff results |

### Phase 2: CAPTURE (Start Interception)

**AI executes:**
```bash
SKILL_DIR="$(dirname "$(readlink -f "$0")")"  # or known install path
"${SKILL_DIR}/scripts/capture-session.sh" start https://example.com -d "${WORKDIR}"
```

Or with explicit scope control:
```bash
"${SKILL_DIR}/scripts/startCaptures.sh" --program -d "${WORKDIR}" \
    --allow-hosts "example.com,*.example.com"
```

Key flags:
- `--program` — proxy mode only, does NOT modify system proxy
- `-d <dir>` — output directory for capture files
- `-P <port>` — custom port (default 18080)
- `--allow-hosts <list>` — restrict capture to these hosts (comma-separated, supports *)
- `--deny-hosts <list>` — always ignore these hosts (takes precedence)
- `--policy <file>` — JSON policy file for complex scope rules

**Scope Control (Security):**
By default, capture-session.sh auto-generates a scope from the target URL domain.
This prevents capturing traffic from unrelated domains (e.g., analytics, auth providers).

After starting, the proxy is at `127.0.0.1:18080`.

### Phase 3: EXPLORE (Browser Automation)

Connect Playwright to browse **through the proxy**.

**Setup proxy in Playwright:**
The AI should use `browser_navigate` and other Playwright MCP tools while
the system proxy or browser proxy is configured to route through mitmproxy.

**Exploration Strategies** (see [BROWSER_EXPLORATION.md](references/BROWSER_EXPLORATION.md)):

| Strategy | When | Actions |
|----------|------|---------|
| `full-crawl` | General analysis | Visit homepage → follow links → interact |
| `targeted-flow` | Specific user journey | Login → navigate → submit form → verify |
| `api-discovery` | API mapping | Visit pages, trigger AJAX, catalog endpoints |
| `performance-probe` | Performance | Rapid navigation, parallel requests |
| `manual-assist` | Complex scenarios | Start capture, let user operate, then analyze |

**Exploration Loop:**
```
1. Navigate to target URL
2. Take snapshot → analyze page structure
3. Identify interactive elements (links, buttons, forms)
4. Click/navigate based on strategy
5. Wait for network activity to settle
6. Repeat 2-5 for depth/breadth coverage
7. Record navigation path for report
```

### Phase 4: HARVEST (Stop & Process)

**AI executes:**
```bash
"${SKILL_DIR}/scripts/stopCaptures.sh" -d "${WORKDIR}"
```

This triggers the full data pipeline:
```
capture.flow → HAR conversion
             → Index (NDJSON) + Summary (Markdown)
             → AI Brief (JSON + Markdown)
             → latest.* symlinks
```

**Output Files:**

| File | Format | Use |
|------|--------|-----|
| `*.flow` | mitmproxy binary | Raw immutable capture |
| `*.har` | HAR 1.2 JSON | Standard HTTP archive |
| `*.index.ndjson` | NDJSON | Per-request index records |
| `*.summary.md` | Markdown | Quick statistics overview |
| `*.ai.json` | JSON | Structured analysis input |
| `*.ai.md` | Markdown | AI-friendly brief |
| `*.manifest.json` | JSON | Session metadata |
| `*.scope_audit.json` | JSON | Out-of-scope traffic report |

### Phase 5: ANALYZE (Deep Analysis)

**AI reads and analyzes** the output files.

**Analysis Order:**
1. Read `latest.summary.md` — get the big picture
2. Read `latest.ai.json` — structured stats with findings
3. Drill into `latest.har` for specific requests (use Read tool with line offsets)
4. Cross-reference with navigation path from Phase 3

**Analysis Dimensions:**

#### Performance Analysis
- Identify p95/p99 latency outliers
- Group slow requests by endpoint
- Calculate time-to-first-byte patterns
- Identify sequential vs parallel request chains
- Detect unnecessary redirects

#### Security Analysis
- Check for missing security headers (CSP, HSTS, X-Frame-Options)
- Identify sensitive data in URLs (tokens, passwords in query strings)
- Detect mixed content (HTTP resources on HTTPS pages)
- Flag unencrypted API calls
- Identify CORS misconfigurations

#### Traffic Patterns
- Top hosts by request count
- Request method distribution
- Content type breakdown
- Error rate by endpoint
- Request size distribution

#### Debugging
- Isolate failed requests (4xx/5xx)
- Trace request chains (redirects, dependent calls)
- Compare request/response headers
- Identify missing or malformed responses

See [ANALYSIS_PATTERNS.md](references/ANALYSIS_PATTERNS.md) for detailed strategies.

## Quick Commands

### One-shot Analysis
User: "帮我分析 https://example.com 的网络请求"
→ AI runs all 5 phases automatically

### Manual Capture Mode
User: "开始抓包，我自己操作浏览器"
→ AI runs Phase 2, waits, then Phase 4-5 when user says "停止"

### Re-analyze Existing Capture
User: "分析 captures/ 目录下的抓包数据"
→ AI skips to Phase 5, reads existing files

### Compare Two Captures
User: "对比这两次抓包的差异"
→ AI reads two sets of data, generates comparison report

## Report Template

See [templates/analysis-report.md](templates/analysis-report.md) for the output format.

Reports include:
- Executive summary (1-2 sentences)
- Key findings (prioritized list)
- Performance metrics table
- Security observations
- Detailed request analysis (top issues)
- Recommendations

## Security Boundaries

See [SECURITY_GUIDELINES.md](references/SECURITY_GUIDELINES.md).

**Critical Rules:**
- ONLY capture traffic from URLs the user explicitly authorizes
- NEVER capture credentials or replay authenticated requests without consent
- NEVER use capture data to attack or exploit targets
- ALWAYS inform the user what will be captured before starting
- Sanitize sensitive data (tokens, passwords) in reports

## File Structure

```
fafafa-skills-capture-analytics/
├── SKILL.md                           # This file
├── skill-rules.json                   # Trigger configuration
├── references/
│   ├── CAPTURE_OPERATIONS.md          # Detailed capture operations
│   ├── ANALYSIS_PATTERNS.md           # Analysis strategies & patterns
│   ├── BROWSER_EXPLORATION.md         # Playwright exploration guide
│   └── SECURITY_GUIDELINES.md         # Security & compliance
├── scripts/
│   ├── startCaptures.sh               # Start mitmproxy capture
│   ├── stopCaptures.sh                # Stop capture & process pipeline
│   ├── analyzeLatest.sh               # Generate AI analysis bundle
│   ├── ai.sh                          # Quick analysis entry point
│   ├── capture-session.sh             # One-shot capture session
│   ├── flow2har.py                    # Flow → HAR converter
│   ├── flow_report.py                 # Index & summary generator
│   └── ai_brief.py                    # AI analysis brief builder
└── templates/
    ├── analysis-report.md             # Report output template
    └── exploration-strategies.json    # Pre-built exploration configs
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `mitmdump: command not found` | `pip install mitmproxy` or install via system package manager |
| Port 18080 already in use | Use `-P <other-port>` flag or stop existing process |
| Playwright can't connect through proxy | Ensure mitmproxy CA cert is trusted, or use `--ignore-https-errors` |
| HAR conversion fails | Script falls back to Python converter automatically |
| Empty capture (0 requests) | Check proxy routing — Playwright must be configured to use the proxy |
| Permission denied on scripts | Run `chmod +x scripts/*.sh` |
