<p align="center">
  <img src="https://raw.githubusercontent.com/dtamade/fafafa-skills-capture-analytics/main/assets/logo.png" alt="Capture Analytics Logo" width="120" height="120">
</p>

<h1 align="center">Capture Analytics</h1>

<p align="center">
  <strong>AI 驱动的自主网络流量抓包与深度分析技能 —— 专为 Claude Code 打造</strong>
</p>

<p align="center">
  <a href="https://github.com/dtamade/fafafa-skills-capture-analytics/actions"><img src="https://img.shields.io/github/actions/workflow/status/dtamade/fafafa-skills-capture-analytics/ci.yml?branch=main&style=flat-square&logo=github" alt="CI 状态"></a>
  <a href="https://github.com/dtamade/fafafa-skills-capture-analytics/releases"><img src="https://img.shields.io/github/v/release/dtamade/fafafa-skills-capture-analytics?style=flat-square&logo=github" alt="版本"></a>
  <a href="https://github.com/dtamade/fafafa-skills-capture-analytics/blob/main/LICENSE"><img src="https://img.shields.io/github/license/dtamade/fafafa-skills-capture-analytics?style=flat-square" alt="许可证"></a>
  <a href="https://github.com/dtamade/fafafa-skills-capture-analytics"><img src="https://img.shields.io/github/stars/dtamade/fafafa-skills-capture-analytics?style=flat-square&logo=github" alt="Stars"></a>
</p>

<p align="center">
  <a href="#特性">特性</a> |
  <a href="#快速开始">快速开始</a> |
  <a href="#安装">安装</a> |
  <a href="#使用方法">使用方法</a> |
  <a href="docs/release-checklist.md">发布清单</a> |
  <a href="#安全">安全</a> |
  <a href="README.md">English</a>
</p>

---

## 这是什么？

Capture Analytics 是一个 Claude Code 技能，它让 AI 能够**自主**抓包并分析网络流量。与需要手动操作的传统工具不同，这个技能使 AI 能够：

1. **启动** mitmproxy 拦截 HTTP/HTTPS/WebSocket 流量
2. **驱动** Playwright 浏览器浏览目标网站
3. **处理** 通过自动化流水线处理抓包数据
4. **分析** 结构化输出并生成综合报告

**这不仅仅是文档** —— 而是一个**面向行动的技能**，让 AI 能够端到端地执行完整的抓包-分析工作流。

## 特性

- **自主抓包** - 使用 mitmproxy 进行 AI 驱动的流量拦截
- **智能浏览器自动化** - Playwright 驱动的网站探索
- **智能输入提取** - 从自然语言中提取 URL 和分析目标
- **多格式输出** - HAR、NDJSON 索引、AI 友好摘要
- **安全优先** - 授权确认、数据脱敏、范围控制
- **跨平台** - Linux (GNOME)、macOS 及手动代理模式
- **全面分析** - 性能分析、安全检测、调试诊断、API 发现
- **120 个测试用例** - 健壮的测试覆盖（79 Python + 41 Shell）

## 快速开始

```bash
# 1. 检查环境（不做任何修改）
./install.sh --check

# 2. 安装依赖（如需要）
./install.sh

# 3. 告诉 Claude Code：
#    "帮我分析 https://example.com 的网络请求"
#    或者："抓包看看这个网站为什么这么慢"
```

就这么简单。剩下的事情 Claude 会自动完成：启动代理、驱动浏览器、停止抓包、分析结果。

## 安装

### 前置条件

- Python 3.8+
- mitmproxy 10.0+
- Bash 4.0+
- Claude Code + Playwright MCP

```bash
# 安装 mitmproxy
pip install mitmproxy

# 验证安装
mitmdump --version
python3 -c "from mitmproxy.io import FlowReader; print('OK')"
```

### 安装为用户级技能

```bash
# 克隆到技能目录
git clone https://github.com/dtamade/fafafa-skills-capture-analytics.git \
  ~/.claude/skills/capture-analytics

# 或者从现有位置创建符号链接
ln -s /path/to/capture-analytics ~/.claude/skills/capture-analytics
```

### 安装为项目级技能

```bash
# 在你的项目目录中
mkdir -p .claude/skills
git clone https://github.com/dtamade/fafafa-skills-capture-analytics.git \
  .claude/skills/capture-analytics
```

### 支持的平台

| 平台 | 代理后端 | 说明 |
|------|----------|------|
| Linux (GNOME) | gsettings | 自动检测 |
| macOS | networksetup | 自动检测 |
| 任意（程序模式） | 无 | 使用 `--program` 参数，手动配置代理 |

## 使用方法

### AI 驱动模式（推荐）

直接告诉 Claude Code 你想分析什么：

```
"帮我分析 https://example.com 的网络请求"
"抓包看看这个 API 为什么返回错误"
"分析一下 mysite.com 的性能问题，这是我的网站"
```

Claude 会：
1. 询问授权确认（安全检查）
2. 启动 mitmproxy 抓包
3. 通过 Playwright 打开浏览器
4. 浏览并探索网站
5. 停止抓包并处理数据
6. 呈现分析结果

### 智能输入提取

技能会智能地从你的请求中提取信息：

| 你说 | AI 理解 |
|------|---------|
| "分析 example.com 的性能" | URL=example.com, 目标=性能分析 |
| "看看 mysite.com 为什么慢，我有权限" | URL=mysite.com, 授权=已确认 |
| "帮我抓包" | AI 会询问 URL 和授权 |

### 手动模式

```bash
# 启动抓包（需要授权确认）
./scripts/capture-session.sh start https://example.com \
  --confirm YES_I_HAVE_AUTHORIZATION

# （手动操作浏览器，代理地址 127.0.0.1:18080）

# 停止并分析
./scripts/capture-session.sh stop
```

### 范围控制

```bash
# 只抓取特定主机的流量
./scripts/capture-session.sh start https://example.com \
  --allow-hosts "example.com,*.example.com"

# 或者使用策略文件
./scripts/capture-session.sh start https://example.com \
  --policy config/policy.json
```

### 命令参考

```bash
capture-session.sh start <url>      # 启动抓包（需要 --confirm）
capture-session.sh stop             # 停止抓包并生成分析
capture-session.sh status           # 检查抓包状态
capture-session.sh validate <url>   # 验证 URL 格式和可达性
capture-session.sh analyze          # 生成 AI 分析包
capture-session.sh doctor           # 检查环境前置条件
scripts/git-doctor.sh               # 诊断 Git 同步/鉴权/连通性
capture-session.sh cleanup          # 清理旧的抓包数据
capture-session.sh diff <a> <b>     # 对比两次抓包
```

## 输出文件

抓包完成后，你会得到这些文件：

| 文件 | 说明 |
|------|------|
| `captures/latest.flow` | 原始 mitmproxy 抓包数据 |
| `captures/latest.har` | HAR 1.2 归档文件 |
| `captures/latest.index.ndjson` | 逐请求结构化索引 |
| `captures/latest.summary.md` | 快速统计摘要 |
| `captures/latest.ai.json` | 结构化分析输入 |
| `captures/latest.ai.md` | AI 友好摘要 |

## 五阶段工作流

```
阶段 1: RECON（侦察）    → 理解目标，选择策略
阶段 2: CAPTURE（抓包）  → 启动 mitmproxy
阶段 3: EXPLORE（探索）  → 通过代理使用 Playwright 浏览
阶段 4: HARVEST（收获）  → 停止抓包，处理数据
阶段 5: ANALYZE（分析）  → 读取输出，生成报告
```

## 安全

### 授权要求

- 抓包需要明确授权：`--confirm YES_I_HAVE_AUTHORIZATION`
- AI 必须在启动抓包前确认授权
- 内部脚本的直接调用会被阻止

### 敏感数据保护

- 敏感数据（令牌、密码、Cookie）会自动脱敏
- 脱敏采用**失败即关闭**策略：如果脱敏模块失败，抓包会中止
- 仅在受控测试环境中使用 `--allow-no-sanitize`

### 范围控制

- 使用 `--allow-hosts` 或 `--policy` 限制抓包范围
- 默认：从目标 URL 域名自动生成范围
- 超出范围的流量会记录到 `*.scope_audit.json`

### 私网保护

- URL 验证默认阻止私有/回环 IP
- 使用 `--allow-private` 覆盖（用于本地开发）

详见 [SECURITY_GUIDELINES.md](references/SECURITY_GUIDELINES.md)。

## 故障排除

| 现象 | 原因 | 解决方案 |
|------|------|----------|
| `Missing command: mitmdump` | mitmproxy 未安装 | `pip install mitmproxy` |
| `Port is already in use: 18080` | 另一个抓包正在运行 | `./scripts/stopCaptures.sh` 或使用 `-P <port>` |
| `Found stale state file` | 上次抓包异常退出 | `./scripts/startCaptures.sh --force-recover` |
| HAR 状态: `failed` | mitmdump HAR 导出错误 | 尝试 `--har-backend python` |

## 项目结构

```
capture-analytics/
├── SKILL.md                    # 主技能文件
├── skill-rules.json            # 触发器配置
├── install.sh                  # 环境检查与安装器
├── requirements.txt            # Python 依赖
├── scripts/                    # Shell 和 Python 脚本
│   ├── capture-session.sh      # 统一入口
│   ├── startCaptures.sh        # 启动 mitmproxy
│   ├── stopCaptures.sh         # 停止并处理流水线
│   └── ...                     # 分析工具
├── references/                 # 详细文档
├── templates/                  # 报告模板
└── tests/                      # 测试套件（120 个测试）
```

## 贡献

欢迎贡献！请在提交 Issue 或 Pull Request 之前阅读我们的[贡献指南](CONTRIBUTING_CN.md)和[行为准则](CODE_OF_CONDUCT.md)。

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 联系方式

- **QQ群**: 685403987
- **邮箱**: dtamade@gmail.com
- **工作室**: fafafa studio
- **GitHub Issues**: [报告 Bug](https://github.com/dtamade/fafafa-skills-capture-analytics/issues)

---

<p align="center">
  用心制作 by <a href="https://github.com/dtamade">dtamade</a> · fafafa studio
</p>
