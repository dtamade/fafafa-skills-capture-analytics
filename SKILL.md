---
name: capture-analytics
description: >
  AI-driven network traffic capture and analysis using mitmproxy/mitmdump + Playwright.
  Triggers on 抓包/流量捕获/网络抓包, HAR 文件分析, websocket/ws 流量, TLS/SSL 分析,
  request replay/流量对比, and API discovery or network debugging requests.
---

# Capture Analytics

> AI-driven autonomous network traffic capture and deep analysis.

## Smart URL Extraction

AI 会自动从用户消息中提取 URL：
- "帮我分析 example.com" → URL = https://example.com
- "抓包 http://localhost:3000" → URL = http://localhost:3000
- "看看 192.168.1.1 的请求" → URL = http://192.168.1.1

**Analysis Goal Inference:**
| Keywords | Goal |
|----------|------|
| 性能/慢/延迟/加载 | performance |
| 安全/漏洞/头部/HTTPS | security |
| 调试/错误/失败/500 | debugging |
| API/接口/端点/请求 | api-discovery |
| (none of above) | general |

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
1. Extract target URL from user message
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
capture-session.sh start https://example.com
```

Or with explicit scope control:
```bash
capture-session.sh start https://example.com --allow-hosts "example.com,*.example.com"
```

Key flags:
- `-d <dir>` — output directory for capture files
- `-P <port>` — custom port (default 18080)
- `--allow-hosts <list>` — restrict capture to these hosts (comma-separated, supports *)
- `--deny-hosts <list>` — always ignore these hosts (takes precedence)
- `--policy <file>` — JSON policy file for complex scope rules

**Scope Control:**
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
capture-session.sh stop
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

### Check Progress
```bash
capture-session.sh progress
```
Shows: duration, request count, data size

## Report Template

See [templates/analysis-report.md](templates/analysis-report.md) for the output format.

Reports include:
- Executive summary (1-2 sentences)
- Key findings (prioritized list)
- Performance metrics table
- Security observations
- Detailed request analysis (top issues)
- Recommendations

## File Structure

```
fafafa-skills-capture-analytics/
├── SKILL.md                           # This file
├── skill-rules.json                   # Trigger configuration
├── references/
│   ├── CAPTURE_OPERATIONS.md          # Detailed capture operations
│   ├── ANALYSIS_PATTERNS.md           # Analysis strategies & patterns
│   └── BROWSER_EXPLORATION.md         # Playwright exploration guide
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
