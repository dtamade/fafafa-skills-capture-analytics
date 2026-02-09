#!/usr/bin/env python3
"""Sanitize sensitive information from capture data.

This module provides functions to redact sensitive data like:
- Authorization headers (Bearer tokens, Basic auth)
- Cookies and Set-Cookie headers
- API keys in URLs and headers
- Passwords in request bodies
- Session tokens
"""

import re
import json
from typing import Any, Dict, List, Optional
from urllib.parse import parse_qs, urlencode, urlparse, urlunparse


# Patterns for sensitive URL parameters
SENSITIVE_URL_PARAMS = {
    'token', 'access_token', 'refresh_token', 'id_token',
    'api_key', 'apikey', 'api-key', 'key',
    'password', 'passwd', 'pwd', 'pass',
    'secret', 'client_secret',
    'session', 'sessionid', 'session_id',
    'auth', 'authorization',
    'credential', 'credentials',
}

# Patterns for sensitive headers
SENSITIVE_HEADERS = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
    'x-access-token',
    'x-session-id',
    'x-csrf-token',
    'x-xsrf-token',
}

# Regex patterns for sensitive values in text
SENSITIVE_PATTERNS = [
    (re.compile(r'(password|passwd|pwd|pass)\s*[=:]\s*["\']?([^"\'&\s]+)', re.I), r'\1=***REDACTED***'),
    (re.compile(r'(token|api_key|apikey|secret|session_id|sessionid)\s*[=:]\s*["\']?([^"\'&\s]+)', re.I), r'\1=***REDACTED***'),
    (re.compile(r'Bearer\s+[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+', re.I), 'Bearer ***JWT_REDACTED***'),
    (re.compile(r'Bearer\s+[A-Za-z0-9\-_]{20,}', re.I), 'Bearer ***TOKEN_REDACTED***'),
    (re.compile(r'Basic\s+[A-Za-z0-9+/=]{10,}', re.I), 'Basic ***REDACTED***'),
]


def sanitize_url(url: str) -> str:
    """Remove sensitive parameters from URL."""
    try:
        parsed = urlparse(url)
        if not parsed.query:
            return url

        params = parse_qs(parsed.query, keep_blank_values=True)
        sanitized_params = {}

        for key, values in params.items():
            if key.lower() in SENSITIVE_URL_PARAMS:
                sanitized_params[key] = ['***REDACTED***']
            else:
                sanitized_params[key] = values

        new_query = urlencode(sanitized_params, doseq=True)
        return urlunparse(parsed._replace(query=new_query))
    except Exception:
        return url


def sanitize_header_value(name: str, value: str) -> str:
    """Sanitize a header value based on header name."""
    name_lower = name.lower()

    if name_lower in SENSITIVE_HEADERS:
        if name_lower == 'authorization':
            # Keep the auth type but redact the token
            if value.lower().startswith('bearer '):
                return 'Bearer ***REDACTED***'
            elif value.lower().startswith('basic '):
                return 'Basic ***REDACTED***'
            else:
                return '***REDACTED***'
        elif name_lower in ('cookie', 'set-cookie'):
            # Redact cookie values but keep names
            return re.sub(r'=([^;]+)', '=***REDACTED***', value)
        else:
            return '***REDACTED***'

    return value


def sanitize_headers(headers: List[Dict[str, str]]) -> List[Dict[str, str]]:
    """Sanitize a list of headers."""
    return [
        {'name': h['name'], 'value': sanitize_header_value(h['name'], h['value'])}
        for h in headers
    ]


def sanitize_text(text: str) -> str:
    """Sanitize sensitive patterns in plain text."""
    result = text
    for pattern, replacement in SENSITIVE_PATTERNS:
        result = pattern.sub(replacement, result)
    return result


def sanitize_json_body(text: str) -> str:
    """Sanitize sensitive fields in JSON body."""
    try:
        data = json.loads(text)
        sanitized = _sanitize_dict(data)
        return json.dumps(sanitized, ensure_ascii=False)
    except (json.JSONDecodeError, TypeError):
        # Not valid JSON, apply text sanitization
        return sanitize_text(text)


_MAX_SANITIZE_DEPTH = 50


def _sanitize_dict(obj: Any, _depth: int = 0) -> Any:
    """Recursively sanitize a dictionary."""
    if _depth > _MAX_SANITIZE_DEPTH:
        return "[nested too deep]" if isinstance(obj, (dict, list)) else obj
    if isinstance(obj, dict):
        result = {}
        for key, value in obj.items():
            if key.lower() in SENSITIVE_URL_PARAMS:
                result[key] = '***REDACTED***'
            else:
                result[key] = _sanitize_dict(value, _depth + 1)
        return result
    elif isinstance(obj, list):
        return [_sanitize_dict(item, _depth + 1) for item in obj]
    elif isinstance(obj, str):
        return sanitize_text(obj)
    else:
        return obj


def sanitize_har_entry(entry: Dict[str, Any]) -> Dict[str, Any]:
    """Sanitize a single HAR entry."""
    result = entry.copy()

    # Sanitize request
    if 'request' in result:
        req = result['request'].copy()

        # URL
        if 'url' in req:
            req['url'] = sanitize_url(req['url'])

        # Headers
        if 'headers' in req:
            req['headers'] = sanitize_headers(req['headers'])

        # Cookies
        if 'cookies' in req:
            for cookie in req['cookies']:
                cookie['value'] = '***REDACTED***'

        # Query string
        if 'queryString' in req:
            for qs in req['queryString']:
                if qs['name'].lower() in SENSITIVE_URL_PARAMS:
                    qs['value'] = '***REDACTED***'

        # Post data
        if 'postData' in req and 'text' in req['postData']:
            mime = req['postData'].get('mimeType', '')
            if 'json' in mime.lower():
                req['postData']['text'] = sanitize_json_body(req['postData']['text'])
            else:
                req['postData']['text'] = sanitize_text(req['postData']['text'])

        result['request'] = req

    # Sanitize response
    if 'response' in result:
        resp = result['response'].copy()

        # Headers
        if 'headers' in resp:
            resp['headers'] = sanitize_headers(resp['headers'])

        # Cookies
        if 'cookies' in resp:
            for cookie in resp['cookies']:
                cookie['value'] = '***REDACTED***'

        # Content (optional - may want to keep for analysis)
        # Uncomment if you want to sanitize response bodies too:
        # if 'content' in resp and 'text' in resp['content']:
        #     mime = resp['content'].get('mimeType', '')
        #     if 'json' in mime.lower():
        #         resp['content']['text'] = sanitize_json_body(resp['content']['text'])

        result['response'] = resp

    return result


def sanitize_har(har: Dict[str, Any]) -> Dict[str, Any]:
    """Sanitize an entire HAR file."""
    result = har.copy()
    if 'log' in result and 'entries' in result['log']:
        result['log'] = result['log'].copy()
        result['log']['entries'] = [
            sanitize_har_entry(entry) for entry in result['log']['entries']
        ]
    return result


def sanitize_index_entry(entry: Dict[str, Any]) -> Dict[str, Any]:
    """Sanitize a single index entry."""
    result = entry.copy()
    if 'url' in result:
        result['url'] = sanitize_url(result['url'])
    if 'path' in result:
        # Sanitize query params in path
        if '?' in result['path']:
            result['path'] = sanitize_url('http://x' + result['path']).replace('http://x', '')
    return result


if __name__ == '__main__':
    # Test sanitization
    test_url = 'https://api.example.com/auth?token=secret123&user=john'
    print(f'Original URL: {test_url}')
    print(f'Sanitized URL: {sanitize_url(test_url)}')

    test_header = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c'
    print(f'Original header: {test_header}')
    print(f'Sanitized header: {sanitize_header_value("Authorization", test_header)}')

    test_json = '{"username": "john", "password": "secret123", "data": "safe"}'
    print(f'Original JSON: {test_json}')
    print(f'Sanitized JSON: {sanitize_json_body(test_json)}')
