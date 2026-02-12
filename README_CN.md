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
- **范围控制** - 限制抓包到特定主机
- **跨平台** - Linux (GNOME)、macOS 及手动代理模式
- **全面分析** - 性能分析、安全检测、调试诊断、API 发现

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

### 安装为用户级技能（推荐）

```bash
# 仓库可克隆到任意目录
git clone https://github.com/dtamade/fafafa-skills-capture-analytics.git \
  ~/src/fafafa-skills-capture-analytics
cd ~/src/fafafa-skills-capture-analytics

# 依赖诊断
./install.sh --check
./install.sh --doctor

# 以“本地副本”方式安装到 Claude（默认，不依赖外部软链接）
./install.sh --install-to ~/.claude/skills/capture-analytics
```

可选（外部依赖模式）：

```bash
# 仅在你明确需要软链接时使用
./install.sh --symlink --install-to ~/.claude/skills/capture-analytics
```

### 安装为项目级技能

```bash
# 安装到项目级 .claude/skills
./install.sh --install-to /path/to/your-project/.claude/skills/capture-analytics
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
"分析一下 localhost:3000 的性能问题"
```

Claude 会：
1. 启动 mitmproxy 抓包
2. 通过 Playwright 打开浏览器
3. 浏览并探索网站
4. 停止抓包并处理数据
5. 呈现分析结果

### 智能输入提取

技能会智能地从你的请求中提取信息：

| 你说 | AI 理解 |
|------|---------|
| "分析 example.com 的性能" | URL=example.com, 目标=性能分析 |
| "抓包 localhost:3000" | URL=https://localhost:3000 |
| "看看 192.168.1.1 的请求" | URL=https://192.168.1.1 |

### 会话/Cookie 场景决策

- **可跳过抓包**：你已掌握完整请求（URL/方法/headers/body/cookies），只需直连重放。
- **必须抓包**：会话状态、cookie、CSRF、OAuth 跳转或隐藏请求链路未知。
- `curl` 烟雾测试仅用于**代理连通性验证**，不能替代真实登录/会话业务链路。

### 手动模式

```bash
# 启动抓包
./scripts/capture-session.sh start https://example.com

# （手动操作浏览器，代理地址 127.0.0.1:18080）

# 停止并分析
./scripts/capture-session.sh stop
```

### 程序模式（非浏览器流量）

```bash
# 启动抓包
./scripts/capture-session.sh start https://example.com

# 用临时代理环境变量启动目标程序
./scripts/runWithProxyEnv.sh -P 18080 -- <your_program_command>

# 停止并分析
./scripts/capture-session.sh stop
```

### 浏览器回退助手

```bash
# 启动抓包
./scripts/capture-session.sh start https://example.com

# 一条命令自动处理有头/无头回退
./scripts/driveBrowserTraffic.sh --url https://example.com -P 18080 --mode auto

# 停止并分析
./scripts/capture-session.sh stop
```

### 范围控制

```bash
# 只抓取特定主机的流量
./scripts/capture-session.sh start https://example.com \
  --allow-hosts "example.com,*.example.com"
```

### 自定义目录/端口示例

```bash
# 使用自定义工作目录
capture-session.sh start https://example.com -d /tmp/capture-demo

# 使用自定义代理端口
capture-session.sh start https://example.com -P 28080
```

### Navlog 示例

```bash
capture-session.sh navlog append --action navigate --url "https://example.com"
# 等号写法（某些 shell 更稳）
capture-session.sh navlog append --action=navigate --url=https://example.com
```

### 帮助命令

```bash
capture-session.sh --help
```

### 命令参考

```bash
capture-session.sh start <url>      # 启动抓包
capture-session.sh stop             # 停止抓包并生成分析
capture-session.sh status           # 检查抓包状态
capture-session.sh progress         # 显示抓包进度（请求数、大小、时长）
capture-session.sh analyze          # 生成 AI 分析包
capture-session.sh doctor           # 检查环境前置条件
capture-session.sh cleanup          # 清理旧的抓包数据
capture-session.sh diff <a> <b>     # 对比两次抓包
capture-session.sh navlog <cmd>     # 管理导航日志（init/append/show）
```

### 全局选项

- `-d, --dir <path>` 设置抓包产物输出目录
- `-P, --port <port>` 设置自定义代理端口（默认 18080）
- `-h, --help` 显示 CLI 帮助与可用命令
- `--force-recover` 启动前清理陈旧状态文件

### 清理选项

- `--keep-days <N>` 保留最近 N 天抓包
- `--keep-size <SIZE>` 按总大小限制保留抓包
- `--secure` 安全擦除旧文件
- `--dry-run` 仅预览清理结果

### 清理命令示例

```bash
capture-session.sh cleanup --keep-days 7
capture-session.sh cleanup --keep-size 1G --dry-run
capture-session.sh cleanup --secure --keep-days 3
```

## 输出文件

抓包完成后，你会得到这些文件：

| 文件 | 说明 |
|------|------|
| `captures/latest.flow` | 原始 mitmproxy 抓包数据 |
| `captures/latest.har` | HAR 1.2 归档文件 |
| `captures/latest.log` | 抓包运行日志（排障用） |
| `captures/latest.index.ndjson` | 逐请求结构化索引 |
| `captures/latest.summary.md` | 快速统计摘要 |
| `captures/latest.ai.json` | 结构化分析输入 |
| `captures/latest.ai.md` | AI 友好摘要 |
| `captures/latest.ai.bundle.txt` | 聚合后的 AI 可读文本 bundle |
| `captures/latest.manifest.json` | 会话清单元数据 |
| `captures/latest.scope_audit.json` | 越界流量审计报告 |
| `captures/latest.navigation.ndjson` | 浏览器导航事件日志 |

## 五阶段工作流

```
阶段 1: RECON（侦察）    → 理解目标，选择策略
阶段 2: CAPTURE（抓包）  → 启动统一入口（capture-session.sh start）
阶段 3: EXPLORE（探索）  → 通过代理使用 Playwright 浏览
阶段 4: HARVEST（收获）  → 停止统一入口（capture-session.sh stop）
阶段 5: ANALYZE（分析）  → 读取输出，生成报告
```

## 范围控制

- 使用 `--allow-hosts` 或 `--deny-hosts` 限制抓包范围
- 默认：从目标 URL 域名自动生成范围
- 超出范围的流量会记录到 `*.scope_audit.json`
- 使用 `--policy <file>` 加载自定义 JSON 范围策略

## 故障排除

| 现象 | 原因 | 解决方案 |
|------|------|----------|
| `Missing command: mitmdump` | mitmproxy 未安装 | `pip install mitmproxy` |
| `Port is already in use: 18080` | 另一个抓包正在运行 | `capture-session.sh stop` 或使用 `-P <port>` |
| `Found stale state file` | 上次抓包异常退出 | `capture-session.sh start https://example.com --force-recover` |
| HAR 状态: `failed` | mitmdump HAR 导出错误 | 尝试 `--har-backend python` |
| `Looks like you launched a headed browser without having a XServer running` | 非图形环境下使用有头 Playwright | 改用 headless 或 `xvfb-run`，或使用 `driveBrowserTraffic.sh --mode auto` |
| 抓包结果只有 curl 烟雾请求 | 只验证了代理连通性，未跑真实会话/业务流 | 从真实浏览器/程序上下文产生流量（含 cookies/headers/session） |

## 项目结构

```
capture-analytics/
├── SKILL.md                    # 主技能文件
├── skill-rules.json            # 触发器配置
├── install.sh                  # 环境检查与安装器
├── requirements.txt            # Python 依赖
├── scripts/                    # Shell 和 Python 脚本
│   ├── capture-session.sh      # 统一入口
│   ├── release-check.sh        # 一键发布就绪检查
│   ├── startCaptures.sh        # 启动 mitmproxy
│   ├── stopCaptures.sh         # 停止并处理流水线
│   ├── doctor.sh               # 环境诊断
│   ├── cleanupCaptures.sh      # 抓包保留与清理
│   ├── navlog.sh               # 导航日志助手
│   ├── runWithProxyEnv.sh      # 以临时代理环境变量运行命令
│   ├── diff_captures.py        # 抓包索引差异对比
│   ├── policy.py               # 范围策略辅助工具
│   ├── analyzeLatest.sh        # 生成最新分析产物
│   ├── ai.sh                   # AI bundle 快捷命令
│   ├── flow2har.py             # flow 转 HAR
│   ├── flow_report.py          # 生成索引与摘要
│   ├── ai_brief.py             # 生成 AI 分析简报
│   └── scope_audit.py          # 范围审计报告生成器
├── references/                 # 详细文档
├── templates/                  # 报告模板
└── tests/                      # 测试套件（详见 tests/）
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
