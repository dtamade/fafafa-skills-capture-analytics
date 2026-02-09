#!/usr/bin/env python3
"""Tests for policy module."""

import sys
import os
import json
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

from policy import (
    extract_target_host,
    wildcard_to_regex,
    compile_hosts_regex,
    host_matches_pattern,
    host_matches_any,
    is_host_allowed,
    generate_default_policy,
    load_policy,
)


def test_extract_target_host():
    """Test hostname extraction from URLs."""
    assert extract_target_host('https://example.com/path') == 'example.com'
    assert extract_target_host('http://api.example.com:8080/') == 'api.example.com'
    assert extract_target_host('example.com') == 'example.com'
    assert extract_target_host('www.example.com/login') == 'www.example.com'
    assert extract_target_host('') == ''
    print('✓ test_extract_target_host passed')


def test_wildcard_to_regex():
    """Test wildcard to regex conversion."""
    assert wildcard_to_regex('example.com') == r'example\.com'
    assert wildcard_to_regex('*.example.com') == r'.*\.example\.com'
    assert wildcard_to_regex('api.*') == r'api\..*'
    assert wildcard_to_regex('*') == '.*'
    print('✓ test_wildcard_to_regex passed')


def test_host_matches_pattern():
    """Test host pattern matching."""
    # Exact match
    assert host_matches_pattern('example.com', 'example.com')
    assert not host_matches_pattern('example.com', 'other.com')

    # Wildcard prefix
    assert host_matches_pattern('api.example.com', '*.example.com')
    assert host_matches_pattern('www.example.com', '*.example.com')
    assert not host_matches_pattern('example.com', '*.example.com')  # * requires at least one char

    # Wildcard suffix
    assert host_matches_pattern('api.google.com', 'api.*')
    assert host_matches_pattern('api.facebook.com', 'api.*')

    # Case insensitive
    assert host_matches_pattern('Example.COM', 'example.com')

    print('✓ test_host_matches_pattern passed')


def test_host_matches_any():
    """Test matching against multiple patterns."""
    patterns = ['example.com', '*.google.com', 'api.*']

    assert host_matches_any('example.com', patterns)
    assert host_matches_any('www.google.com', patterns)
    assert host_matches_any('api.facebook.com', patterns)
    assert not host_matches_any('other.com', patterns)

    print('✓ test_host_matches_any passed')


def test_is_host_allowed():
    """Test host allowlist/denylist logic."""
    allow = ['example.com', '*.example.com']
    deny = ['login.example.com', '*.google.com']

    # Allowed by whitelist
    allowed, reason = is_host_allowed('example.com', allow, deny)
    assert allowed and reason == 'allowed_by_whitelist'

    allowed, reason = is_host_allowed('api.example.com', allow, deny)
    assert allowed and reason == 'allowed_by_whitelist'

    # Denied by blacklist (takes precedence)
    allowed, reason = is_host_allowed('login.example.com', allow, deny)
    assert not allowed and reason == 'denied_by_blacklist'

    # Not in whitelist
    allowed, reason = is_host_allowed('other.com', allow, deny)
    assert not allowed and reason == 'not_in_whitelist'

    # Empty whitelist = permissive mode
    allowed, reason = is_host_allowed('anything.com', [], deny)
    assert allowed and reason == 'no_whitelist'

    # Empty host
    allowed, reason = is_host_allowed('', allow, deny)
    assert not allowed and reason == 'empty_host'

    print('✓ test_is_host_allowed passed')


def test_compile_hosts_regex():
    """Test regex compilation."""
    hosts = ['example.com', '*.google.com']
    regex = compile_hosts_regex(hosts)

    # Should be valid regex
    import re
    pattern = re.compile(regex)

    assert pattern.match('example.com')
    assert pattern.match('www.google.com')
    assert not pattern.match('other.com')

    # Empty list
    assert compile_hosts_regex([]) == ''

    print('✓ test_compile_hosts_regex passed')


def test_generate_default_policy():
    """Test default policy generation."""
    policy = generate_default_policy('https://example.com/login')

    assert 'example.com' in policy['scope']['allow_hosts']
    assert '*.example.com' in policy['scope']['allow_hosts']
    assert policy['consent']['require_confirm'] == True
    assert '*.google.com' in policy['scope']['deny_hosts']

    # www. prefix handling
    policy2 = generate_default_policy('https://www.example.com')
    assert 'example.com' in policy2['scope']['allow_hosts']

    print('✓ test_generate_default_policy passed')


def test_load_policy():
    """Test policy file loading."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump({
            'scope': {
                'allow_hosts': ['test.com'],
                'deny_hosts': ['bad.com']
            }
        }, f)
        temp_path = f.name

    try:
        policy = load_policy(temp_path)
        assert policy['scope']['allow_hosts'] == ['test.com']
        assert policy['scope']['deny_hosts'] == ['bad.com']
        assert 'consent' in policy
        assert 'audit' in policy
        print('✓ test_load_policy passed')
    finally:
        os.unlink(temp_path)


def run_all_tests():
    """Run all policy tests."""
    print('Running policy module tests...\n')

    test_extract_target_host()
    test_wildcard_to_regex()
    test_host_matches_pattern()
    test_host_matches_any()
    test_is_host_allowed()
    test_compile_hosts_regex()
    test_generate_default_policy()
    test_load_policy()

    print('\n✓ All policy tests passed!')


if __name__ == '__main__':
    run_all_tests()
