#!/usr/bin/env python3
"""Tests for validate_url.py"""

import json
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.parent / 'scripts'
VALIDATE_URL = SCRIPT_DIR / 'validate_url.py'


def run_validator(url: str, *args) -> dict:
    """Run validate_url.py and return parsed JSON output."""
    cmd = [sys.executable, str(VALIDATE_URL), url] + list(args)
    result = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(result.stdout), result.returncode


class TestURLValidation:
    """Test URL format validation."""

    def test_valid_https_url(self):
        result, code = run_validator('https://example.com')
        assert result['valid'] is True
        assert result['domain'] == 'example.com'
        assert code == 0

    def test_valid_http_url(self):
        result, code = run_validator('http://example.com')
        assert result['valid'] is True
        assert result['domain'] == 'example.com'
        assert code == 0

    def test_auto_add_https(self):
        """Bare domain should get https:// prefix."""
        result, code = run_validator('example.com')
        assert result['valid'] is True
        assert result['normalized_url'] == 'https://example.com'
        assert code == 0

    def test_subdomain(self):
        result, code = run_validator('https://sub.example.com')
        assert result['valid'] is True
        assert result['domain'] == 'sub.example.com'

    def test_with_path(self):
        result, code = run_validator('https://example.com/path/to/page')
        assert result['valid'] is True
        assert result['domain'] == 'example.com'

    def test_with_port(self):
        result, code = run_validator('https://example.com:8080')
        assert result['valid'] is True
        assert result['domain'] == 'example.com'

    def test_localhost(self):
        result, code = run_validator('http://localhost')
        assert result['valid'] is True
        assert result['domain'] == 'localhost'

    def test_ip_address(self):
        result, code = run_validator('http://192.168.1.1')
        assert result['valid'] is True
        assert result['domain'] == '192.168.1.1'

    def test_reject_single_label(self):
        """Single label hostname (no TLD) should be rejected."""
        result, code = run_validator('not-a-domain')
        assert result['valid'] is False
        assert 'TLD' in result['error']
        assert code == 1

    def test_reject_empty(self):
        result, code = run_validator('')
        assert result['valid'] is False
        assert code == 1

    def test_reject_invalid_scheme(self):
        result, code = run_validator('ftp://example.com')
        assert result['valid'] is False
        assert 'scheme' in result['error'].lower()
        assert code == 1

    def test_reject_hostname_with_leading_dot(self):
        result, code = run_validator('https://.example.com')
        assert result['valid'] is False
        assert code == 1

    def test_reject_hostname_with_consecutive_dots(self):
        result, code = run_validator('https://example..com')
        assert result['valid'] is False
        assert code == 1

    def test_reject_label_starting_with_hyphen(self):
        result, code = run_validator('https://-example.com')
        assert result['valid'] is False
        assert 'hyphen' in result['error'].lower()
        assert code == 1


class TestReachabilityCheck:
    """Test optional reachability checking."""

    def test_reachable_null_by_default(self):
        """Without --check-reachable, reachable should be null."""
        result, _ = run_validator('https://example.com')
        assert result['reachable'] is None

    def test_reachable_returns_bool_when_requested(self):
        """With --check-reachable, reachable should be bool."""
        result, _ = run_validator('https://example.com', '--check-reachable')
        assert result['reachable'] in (True, False)

    def test_unreachable_domain(self):
        """Non-existent domain should return reachable=False."""
        result, _ = run_validator(
            'https://this-domain-definitely-does-not-exist-12345.com',
            '--check-reachable'
        )
        assert result['reachable'] is False
        assert 'reachable_error' in result


if __name__ == '__main__':
    import pytest
    sys.exit(pytest.main([__file__, '-v']))
