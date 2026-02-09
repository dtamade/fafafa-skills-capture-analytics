#!/usr/bin/env python3
"""URL validation utility for capture-analytics skill.

Validates URL format, extracts domain, and optionally tests reachability.
Outputs JSON for programmatic consumption.
"""

import argparse
import json
import socket
import ssl
import sys
from typing import Optional
from urllib.parse import urlparse


def validate_url(url: str) -> tuple[bool, str, Optional[str]]:
    """Validate URL format and extract domain.

    Args:
        url: URL string to validate

    Returns:
        Tuple of (is_valid, normalized_url, domain_or_error)
    """
    if not url or not isinstance(url, str):
        return False, url or '', 'Empty or invalid URL'

    url = url.strip()

    # Check for valid scheme
    if not url.startswith(('http://', 'https://')):
        # Try to auto-fix common patterns
        if url.startswith('//'):
            url = 'https:' + url
        elif '://' not in url:
            # Looks like bare domain, add https
            url = 'https://' + url
        else:
            return False, url, 'URL must use http:// or https:// scheme'

    try:
        parsed = urlparse(url)
    except Exception as e:
        return False, url, f'URL parse error: {e}'

    # Must have valid scheme and host
    if parsed.scheme not in ('http', 'https'):
        return False, url, f'Invalid scheme: {parsed.scheme}'

    if not parsed.hostname:
        return False, url, 'Missing hostname'

    # Basic hostname validation
    hostname = parsed.hostname
    if len(hostname) > 253:
        return False, url, 'Hostname too long (max 253 chars)'

    # Check for obviously invalid hostnames
    if hostname.startswith('.') or hostname.endswith('.'):
        return False, url, 'Hostname cannot start or end with dot'

    if '..' in hostname:
        return False, url, 'Hostname cannot contain consecutive dots'

    # Check each label
    labels = hostname.split('.')
    for label in labels:
        if not label:
            return False, url, 'Empty label in hostname'
        if len(label) > 63:
            return False, url, f'Label too long: {label[:20]}...'
        # Allow alphanumeric, hyphens, but not starting/ending with hyphen
        if label.startswith('-') or label.endswith('-'):
            return False, url, f'Label cannot start/end with hyphen: {label}'

    # Must have at least 2 labels (domain + TLD) or be localhost/IP
    if len(labels) < 2:
        # Allow localhost and IP addresses
        if hostname == 'localhost':
            return True, url, hostname
        # Check if it's an IP address
        try:
            socket.inet_aton(hostname)
            return True, url, hostname
        except socket.error:
            pass
        try:
            socket.inet_pton(socket.AF_INET6, hostname)
            return True, url, hostname
        except socket.error:
            pass
        return False, url, 'Hostname must have domain and TLD (e.g., example.com)'

    return True, url, hostname


def check_reachable(url: str, timeout: float = 5.0) -> tuple[bool, Optional[str]]:
    """Check if URL is reachable (DNS resolves and port responds).

    Args:
        url: URL to check
        timeout: Connection timeout in seconds

    Returns:
        Tuple of (is_reachable, error_message)
    """
    try:
        parsed = urlparse(url)
        hostname = parsed.hostname
        port = parsed.port

        if port is None:
            port = 443 if parsed.scheme == 'https' else 80

        # DNS resolution
        try:
            socket.getaddrinfo(hostname, port, socket.AF_UNSPEC, socket.SOCK_STREAM)
        except socket.gaierror as e:
            return False, f'DNS resolution failed: {e}'

        # TCP connection test
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)

        try:
            if parsed.scheme == 'https':
                context = ssl.create_default_context()
                # Allow self-signed certs for testing
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
                sock = context.wrap_socket(sock, server_hostname=hostname)

            sock.connect((hostname, port))
            sock.close()
            return True, None

        except socket.timeout:
            return False, f'Connection timeout ({timeout}s)'
        except ConnectionRefusedError:
            return False, 'Connection refused'
        except ssl.SSLError as e:
            return False, f'SSL error: {e}'
        except OSError as e:
            return False, f'Connection error: {e}'
        finally:
            try:
                sock.close()
            except Exception:
                pass

    except Exception as e:
        return False, f'Unexpected error: {e}'


def main():
    parser = argparse.ArgumentParser(
        description='Validate URL format and optionally test reachability',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  %(prog)s "https://example.com"
  %(prog)s "example.com"                    # Auto-adds https://
  %(prog)s "https://example.com" --check-reachable
  %(prog)s "https://example.com" --check-reachable --timeout 3
'''
    )

    parser.add_argument('url', help='URL to validate')
    parser.add_argument(
        '--check-reachable', '-c',
        action='store_true',
        help='Test if URL is reachable (DNS + connection)'
    )
    parser.add_argument(
        '--timeout', '-t',
        type=float,
        default=5.0,
        help='Timeout for reachability check in seconds (default: 5)'
    )

    args = parser.parse_args()

    result = {
        'valid': False,
        'url': args.url,
        'normalized_url': None,
        'domain': None,
        'reachable': None,
        'error': None
    }

    # Validate URL format
    is_valid, normalized_url, domain_or_error = validate_url(args.url)

    result['normalized_url'] = normalized_url

    if not is_valid:
        result['error'] = domain_or_error
        print(json.dumps(result, ensure_ascii=False))
        sys.exit(1)

    result['valid'] = True
    result['domain'] = domain_or_error  # This is the domain when valid

    # Optional reachability check
    if args.check_reachable:
        is_reachable, reach_error = check_reachable(normalized_url, args.timeout)
        result['reachable'] = is_reachable
        if not is_reachable:
            result['reachable_error'] = reach_error

    print(json.dumps(result, ensure_ascii=False))
    sys.exit(0 if result['valid'] else 1)


if __name__ == '__main__':
    main()
