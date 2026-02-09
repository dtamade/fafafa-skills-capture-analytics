#!/usr/bin/env python3
"""Tests for scope_audit module."""

import sys
import os
import json
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

from scope_audit import run_scope_audit, render_audit_summary


def create_test_index(entries):
    """Create temporary index file with test entries."""
    fd, path = tempfile.mkstemp(suffix='.ndjson')
    with os.fdopen(fd, 'w') as f:
        for entry in entries:
            f.write(json.dumps(entry) + '\n')
    return path


def test_audit_all_in_scope():
    """Test audit when all traffic is in scope."""
    entries = [
        {'id': 1, 'host': 'example.com', 'method': 'GET', 'url': 'https://example.com/'},
        {'id': 2, 'host': 'api.example.com', 'method': 'POST', 'url': 'https://api.example.com/data'},
    ]
    index_file = create_test_index(entries)

    try:
        result = run_scope_audit(
            index_file,
            allow_hosts=['example.com', '*.example.com'],
            deny_hosts=[]
        )

        assert result['status'] == 'pass'
        assert result['totalRequests'] == 2
        assert result['inScopeCount'] == 2
        assert result['outOfScopeCount'] == 0
        assert len(result['violations']) == 0
        print('✓ test_audit_all_in_scope passed')
    finally:
        os.unlink(index_file)


def test_audit_with_violations():
    """Test audit when there are out-of-scope requests."""
    entries = [
        {'id': 1, 'host': 'example.com', 'method': 'GET', 'url': 'https://example.com/'},
        {'id': 2, 'host': 'malicious.com', 'method': 'GET', 'url': 'https://malicious.com/steal'},
        {'id': 3, 'host': 'www.google.com', 'method': 'GET', 'url': 'https://www.google.com/'},
    ]
    index_file = create_test_index(entries)

    try:
        result = run_scope_audit(
            index_file,
            allow_hosts=['example.com'],
            deny_hosts=['*.google.com']
        )

        assert result['status'] == 'violation'
        assert result['totalRequests'] == 3
        assert result['inScopeCount'] == 1
        assert result['outOfScopeCount'] == 2

        # Check violation details
        violation_hosts = [v['host'] for v in result['violations']]
        assert 'malicious.com' in violation_hosts
        assert 'www.google.com' in violation_hosts

        print('✓ test_audit_with_violations passed')
    finally:
        os.unlink(index_file)


def test_audit_deny_takes_precedence():
    """Test that deny list takes precedence over allow list."""
    entries = [
        {'id': 1, 'host': 'login.example.com', 'method': 'POST', 'url': 'https://login.example.com/auth'},
    ]
    index_file = create_test_index(entries)

    try:
        result = run_scope_audit(
            index_file,
            allow_hosts=['*.example.com'],  # Would match login.example.com
            deny_hosts=['login.*']  # But deny takes precedence
        )

        assert result['status'] == 'violation'
        assert result['outOfScopeCount'] == 1
        assert result['violations'][0]['reason'] == 'denied_by_blacklist'

        print('✓ test_audit_deny_takes_precedence passed')
    finally:
        os.unlink(index_file)


def test_audit_empty_allowlist():
    """Test audit with empty allowlist (permissive mode)."""
    entries = [
        {'id': 1, 'host': 'anything.com', 'method': 'GET', 'url': 'https://anything.com/'},
        {'id': 2, 'host': 'blocked.com', 'method': 'GET', 'url': 'https://blocked.com/'},
    ]
    index_file = create_test_index(entries)

    try:
        result = run_scope_audit(
            index_file,
            allow_hosts=[],  # Empty = allow all
            deny_hosts=['blocked.com']  # Except this
        )

        assert result['status'] == 'violation'
        assert result['inScopeCount'] == 1
        assert result['outOfScopeCount'] == 1

        print('✓ test_audit_empty_allowlist passed')
    finally:
        os.unlink(index_file)


def test_audit_host_summary():
    """Test that host summary is generated correctly."""
    entries = [
        {'id': 1, 'host': 'example.com', 'method': 'GET', 'url': 'https://example.com/1'},
        {'id': 2, 'host': 'example.com', 'method': 'GET', 'url': 'https://example.com/2'},
        {'id': 3, 'host': 'api.example.com', 'method': 'POST', 'url': 'https://api.example.com/'},
    ]
    index_file = create_test_index(entries)

    try:
        result = run_scope_audit(
            index_file,
            allow_hosts=['*.example.com', 'example.com'],
            deny_hosts=[]
        )

        assert result['hostSummary']['example.com'] == 2
        assert result['hostSummary']['api.example.com'] == 1

        print('✓ test_audit_host_summary passed')
    finally:
        os.unlink(index_file)


def test_render_audit_summary():
    """Test human-readable summary rendering."""
    result = {
        'status': 'violation',
        'auditedAt': '2026-02-09T10:00:00Z',
        'totalRequests': 10,
        'inScopeCount': 8,
        'outOfScopeCount': 2,
        'violations': [
            {'id': 5, 'host': 'bad.com', 'method': 'GET', 'reason': 'not_in_whitelist'},
        ],
        'violationsTruncated': False,
        'hostSummary': {'example.com': 8, 'bad.com': 2},
    }

    summary = render_audit_summary(result)

    assert '**Status**: `VIOLATION`' in summary
    assert 'bad.com' in summary
    assert 'not_in_whitelist' in summary

    print('✓ test_render_audit_summary passed')


def run_all_tests():
    """Run all scope audit tests."""
    print('Running scope_audit module tests...\n')

    test_audit_all_in_scope()
    test_audit_with_violations()
    test_audit_deny_takes_precedence()
    test_audit_empty_allowlist()
    test_audit_host_summary()
    test_render_audit_summary()

    print('\n✓ All scope_audit tests passed!')


if __name__ == '__main__':
    run_all_tests()
