#!/usr/bin/env python3
"""Tests for skill trigger rules."""

import json
import re
import os


def load_rules():
    """Load skill-rules.json."""
    rules_path = os.path.join(os.path.dirname(__file__), '..', 'skill-rules.json')
    with open(rules_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def _check_trigger(prompt, rules):
    """Check if a prompt triggers the skill (helper, not a test)."""
    config = rules['capture-analytics']['promptTriggers']
    keywords = config['keywords']
    patterns = [re.compile(p, re.I) for p in config['intentPatterns']]

    keyword_match = any(kw.lower() in prompt.lower() for kw in keywords)
    pattern_match = any(p.search(prompt) for p in patterns)

    return keyword_match or pattern_match


def test_should_trigger():
    """Test prompts that SHOULD trigger the skill."""
    rules = load_rules()

    should_trigger = [
        # Chinese
        '帮我抓包分析 https://example.com',
        '我要抓包看看这个网站的请求',
        '用 mitmproxy 捕获流量',
        '分析这个 HAR 文件',
        '请求重放测试',
        '网络调试一下这个接口',
        # English
        'capture traffic from this website',
        'please analyze this website requests',
        'analyze network requests',
        'use mitmproxy to intercept HTTP',
        'debug network timeout issue',
        'debug websocket reconnect issue',
        'replay this API request',
        # WebSocket (newly added)
        'websocket 抓包分析',
        'capture websocket traffic',
        'ws 流量监控',
        # TLS
        'tls 握手分析',
        'ssl 分析',
        # Session/cookie/header aware triggers
        '抓包分析 session cookie 流程',
        'debug oauth redirect traffic capture',
    ]

    passed = 0
    failed = 0

    for prompt in should_trigger:
        if _check_trigger(prompt, rules):
            passed += 1
        else:
            print(f'✗ Should trigger but didn\'t: "{prompt}"')
            failed += 1

    print(f'Should trigger: {passed}/{len(should_trigger)} passed')
    assert failed == 0, f"{failed} prompts should have triggered but didn't"


def test_should_not_trigger():
    """Test prompts that should NOT trigger the skill."""
    rules = load_rules()

    should_not_trigger = [
        # Generic analysis (too broad)
        '帮我写个网站',
        '分析一下这段代码',
        '做个性能优化',
        '写个安全检查脚本',
        # Database
        '排查数据库慢查询',
        '分析 SQL 性能',
        # Frontend only
        '优化前端渲染性能',
        'CSS 样式分析',
        # Unrelated
        '帮我写文档',
        '代码审查',
        'git 提交',
        'How to mock network requests in Jest tests?',
        'Need endpoint mapping for OpenAPI spec',
        'share file with me',
        'news 分析 报告',
    ]

    passed = 0
    failed = 0

    for prompt in should_not_trigger:
        if not _check_trigger(prompt, rules):
            passed += 1
        else:
            print(f'✗ Should NOT trigger but did: "{prompt}"')
            failed += 1

    print(f'Should not trigger: {passed}/{len(should_not_trigger)} passed')
    assert failed == 0, f"{failed} prompts should not have triggered but did"


def test_edge_cases():
    """Test edge case prompts."""
    rules = load_rules()

    # These are borderline - document expected behavior
    edge_cases = [
        # Should trigger (specific enough)
        ('帮我分析接口超时问题，看看请求链路', True),
        ('debug network error on login', True),
        ('please analyze this website requests', True),
        # Should not trigger (too generic)
        ('帮我做网站安全分析报告', False),  # No capture/network context
        ('分析前端性能', False),  # Could be rendering, not network
        ('Need endpoint mapping for OpenAPI spec', False),
    ]

    passed = 0
    failed = 0

    for prompt, expected in edge_cases:
        result = _check_trigger(prompt, rules)
        if result == expected:
            passed += 1
        else:
            status = 'triggered' if result else 'didn\'t trigger'
            expected_str = 'trigger' if expected else 'not trigger'
            print(f'✗ Edge case {status}, expected {expected_str}: "{prompt}"')
            failed += 1

    print(f'Edge cases: {passed}/{len(edge_cases)} passed')
    assert failed == 0, f"{failed} edge case(s) failed"


def test_file_trigger_patterns_include_current_outputs():
    """Ensure file trigger patterns cover generated capture artifacts."""
    rules = load_rules()
    patterns = rules['capture-analytics']['fileTriggers']['pathPatterns']

    required_suffixes = [
        '.flow',
        '.har',
        '.ai.json',
        '.ai.md',
        '.summary.md',
        '.index.ndjson',
        '.manifest.json',
        '.scope_audit.json',
        '.navigation.ndjson',
        '.log',
    ]

    missing = []
    for suffix in required_suffixes:
        if not any(suffix in p for p in patterns):
            missing.append(suffix)

    assert not missing, f"Missing file trigger patterns for: {missing}"


def run_all_tests():
    """Run all trigger rule tests (standalone runner)."""
    print('Running trigger rule tests...\n')

    failed = False
    try:
        test_should_trigger()
    except AssertionError as e:
        print(f'✗ {e}')
        failed = True
    try:
        test_should_not_trigger()
    except AssertionError as e:
        print(f'✗ {e}')
        failed = True
    try:
        test_edge_cases()
    except AssertionError as e:
        print(f'✗ {e}')
        failed = True
    try:
        test_file_trigger_patterns_include_current_outputs()
    except AssertionError as e:
        print(f'✗ {e}')
        failed = True

    print()
    if not failed:
        print('✓ All trigger rule tests passed!')
        return 0
    else:
        print('✗ Some trigger rule tests failed')
        return 1


if __name__ == '__main__':
    exit(run_all_tests())


def test_multimode_enforcement_contract() -> None:
    """Capture skill should enforce task-adaptive traffic generation modes."""
    rules = load_rules()
    cfg = rules['capture-analytics']

    assert cfg.get('enforcement') == 'block', (
        'capture-analytics enforcement should remain block to avoid skipping capture workflow'
    )

    keywords = cfg.get('promptTriggers', {}).get('keywords', [])
    required = [
        'playwright',
        'browser automation',
        'HTTP_PROXY',
        'ALL_PROXY',
        'program mode',
        '环境变量抓包',
        'session cookie',
        'cookie header',
    ]
    for token in required:
        assert token in keywords, f'missing multimode trigger keyword: {token}'
