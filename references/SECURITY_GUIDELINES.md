# Security Guidelines

## Table of Contents

1. [Ethical Boundaries](#ethical-boundaries)
2. [Authorization Requirements](#authorization-requirements)
3. [Data Handling](#data-handling)
4. [Sensitive Information](#sensitive-information)
5. [Legal Considerations](#legal-considerations)
6. [Security Boundary Checklist](#security-boundary-checklist)

---

## Ethical Boundaries

### ALLOWED Uses

✅ Testing your own applications
✅ Authorized penetration testing (with written permission)
✅ Educational research on test environments
✅ Debugging network issues in development
✅ Performance analysis of your services
✅ Security assessment with owner consent

### PROHIBITED Uses

❌ Capturing traffic without authorization
❌ Intercepting other users' communications
❌ Bypassing security controls maliciously
❌ Credential theft or session hijacking
❌ Man-in-the-middle attacks on third parties
❌ Any activity violating computer crime laws

---

## Authorization Requirements

### Before Starting Capture

**Always verify:**

1. **Ownership** - You own or control the target
2. **Permission** - You have written authorization
3. **Scope** - You understand what will be captured
4. **Purpose** - Your intent is legitimate

### Authorization Checklist

```
□ Target URL belongs to user or their organization
□ User confirms they have permission to test
□ Scope is clearly defined (which pages/APIs)
□ Duration is limited and reasonable
□ No third-party services will be affected
```

### When to Ask User

**Prompt for confirmation before:**
- Capturing any authenticated sessions
- Testing login flows
- Analyzing third-party integrations
- Storing capture data long-term

**Example prompt:**
```
I'll capture traffic from [URL]. This will record all HTTP requests
including headers and response bodies. Please confirm:
1. You own or have permission to test this site
2. You understand what data will be captured
3. You want to proceed

Type "yes" to continue.
```

---

## Data Handling

### During Capture

- Keep capture sessions short (minutes, not hours)
- Limit scope to necessary pages
- Be aware of what's being captured
- Don't capture more than needed

### After Capture

- Review captured data before sharing
- Delete captures when analysis is complete
- Don't commit capture files to version control
- Don't upload raw captures to cloud services

### Data Retention

```
Recommended retention:
- Active analysis: Keep for session duration
- Investigation: Keep up to 7 days
- Long-term: Delete or sanitize
```

### Secure Deletion

```bash
# Via cleanup script (recommended)
./scripts/cleanupCaptures.sh --secure              # shred + rm all expired sessions
./scripts/cleanupCaptures.sh --secure --keep-days 0 # shred ALL captures

# Manual
shred -u captures/*.flow
rm -rf captures/
```

---

## Sensitive Information

### What Counts as Sensitive

| Type | Examples | Risk Level |
|------|----------|------------|
| Credentials | Passwords, API keys | CRITICAL |
| Session data | Cookies, JWTs, tokens | HIGH |
| Personal info | Names, emails, addresses | HIGH |
| Financial | Card numbers, bank details | CRITICAL |
| Health | Medical records | CRITICAL |
| Business | Trade secrets, contracts | HIGH |

### Sanitization Rules

**Before generating reports:**

1. Mask credentials: `password=***` not `password=secret123`
2. Truncate tokens: `Bearer eyJ...` → `Bearer [REDACTED]`
3. Hash identifiers: `user@email.com` → `user@***.com`
4. Remove PII: Replace names with placeholders

### Report Sanitization

```python
# Patterns to redact
SENSITIVE_PATTERNS = [
    r'password=\S+',
    r'token=\S+',
    r'api_key=\S+',
    r'Bearer \S+',
    r'Authorization: \S+',
]
```

### HAR Sanitization

Before sharing HAR files:

```python
# Remove sensitive headers
REDACT_HEADERS = [
    'Authorization',
    'Cookie',
    'Set-Cookie',
    'X-Api-Key',
]

# Remove sensitive query params
REDACT_PARAMS = [
    'token',
    'api_key',
    'password',
    'secret',
]
```

---

## Legal Considerations

### Relevant Laws (Examples)

| Jurisdiction | Law | Covers |
|--------------|-----|--------|
| USA | CFAA | Computer fraud/abuse |
| USA | ECPA | Electronic communications |
| EU | GDPR | Personal data protection |
| UK | CMA | Computer misuse |
| Many | Local laws | Varies by country |

### General Principles

1. **Don't access without authorization**
   - Even if technically possible
   - Even if "just testing"

2. **Don't intercept communications**
   - Between other parties
   - Without consent of at least one party (varies by jurisdiction)

3. **Respect data protection**
   - Minimize data collection
   - Protect collected data
   - Delete when no longer needed

4. **Document authorization**
   - Keep records of permission
   - Note scope and duration
   - Useful if questions arise

### When in Doubt

- Stop and ask
- Get written permission
- Consult legal counsel
- Err on the side of caution

---

## AI Behavior Guidelines

### Pre-Capture Checks

```
Before starting capture, AI should:
1. Confirm target URL with user
2. State what will be captured
3. Ask for explicit confirmation
4. Warn about sensitive data capture
```

### During Capture

```
While capturing, AI should:
1. Not capture more than needed
2. Stop if unauthorized content detected
3. Warn user of unexpected findings
4. Respect site robots.txt (for crawling)
```

### Post-Capture

```
After capture, AI should:
1. Summarize what was captured
2. Highlight any sensitive data found
3. Recommend sanitization before sharing
4. Offer to delete raw captures
```

### Refusal Scenarios

**AI should refuse if:**
- Target is clearly not owned by user
- User cannot confirm authorization
- Request appears malicious
- Would violate obvious legal boundaries

**Refusal response:**
```
I can't proceed with this capture because:
[Specific reason]

If you have authorization, please:
[What user needs to provide]
```

---

## Security Boundary Checklist

Use this checklist to verify that a capture session follows security best practices.

### Pre-Capture

```
□ Target URL confirmed with user
□ Authorization verified (ownership or written permission)
□ Scope defined with --allow-hosts or --policy
□ Deny list set for known third-party domains (--deny-hosts)
□ Environment verified (./scripts/doctor.sh --strict)
□ Capture directory is NOT inside a git working tree (or .gitignore includes captures/)
```

### During Capture

```
□ Using program mode (--program) when system proxy changes are not desired
□ Capture duration is bounded (minutes, not hours)
□ Navigation limited to in-scope pages
□ No login with real credentials unless explicitly authorized
```

### Post-Capture

```
□ Scope audit reviewed (*.scope_audit.json shows no unexpected violations)
□ Sensitive data identified in summary/index
□ Reports sanitized before sharing (sanitize.py or manual review)
□ Raw .flow and .har files NOT committed to version control
□ Raw .flow and .har files NOT uploaded to cloud/shared storage
```

### Data Lifecycle

```
□ Retention policy defined (--keep-days or --keep-size)
□ Cleanup scheduled or run after analysis complete
□ Secure deletion used for sensitive captures (--secure flag)
□ proxy_info.env removed after stop (default behavior)
□ No capture artifacts left in /tmp or other world-readable locations
```

### Tool-Level Safeguards

The capture-analytics toolkit enforces several security measures:

| Safeguard | Implementation |
|-----------|---------------|
| Scope filtering | `--allow-hosts` / `--deny-hosts` / `--policy` restrict mitmproxy to in-scope hosts |
| Scope audit | `scope_audit.py` detects out-of-scope requests; exit code 3 warns on violations |
| Fail-closed policy | If scope policy compilation fails, capture refuses to start |
| Atomic file writes | State files use tmp+mv to prevent partial writes |
| File locking | `flock` prevents concurrent capture operations |
| Proxy restore | System proxy is restored on stop (or on error via trap) |
| Secure delete | `--secure` flag uses `shred` before `rm` |
| State cleanup | `proxy_info.env` is removed after successful stop |
| Input validation | `read_kv()` escapes regex special characters to prevent injection |
| Command injection prevention | All subprocess invocations use arrays, not `eval` |
