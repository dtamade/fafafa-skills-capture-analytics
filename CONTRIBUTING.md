# Contributing to Capture Analytics

First off, thank you for considering contributing to Capture Analytics! It's people like you that make this project better for everyone.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Testing](#testing)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to dtamade@gmail.com.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/capture-analytics.git
   cd capture-analytics
   ```
3. Set up the development environment:
   ```bash
   ./install.sh
   ```
4. Create a branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates.

When you create a bug report, please include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (commands, URLs, etc.)
- **Describe the behavior you observed and what you expected**
- **Include logs and error messages**
- **Specify your environment** (OS, Python version, mitmproxy version)

Use our [bug report template](.github/ISSUE_TEMPLATE/bug_report.md) for guidance.

### Suggesting Features

Feature suggestions are welcome! Please:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the proposed feature
- **Explain why this feature would be useful** to most users
- **List any alternatives you've considered**

Use our [feature request template](.github/ISSUE_TEMPLATE/feature_request.md) for guidance.

### Pull Requests

1. **Ensure your PR addresses an existing issue** or create one first
2. **Follow the coding standards** outlined below
3. **Include tests** for new functionality
4. **Update documentation** if needed
5. **Keep PRs focused** - one feature or fix per PR

## Development Setup

### Prerequisites

- Python 3.8+
- mitmproxy 10.0+
- Bash 4.0+
- Git

### Environment Setup

```bash
# Clone and enter the project
git clone https://github.com/dtamade/fafafa-skills-capture-analytics.git
cd capture-analytics

# Install dependencies
./install.sh

# Verify everything works
./install.sh --check
```

### Running Tests

```bash
# Run all Python tests
python3 -m pytest tests/ -v

# Run all Shell tests
for test in tests/test_*.sh; do bash "$test"; done

# Run specific test file
python3 -m pytest tests/test_sanitize.py -v
```

## Coding Standards

### Python

- Follow [PEP 8](https://peps.python.org/pep-0008/) style guidelines
- Use type hints where practical
- Document public functions with docstrings
- Maximum line length: 100 characters

```python
def process_flow(flow_path: str, output_dir: str) -> dict:
    """
    Process a mitmproxy flow file.

    Args:
        flow_path: Path to the .flow file
        output_dir: Directory for output files

    Returns:
        Dict containing processing results and statistics
    """
    # Implementation
```

### Shell Scripts

- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Quote all variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals, not `[ ]`
- Document with comments for complex logic

```bash
#!/usr/bin/env bash
set -euo pipefail

# Description of what this script does
main() {
    local input_file="$1"

    if [[ ! -f "$input_file" ]]; then
        echo "Error: File not found: $input_file" >&2
        exit 1
    fi

    # Process the file...
}

main "$@"
```

### Documentation

- Use Markdown for documentation files
- Keep README files concise and focused
- Update CHANGELOG.md for user-facing changes
- Include code examples where helpful

## Commit Guidelines

### Commit Message Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples

```
feat(capture): add WebSocket traffic support

Add support for capturing and analyzing WebSocket frames.
- New ws_analyzer.py module
- Updated flow_report.py to include WS stats
- Added tests for WebSocket handling

Closes #42
```

```
fix(sanitize): handle Unicode in header values

Previously, headers with non-ASCII characters would cause
the sanitizer to crash. Now properly encoded.

Fixes #57
```

### Guidelines

- Use imperative mood: "Add feature" not "Added feature"
- Keep subject line under 72 characters
- Separate subject from body with blank line
- Reference issues in footer when applicable

## Testing

### Test Requirements

- All new features must include tests
- Bug fixes should include regression tests
- Tests should be deterministic (no flaky tests)
- Mock external dependencies when possible

### Test Structure

```
tests/
├── test_sanitize.py        # Unit tests for sanitize.py
├── test_flow_report.py     # Unit tests for flow_report.py
├── test_capture.sh         # Integration tests for capture scripts
└── ...
```

### Writing Tests

Python tests use pytest:

```python
import pytest
from scripts.sanitize import sanitize_headers

class TestSanitizeHeaders:
    def test_removes_authorization(self):
        headers = {"Authorization": "Bearer secret123"}
        result = sanitize_headers(headers)
        assert "Authorization" not in result or result["Authorization"] == "[REDACTED]"

    def test_preserves_safe_headers(self):
        headers = {"Content-Type": "application/json"}
        result = sanitize_headers(headers)
        assert result["Content-Type"] == "application/json"
```

Shell tests follow this pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail

# test_capture.sh - Integration tests for capture-session.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

test_validate_url() {
    if "$SCRIPT_DIR/scripts/capture-session.sh" validate "https://example.com" >/dev/null 2>&1; then
        echo "PASS: validate accepts valid URL"
        ((PASS++))
    else
        echo "FAIL: validate rejects valid URL"
        ((FAIL++))
    fi
}

# Run tests
test_validate_url

echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
```

## Questions?

If you have questions, feel free to:

- Open a [Discussion](https://github.com/dtamade/fafafa-skills-capture-analytics/discussions)
- Contact maintainer: dtamade@gmail.com
- QQ Group: 685403987
- Studio: fafafa studio

Thank you for contributing!
