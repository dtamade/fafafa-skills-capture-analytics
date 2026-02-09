# 贡献指南

首先，感谢你考虑为 Capture Analytics 做出贡献！正是像你这样的人让这个项目变得更好。

## 目录

- [行为准则](#行为准则)
- [开始之前](#开始之前)
- [如何贡献](#如何贡献)
  - [报告 Bug](#报告-bug)
  - [功能建议](#功能建议)
  - [Pull Request](#pull-request)
- [开发环境](#开发环境)
- [代码规范](#代码规范)
- [提交规范](#提交规范)
- [测试](#测试)

## 行为准则

本项目及其所有参与者都受我们的[行为准则](CODE_OF_CONDUCT.md)约束。参与即表示你同意遵守此准则。如有不当行为，请发送邮件至 dtamade@gmail.com 举报。

## 开始之前

1. 在 GitHub 上 Fork 本仓库
2. 克隆你的 Fork：
   ```bash
   git clone https://github.com/你的用户名/capture-analytics.git
   cd capture-analytics
   ```
3. 设置开发环境：
   ```bash
   ./install.sh
   ```
4. 为你的更改创建分支：
   ```bash
   git checkout -b feature/你的功能名称
   ```

## 如何贡献

### 报告 Bug

提交 Bug 报告前，请先搜索现有 Issue，避免重复。

提交 Bug 报告时，请包含以下信息：

- **使用清晰的标题**描述问题
- **详细描述复现步骤**
- **提供具体示例**（命令、URL 等）
- **描述实际行为与期望行为**
- **附上日志和错误信息**
- **说明你的环境**（操作系统、Python 版本、mitmproxy 版本）

请使用我们的 [Bug 报告模板](.github/ISSUE_TEMPLATE/bug_report.md)。

### 功能建议

我们欢迎功能建议！请：

- **使用清晰的标题**
- **详细描述**提议的功能
- **解释为什么这个功能对大多数用户有用**
- **列出你考虑过的替代方案**

请使用我们的[功能请求模板](.github/ISSUE_TEMPLATE/feature_request.md)。

### Pull Request

1. **确保你的 PR 对应一个已有的 Issue**，或者先创建一个
2. **遵循下面的代码规范**
3. **为新功能编写测试**
4. **按需更新文档**
5. **保持 PR 专注** —— 每个 PR 只做一件事

## 开发环境

### 前置条件

- Python 3.8+
- mitmproxy 10.0+
- Bash 4.0+
- Git

### 环境配置

```bash
# 克隆并进入项目
git clone https://github.com/dtamade/fafafa-skills-capture-analytics.git
cd capture-analytics

# 安装依赖
./install.sh

# 验证一切正常
./install.sh --check
```

### 运行测试

```bash
# 运行所有 Python 测试
python3 -m pytest tests/ -v

# 运行所有 Shell 测试
for test in tests/test_*.sh; do bash "$test"; done

# 运行特定测试文件
python3 -m pytest tests/test_sanitize.py -v
```

## 代码规范

### Python

- 遵循 [PEP 8](https://peps.python.org/pep-0008/) 风格指南
- 尽量使用类型提示
- 为公共函数编写文档字符串
- 单行最大长度：100 字符

```python
def process_flow(flow_path: str, output_dir: str) -> dict:
    """
    处理 mitmproxy flow 文件。

    Args:
        flow_path: .flow 文件路径
        output_dir: 输出文件目录

    Returns:
        包含处理结果和统计信息的字典
    """
    # 实现代码
```

### Shell 脚本

- 使用 `#!/usr/bin/env bash` 作为 shebang
- 启用严格模式：`set -euo pipefail`
- 引用所有变量：`"$var"` 而不是 `$var`
- 使用 `[[ ]]` 而不是 `[ ]` 进行条件判断
- 为复杂逻辑添加注释

```bash
#!/usr/bin/env bash
set -euo pipefail

# 脚本功能说明
main() {
    local input_file="$1"

    if [[ ! -f "$input_file" ]]; then
        echo "错误：文件不存在：$input_file" >&2
        exit 1
    fi

    # 处理文件...
}

main "$@"
```

### 文档

- 使用 Markdown 编写文档
- README 保持简洁，详细内容放在单独文档中
- 适当添加代码示例
- 更新 CHANGELOG.md 记录用户可见的变更

## 提交规范

### 提交信息格式

我们遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```
<类型>(<范围>): <主题>

<正文>

<页脚>
```

### 类型

- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档变更
- `style`: 代码格式调整（不影响功能）
- `refactor`: 代码重构
- `test`: 添加或更新测试
- `chore`: 构建、工具等杂项

### 示例

```
feat(capture): 添加 WebSocket 流量支持

新增对 WebSocket 帧的捕获和分析支持。
- 新增 ws_analyzer.py 模块
- 更新 flow_report.py 以包含 WS 统计
- 添加 WebSocket 处理测试

Closes #42
```

```
fix(sanitize): 处理请求头中的 Unicode 字符

之前，包含非 ASCII 字符的请求头会导致脱敏失败。
现在已正确处理编码问题。

Fixes #57
```

### 提交指南

- 使用祈使语气："添加功能" 而不是 "添加了功能"
- 主题行不超过 72 个字符
- 用空行分隔主题和正文
- 在页脚引用相关 Issue

## 测试

### 测试要求

- 所有新功能必须包含测试
- Bug 修复应包含回归测试
- 测试应该是确定性的（不允许偶发失败）
- 尽可能模拟外部依赖

### 测试结构

```
tests/
├── test_sanitize.py        # sanitize.py 的单元测试
├── test_flow_report.py     # flow_report.py 的单元测试
├── test_capture.sh         # capture 脚本的集成测试
└── ...
```

### 编写测试

Python 测试使用 pytest：

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

Shell 测试遵循以下模式：

```bash
#!/usr/bin/env bash
set -euo pipefail

# test_capture.sh - capture-session.sh 的集成测试

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

test_validate_url() {
    if "$SCRIPT_DIR/scripts/capture-session.sh" validate "https://example.com" >/dev/null 2>&1; then
        echo "PASS: validate 接受有效 URL"
        ((PASS++))
    else
        echo "FAIL: validate 拒绝了有效 URL"
        ((FAIL++))
    fi
}

# 运行测试
test_validate_url

echo "结果: $PASS 通过, $FAIL 失败"
exit $FAIL
```

## 有问题？

如果有任何问题，请：

- 在 [Discussions](https://github.com/dtamade/fafafa-skills-capture-analytics/discussions) 发起讨论
- 联系维护者：dtamade@gmail.com
- QQ群：685403987
- 工作室：fafafa studio

感谢你的贡献！
