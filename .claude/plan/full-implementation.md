# capture-analytics 完整实施计划

> 生成时间: 2026-02-09
> 来源: Codex 架构分析 + Claude 整合

## 执行顺序

```
Phase 1 (安全地基)
    └── #1 P0-2 域名约束 [大]

Phase 2 (可运维性)
    ├── #2 doctor 自检 [中]
    └── #3 数据生命周期 [中]

Phase 3 (分析增强)
    ├── #4 差异分析 [中]
    └── #5 导航日志关联 [中]

Phase 4 (可分享)
    ├── #6 安装和配置 [中]
    ├── #7 跨平台支持 [大]
    ├── #8 文档完善 [小-中]
    └── #9 测试补齐 [大]
```

---

## Phase 1: 安全地基

### #1 P0-2 域名约束 ⚠️ 安全关键

**目标**: 限制 AI 只能捕获授权域名的流量

**涉及文件**:
| 文件 | 操作 | 说明 |
|------|------|------|
| `config/policy.example.json` | 新增 | 策略模板 |
| `scripts/policy.py` | 新增 | 策略加载/编译 |
| `scripts/scope_audit.py` | 新增 | 越界检测 |
| `scripts/startCaptures.sh` | 修改 | 接入 allow/ignore_hosts |
| `scripts/capture-session.sh` | 修改 | --confirm 参数 |
| `scripts/stopCaptures.sh` | 修改 | 调用审计 |
| `tests/test_policy.py` | 新增 | 策略测试 |
| `tests/test_scope_audit.py` | 新增 | 审计测试 |

**新增函数**:
```python
# policy.py
load_policy(path: str) -> dict
compile_allow_hosts_regex(hosts: list) -> str
compile_ignore_hosts_regex(hosts: list) -> str
extract_target_host(url: str) -> str

# scope_audit.py
run_scope_audit(index_file: str, allow_hosts: list) -> dict
```

**修改点**:
- `startCaptures.sh`: 解析 `--allow-hosts`, `--deny-hosts`, 拼接 mitmdump 参数
- `capture-session.sh`: 解析 `--confirm "YES_I_HAVE_AUTHORIZATION"`
- `stopCaptures.sh`: 调用 scope_audit.py, 结果写入 manifest

**验收标准**:
- [ ] 无 --confirm 参数时拒绝启动
- [ ] 只有白名单域名的流量被捕获
- [ ] 越界流量触发 violation 状态
- [ ] 测试全部通过

**工作量**: 大 (预计 4-6 小时)

---

## Phase 2: 可运维性

### #2 doctor 自检命令

**目标**: 一键检查运行环境

**涉及文件**:
| 文件 | 操作 | 说明 |
|------|------|------|
| `scripts/doctor.sh` | 新增 | 自检脚本 |
| `scripts/capture-session.sh` | 修改 | doctor 子命令 |
| `tests/test_doctor.sh` | 新增 | 测试 |

**检查项**:
```
[✓] mitmdump 版本 >= 10.0
[✓] Python 3.8+
[✓] mitmproxy Python 模块
[✓] Playwright MCP 可用
[✓] CA 证书已安装
[✓] 端口 18080 可用
[✓] policy.json 有效 (如存在)
```

**验收标准**:
- [ ] `capture-session.sh doctor` 输出检查结果
- [ ] 任一检查失败返回非零退出码
- [ ] 提供修复建议

**工作量**: 中 (预计 2-3 小时)

---

### #3 数据生命周期

**目标**: 管理捕获数据的清理

**涉及文件**:
| 文件 | 操作 | 说明 |
|------|------|------|
| `scripts/cleanupCaptures.sh` | 新增 | 清理脚本 |
| `scripts/capture-session.sh` | 修改 | cleanup 子命令 |
| `tests/test_cleanup.sh` | 新增 | 测试 |

**功能**:
```bash
# 按天清理 (保留最近7天)
capture-session.sh cleanup --keep-days 7

# 按大小清理 (保留最近 1GB)
capture-session.sh cleanup --keep-size 1G

# 安全删除 (覆写后删除)
capture-session.sh cleanup --secure --keep-days 3

# 预览模式
capture-session.sh cleanup --keep-days 7 --dry-run
```

**验收标准**:
- [ ] 正确识别过期文件
- [ ] dry-run 不实际删除
- [ ] secure 模式使用 shred
- [ ] 更新 latest.* 链接

**工作量**: 中 (预计 2-3 小时)

---

## Phase 3: 分析增强

### #4 差异分析

**目标**: 对比两次捕获的变化

**涉及文件**:
| 文件 | 操作 | 说明 |
|------|------|------|
| `scripts/diff_captures.py` | 新增 | 对比脚本 |
| `scripts/capture-session.sh` | 修改 | diff 子命令 |
| `tests/test_diff_captures.py` | 新增 | 测试 |

**功能**:
```bash
# 对比两次捕获
capture-session.sh diff captures/a.index.ndjson captures/b.index.ndjson

# 输出
# - 新增 endpoints
# - 删除 endpoints
# - 状态码变化
# - 延迟变化 (>20% 标记)
```

**验收标准**:
- [ ] 正确识别 endpoint 差异
- [ ] 输出 Markdown 格式
- [ ] AI 可消费的 JSON 格式

**工作量**: 中 (预计 2-3 小时)

---

### #5 导航日志关联

**目标**: 记录浏览器导航路径

**涉及文件**:
| 文件 | 操作 | 说明 |
|------|------|------|
| `scripts/navlog.sh` | 新增 | 导航记录 |
| `scripts/startCaptures.sh` | 修改 | 初始化 navlog |
| `scripts/stopCaptures.sh` | 修改 | 生成 artifact |
| `tests/test_navlog.sh` | 新增 | 测试 |

**格式**:
```jsonl
{"ts":"2026-02-09T10:00:00Z","action":"navigate","url":"https://example.com","title":"Home"}
{"ts":"2026-02-09T10:00:05Z","action":"click","selector":"#login","url":"https://example.com/login"}
```

**验收标准**:
- [ ] start 时创建空 navlog
- [ ] 提供 navlog append 命令
- [ ] stop 时生成 latest.navigation.ndjson

**工作量**: 中 (预计 2-3 小时)

---

## Phase 4: 可分享

### #6 安装和配置

**涉及文件**:
| 文件 | 操作 |
|------|------|
| `install.sh` | 新增 |
| `requirements.txt` | 新增 |
| `config/policy.example.json` | 新增 (Phase 1) |

**工作量**: 中 (预计 2 小时)

---

### #7 跨平台支持

**涉及文件**:
| 文件 | 操作 |
|------|------|
| `scripts/startCaptures.sh` | 修改 |
| `scripts/stopCaptures.sh` | 修改 |
| `references/WINDOWS_SETUP.md` | 新增 |

**支持矩阵**:
| 平台 | 代理设置 | 优先级 |
|------|----------|--------|
| Linux (GNOME) | gsettings | ✅ 已有 |
| macOS | networksetup | 待实现 |
| Windows | 文档指引 | 待实现 |

**工作量**: 大 (预计 4 小时)

---

### #8 文档完善

**新增章节**:
- README: 快速成功路径
- README: 常见失败排查表
- SECURITY_GUIDELINES: 安全边界 checklist
- 所有命令示例更新

**工作量**: 小-中 (预计 1-2 小时)

---

### #9 测试补齐

**测试矩阵**:
| 测试文件 | 覆盖功能 |
|----------|----------|
| test_policy.py | 域名策略 |
| test_scope_audit.py | 越界检测 |
| test_doctor.sh | 自检 |
| test_cleanup.sh | 清理 |
| test_diff_captures.py | 差异分析 |
| test_navlog.sh | 导航日志 |
| test_integration.sh | 全链路 |

**工作量**: 大 (预计 4 小时，与各功能并行)

---

## 总工作量估算

| Phase | 功能数 | 预计时间 |
|-------|--------|----------|
| Phase 1 | 1 | 4-6 小时 |
| Phase 2 | 2 | 4-6 小时 |
| Phase 3 | 2 | 4-6 小时 |
| Phase 4 | 4 | 11-14 小时 |
| **总计** | **9** | **23-32 小时** |

---

## 里程碑

| 里程碑 | 完成标志 | 目标日期 |
|--------|----------|----------|
| M1: 安全加固 | P0-2 域名约束完成 | TBD |
| M2: 可运维 | doctor + cleanup 完成 | TBD |
| M3: 分析增强 | diff + navlog 完成 | TBD |
| M4: 可发布 | 文档+测试+安装 完成 | TBD |

---

## 下一步

请选择执行方式:
1. **顺序执行** - 按 Phase 1 → 2 → 3 → 4 顺序
2. **跳过某些功能** - 指定要实现的功能编号
3. **调整优先级** - 重新排序
