# Progress Log

## Session: 2026-02-11

### Phase 1: 全仓扫描与缺口归档
- **Status:** complete
- Actions taken:
  - 执行仓库状态、TODO/FIXME、文档命令引用、脚本能力点扫描。
  - 执行 Python 与 Shell 全量测试，建立基线。
  - 执行发布检查 dry-run，确认流程可运行。
  - 归档缺口并做优先级排序（P0/P1）。
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: 计划编制（writing-plans）
- **Status:** complete
- Actions taken:
  - 生成正式执行计划 `docs/plans/2026-02-11-docs-drift-hardening.md`。
  - 计划含 4 个任务（前三任务采用严格 TDD，第四任务全量验证）。
- Files created/modified:
  - `docs/plans/2026-02-11-docs-drift-hardening.md` (created)

### Phase 3: 执行首批任务（executing-plans + TDD）
- **Status:** complete
- Actions taken:
  - Task 1（navlog 命令文档化）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_capture_session_commands_match_readme_docs -q` -> `FAILED`（缺少 `capture-session.sh navlog <cmd>`）
    - GREEN: 更新 `README.md`、`README_CN.md` 命令参考
    - VERIFY: 同命令 -> `1 passed`
  - Task 2（输出产物文档化）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_list_current_generated_artifacts -q` -> `FAILED`（缺少 manifest/scope/navigation）
    - GREEN: 更新 `README.md`、`README_CN.md` 输出表；更新 `docs/release-checklist.md` 产物清单
    - VERIFY: 同命令 -> `1 passed`
  - Task 3（SKILL 输出表一致性）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_output_table_lists_navigation_artifact -q` -> `FAILED`（缺少 `*.navigation.ndjson`）
    - GREEN: 更新 `SKILL.md` 输出文件表
    - VERIFY: 同命令 -> `1 passed`
- Files created/modified:
  - `tests/test_docs_consistency.py`
  - `README.md`
  - `README_CN.md`
  - `docs/release-checklist.md`
  - `SKILL.md`

### Phase 4: 回归验证
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `6 passed`
  - `python3 -m pytest tests -q` -> `62 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`
- Files created/modified:
  - `task_plan.md` (updated)
  - `progress.md` (updated)

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED Task1 | `pytest ...::test_capture_session_commands_match_readme_docs -q` | FAIL | FAIL（缺 navlog） | ✓ |
| GREEN Task1 | 同上 | PASS | `1 passed` | ✓ |
| RED Task2 | `pytest ...::test_docs_list_current_generated_artifacts -q` | FAIL | FAIL（缺产物文档） | ✓ |
| GREEN Task2 | 同上 | PASS | `1 passed` | ✓ |
| RED Task3 | `pytest ...::test_skill_output_table_lists_navigation_artifact -q` | FAIL | FAIL（缺 navigation token） | ✓ |
| GREEN Task3 | 同上 | PASS | `1 passed` | ✓ |
| Docs suite | `python3 -m pytest tests/test_docs_consistency.py -q` | PASS | `6 passed` | ✓ |
| Python full | `python3 -m pytest tests -q` | PASS | `62 passed` | ✓ |
| Shell full | `for test in tests/test_*.sh; do bash "$test"; done` | PASS | 全部通过 | ✓ |
| Release check | `./scripts/release-check.sh --dry-run` | PASS | Dry-run complete | ✓ |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-02-11 | `zsh: unmatched "` | 1 | 拆分命令并修正引号 |
| 2026-02-11 | `Unknown regexp modifier` (perl) | 1 | 更换为 `#` 分隔符并重试成功 |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 4 已完成 |
| Where am I going? | 进入下一轮扫描→计划→执行 |
| What's the goal? | 持续消除文档/测试漂移并固化为回归检查 |
| What have I learned? | 关键漂移在 public command 与 artifact docs 一致性 |
| What have I done? | 已完成首轮 3 个 TDD 任务 + 全量验证 |


### Round 2: 扫描与计划编制
- **Status:** complete
- Actions taken:
  - 对照 `capture-session.sh --help` 扫描 README/README_CN/SKILL 的选项覆盖。
  - 识别缺口：`--policy`、cleanup flags、`latest.log` 文档缺失。
  - 生成 Round 2 计划：`docs/plans/2026-02-11-round2-option-and-log-doc-hardening.md`。
- Files created/modified:
  - `findings.md` (updated)
  - `task_plan.md` (updated)
  - `docs/plans/2026-02-11-round2-option-and-log-doc-hardening.md` (created)


### Round 2: executing-plans + strict TDD
- **Status:** complete
- Actions taken:
  - Task 1（policy 选项文档化）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_policy_option -q` -> `FAILED`
    - GREEN: 更新 `README.md`、`README_CN.md` 范围控制章节加入 `--policy`
    - VERIFY: 同命令 -> `1 passed`
  - Task 2（cleanup flags 文档化）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_cleanup_flags -q` -> `FAILED`
    - GREEN: 更新 `README.md`、`README_CN.md`、`SKILL.md` 加入 `--keep-days`、`--keep-size`、`--secure`、`--dry-run`
    - VERIFY: 同命令 -> `1 passed`
  - Task 3（latest.log 产物文档化）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_list_latest_log_artifact -q` -> `FAILED`
    - GREEN: 更新 `README.md`、`README_CN.md`、`docs/release-checklist.md`、`SKILL.md` 加入 log 产物
    - VERIFY: 同命令 -> `1 passed`
- Files created/modified:
  - `tests/test_docs_consistency.py`
  - `README.md`
  - `README_CN.md`
  - `SKILL.md`
  - `docs/release-checklist.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Round 2: 全量验证
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `9 passed`
  - `python3 -m pytest tests -q` -> `65 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`


### Round 3: executing-plans + strict TDD
- **Status:** complete
- Actions taken:
  - Task 1（dir 选项文档化）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_dir_option -q` -> `FAILED`
    - GREEN: 更新 `README.md`、`README_CN.md` 增加 `-d, --dir` 说明
    - VERIFY: 同命令 -> `1 passed`
  - Task 2（port 选项文档化）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_port_option -q` -> `FAILED`
    - GREEN: 更新 `README.md`、`README_CN.md` 增加 `-P, --port` 说明
    - VERIFY: 同命令 -> `1 passed`
  - Task 3（自定义目录/端口示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_custom_dir_port_example -q` -> `FAILED`
    - GREEN: 更新 `README.md`、`README_CN.md` 增加两个示例命令
    - VERIFY: 同命令 -> `1 passed`
- Files created/modified:
  - `tests/test_docs_consistency.py`
  - `README.md`
  - `README_CN.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Round 3: 全量验证
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `12 passed`
  - `python3 -m pytest tests -q` -> `68 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`


### Round 4: 扫描与计划编制
- **Status:** complete
- Actions taken:
  - 扫描 `SKILL.md` 与 `capture-session.sh` 命令覆盖差异，定位 navlog 指南缺失。
  - 扫描 `skill-rules.json` 与 `tests/test_rules.py`，定位 `.log` 触发规则缺失。
  - 生成计划：`docs/plans/2026-02-11-round4-navlog-and-rule-log-trigger.md`。

### Round 4: executing-plans + strict TDD
- **Status:** complete
- Actions taken:
  - Task 1（SKILL navlog 指南）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_includes_navlog_command_guidance -q` -> `FAILED`
    - GREEN: 更新 `SKILL.md` 增加 navlog 用法
    - VERIFY: 同命令 -> `1 passed`
  - Task 2（规则测试增加 .log）
    - RED: `python3 -m pytest tests/test_rules.py::test_file_trigger_patterns_include_current_outputs -q` -> `FAILED`（缺 `.log`）
    - GREEN(前置): 更新 `tests/test_rules.py` 期望
  - Task 3（规则实现 .log pattern）
    - GREEN: 更新 `skill-rules.json` 增加 `**/captures/*.log`
    - VERIFY: `python3 -m pytest tests/test_rules.py::test_file_trigger_patterns_include_current_outputs -q` -> `1 passed`

### Round 4: 全量验证
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `13 passed`
  - `python3 -m pytest tests/test_rules.py -q` -> `4 passed`
  - `python3 -m pytest tests -q` -> `69 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`


### Round 5: 扫描与计划编制
- **Status:** complete
- Actions taken:
  - 扫描发现 README/CN 缺 `--help` 与 navlog append 示例。
  - 生成计划：`docs/plans/2026-02-11-round5-help-and-navlog-example.md`。

### Round 5: executing-plans + strict TDD
- **Status:** complete
- Actions taken:
  - Task 1（help 选项文档化）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_help_option -q` -> `FAILED`
    - GREEN: 更新 `README.md`、`README_CN.md` 全局选项加入 `-h, --help`
    - VERIFY: 同命令 -> `1 passed`
  - Task 2（navlog append 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_navlog_append_example -q` -> `FAILED`
    - GREEN: 更新 `README.md`、`README_CN.md` 增加 navlog append 示例
    - VERIFY: 同命令 -> `1 passed`
  - Task 3（help 命令示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_help_command_example -q` -> `FAILED`
    - GREEN: 更新 `README.md`、`README_CN.md` 增加 `capture-session.sh --help` 示例
    - VERIFY: 同命令 -> `1 passed`

### Round 5: 全量验证
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `16 passed`
  - `python3 -m pytest tests -q` -> `72 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`


### Round 6: 扫描与计划编制
- **Status:** complete
- Actions taken:
  - 识别统一入口缺口：`capture-session.sh` 无 `--force-recover` 支持，而 README 推荐了底层脚本命令。
  - 生成计划：`docs/plans/2026-02-11-round6-force-recover-unified-entry.md`。

### Round 6: executing-plans + strict TDD
- **Status:** complete
- Actions taken:
  - Task 1（force-recover 契约）
    - RED: `python3 -m pytest tests/test_capture_session_contract.py -q` -> `FAILED`
    - GREEN: 实现 `capture-session.sh` 的 `--force-recover` help/解析/转发
    - VERIFY: `python3 -m pytest tests/test_capture_session_contract.py -q` -> `1 passed`
  - Task 2（README/CN 统一入口）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_readme_uses_capture_session_force_recover -q` -> `FAILED`
    - GREEN: 更新 README/CN 故障排除为统一入口命令
    - VERIFY: 同命令 -> `1 passed`
  - Task 3（SKILL stale-state 指南）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_includes_force_recover_guidance -q` -> `FAILED`
    - GREEN: 更新 SKILL troubleshooting
    - VERIFY: 同命令 -> `1 passed`

### Round 6: 全量验证
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_capture_session_contract.py -q` -> `1 passed`
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `18 passed`
  - `python3 -m pytest tests -q` -> `75 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`


### Round 7: 扫描与计划编制
- **Status:** complete
- Actions taken:
  - 识别 force-recover 在选项条目与 workflow 文案中的遗留不一致。
  - 生成计划：`docs/plans/2026-02-11-round7-force-recover-option-and-workflow.md`。

### Round 7: executing-plans + strict TDD
- **Status:** complete
- Actions taken:
  - Task 1（force-recover 选项条目）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_docs_include_force_recover_option_bullet -q` -> `FAILED`
    - GREEN: 更新 README/CN/SKILL 增加 `--force-recover` 条目
    - VERIFY: 同命令 -> `1 passed`
  - Task 2（英文 workflow wrapper 对齐）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_readme_workflow_uses_wrapper_commands -q` -> `FAILED`
    - GREEN: 更新 README 五阶段 Phase2/Phase4 为 `capture-session.sh start/stop`
    - VERIFY: 同命令 -> `1 passed`
  - Task 3（中文 workflow wrapper 锚点）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_readme_cn_workflow_mentions_wrapper_commands -q` -> `FAILED`
    - GREEN: 更新 README_CN 五阶段 Phase2/Phase4 增加 wrapper 命令锚点
    - VERIFY: 同命令 -> `1 passed`

### Round 7: 全量验证
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `21 passed`
  - `python3 -m pytest tests/test_capture_session_contract.py -q` -> `1 passed`
  - `python3 -m pytest tests -q` -> `78 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`


### Round 8: 扫描与计划编制
- **Status:** complete
- Actions taken:
  - 全仓扫描命令：
    - `./scripts/capture-session.sh --help`
    - `./scripts/capture-session.sh --help | awk '/^Options:/{inopt=1;next}/^Scope Control:/{inopt=0} inopt{print}' | rg -o -- '--[a-z-]+' | sort -u`
    - `for opt in $(...); do rg -q --fixed-strings -- "$opt" SKILL.md || echo "$opt"; done`
  - 关键扫描输出：
    - SKILL 缺长参数：`--dir`、`--port`、`--help`
    - release checklist 缺 smoke 命令：`doctor`、`start ... --force-recover`、`navlog append ...`
  - 生成计划：`docs/plans/2026-02-11-round8-skill-option-and-smoke-hardening.md`。

### Round 8: executing-plans + strict TDD
- **Status:** complete
- Actions taken:
  - Task 1（SKILL 长参数与 help 文档）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_includes_long_form_common_options -q` -> `FAILED`（`SKILL.md missing long-form option docs: --dir`）
    - GREEN: 更新 `SKILL.md` key flags 为 `-d, --dir`、`-P, --port`，并新增 `-h, --help`
    - VERIFY: 同命令 -> `1 passed`
  - Task 2（release checklist 增加 doctor 预检）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_doctor_preflight -q` -> `FAILED`
    - GREEN: 更新 `docs/release-checklist.md` smoke block 增加 `./scripts/capture-session.sh doctor`
    - VERIFY: 同命令 -> `1 passed`
  - Task 3（release checklist 增加 force-recover + navlog）
    - RED(尝试1): `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_force_recover_and_navlog_smoke -q` -> `ERROR`（新增断言字符串引号未转义导致 `SyntaxError`）
    - 修复: 调整测试断言为单引号包裹整串命令
    - RED(尝试2): 同命令 -> `FAILED`（缺 `--force-recover` 命令）
    - GREEN: 更新 `docs/release-checklist.md` 为 `start ... --force-recover` 并新增 `navlog append` 命令
    - VERIFY: 同命令 -> `1 passed`

### Round 8: 全量验证
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `24 passed`
  - `python3 -m pytest tests -q` -> `81 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过（cleanup/common/doctor/git-doctor/install/navlog/progress/read_kv/release-check）
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 8: 最终复验（格式微调后）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `24 passed`
  - `python3 -m pytest tests -q` -> `81 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 9: 扫描与计划编制
- **Status:** complete
- Actions taken:
  - 扫描命令与输出要点：
    - `rg -n "\./scripts/(startCaptures|stopCaptures)\.sh" README.md README_CN.md` -> 命中两处 `./scripts/stopCaptures.sh`（README/CN 各 1）。
    - `for t in 'capture-session.sh cleanup --keep-days 7' ...; do rg ...; done` -> README/CN/SKILL 均未命中 cleanup 示例。
    - `for t in doctor.sh navlog.sh cleanupCaptures.sh diff_captures.py; do rg ... SKILL.md; done` -> 全部缺失。
  - 生成计划：`docs/plans/2026-02-11-round9-wrapper-troubleshooting-and-structure-hardening.md`。

### Round 9: executing-plans + strict TDD
- **Status:** complete
- Actions taken:
  - Task 1（README/CN 排障 stop 命令统一 wrapper）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_readme_troubleshooting_uses_wrapper_stop_command -q` -> `FAILED`
    - GREEN: 更新 README/CN `Port is already in use: 18080` 行为 `capture-session.sh stop`
    - VERIFY: 同命令 -> `1 passed`
  - Task 2（README/CN 增 cleanup 命令示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_readmes_include_cleanup_command_examples -q` -> `FAILED`
    - GREEN: README/CN 新增 3 条 cleanup 示例命令（keep-days / keep-size dry-run / secure keep-days）
    - VERIFY: 同命令 -> `1 passed`
  - Task 3（SKILL 文件结构补 helper 脚本）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_file_structure_lists_operational_helper_scripts -q` -> `FAILED`
    - GREEN: `SKILL.md` File Structure 补 `doctor.sh`/`cleanupCaptures.sh`/`navlog.sh`/`diff_captures.py`
    - VERIFY: 同命令 -> `1 passed`

### Round 9: 全量验证
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `27 passed`
  - `python3 -m pytest tests -q` -> `84 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 10: 扫描与 50 任务计划编制
- **Status:** complete
- Actions taken:
  - 全仓扫描摘要命令：
    - `./scripts/capture-session.sh --help > /tmp/capture_help.txt`
    - Python 比对脚本：提取 help commands/options/examples 与 `SKILL.md` / `docs/release-checklist.md` 差异
  - 关键扫描输出：
    - SKILL 缺 help 示例 7 条（doctor/localhost/analyze/cleanup×3/diff）
    - SKILL 文件结构缺 7 个现存脚本（cleanup.py/common.sh/git-doctor.sh/policy.py/proxy_utils.sh/release-check.sh/scope_audit.py）
    - release-checklist 缺 help 示例 6 条（localhost/allow-hosts/cleanup×3/diff）
  - 产出计划：`docs/plans/2026-02-11-round10-50-task-gap-backlog.md`（50任务，P0/P1/P2）。

### Round 10: executing-plans + strict TDD（Batch 1: Task 1-3）
- **Status:** complete
- Actions taken:
  - Task 1（SKILL 加 doctor 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_doctor_example -q` -> `FAILED`
    - GREEN: `SKILL.md` Quick Commands 增加 `capture-session.sh doctor`
    - VERIFY: 同命令 -> `1 passed`
  - Task 2（SKILL 加 localhost start 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_localhost_start_example -q` -> `FAILED`
    - GREEN: `SKILL.md` 增加 `capture-session.sh start http://localhost:3000`
    - VERIFY: 同命令 -> `1 passed`
  - Task 3（SKILL 加 analyze 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_analyze_example -q` -> `FAILED`
    - GREEN: `SKILL.md` 增加 `capture-session.sh analyze`
    - VERIFY: 同命令 -> `1 passed`

### Round 10: 全量验证（Batch 1）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `30 passed`
  - `python3 -m pytest tests -q` -> `87 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 10: executing-plans + strict TDD（Batch 2: Task 4-6）
- **Status:** complete
- Actions taken:
  - Task 4（SKILL 加 cleanup keep-days 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_cleanup_keep_days_example -q` -> `FAILED`
    - GREEN: `SKILL.md` 增加 `capture-session.sh cleanup --keep-days 7`
    - VERIFY: 同命令 -> `1 passed`
  - Task 5（SKILL 加 cleanup keep-size dry-run 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_cleanup_keep_size_dry_run_example -q` -> `FAILED`
    - GREEN: `SKILL.md` 追加 `capture-session.sh cleanup --keep-size 1G --dry-run`
    - VERIFY: 同命令 -> `1 passed`
  - Task 6（SKILL 加 cleanup secure 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_cleanup_secure_example -q` -> `FAILED`
    - GREEN: `SKILL.md` 追加 `capture-session.sh cleanup --secure --keep-days 3`
    - VERIFY: 同命令 -> `1 passed`

### Round 10: 全量验证（Batch 2）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `33 passed`
  - `python3 -m pytest tests -q` -> `90 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 10: executing-plans + strict TDD（Batch 3: Task 7-9）
- **Status:** complete
- Actions taken:
  - Task 7（SKILL 加 diff 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_diff_example -q` -> `FAILED`
    - GREEN: `SKILL.md` 增加 `capture-session.sh diff captures/a.index.ndjson captures/b.index.ndjson`
    - VERIFY: 同命令 -> `1 passed`
  - Task 8（SKILL 加 status 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_status_example -q` -> `FAILED`
    - GREEN: `SKILL.md` 增加 `capture-session.sh status`
    - VERIFY: 同命令 -> `1 passed`
  - Task 9（SKILL 加 help 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_quick_commands_include_help_example -q` -> `FAILED`
    - GREEN: `SKILL.md` 增加 `capture-session.sh --help`
    - VERIFY: 同命令 -> `1 passed`

### Round 10: 全量验证（Batch 3）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `36 passed`
  - `python3 -m pytest tests -q` -> `93 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 10: executing-plans + strict TDD（Batch 4: Task 10-12）
- **Status:** complete
- Actions taken:
  - Task 10（SKILL 文件结构含 `cleanup.py`，补做 VERIFY）
    - VERIFY: `python3 -m pytest tests/test_docs_consistency.py::test_skill_file_structure_lists_cleanup_py -q` -> `1 passed`
  - Task 11（SKILL 文件结构加 `common.sh`）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_file_structure_lists_common_sh -q` -> `FAILED`
    - GREEN: `SKILL.md` 文件结构新增 `common.sh`
    - VERIFY: 同命令 -> `1 passed`
  - Task 12（SKILL 文件结构加 `git-doctor.sh`）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_file_structure_lists_git_doctor_sh -q` -> `FAILED`
    - GREEN: `SKILL.md` 文件结构新增 `git-doctor.sh`
    - VERIFY: 同命令 -> `1 passed`

### Round 10: 全量验证（Batch 4）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `39 passed`
  - `python3 -m pytest tests -q` -> `96 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过（cleanup/common/doctor/git-doctor/install/navlog/progress/read_kv/release-check）
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 10: executing-plans + strict TDD（Batch 5: Task 13-15）
- **Status:** complete
- Actions taken:
  - Task 13（SKILL 文件结构加 `policy.py`）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_file_structure_lists_policy_py -q` -> `FAILED`
    - GREEN: `SKILL.md` 文件结构新增 `policy.py`
    - VERIFY: 同命令 -> `1 passed`
  - Task 14（SKILL 文件结构加 `proxy_utils.sh`）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_file_structure_lists_proxy_utils_sh -q` -> `FAILED`
    - GREEN: `SKILL.md` 文件结构新增 `proxy_utils.sh`
    - VERIFY: 同命令 -> `1 passed`
  - Task 15（SKILL 文件结构加 `release-check.sh`）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_file_structure_lists_release_check_sh -q` -> `FAILED`
    - GREEN: `SKILL.md` 文件结构新增 `release-check.sh`
    - VERIFY: 同命令 -> `1 passed`

### Round 10: 全量验证（Batch 5）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `42 passed`
  - `python3 -m pytest tests -q` -> `99 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过（cleanup/common/doctor/git-doctor/install/navlog/progress/read_kv/release-check）
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 10: executing-plans + strict TDD（Batch 6: Task 16-18）
- **Status:** complete
- Actions taken:
  - Task 16（SKILL 文件结构加 `scope_audit.py`）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_skill_file_structure_lists_scope_audit_py -q` -> `FAILED`
    - GREEN: `SKILL.md` 文件结构新增 `scope_audit.py`
    - VERIFY: 同命令 -> `1 passed`
  - Task 17（release-checklist 加 localhost start 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_localhost_start_example -q` -> `FAILED`
    - GREEN: `docs/release-checklist.md` 增加 `./scripts/capture-session.sh start http://localhost:3000`
    - VERIFY: 同命令 -> `1 passed`
  - Task 18（release-checklist 加 allow-hosts start 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_allow_hosts_start_example -q` -> `FAILED`
    - Fix test literal escaping: `api\.example\.com`
    - RED recheck: 同命令 -> `FAILED`
    - GREEN: `docs/release-checklist.md` 增加 `./scripts/capture-session.sh start https://example.com --allow-hosts 'api\.example\.com'`
    - VERIFY: 同命令 -> `1 passed`

### Round 10: 全量验证（Batch 6）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `45 passed`
  - `python3 -m pytest tests -q` -> `102 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过（cleanup/common/doctor/git-doctor/install/navlog/progress/read_kv/release-check）
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 10: executing-plans + strict TDD（Batch 7: Task 19-21）
- **Status:** complete
- Actions taken:
  - Task 19（release-checklist 加 cleanup keep-days 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_cleanup_keep_days_example -q` -> `FAILED`
    - GREEN: `docs/release-checklist.md` 增加 `./scripts/capture-session.sh cleanup --keep-days 7`
    - VERIFY: 同命令 -> `1 passed`
  - Task 20（release-checklist 加 cleanup keep-size dry-run 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_cleanup_keep_size_dry_run_example -q` -> `FAILED`
    - GREEN: `docs/release-checklist.md` 增加 `./scripts/capture-session.sh cleanup --keep-size 1G --dry-run`
    - VERIFY: 同命令 -> `1 passed`
  - Task 21（release-checklist 加 cleanup secure 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_cleanup_secure_example -q` -> `FAILED`
    - GREEN: `docs/release-checklist.md` 增加 `./scripts/capture-session.sh cleanup --secure --keep-days 3`
    - VERIFY: 同命令 -> `1 passed`

### Round 10: 全量验证（Batch 7）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `48 passed`
  - `python3 -m pytest tests -q` -> `105 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过（cleanup/common/doctor/git-doctor/install/navlog/progress/read_kv/release-check）
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 10: executing-plans + strict TDD（Batch 8: Task 22-24）
- **Status:** complete
- Actions taken:
  - Task 22（release-checklist 加 diff 示例）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_includes_diff_example -q` -> `FAILED`
    - GREEN: `docs/release-checklist.md` 增加 `./scripts/capture-session.sh diff captures/a.index.ndjson captures/b.index.ndjson`
    - VERIFY: 同命令 -> `1 passed`
  - Task 23（release-checklist 加 `--allow-hosts` 可发现性说明）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_mentions_allow_hosts_option -q` -> `FAILED`
    - GREEN: `docs/release-checklist.md` 增加 `Scope note: use \`--allow-hosts\` to capture only matching hosts.`
    - VERIFY: 同命令 -> `1 passed`
  - Task 24（release-checklist 加 `--deny-hosts` 可发现性说明）
    - RED: `python3 -m pytest tests/test_docs_consistency.py::test_release_checklist_mentions_deny_hosts_option -q` -> `FAILED`
    - GREEN: `docs/release-checklist.md` 增加 `Scope note: use \`--deny-hosts\` to exclude noisy or third-party hosts.`
    - VERIFY: 同命令 -> `1 passed`

### Round 10: 全量验证（Batch 8）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `51 passed`
  - `python3 -m pytest tests -q` -> `108 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过（cleanup/common/doctor/git-doctor/install/navlog/progress/read_kv/release-check）
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`

### Round 10: executing-plans + strict TDD（One-shot Final: Task 25-50）
- **Status:** complete
- Actions taken:
  - Add RED tests for remaining docs gaps（Task 25-46）in `tests/test_docs_consistency.py`:
    - release-checklist option notes: policy/keep-days/keep-size/secure/help/dir/port
    - README/README_CN structure script entries: doctor/cleanupCaptures/navlog/diff_captures/policy/analyzeLatest/ai/flow2har/flow_report/ai_brief/scope_audit
    - AI bundle artifact coverage: README/README_CN/SKILL/release-checklist
  - Add contract tests（Task 47-50）in `tests/test_capture_session_contract.py`:
    - allow-hosts / deny-hosts / policy / cleanup flags forwarding

### Round 10: RED evidence（One-shot Final）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `22 failed, 51 passed`
  - `python3 -m pytest tests/test_capture_session_contract.py -q` -> `5 passed`

### Round 10: GREEN implementation（One-shot Final）
- **Status:** complete
- Actions taken:
  - `docs/release-checklist.md`:
    - Added notes for `--policy` / `--keep-days` / `--keep-size` / `--secure` / `--help` / `--dir` / `--port`
    - Added artifact: `captures/latest.ai.bundle.txt`
  - `README.md` / `README_CN.md`:
    - Expanded `Project Structure` scripts list with 11 required script entries
    - Added output artifact row: `captures/latest.ai.bundle.txt`
  - `SKILL.md`:
    - Added output artifact token: `*.ai.bundle.txt`

### Round 10: VERIFY and full validation（One-shot Final）
- **Status:** complete
- Actions taken:
  - `python3 -m pytest tests/test_docs_consistency.py -q` -> `73 passed`
  - `python3 -m pytest tests/test_capture_session_contract.py -q` -> `5 passed`
  - `python3 -m pytest tests -q` -> `134 passed`
  - `for test in tests/test_*.sh; do bash "$test"; done` -> 全部通过（cleanup/common/doctor/git-doctor/install/navlog/progress/read_kv/release-check）
  - `./scripts/release-check.sh --dry-run` -> `Dry-run complete.`
