# Browser Exploration Strategies

## Table of Contents

1. [Connecting Playwright Through Proxy](#connecting-playwright-through-proxy)
2. [Exploration Strategies](#exploration-strategies)
3. [Navigation Patterns](#navigation-patterns)
4. [Handling Authentication](#handling-authentication)
5. [Best Practices](#best-practices)

---

## Connecting Playwright Through Proxy

### Method 1: Playwright MCP with System Proxy

If the system proxy is configured (non-program mode), Playwright will use it automatically.

### Method 2: Environment Variables (Recommended for --program mode)

Set environment variables before browser operations:

```bash
# Set proxy environment variables
export HTTP_PROXY=http://127.0.0.1:18080
export HTTPS_PROXY=http://127.0.0.1:18080
export http_proxy=http://127.0.0.1:18080
export https_proxy=http://127.0.0.1:18080
```

### Method 3: Browser Context with Proxy (Playwright Code)

When using `browser_run_code`, configure proxy at context level:

```javascript
// Correct way to set proxy in Playwright
const browser = await chromium.launch();
const context = await browser.newContext({
  proxy: {
    server: 'http://127.0.0.1:18080'
  },
  ignoreHTTPSErrors: true  // Trust mitmproxy CA
});
const page = await context.newPage();
await page.goto('https://example.com');
```

### Method 4: Launch Browser with Proxy Args

```javascript
const browser = await chromium.launch({
  args: ['--proxy-server=http://127.0.0.1:18080']
});
```

### SSL Certificate Handling

For HTTPS sites, either:

1. **Ignore cert errors** (simpler, recommended for testing):
   - Playwright MCP handles this automatically in most cases

2. **Install mitmproxy CA** (production-grade):
   ```bash
   # Find cert
   ls ~/.mitmproxy/mitmproxy-ca-cert.pem

   # For system trust (varies by OS)
   sudo cp ~/.mitmproxy/mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/
   sudo update-ca-certificates
   ```

---

## Exploration Strategies

### 1. Full Crawl Strategy

**Use when:** General site analysis, API discovery, performance baseline

**Approach:**
```
1. Navigate to homepage
2. Take snapshot → identify all links
3. Visit each link (BFS or DFS)
4. On each page:
   - Record load time
   - Identify interactive elements
   - Click buttons that trigger AJAX
5. Limit depth to 3-4 levels
6. Limit total pages to ~50
```

**AI Decision Points:**
- Skip external links (different domain)
- Skip download links (.pdf, .zip, etc.)
- Prioritize navigation menus
- Avoid logout/destructive links

### 2. Targeted Flow Strategy

**Use when:** Testing specific user journey

**Approach:**
```
1. Navigate to entry point (login, landing)
2. Follow specific path:
   - Login → Dashboard → Feature → Submit
3. Capture each step's network activity
4. Verify expected responses
```

**Example Flow:**
```
homepage → login form → submit credentials → dashboard →
profile page → edit form → submit changes → verify
```

### 3. API Discovery Strategy

**Use when:** Mapping backend endpoints

**Approach:**
```
1. Visit pages that use AJAX
2. Trigger interactive elements:
   - Dropdowns (load options)
   - Search (autocomplete APIs)
   - Infinite scroll (pagination APIs)
   - Modals (lazy-loaded content)
3. Catalog unique endpoints from capture
```

**High-Yield Interactions:**
- Search boxes with autocomplete
- Filter/sort controls
- "Load more" buttons
- Tab switches
- Form submissions

### 4. Stress Probe Strategy

**Use when:** Performance analysis, finding slow endpoints

**Approach:**
```
1. Identify key pages
2. Navigate rapidly between them
3. Trigger parallel requests:
   - Multiple tabs
   - Rapid clicks
   - Form spam (carefully)
4. Measure latency distribution
```

### 5. Manual Assist Strategy

**Use when:** Complex scenarios, authentication required

**Approach:**
```
1. AI starts capture
2. User operates browser manually
3. AI monitors and suggests next actions
4. User signals completion
5. AI stops capture and analyzes
```

---

## Navigation Patterns

### Page Load Pattern

```
1. browser_navigate → URL
2. browser_wait_for → page loaded
3. browser_snapshot → analyze structure
4. Extract: links, buttons, forms
5. Decide: next action
```

### Click and Wait Pattern

```
1. browser_click → element ref
2. browser_wait_for → network idle OR specific text
3. browser_snapshot → verify new state
4. Continue or backtrack
```

### Form Submission Pattern

```
1. browser_snapshot → find form fields
2. browser_fill_form → populate fields
3. browser_click → submit button
4. browser_wait_for → response indicator
5. browser_snapshot → verify result
```

### Scroll Discovery Pattern

```
1. browser_evaluate → scroll to bottom
2. browser_wait_for → new content loaded
3. browser_snapshot → check for new elements
4. Repeat until no new content
```

---

## Handling Authentication

### Public Sites

No special handling needed. Just navigate.

### Login-Required Sites

**Option 1: Manual login first**
```
1. Start capture
2. Navigate to login page
3. Use browser_fill_form for credentials
4. Submit and verify login success
5. Continue with authenticated session
```

**Option 2: Session injection**
```
1. User provides session cookies
2. AI sets cookies via browser_evaluate
3. Navigate directly to authenticated pages
```

### OAuth/SSO

Complex - recommend Manual Assist Strategy:
```
1. AI starts capture
2. AI navigates to OAuth entry point
3. User completes OAuth manually
4. AI continues with established session
```

### Security Considerations

- NEVER store credentials in capture files
- Sanitize auth tokens in reports
- Warn user before capturing login flows
- Consider using test accounts

---

## Best Practices

### 1. Start Small

```
Begin with 5-10 pages, then expand.
Avoid overwhelming the target server.
```

### 2. Respect Rate Limits

```
Add delays between requests (1-2 seconds).
Watch for 429 responses.
Back off if server shows strain.
```

### 3. Identify Yourself (Optionally)

```
Consider setting User-Agent to identify automated traffic.
Some sites block default Playwright User-Agent.
```

### 4. Handle Errors Gracefully

```
If a page fails to load:
- Log the error
- Continue with next target
- Don't retry excessively
```

### 5. Track Navigation Path

```
Keep a log of visited URLs:
- Helps correlate requests in analysis
- Enables report generation
- Useful for reproducing issues
```

### 6. Know When to Stop

```
Stop exploration when:
- Reached page/time limit
- Covered main user journeys
- Encountered authentication wall
- Found enough data for analysis goal
```

### 7. Clean Up

```
Always stop capture when done.
Close browser sessions.
Don't leave orphan mitmdump processes.
```
