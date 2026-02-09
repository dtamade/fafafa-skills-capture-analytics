# Analysis Patterns Reference

## Table of Contents

1. [Reading Output Files](#reading-output-files)
2. [Performance Analysis](#performance-analysis)
3. [Security Analysis](#security-analysis)
4. [Traffic Patterns](#traffic-patterns)
5. [Debugging Techniques](#debugging-techniques)
6. [Report Generation](#report-generation)

---

## Reading Output Files

### Recommended Order

1. **latest.summary.md** - Quick overview (total requests, error rate, top hosts)
2. **latest.ai.json** - Structured stats with findings
3. **latest.ai.md** - Natural language brief
4. **latest.har** - Deep dive into specific requests
5. **latest.index.ndjson** - Programmatic analysis

### AI JSON Structure

```json
{
  "stats": {
    "totalRequests": 287,
    "respondedRequests": 280,
    "noResponseRequests": 7,
    "avgDurationMs": 156,
    "p95DurationMs": 890,
    "statusBuckets": {"2xx": 245, "3xx": 12, "4xx": 18, "5xx": 5},
    "topHosts": [{"host": "api.example.com", "count": 128}],
    "topEndpoints": [{"endpoint": "GET api.example.com/users", "count": 45}],
    "topErrorEndpoints": [...],
    "slowestRequests": [...],
    "errorProneEndpoints": [...]
  },
  "findings": ["Total requests: 287...", "Latency baseline: avg=156ms..."],
  "analysisTargets": {
    "rootCause": "Identify likely root causes...",
    "timeline": "Reconstruct key request timeline...",
    "grouping": "Group requests by user action...",
    "regression": "Highlight patterns that look like regressions..."
  }
}
```

### Index NDJSON Fields

Each line contains:

```json
{
  "id": 1,
  "startedDateTime": "2025-02-09T15:30:45.123Z",
  "method": "GET",
  "scheme": "https",
  "host": "api.example.com",
  "port": 443,
  "path": "/users",
  "url": "https://api.example.com/users?id=123",
  "status": 200,
  "statusBucket": "2xx",
  "durationMs": 245,
  "requestBytes": 512,
  "responseBytes": 2048,
  "contentType": "application/json"
}
```

---

## Performance Analysis

### Key Metrics

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| Avg latency | <200ms | 200-500ms | >500ms |
| P95 latency | <500ms | 500-1000ms | >1000ms |
| Error rate | <1% | 1-5% | >5% |
| No-response | <1% | 1-3% | >3% |

### Latency Analysis Patterns

**Find outliers:**
```
1. Read slowestRequests from ai.json
2. Group by endpoint
3. Identify: Is one endpoint slow, or all?
4. Check: Are slow requests correlated by time?
```

**Calculate percentiles:**
```
From index.ndjson:
- Sort by durationMs
- p50 = median
- p90 = 90th percentile
- p99 = 99th percentile
```

**Time-series analysis:**
```
Plot durationMs over time (startedDateTime)
Look for:
- Spikes (sudden slowdown)
- Trends (gradual degradation)
- Periodicity (regular patterns)
```

### Bottleneck Identification

**Sequential dependency chains:**
```
Look for patterns like:
Request A → wait → Request B → wait → Request C
These can be parallelized.
```

**Large payloads:**
```
Sort by responseBytes
Large responses slow everything down
Consider: compression, pagination, lazy loading
```

**Redirect chains:**
```
Count 3xx responses
Follow Location headers
Multiple redirects = wasted round-trips
```

---

## Security Analysis

### Header Checks

**Must-have security headers:**

| Header | Purpose | Missing = Risk |
|--------|---------|----------------|
| `Strict-Transport-Security` | Force HTTPS | Downgrade attacks |
| `Content-Security-Policy` | Prevent XSS | Script injection |
| `X-Frame-Options` | Prevent clickjacking | UI redress |
| `X-Content-Type-Options` | Prevent MIME sniffing | Content injection |

**Check in HAR responses:**
```
For each response.headers:
  Check for presence of security headers
  Flag missing ones
```

### Sensitive Data in URLs

**Bad patterns to flag:**

```
?token=xxx
?api_key=xxx
?password=xxx
?session=xxx
?auth=xxx
```

**Search in index:**
```
Grep paths containing sensitive-looking query params
```

### Mixed Content

**HTTP resources on HTTPS pages:**
```
If page is HTTPS but loads:
- http:// scripts
- http:// images
- http:// APIs
→ Security warning
```

### CORS Issues

**Look for:**
```
Access-Control-Allow-Origin: *  → Overly permissive
Missing CORS headers on API calls → May cause issues
```

### Cookie Security

**In HAR, check Set-Cookie headers:**
```
Missing HttpOnly → XSS can steal cookies
Missing Secure → Sent over HTTP
Missing SameSite → CSRF vulnerable
```

---

## Traffic Patterns

### Host Analysis

```
From topHosts in ai.json:
- Primary host (your app)
- Third-party hosts (analytics, CDN, ads)
- Unexpected hosts (tracking, malware?)
```

### Request Method Distribution

```
GET: 60-80% typical (page loads, API reads)
POST: 10-30% typical (form submissions, API writes)
OPTIONS: CORS preflight (should be minimal)
Other: Unusual, investigate
```

### Content Type Breakdown

```
application/json: API calls
text/html: Page loads
image/*: Assets
application/javascript: Scripts
```

### Error Patterns

**Error clustering:**
```
Do errors cluster by:
- Time? (outage window)
- Endpoint? (broken feature)
- Host? (backend down)
```

**Error types:**
```
400: Bad request (client bug)
401/403: Auth issues
404: Missing resource
500: Server error
502/503/504: Infrastructure issues
```

---

## Debugging Techniques

### Isolating Failed Requests

```
1. Filter index for status >= 400
2. Group by endpoint
3. Find first occurrence (timeline)
4. Check request payload for issues
5. Check response body for error messages
```

### Request Chain Tracing

```
For a user action:
1. Find the triggering request
2. Follow subsequent requests (by time)
3. Identify dependencies
4. Find where chain breaks
```

### Comparing Request/Response

```
For flaky endpoints:
1. Find successful and failed requests to same endpoint
2. Diff request headers/body
3. Diff response headers/body
4. Identify what differs
```

### Replay for Verification

```bash
# From HAR entry, construct curl:
curl -X POST 'https://api.example.com/endpoint' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer xxx' \
  -d '{"key": "value"}'
```

---

## Report Generation

### Executive Summary Template

```markdown
## Summary

Analyzed **[N] requests** to **[target]** over **[duration]**.

**Key Finding:** [One sentence describing the main issue/observation]

### Metrics
- Total requests: X
- Error rate: Y%
- Avg latency: Z ms
- P95 latency: W ms
```

### Findings Format

```markdown
## Findings

### 1. [Issue Title]
- **Impact:** [High/Medium/Low]
- **Evidence:** [Specific data points]
- **Recommendation:** [Action to take]

### 2. [Issue Title]
...
```

### Performance Table

```markdown
## Endpoint Performance

| Endpoint | Count | Avg ms | P95 ms | Errors |
|----------|-------|--------|--------|--------|
| GET /api/users | 45 | 120 | 350 | 0 |
| POST /api/submit | 12 | 890 | 2100 | 3 |
```

### Security Observations

```markdown
## Security

| Check | Status | Details |
|-------|--------|---------|
| HTTPS Only | ✅ Pass | All requests over HTTPS |
| Security Headers | ⚠️ Warn | Missing CSP on api.example.com |
| Sensitive in URLs | ❌ Fail | Token exposed in query string |
```

### Next Steps

```markdown
## Recommendations

1. **[Priority] Action item**
   - Why: [Reason]
   - How: [Specific steps]

2. **[Priority] Action item**
   ...
```
