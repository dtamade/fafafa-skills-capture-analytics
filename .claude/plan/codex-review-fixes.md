# 修复计划：capture-analytics skill

基于 Codex 审查报告，按优先级修复所有问题。

## P0 - 安全与可执行性（必须修复）

### P0-1: 修复命令注入风险
**文件**: `scripts/capture-session.sh:122`
**问题**: `source "$ENV_FILE"` 直接执行外部文件内容
**修复**: 改用 `read_kv` 函数白名单解析，只提取需要的变量

### P0-2: 增加目标域约束
**文件**: `scripts/startCaptures.sh`, `scripts/capture-session.sh`
**问题**: 抓包范围无限制，可能抓取非授权流量
**修复**:
- 新增 `--allow-hosts` 参数限制抓包域名
- 在 manifest 记录授权域和时间窗

### P0-3: 实现敏感信息脱敏
**文件**: `scripts/flow2har.py`, `scripts/flow_report.py`, `scripts/ai_brief.py`
**问题**: URL、header、cookie、body 中的敏感信息未脱敏
**修复**:
- 新建 `scripts/sanitize.py` 脱敏模块
- 在输出前调用脱敏函数

### P0-4: 修正文档参数
**文件**: `SKILL.md:69`, `SKILL.md:112`
**问题**: `-d` 应传工作目录，不是 `.../captures`
**修复**: 更正示例命令

---

## P1 - 功能与体验优化

### P1-1: 统一策略命名
**文件**: `SKILL.md:94`, `templates/exploration-strategies.json:73`
**问题**: `stress-probe` vs `performance-probe` 不一致
**修复**: 统一为 `performance-probe`

### P1-2: 修复 capture-session.sh --help
**文件**: `scripts/capture-session.sh`
**问题**: 参数解析顺序导致 `--help` 不生效
**修复**: 在取 COMMAND 前先检查 `--help`

### P1-3: 补全依赖检测
**文件**: `scripts/startCaptures.sh`, `scripts/stopCaptures.sh`
**问题**: 只检测 mitmdump，未检测 python3 mitmproxy 模块
**修复**: 增加 Python 模块检测

### P1-4: 改进错误处理
**文件**: `scripts/stopCaptures.sh:334`, `scripts/stopCaptures.sh:349`
**问题**: 子流程错误被重定向到 /dev/null
**修复**: 保留错误信息到日志文件

### P1-5: 优化触发规则
**文件**: `skill-rules.json`
**问题**:
- 误触发：`安全分析`、`网站分析` 过宽
- 漏触发：websocket/ws/tls 未覆盖
**修复**: 收紧关键词，增加 websocket 相关词

### P1-6: 修正 Playwright 代理示例
**文件**: `references/BROWSER_EXPLORATION.md:19-25`
**问题**: `route('**/*')` 不是设置代理的方法
**修复**: 提供正确的代理配置说明

---

## P2 - 质量与测试

### P2-1: 添加基础测试
**新文件**: `tests/test_sanitize.py`, `tests/test_rules.py`
**内容**: 脱敏规则测试、触发规则命中测试

### P2-2: 收紧文件触发
**文件**: `skill-rules.json:60`
**问题**: `**/*.har` 过宽
**修复**: 改为更上下文敏感的组合规则

---

## 执行顺序

1. P0-1 命令注入修复（安全优先）
2. P0-4 文档参数修正（避免混淆）
3. P1-2 --help 修复
4. P1-1 策略命名统一
5. P1-5 触发规则优化
6. P1-6 Playwright 示例修正
7. P0-3 脱敏模块实现
8. P0-2 域约束（需要改动较大）
9. P1-3 依赖检测
10. P1-4 错误处理
11. P2-1 添加测试
12. P2-2 文件触发收紧

---

## 预计改动文件

- `scripts/capture-session.sh` - 修复命令注入、--help
- `scripts/startCaptures.sh` - 添加域约束、依赖检测
- `scripts/stopCaptures.sh` - 改进错误处理、域约束、依赖检测
- `scripts/sanitize.py` - 新建脱敏模块
- `scripts/flow2har.py` - 集成脱敏
- `scripts/flow_report.py` - 集成脱敏
- `scripts/ai_brief.py` - 集成脱敏
- `scripts/analyzeLatest.sh` - 集成脱敏
- `SKILL.md` - 修正参数、策略命名
- `skill-rules.json` - 优化触发规则
- `references/BROWSER_EXPLORATION.md` - 修正代理示例
- `templates/exploration-strategies.json` - 统一命名
- `tests/` - 新建测试目录
