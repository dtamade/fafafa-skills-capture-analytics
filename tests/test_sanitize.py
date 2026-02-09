#!/usr/bin/env python3
"""Tests for the sanitize module."""

import sys
import os

# Add scripts directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

from sanitize import (
    sanitize_url,
    sanitize_header_value,
    sanitize_headers,
    sanitize_text,
    sanitize_json_body,
    sanitize_har_entry,
    sanitize_index_entry,
)


def test_sanitize_url():
    """Test URL parameter sanitization."""
    # Should redact sensitive params (note: value may be URL-encoded)
    result = sanitize_url('https://api.com/auth?token=secret123')
    assert 'REDACTED' in result or 'secret123' not in result

    result = sanitize_url('https://api.com/login?password=pass123')
    assert 'REDACTED' in result or 'pass123' not in result

    result = sanitize_url('https://api.com/api?api_key=key123')
    assert 'REDACTED' in result or 'key123' not in result

    # Should preserve non-sensitive params
    result = sanitize_url('https://api.com/search?q=hello&page=1')
    assert 'hello' in result
    assert 'page=1' in result

    # Should handle URLs without query params
    assert sanitize_url('https://api.com/users') == 'https://api.com/users'

    print('✓ test_sanitize_url passed')


def test_sanitize_header_value():
    """Test header value sanitization."""
    # Authorization headers
    assert sanitize_header_value('Authorization', 'Bearer abc123') == 'Bearer ***REDACTED***'
    assert sanitize_header_value('Authorization', 'Basic dXNlcjpwYXNz') == 'Basic ***REDACTED***'

    # Cookie headers
    result = sanitize_header_value('Cookie', 'session=abc123; theme=dark')
    assert 'session=***REDACTED***' in result
    assert 'theme=***REDACTED***' in result

    # Non-sensitive headers should pass through
    assert sanitize_header_value('Content-Type', 'application/json') == 'application/json'

    print('✓ test_sanitize_header_value passed')


def test_sanitize_headers():
    """Test headers list sanitization."""
    headers = [
        {'name': 'Authorization', 'value': 'Bearer token123'},
        {'name': 'Content-Type', 'value': 'application/json'},
        {'name': 'X-Api-Key', 'value': 'secret-key'},
    ]
    result = sanitize_headers(headers)

    assert result[0]['value'] == 'Bearer ***REDACTED***'
    assert result[1]['value'] == 'application/json'
    assert result[2]['value'] == '***REDACTED***'

    print('✓ test_sanitize_headers passed')


def test_sanitize_text():
    """Test text pattern sanitization."""
    # Password patterns
    assert '***REDACTED***' in sanitize_text('password=secret123')
    assert '***REDACTED***' in sanitize_text('passwd: mypass')

    # Token patterns
    assert '***REDACTED***' in sanitize_text('token=abc123def')

    # JWT tokens
    jwt = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U'
    assert '***JWT_REDACTED***' in sanitize_text(jwt)

    print('✓ test_sanitize_text passed')


def test_sanitize_json_body():
    """Test JSON body sanitization."""
    # Should redact sensitive fields
    body = '{"username": "john", "password": "secret123", "data": "safe"}'
    result = sanitize_json_body(body)
    assert '"password": "***REDACTED***"' in result
    assert '"data": "safe"' in result

    # Should handle nested objects
    nested = '{"user": {"name": "john", "token": "abc123"}}'
    result = sanitize_json_body(nested)
    assert '***REDACTED***' in result

    # Should handle invalid JSON gracefully
    invalid = 'not json password=secret'
    result = sanitize_json_body(invalid)
    assert '***REDACTED***' in result

    print('✓ test_sanitize_json_body passed')


def test_sanitize_har_entry():
    """Test HAR entry sanitization."""
    entry = {
        'request': {
            'url': 'https://api.com/auth?token=secret',
            'headers': [
                {'name': 'Authorization', 'value': 'Bearer abc123'},
                {'name': 'Content-Type', 'value': 'application/json'},
            ],
            'cookies': [{'name': 'session', 'value': 'xyz789'}],
            'queryString': [
                {'name': 'token', 'value': 'secret'},
                {'name': 'page', 'value': '1'},
            ],
            'postData': {
                'mimeType': 'application/json',
                'text': '{"password": "secret123"}',
            },
        },
        'response': {
            'headers': [
                {'name': 'Set-Cookie', 'value': 'session=abc123'},
            ],
            'cookies': [{'name': 'auth', 'value': 'token123'}],
        },
    }

    result = sanitize_har_entry(entry)

    # Check URL sanitization (may be URL-encoded)
    assert 'REDACTED' in result['request']['url'] or 'secret' not in result['request']['url']

    # Check header sanitization
    assert result['request']['headers'][0]['value'] == 'Bearer ***REDACTED***'
    assert result['request']['headers'][1]['value'] == 'application/json'

    # Check cookie sanitization
    assert result['request']['cookies'][0]['value'] == '***REDACTED***'

    # Check query string sanitization
    assert result['request']['queryString'][0]['value'] == '***REDACTED***'
    assert result['request']['queryString'][1]['value'] == '1'

    # Check post data sanitization
    assert 'REDACTED' in result['request']['postData']['text'] or 'secret123' not in result['request']['postData']['text']

    print('✓ test_sanitize_har_entry passed')


def test_sanitize_index_entry():
    """Test index entry sanitization."""
    entry = {
        'id': 1,
        'url': 'https://api.com/auth?token=secret&page=1',
        'path': '/auth?token=secret&page=1',
        'host': 'api.com',
        'method': 'GET',
    }

    result = sanitize_index_entry(entry)

    # URL-encoded REDACTED or original secret not present
    assert 'REDACTED' in result['url'] or 'secret' not in result['url']
    assert 'REDACTED' in result['path'] or 'secret' not in result['path']
    assert result['host'] == 'api.com'
    assert result['method'] == 'GET'

    print('✓ test_sanitize_index_entry passed')


def run_all_tests():
    """Run all tests."""
    print('Running sanitize module tests...\n')

    test_sanitize_url()
    test_sanitize_header_value()
    test_sanitize_headers()
    test_sanitize_text()
    test_sanitize_json_body()
    test_sanitize_har_entry()
    test_sanitize_index_entry()

    print('\n✓ All tests passed!')


if __name__ == '__main__':
    run_all_tests()
