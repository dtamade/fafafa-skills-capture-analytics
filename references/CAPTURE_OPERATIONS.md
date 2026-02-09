# Capture Operations Reference

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Starting Capture](#starting-capture)
3. [Stopping Capture](#stopping-capture)
4. [Output Files](#output-files)
5. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

```bash
# Check mitmproxy
which mitmdump && mitmdump --version
# Expected: mitmproxy 10.x or later

# Check Python with mitmproxy bindings
python3 -c "from mitmproxy.io import FlowReader; print('OK')"
```

### Installation

```bash
# Via pip (recommended)
pip install mitmproxy

# Via system package (Debian/Ubuntu)
sudo apt install mitmproxy

# Via Homebrew (macOS)
brew install mitmproxy
```

### SSL Certificate (for HTTPS)

mitmproxy generates a CA certificate on first run. For HTTPS interception:

1. Start mitmproxy once: `mitmdump -p 8080`
2. Find cert at: `~/.mitmproxy/mitmproxy-ca-cert.pem`
3. For Playwright: use `--ignore-https-errors` or install the cert

---

## Starting Capture

### Basic Start

```bash
# From skill directory
./scripts/startCaptures.sh --program -d /path/to/workdir
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-p, --program` | Program mode (don't modify system proxy) | false |
| `-H, --host` | Listen host | 127.0.0.1 |
| `-P, --port` | Listen port | 18080 |
| `-d, --dir` | Working directory | current dir |
| `--force-recover` | Clean stale state files | false |

### What Happens on Start

1. Validates port availability
2. Starts `mitmdump` in background
3. Creates `captures/` directory
4. Writes session state to `captures/proxy_info.env`
5. Creates initial `manifest.json`
6. (Non-program mode) Sets GNOME system proxy

### Session State File

`captures/proxy_info.env` contains:

```bash
MITM_PID=12345
PROGRAM_MODE=true
TARGET_DIR=/path/to/project
CAPTURES_DIR=/path/to/project/captures
RUN_ID=20250209_153045_12345
FLOW_FILE=/path/to/captures/capture_20250209_153045_12345.flow
# ... more fields
```

---

## Stopping Capture

### Basic Stop

```bash
./scripts/stopCaptures.sh -d /path/to/workdir
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-d, --dir` | Working directory | current dir |
| `--keep-env` | Keep proxy_info.env for debugging | false |
| `--har-backend` | HAR converter: auto/mitmdump/python | auto |
| `--no-har` | Skip HAR conversion | false |

### What Happens on Stop

1. Reads session state from `proxy_info.env`
2. Gracefully stops mitmdump (TERM → wait → KILL)
3. Restores GNOME proxy (if not program mode)
4. Triggers data pipeline:
   - Flow → HAR conversion
   - Index generation (NDJSON)
   - Summary generation (Markdown)
   - AI brief generation (JSON + Markdown)
5. Creates `latest.*` symlinks
6. Removes `proxy_info.env`

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Fatal error (missing files, etc.) |
| 2 | Partial success (some pipeline steps failed) |

---

## Output Files

### Per-Capture Files

| File | Format | Description |
|------|--------|-------------|
| `capture_*.flow` | mitmproxy binary | Raw immutable capture |
| `capture_*.har` | HAR 1.2 JSON | Standard HTTP archive |
| `capture_*.log` | text | mitmdump stderr log |
| `capture_*.manifest.json` | JSON | Session metadata |
| `capture_*.index.ndjson` | NDJSON | Per-request index |
| `capture_*.summary.md` | Markdown | Quick statistics |
| `capture_*.ai.json` | JSON | Structured AI input |
| `capture_*.ai.md` | Markdown | AI-friendly brief |

### Symlinks (Latest Capture)

```
captures/
├── latest.flow → capture_20250209_153045_12345.flow
├── latest.har → capture_20250209_153045_12345.har
├── latest.summary.md → ...
├── latest.ai.json → ...
├── latest.ai.md → ...
└── latest.manifest.json → ...
```

### File Sizes (Typical)

| File | Size Range |
|------|------------|
| `.flow` | 100KB - 50MB |
| `.har` | 50KB - 20MB |
| `.index.ndjson` | 10KB - 5MB |
| `.summary.md` | 2KB - 10KB |
| `.ai.json` | 5KB - 50KB |
| `.ai.md` | 1KB - 5KB |

---

## Troubleshooting

### Port Already in Use

```bash
# Find process using port
lsof -i :18080
ss -tlnp | grep 18080

# Kill it or use different port
./scripts/startCaptures.sh --program -P 19080
```

### Stale State File

```bash
# Error: "Found stale state file"
./scripts/startCaptures.sh --force-recover
```

### HAR Conversion Fails

```bash
# Force Python backend
./scripts/stopCaptures.sh --har-backend python

# Or skip HAR entirely
./scripts/stopCaptures.sh --no-har
```

### Empty Capture (0 Requests)

Check proxy routing:

```bash
# Test with curl
curl -x http://127.0.0.1:18080 https://example.com

# For Playwright, ensure proxy is configured
# See BROWSER_EXPLORATION.md
```

### Permission Denied

```bash
chmod +x scripts/*.sh scripts/*.py
```

### mitmproxy Not Found

```bash
# Check PATH
which mitmdump

# Install if missing
pip install mitmproxy
```
