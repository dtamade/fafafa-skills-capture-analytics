# Task Plan: Docs Drift Hardening (TDD)

## Goal
通过严格 TDD 持续修复 CLI 文档漂移（命令、选项、输出产物）并补齐一致性回归测试。

## Current Phase
Round 10 complete (Tasks 1-50 / 50), full package closed

## Phases

### Phase 1: Round 1
- [x] navlog + 产物文档一致性修复
- [x] 回归测试增强
- [x] 全量验证
- **Status:** complete

### Phase 2: Round 2
- [x] policy/cleanup/log 文档一致性修复
- [x] 回归测试增强
- [x] 全量验证
- **Status:** complete

### Phase 3: Round 3
- [x] dir/port 文档与示例修复
- [x] 回归测试增强
- [x] 全量验证
- **Status:** complete

### Phase 4: Round 4
- [x] SKILL navlog 指南补齐
- [x] 规则测试与规则配置补 `.log`
- [x] 全量验证
- **Status:** complete

### Phase 5: Round 5
- [x] help option/help command/navlog 示例文档修复
- [x] 回归测试增强
- [x] 全量验证
- **Status:** complete

### Phase 6: Round 6
- [x] capture-session 支持 `--force-recover`
- [x] README/CN 故障排除统一入口命令
- [x] SKILL stale-state 指南补齐
- [x] 回归测试增强与全量验证
- **Status:** complete

### Phase 7: Round 7
- [x] force-recover 选项条目补齐
- [x] 英文/中文 workflow 对齐 wrapper 命令
- [x] 回归测试增强与全量验证
- **Status:** complete

### Phase 8: Round 8
- [x] SKILL 长选项与 help 文档对齐
- [x] release checklist 加入 doctor 预检
- [x] release checklist 加入 force-recover + navlog smoke 命令
- [x] 回归测试增强与全量验证
- **Status:** complete

### Phase 9: Round 9
- [x] README/CN 排障 stop 命令统一 wrapper
- [x] README/CN 补 cleanup 命令示例
- [x] SKILL 文件结构补关键 helper 脚本条目
- [x] 回归测试增强与全量验证
- **Status:** complete

### Phase 10: Round 10（50任务计划）
- [x] 全仓扫描并提炼 50 个可执行缺口任务
- [x] 生成 Round10 优先级计划文件
- [x] 按 TDD 执行首批 Task 1-3（SKILL 快速命令示例）
- [x] 按 TDD 执行第二批 Task 4-6（SKILL cleanup 示例）
- [x] 按 TDD 执行第三批 Task 7-9（SKILL diff/status/help 示例）
- [x] 每批后全量验证（pytest/shell/release-check dry-run）
- [x] 持续执行 Task 10-50
- **Status:** complete

### Phase 11: Next Loop
- [x] 执行 Round10 Task 10-12
- [x] 全量验证并记录证据
- [x] 更新计划并进入下一批
- **Status:** complete

### Phase 12: Next Loop
- [x] 执行 Round10 Task 13-15
- [x] 全量验证并记录证据
- [x] 更新计划并进入下一批
- **Status:** complete

### Phase 13: Next Loop
- [x] 执行 Round10 Task 16-18
- [x] 全量验证并记录证据
- [x] 更新计划并进入下一批
- **Status:** complete

### Phase 14: Next Loop
- [x] 执行 Round10 Task 19-21
- [x] 全量验证并记录证据
- [x] 更新计划并进入下一批
- **Status:** complete

### Phase 15: Next Loop
- [x] 执行 Round10 Task 22-24
- [x] 全量验证并记录证据
- [x] 更新计划并进入下一批
- **Status:** complete

### Phase 16: One-shot Closure
- [x] 一次性执行 Round10 Task 25-50（整包）
- [x] 严格 TDD：先 RED 后 GREEN 再 VERIFY
- [x] 全量验证并记录证据
- **Status:** complete

## Key Questions
1. 是否引入自动化脚本：从 `capture-session.sh --help` 生成 docs consistency 断言基线？
2. 是否将 README/README_CN 的命令与选项片段模板化，减少重复维护？

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 每轮固定“扫描→计划→3任务→验证” | 节奏稳定、可审计 |
| 优先统一入口心智模型 | 降低用户路径分叉 |
| 严格 RED→GREEN→VERIFY | 保持 TDD 纪律 |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| 多轮累计 diff 混合 | 1 | 以目标测试命令输出作为任务验收主证据 |
| shell/perl 替换变量误展开（Round6） | 1 | 立即修复并用契约测试回归确认 |
| Round8 新增断言字符串引号转义错误导致 SyntaxError | 1 | 修正为单引号包裹整串命令并重新执行 RED 用例 |
