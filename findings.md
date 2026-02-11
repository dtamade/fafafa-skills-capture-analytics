# Findings & Decisions

## Requirements
- 按 `writing-plans + planning-with-files` 流程先全仓扫描缺口。
- 输出一份可执行、可排序优先级的实施计划。
- 按 `executing-plans` 执行计划。
- 严格遵循 TDD（RED → GREEN → REFACTOR）。
- 每一步报告命令与输出证据。

## Research Findings
- 基线状态：`git status --short` 仅有 `task_plan.md`、`findings.md`、`progress.md` 未追踪。
- 全仓标记扫描：`rg -n '\\b(TODO|FIXME|TBD|XXX|HACK)\\b' --glob '!.git'` 无结果。
- 测试基线：`python3 -m pytest tests -q` => `60 passed in 0.39s`。
- Shell 测试基线：`for test in tests/test_*.sh; do bash "$test"; done` 全部通过。
- 发布检查基线：`./scripts/release-check.sh --dry-run` 执行成功。
- 文档漂移缺口 1（命令）：`scripts/capture-session.sh --help` 明确包含 `navlog <cmd>`，但 `README.md` / `README_CN.md` 命令列表未包含 `capture-session.sh navlog <cmd>`。
- 文档漂移缺口 2（产物）：`scripts/stopCaptures.sh` 会建立 `latest.manifest.json`、`latest.scope_audit.json`、`latest.navigation.ndjson` 软链接，但 README 输出文件表格未完整覆盖。
- 文档漂移缺口 3（防回归）：`tests/test_docs_consistency.py` 尚未对上述 `navlog` 命令与新增产物文档化进行一致性断言。

## Gap Priority (Impact × Risk)
1. **P0** 文档命令漂移：`navlog` 未在 README 中暴露，易导致用户遗漏能力。
2. **P0** 产物文档漂移：manifest/scope/navigation 未在 README 明示，影响可发现性与排障。
3. **P1** 缺少回归守护：docs consistency 未覆盖上述项，未来易回归。

## Decisions
| Decision | Rationale |
|----------|-----------|
| 先用测试定义文档期望，再修改文档 | 满足严格 TDD，避免“先改后测” |
| 优先修复 `README.md` 与 `README_CN.md` | 用户入口文档影响最大 |
| 同步增强 `tests/test_docs_consistency.py` | 将本次修复固化为长期防线 |
| 迭代范围控制为文档+测试，不改业务逻辑 | 风险最小、回归成本低 |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| `rg` 初次命令引号冲突导致 `zsh: unmatched` | 拆分命令并改用单引号正则 |

## Resources
- `scripts/capture-session.sh`
- `scripts/stopCaptures.sh`
- `README.md`
- `README_CN.md`
- `docs/release-checklist.md`
- `tests/test_docs_consistency.py`


## Resolution Status (Round 1)
- ✅ `navlog` 命令已补到 `README.md` / `README_CN.md`。
- ✅ `latest.manifest.json` / `latest.scope_audit.json` / `latest.navigation.ndjson` 已补到 README 与 release checklist。
- ✅ `SKILL.md` 输出表已补 `*.navigation.ndjson`。
- ✅ `tests/test_docs_consistency.py` 已新增回归断言，防止上述项再次漂移。

## Round 2 Scan (2026-02-11)

### New Research Findings
- `capture-session.sh --help` 暴露了关键选项：`--policy`、`--keep-days`、`--keep-size`、`--secure`、`--dry-run`。
- `README.md` 与 `README_CN.md` 当前均未出现上述 5 个选项（通过 `rg --fixed-strings --` 扫描确认）。
- `SKILL.md` 仅覆盖 `--policy`，未覆盖 cleanup 选项。
- `scripts/stopCaptures.sh` 会设置 `latest.log` 软链接（`LATEST_LOG_LINK`），但 README/README_CN/release-checklist/SKILL 未文档化该产物。

### Round 2 Gap Priority (Impact × Risk)
1. **P0** 关键选项不可发现：README/CN 缺少 `--policy` 与 cleanup flags，用户难以使用高级能力。
2. **P0** `latest.log` 产物文档缺失：调试关键产物未被公开，影响排障流程。
3. **P1** 回归防线缺口：`tests/test_docs_consistency.py` 尚未覆盖上述选项与 `latest.log`。

### Round 2 Decisions
| Decision | Rationale |
|----------|-----------|
| 继续文档+测试最小改动策略 | 保持低风险迭代 |
| 先加 failing tests 再改文档 | 严格 TDD |
| 优先 README/CN，再补 SKILL 与 release checklist | 用户入口优先，流程文档次之 |

### Round 2 Resolution Status
- ✅ README / README_CN 已补 `--policy` 选项文档。
- ✅ README / README_CN / SKILL 已补 cleanup flags：`--keep-days`、`--keep-size`、`--secure`、`--dry-run`。
- ✅ README / README_CN / release checklist / SKILL 已补 `latest.log` 产物说明。
- ✅ `tests/test_docs_consistency.py` 已新增 3 条防回归测试（policy/cleanup/log）。

## Round 3 Scan (2026-02-11)

### New Research Findings
- `capture-session.sh --help` 暴露 `-d, --dir <path>` 与 `-P, --port <port>`。
- `README.md` / `README_CN.md` 目前未出现 `-d, --dir` 与 `-P, --port` 选项说明。
- `SKILL.md` 已有 `-d <dir>`、`-P <port>`，但用户入口文档（README）缺失，存在发现性缺口。

### Round 3 Gap Priority (Impact × Risk)
1. **P0** 目录与端口选项不可发现：用户难以在多项目目录或端口冲突场景下快速上手。
2. **P1** 缺少回归断言：`tests/test_docs_consistency.py` 未覆盖 dir/port 选项。

### Round 3 Decisions
| Decision | Rationale |
|----------|-----------|
| 用三条小任务分别固化 dir/port/示例 | 任务粒度小，便于 TDD 验证 |
| 只改 README/CN 与测试 | 延续最小改动策略 |

### Round 3 Resolution Status
- ✅ README / README_CN 已补 `-d, --dir` 与 `-P, --port` 全局选项说明。
- ✅ README / README_CN 已补自定义目录与端口示例命令。
- ✅ `tests/test_docs_consistency.py` 已新增 3 条防回归测试（dir/port/example）。

## Round 4 Scan (2026-02-11)

### New Research Findings
- `scripts/capture-session.sh` 明确支持 `navlog <cmd>`，但 `SKILL.md` 当前未出现 `navlog`。
- 抓包产物已包含 `latest.log`（并已文档化），但 `skill-rules.json` 的 `fileTriggers.pathPatterns` 仍缺 `*.log`。
- `tests/test_rules.py` 的 `required_suffixes` 也缺 `.log`，导致触发规则测试与当前产物集合不一致。

### Round 4 Gap Priority (Impact × Risk)
1. **P0** SKILL 指南缺失 navlog：AI 使用说明不完整。
2. **P0** 规则触发缺失 log：基于日志文件的技能触发可能失效。
3. **P1** 规则测试缺少 log 守护：未来易再次回归。

### Round 4 Decisions
| Decision | Rationale |
|----------|-----------|
| 先补 failing tests，再补文档/规则 | 严格 TDD |
| 任务拆为 3 个小步 | 便于按 executing-plans 批次执行 |

### Round 4 Resolution Status
- ✅ `SKILL.md` 已新增 `capture-session.sh navlog ...` 指南。
- ✅ `tests/test_rules.py` 已将 `.log` 纳入必需产物后缀。
- ✅ `skill-rules.json` 已新增 `**/captures/*.log` 文件触发规则。

## Round 5 Scan (2026-02-11)

### New Research Findings
- `capture-session.sh --help` 明确支持 `-h, --help`，但 README/README_CN 未文档化 `--help` 选项。
- README/README_CN 仅有 `navlog <cmd>` 命令引用，缺少 `navlog append --action ... --url ...` 可执行示例。
- `SKILL.md` 已有 navlog append 示例，但用户入口文档（README/CN）尚未同步。

### Round 5 Gap Priority (Impact × Risk)
1. **P0** `--help` 选项不可发现：降低 CLI 自助探索效率。
2. **P0** navlog append 示例缺失：用户不易理解 `navlog` 子命令实际用法。
3. **P1** docs consistency 缺少上述回归断言：未来易回归。

### Round 5 Decisions
| Decision | Rationale |
|----------|-----------|
| 先加 failing tests 再补 README/CN | 严格 TDD |
| 仅做文档+测试层改动 | 保持低风险迭代 |

### Round 5 Resolution Status
- ✅ README / README_CN 已补 `-h, --help` 全局选项说明。
- ✅ README / README_CN 已补 `navlog append --action ... --url ...` 示例。
- ✅ README / README_CN 已补 `capture-session.sh --help` 帮助命令示例。
- ✅ `tests/test_docs_consistency.py` 已新增 3 条回归断言（help option/navlog example/help command）。

## Round 6 Scan (2026-02-11)

### New Research Findings
- `README.md` / `README_CN.md` 的故障排除建议使用 `./scripts/startCaptures.sh --force-recover`。
- `scripts/startCaptures.sh` 支持 `--force-recover`，但统一入口 `scripts/capture-session.sh` 当前未解析/转发该参数。
- 这导致文档推荐用户使用内部脚本，和“统一入口 capture-session.sh”定位不一致。
- `SKILL.md` 的 Troubleshooting 表尚未覆盖 stale state 恢复路径。

### Round 6 Gap Priority (Impact × Risk)
1. **P0** 统一入口缺能力：`capture-session.sh` 无法处理 stale recovery。
2. **P0** README/CN 故障排除推荐内部脚本，和统一入口策略冲突。
3. **P1** SKILL 缺少 stale recovery 指南，且无回归守护。

### Round 6 Decisions
| Decision | Rationale |
|----------|-----------|
| 先加脚本契约测试，再实现参数支持 | 严格 TDD 且降低实现偏差 |
| README/CN 改为统一入口命令 | 对齐用户路径，减少心智负担 |
| SKILL 同步补故障项并加测试 | 保持 docs 一致性闭环 |

### Round 6 Resolution Status
- ✅ `capture-session.sh` 已支持 `--force-recover`（help/解析/转发到 `startCaptures.sh`）。
- ✅ README / README_CN stale-state 修复命令已统一为 `capture-session.sh start https://example.com --force-recover`。
- ✅ SKILL Troubleshooting 已新增 stale-state 恢复指导。
- ✅ 新增脚本契约测试 `tests/test_capture_session_contract.py`，并新增 docs consistency 相关断言。

## Round 7 Scan (2026-02-11)

### New Research Findings
- `capture-session.sh` 已支持 `--force-recover`，但 README/README_CN 全局选项与 SKILL key flags 尚未列出该选项。
- README 英文五阶段工作流仍写 `scripts/startCaptures.sh` / `scripts/stopCaptures.sh`，与统一入口策略不一致。
- README_CN 五阶段工作流是抽象描述，缺少与统一入口命令的显式绑定表达。

### Round 7 Gap Priority (Impact × Risk)
1. **P0** force-recover 选项文档仍不完整。
2. **P0** 英文 workflow 仍暴露内部脚本路径。
3. **P1** 中文 workflow 缺少统一入口命令锚点，易与英文漂移。

### Round 7 Decisions
| Decision | Rationale |
|----------|-----------|
| 增加 failing docs tests 锁定三类缺口 | 保持严格 TDD |
| README workflow 明确使用 capture-session wrapper | 对齐统一入口心智模型 |
| README_CN 同步加入 wrapper 锚点文本 | 避免双语文档漂移 |

### Round 7 Resolution Status
- ✅ README / README_CN / SKILL 选项条目已补 `--force-recover`。
- ✅ README 英文五阶段工作流已改为 wrapper 命令锚点（`capture-session.sh start/stop`）。
- ✅ README 中文五阶段工作流已补 wrapper 命令锚点。
- ✅ docs consistency 已新增 3 条相关回归测试。

## Round 8 Scan (2026-02-11)

### New Research Findings
- `capture-session.sh --help` 的 `Options:` 区块包含：`--allow-hosts`、`--deny-hosts`、`--dir`、`--dry-run`、`--force-recover`、`--help`、`--keep-days`、`--keep-size`、`--policy`、`--port`、`--secure`。
- `SKILL.md` 的 Key flags 在 Round 7 之后仍只写短参数形式，缺失长参数 token：`--dir`、`--port`，且未显式给出 `--help`。
- `docs/release-checklist.md` 的 smoke test 命令块在 Round 7 后仍缺：
  - `./scripts/capture-session.sh doctor`
  - `./scripts/capture-session.sh start https://example.com --force-recover`
  - `./scripts/capture-session.sh navlog append --action navigate --url "https://example.com"`
- TODO/FIXME 扫描未发现新增代码缺口（仅 planning 日志内包含关键字文本）。

### Round 8 Gap Priority (Impact × Risk)
1. **P0** SKILL 长参数缺口：AI/操作者可能看不到标准长参数写法，降低一致性与可发现性。
2. **P0** release smoke 缺少 doctor 预检：发布前环境问题更容易漏检。
3. **P1** release smoke 缺少 force-recover + navlog 操作：对 stale state 与导航日志链路覆盖不足。

### Round 8 Decisions
| Decision | Rationale |
|----------|-----------|
| 用 3 个独立 failing tests 驱动修复 | 保持执行批次小、严格 TDD 证据清晰 |
| 仅修改 `SKILL.md` + `docs/release-checklist.md` + docs consistency 测试 | 最小改动，不触碰运行逻辑 |
| 保持“扫描→计划→执行前三任务→全量验证”节奏 | 与既有迭代模式一致，可重复执行 |

### Round 8 Resolution Status
- ✅ `SKILL.md` 已补长参数文档：`--dir`、`--port`，并补 `-h, --help`。
- ✅ `docs/release-checklist.md` smoke test 已加入 `capture-session.sh doctor`。
- ✅ `docs/release-checklist.md` smoke test 已加入 `--force-recover` 启动命令与 `navlog append` 示例。
- ✅ `tests/test_docs_consistency.py` 已新增 3 条回归断言，覆盖以上缺口。

## Round 9 Scan (2026-02-11)

### New Research Findings
- README/README_CN 的故障排除仍包含内部脚本路径：`./scripts/stopCaptures.sh`（与统一入口策略不一致）。
- README/README_CN 虽有 Cleanup 选项说明，但没有任何 `capture-session.sh cleanup ...` 可执行示例，导致选项可发现性高、可操作性低。
- `SKILL.md` 的 File Structure `scripts/` 列表缺少当前关键 helper 脚本：`doctor.sh`、`cleanupCaptures.sh`、`navlog.sh`、`diff_captures.py`。

### Round 9 Gap Priority (Impact × Risk)
1. **P0** README/CN 仍暴露内部 stop 脚本路径，破坏“统一 wrapper 入口”心智模型。
2. **P0** README/CN 缺 cleanup 实操示例，用户不易正确组合 cleanup 参数。
3. **P1** SKILL 文件结构清单与仓库脚本不一致，影响 AI/开发者定位脚本能力。

### Round 9 Decisions
| Decision | Rationale |
|----------|-----------|
| 继续使用 3 个独立 failing tests 驱动修复 | 严格 TDD，证据可审计 |
| README/CN 仅做最小文案修复（排障行 + cleanup 示例） | 低风险、用户收益直接 |
| SKILL 仅补文件结构缺失脚本，不扩展行为说明 | 控制变更面，避免过度改写 |

### Round 9 Resolution Status
- ✅ README/README_CN 排障中的 `Port is already in use` 已改为 `capture-session.sh stop` 统一入口。
- ✅ README/README_CN 已新增 cleanup 命令示例：`--keep-days`、`--keep-size --dry-run`、`--secure --keep-days`。
- ✅ SKILL 文件结构已补 `doctor.sh`、`cleanupCaptures.sh`、`navlog.sh`、`diff_captures.py`。
- ✅ docs consistency 已新增 3 条回归断言并通过全量验证。

## Round 10 Scan (2026-02-11)

### New Research Findings
- 基于 `capture-session.sh --help` 与文档比对，`SKILL.md` 缺少 7 条 help 示例命令：
  - `capture-session.sh doctor`
  - `capture-session.sh start http://localhost:3000`
  - `capture-session.sh analyze`
  - `capture-session.sh cleanup --keep-days 7`
  - `capture-session.sh cleanup --keep-size 1G --dry-run`
  - `capture-session.sh cleanup --secure --keep-days 3`
  - `capture-session.sh diff captures/a.index.ndjson captures/b.index.ndjson`
- `SKILL.md` 文件结构仍缺 7 个现存脚本：`cleanup.py`、`common.sh`、`git-doctor.sh`、`policy.py`、`proxy_utils.sh`、`release-check.sh`、`scope_audit.py`。
- `docs/release-checklist.md` 对 `capture-session.sh --help` 示例覆盖仍缺 6 条命令（localhost/allow-hosts/cleanup×3/diff）。
- `SKILL.md` 仍缺少命令级 token：`capture-session.sh status`、`capture-session.sh doctor`、`capture-session.sh analyze`、`capture-session.sh cleanup`、`capture-session.sh diff`（其中 doctor/analyze 已在本批修复）。

### Round 10 Gap Priority (Impact × Risk)
1. **P0** SKILL 快速命令示例缺口（直接影响 AI 操作路径与可复制性）。
2. **P0** release checklist 与 CLI help 示例不一致（发布流程可操作性不足）。
3. **P1** SKILL/README 结构清单缺失脚本条目（定位能力下降）。
4. **P2** wrapper 合同测试仍有多分支未覆盖（长期回归风险）。

### Round 10 Decisions
| Decision | Rationale |
|----------|-----------|
| 生成 50 任务优先队列（P0/P1/P2） | 满足“50个任务”要求并可分批执行 |
| 本批先执行 Task 1-3（均为 P0） | 最大化用户可见收益且变更风险低 |
| 持续保持 3 任务/批次 + 全量验证 | 与既有循环模式一致，可审计可回滚 |

### Round 10 Resolution Status (Batch 1)
- ✅ 已完成 50 任务计划文件：`docs/plans/2026-02-11-round10-50-task-gap-backlog.md`。
- ✅ 已完成 Task 1-3：SKILL 新增 doctor / localhost start / analyze 快速命令示例。
- ✅ `tests/test_docs_consistency.py` 新增 3 条回归测试并全部通过。
- ✅ 全量验证通过：docs consistency、全部 pytest、全部 shell tests、release-check dry-run。

### Round 10 Resolution Status (Batch 2)
- ✅ 已完成 Task 4-6：SKILL `Cleanup Command Examples` 追加三条命令：
  - `capture-session.sh cleanup --keep-days 7`
  - `capture-session.sh cleanup --keep-size 1G --dry-run`
  - `capture-session.sh cleanup --secure --keep-days 3`
- ✅ docs consistency 新增 3 条回归断言：keep-days / keep-size dry-run / secure。
- ✅ Batch 2 全量验证通过（docs consistency / 全部 pytest / 全部 shell tests / release-check dry-run）。

### Round 10 Resolution Status (Batch 3)
- ✅ 已完成 Task 7-9：SKILL Quick Commands 新增三类示例：
  - `capture-session.sh diff captures/a.index.ndjson captures/b.index.ndjson`
  - `capture-session.sh status`
  - `capture-session.sh --help`
- ✅ docs consistency 新增 3 条回归断言：diff/status/help 示例守护。
- ✅ Batch 3 全量验证通过（docs consistency / 全部 pytest / 全部 shell tests / release-check dry-run）。

### Round 10 Resolution Status (Batch 4)
- ✅ 已完成 Task 10-12：SKILL File Structure 补齐 3 个脚本条目：
  - `cleanup.py`
  - `common.sh`
  - `git-doctor.sh`
- ✅ `tests/test_docs_consistency.py` 新增 2 条回归断言：`common.sh` 与 `git-doctor.sh` 文件结构守护。
- ✅ Task10（`cleanup.py`）在本批完成 VERIFY 并通过。
- ✅ Batch 4 全量验证通过（docs consistency / 全部 pytest / 全部 shell tests / release-check dry-run）。

### Round 10 Resolution Status (Batch 5)
- ✅ 已完成 Task 13-15：SKILL File Structure 补齐 3 个脚本条目：
  - `policy.py`
  - `proxy_utils.sh`
  - `release-check.sh`
- ✅ `tests/test_docs_consistency.py` 新增 3 条回归断言：`policy.py` / `proxy_utils.sh` / `release-check.sh` 文件结构守护。
- ✅ Batch 5 全量验证通过（docs consistency / 全部 pytest / 全部 shell tests / release-check dry-run）。

### Round 10 Resolution Status (Batch 6)
- ✅ 已完成 Task 16-18：
  - SKILL File Structure 补齐 `scope_audit.py`。
  - `docs/release-checklist.md` 补齐 localhost 与 `--allow-hosts` 启动示例。
- ✅ `tests/test_docs_consistency.py` 新增 3 条回归断言：`scope_audit.py` 文件结构守护 + release checklist 两条启动示例守护。
- ✅ Batch 6 全量验证通过（docs consistency / 全部 pytest / 全部 shell tests / release-check dry-run）。

### Round 10 Resolution Status (Batch 7)
- ✅ 已完成 Task 19-21：`docs/release-checklist.md` 补齐 3 条 cleanup 示例：
  - `./scripts/capture-session.sh cleanup --keep-days 7`
  - `./scripts/capture-session.sh cleanup --keep-size 1G --dry-run`
  - `./scripts/capture-session.sh cleanup --secure --keep-days 3`
- ✅ `tests/test_docs_consistency.py` 新增 3 条 release checklist cleanup 示例回归断言。
- ✅ Batch 7 全量验证通过（docs consistency / 全部 pytest / 全部 shell tests / release-check dry-run）。

### Round 10 Resolution Status (Batch 8)
- ✅ 已完成 Task 22-24：
  - `docs/release-checklist.md` 补齐 diff 示例命令。
  - `docs/release-checklist.md` 补齐 `--allow-hosts` / `--deny-hosts` 可发现性说明。
- ✅ `tests/test_docs_consistency.py` 新增 3 条回归断言：diff 示例 + allow/deny host 说明守护。
- ✅ Batch 8 全量验证通过（docs consistency / 全部 pytest / 全部 shell tests / release-check dry-run）。

### Round 10 Resolution Status (One-shot Final: Tasks 25-50)
- ✅ 已按“整包一次性完成”执行 Task 25-50：
  - **release-checklist 选项可发现性补齐（Task 25-31）**：补 `--policy`、`--keep-days`、`--keep-size`、`--secure`、`--help`、`--dir`、`--port` 说明。
  - **README/README_CN 项目结构补齐（Task 32-42）**：补 `doctor.sh`、`cleanupCaptures.sh`、`navlog.sh`、`diff_captures.py`、`policy.py`、`analyzeLatest.sh`、`ai.sh`、`flow2har.py`、`flow_report.py`、`ai_brief.py`、`scope_audit.py`。
  - **AI bundle 产物覆盖补齐（Task 43-46）**：README/README_CN/release-checklist 增 `captures/latest.ai.bundle.txt`，SKILL 输出表增 `*.ai.bundle.txt`。
  - **wrapper 合同测试扩展（Task 47-50）**：新增 allow-hosts / deny-hosts / policy / cleanup flags 转发契约测试。
- ✅ TDD 证据：新增断言后 `docs_consistency` RED 出现 22 个失败，再做文档修复后 GREEN 全过。
- ✅ 最终验证全绿：`docs_consistency 73 passed`、`test_capture_session_contract 5 passed`、`tests 134 passed`、全部 shell tests 通过、`release-check --dry-run` 完成。
