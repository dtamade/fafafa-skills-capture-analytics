#!/usr/bin/env python3
"""Policy module for capture scope management.

Provides domain whitelist/blacklist functionality and regex compilation
for mitmproxy allow_hosts/ignore_hosts configuration.
"""

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from urllib.parse import urlparse


def load_policy(path: str) -> Dict:
    """Load policy from JSON file.

    Args:
        path: Path to policy JSON file

    Returns:
        Policy dict with scope, consent, audit sections

    Raises:
        FileNotFoundError: If policy file doesn't exist
        json.JSONDecodeError: If policy file is invalid JSON
    """
    with open(path, 'r', encoding='utf-8') as f:
        policy = json.load(f)

    # Validate required fields
    if 'scope' not in policy:
        policy['scope'] = {}
    if 'allow_hosts' not in policy['scope']:
        policy['scope']['allow_hosts'] = []
    if 'deny_hosts' not in policy['scope']:
        policy['scope']['deny_hosts'] = []
    if 'consent' not in policy:
        policy['consent'] = {'require_confirm': False}
    if 'audit' not in policy:
        policy['audit'] = {'fail_on_violation': True, 'log_violations': True}

    return policy


def extract_target_host(url: str) -> str:
    """Extract hostname from URL.

    Args:
        url: Full URL or hostname

    Returns:
        Hostname without scheme, port, or path
    """
    if not url:
        return ''

    # Add scheme if missing for urlparse
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url

    parsed = urlparse(url)
    return parsed.hostname or ''


def wildcard_to_regex(pattern: str) -> str:
    """Convert wildcard pattern to regex.

    Supports:
        - * matches any characters (including dots)
        - Literal dots are escaped

    Args:
        pattern: Wildcard pattern like "*.example.com"

    Returns:
        Regex pattern like ".*\\.example\\.com"
    """
    # Escape regex special chars except *
    escaped = re.escape(pattern)
    # Convert \* back to .* (match anything)
    escaped = escaped.replace(r'\*', '.*')
    return escaped


def compile_hosts_regex(hosts: List[str]) -> str:
    """Compile list of host patterns into single regex.

    Args:
        hosts: List of host patterns (may include wildcards)

    Returns:
        Combined regex pattern for mitmproxy
    """
    if not hosts:
        return ''

    patterns = []
    for host in hosts:
        host = host.strip()
        if not host:
            continue
        pattern = wildcard_to_regex(host)
        # Anchor pattern to match full hostname
        patterns.append(f'^{pattern}$')

    if not patterns:
        return ''

    # Combine with alternation
    return '|'.join(patterns)


def compile_allow_hosts_regex(hosts: List[str]) -> str:
    """Compile allow_hosts list for mitmproxy --set allow_hosts=...

    Args:
        hosts: List of allowed host patterns

    Returns:
        Regex string for mitmproxy allow_hosts option
    """
    return compile_hosts_regex(hosts)


def compile_ignore_hosts_regex(hosts: List[str]) -> str:
    """Compile deny_hosts list for mitmproxy --set ignore_hosts=...

    Args:
        hosts: List of denied host patterns

    Returns:
        Regex string for mitmproxy ignore_hosts option
    """
    return compile_hosts_regex(hosts)


def host_matches_pattern(host: str, pattern: str) -> bool:
    """Check if host matches a wildcard pattern.

    Args:
        host: Actual hostname
        pattern: Wildcard pattern

    Returns:
        True if host matches pattern
    """
    regex = wildcard_to_regex(pattern)
    return bool(re.match(f'^{regex}$', host, re.IGNORECASE))


def host_matches_any(host: str, patterns: List[str]) -> bool:
    """Check if host matches any pattern in list.

    Args:
        host: Actual hostname
        patterns: List of wildcard patterns

    Returns:
        True if host matches any pattern
    """
    for pattern in patterns:
        if host_matches_pattern(host, pattern):
            return True
    return False


def is_host_allowed(host: str, allow_hosts: List[str], deny_hosts: List[str]) -> Tuple[bool, str]:
    """Check if host is allowed by policy.

    Logic:
        1. If host matches deny_hosts -> denied
        2. If allow_hosts is empty -> allowed (permissive mode)
        3. If host matches allow_hosts -> allowed
        4. Otherwise -> denied

    Args:
        host: Hostname to check
        allow_hosts: Whitelist patterns
        deny_hosts: Blacklist patterns

    Returns:
        Tuple of (allowed: bool, reason: str)
    """
    if not host:
        return False, 'empty_host'

    # Check deny list first (takes precedence)
    if deny_hosts and host_matches_any(host, deny_hosts):
        return False, 'denied_by_blacklist'

    # If no whitelist, allow all (except blacklisted)
    if not allow_hosts:
        return True, 'no_whitelist'

    # Check allow list
    if host_matches_any(host, allow_hosts):
        return True, 'allowed_by_whitelist'

    return False, 'not_in_whitelist'


def generate_default_policy(target_url: str) -> Dict:
    """Generate default policy from target URL.

    Creates a minimal policy that allows:
        - The target hostname
        - www.{target_hostname}
        - api.{target_hostname}
        - *.{target_hostname}

    Args:
        target_url: Target URL to capture

    Returns:
        Policy dict
    """
    host = extract_target_host(target_url)
    if not host:
        return {
            'scope': {'allow_hosts': [], 'deny_hosts': []},
            'consent': {'require_confirm': True},
            'audit': {'fail_on_violation': True}
        }

    # Remove www. prefix if present for base domain
    base_host = host
    if base_host.startswith('www.'):
        base_host = base_host[4:]

    allow_hosts = [
        base_host,
        f'www.{base_host}',
        f'*.{base_host}',
    ]

    # Common deny patterns (auth providers, analytics)
    deny_hosts = [
        '*.google.com',
        '*.googleapis.com',
        '*.gstatic.com',
        '*.facebook.com',
        '*.fbcdn.net',
        'accounts.*',
        'login.*',
        'auth.*',
        '*.auth0.com',
        '*.okta.com',
    ]

    return {
        'scope': {
            'allow_hosts': allow_hosts,
            'deny_hosts': deny_hosts,
        },
        'consent': {
            'require_confirm': True,
            'confirm_phrase': 'YES_I_HAVE_AUTHORIZATION',
        },
        'audit': {
            'fail_on_violation': True,
            'log_violations': True,
        },
    }


def main():
    """CLI interface for policy module."""
    import argparse

    parser = argparse.ArgumentParser(description='Policy management for capture scope')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # generate command
    gen_parser = subparsers.add_parser('generate', help='Generate default policy from URL')
    gen_parser.add_argument('url', help='Target URL')
    gen_parser.add_argument('-o', '--output', help='Output file (default: stdout)')

    # compile command
    compile_parser = subparsers.add_parser('compile', help='Compile policy to mitmproxy args')
    compile_parser.add_argument('policy_file', help='Policy JSON file')

    # check command
    check_parser = subparsers.add_parser('check', help='Check if host is allowed')
    check_parser.add_argument('policy_file', help='Policy JSON file')
    check_parser.add_argument('host', help='Host to check')

    args = parser.parse_args()

    if args.command == 'generate':
        policy = generate_default_policy(args.url)
        output = json.dumps(policy, indent=2, ensure_ascii=False)
        if args.output:
            with open(args.output, 'w', encoding='utf-8') as f:
                f.write(output)
            print(f'Policy written to {args.output}', file=sys.stderr)
        else:
            print(output)

    elif args.command == 'compile':
        policy = load_policy(args.policy_file)
        allow_regex = compile_allow_hosts_regex(policy['scope']['allow_hosts'])
        ignore_regex = compile_ignore_hosts_regex(policy['scope']['deny_hosts'])
        print(f'allow_hosts={allow_regex}')
        print(f'ignore_hosts={ignore_regex}')

    elif args.command == 'check':
        policy = load_policy(args.policy_file)
        allowed, reason = is_host_allowed(
            args.host,
            policy['scope']['allow_hosts'],
            policy['scope']['deny_hosts']
        )
        status = 'ALLOWED' if allowed else 'DENIED'
        print(f'{status}: {args.host} ({reason})')
        sys.exit(0 if allowed else 1)

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
