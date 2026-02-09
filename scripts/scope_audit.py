#!/usr/bin/env python3
"""Scope audit module for detecting out-of-scope traffic.

Analyzes captured traffic index and checks for policy violations.
"""

import json
import os
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Import policy module
sys.path.insert(0, str(Path(__file__).parent))
from policy import is_host_allowed, load_policy


def load_index(index_file: str) -> List[Dict]:
    """Load index entries from NDJSON file.

    Args:
        index_file: Path to .index.ndjson file

    Returns:
        List of index entry dicts (capped at 100000 entries)
    """
    MAX_ENTRIES = 100000
    entries = []
    with open(index_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
                if len(entries) >= MAX_ENTRIES:
                    break
    return entries


def run_scope_audit(
    index_file: str,
    allow_hosts: List[str],
    deny_hosts: List[str]
) -> Dict:
    """Run scope audit on captured traffic.

    Args:
        index_file: Path to index.ndjson file
        allow_hosts: Whitelist patterns
        deny_hosts: Blacklist patterns

    Returns:
        Audit result dict with:
            - status: 'pass' | 'violation'
            - total_requests: int
            - in_scope_count: int
            - out_of_scope_count: int
            - violations: list of violation details
            - host_summary: Counter of hosts
    """
    entries = load_index(index_file)

    total = len(entries)
    in_scope = 0
    out_of_scope = 0
    violations = []
    host_counter = Counter()

    for entry in entries:
        host = entry.get('host', '')
        host_counter[host] += 1

        allowed, reason = is_host_allowed(host, allow_hosts, deny_hosts)

        if allowed:
            in_scope += 1
        else:
            out_of_scope += 1
            violations.append({
                'id': entry.get('id'),
                'host': host,
                'url': entry.get('url', ''),
                'method': entry.get('method', ''),
                'reason': reason,
            })

    status = 'pass' if out_of_scope == 0 else 'violation'

    return {
        'status': status,
        'auditedAt': datetime.now(timezone.utc).isoformat(),
        'totalRequests': total,
        'inScopeCount': in_scope,
        'outOfScopeCount': out_of_scope,
        'violations': violations[:50],  # Limit to first 50
        'violationsTruncated': len(violations) > 50,
        'hostSummary': dict(host_counter.most_common(20)),
    }


def render_audit_summary(result: Dict) -> str:
    """Render audit result as human-readable summary.

    Args:
        result: Audit result dict

    Returns:
        Markdown formatted summary
    """
    lines = []
    lines.append('# Scope Audit Report')
    lines.append('')
    lines.append(f'- **Status**: `{result["status"].upper()}`')
    lines.append(f'- **Audited at**: `{result["auditedAt"]}`')
    lines.append(f'- **Total requests**: `{result["totalRequests"]}`')
    lines.append(f'- **In-scope**: `{result["inScopeCount"]}`')
    lines.append(f'- **Out-of-scope**: `{result["outOfScopeCount"]}`')
    lines.append('')

    if result['status'] == 'violation':
        lines.append('## ⚠️ Violations')
        lines.append('')
        lines.append('| ID | Host | Method | Reason |')
        lines.append('|----|------|--------|--------|')
        for v in result['violations'][:20]:
            lines.append(f'| {v["id"]} | {v["host"]} | {v["method"]} | {v["reason"]} |')
        if result.get('violationsTruncated'):
            lines.append('')
            lines.append(f'*... and {result["outOfScopeCount"] - 50} more violations*')
        lines.append('')

    lines.append('## Host Summary')
    lines.append('')
    lines.append('| Host | Count |')
    lines.append('|------|-------|')
    for host, count in result.get('hostSummary', {}).items():
        lines.append(f'| {host} | {count} |')
    lines.append('')

    return '\n'.join(lines)


def main():
    """CLI interface for scope audit."""
    import argparse

    parser = argparse.ArgumentParser(description='Audit captured traffic against scope policy')
    parser.add_argument('index_file', help='Path to index.ndjson file')
    parser.add_argument('-p', '--policy', help='Policy JSON file')
    parser.add_argument('--allow-hosts', help='Comma-separated allow hosts (overrides policy)')
    parser.add_argument('--deny-hosts', help='Comma-separated deny hosts (overrides policy)')
    parser.add_argument('-o', '--output', help='Output JSON file')
    parser.add_argument('--summary', action='store_true', help='Print human-readable summary')

    args = parser.parse_args()

    # Load policy or use CLI args
    allow_hosts = []
    deny_hosts = []

    if args.policy:
        policy = load_policy(args.policy)
        allow_hosts = policy['scope'].get('allow_hosts', [])
        deny_hosts = policy['scope'].get('deny_hosts', [])

    if args.allow_hosts:
        allow_hosts = [h.strip() for h in args.allow_hosts.split(',') if h.strip()]
    if args.deny_hosts:
        deny_hosts = [h.strip() for h in args.deny_hosts.split(',') if h.strip()]

    # Run audit
    result = run_scope_audit(args.index_file, allow_hosts, deny_hosts)

    # Output
    if args.output:
        fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
        print(f'Audit result written to {args.output}', file=sys.stderr)

    if args.summary:
        print(render_audit_summary(result))
    elif not args.output:
        print(json.dumps(result, indent=2, ensure_ascii=False))

    # Exit code based on audit status
    sys.exit(0 if result['status'] == 'pass' else 2)


if __name__ == '__main__':
    main()
