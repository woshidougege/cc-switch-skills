# CC Switch Skills

我的个人 Skills 集合（DSH / Codex / CC Switch 共用），用于发现与更新同步。

## Included skills

- `agent-dev-efficiency`：多步骤 Agent 任务提效策略；先压「单步预算」（一次 `run_code` 干一批活、默认不开浏览器），再谈并行委派；普通任务不建 Goal、不自行设 Token 上限。
- `dev-requirements`：通用开发硬规则，包含 PowerShell、文件/IDE 工具边界、worktree、验证分级（非必要不开浏览器）、以及数据库访问规则（默认个人账号 `p_renxp4`；服务账号 `a_appconnect` 用前必须逐次申请，各环境明文密码已写在 Skill 里，无需再解 jasypt）。
- `external-llm-gateway`：通过本机 WorkBuddy2API 网关调用外部大模型（付费调用需先说明模型与预估 Token）。
- `frontend-design`：前端视觉设计方向、排版与去模板化规范。
- `jira-ticket`：Jira 查询、预览、提交和截图证据流程。
- `local-web-search`：用本机 Chrome（无头）或 Bing RSS 做免 Key 网页搜索。
- `ssg-sales-ops-branch-workflow`：SSG Sales Ops 前后端分支流程；后端 auth/admin 分服务选择 `auth-release`/`admin-release`，前端维护 `master`/`develop` 双独立 MR。
- `weekly-daily-report`：Git 提交采集、日报 Excel 和周报生成。

## 本地凭据文件

- `external-llm-gateway/scripts/config.json`：已入库。Key 只对本机 `http://127.0.0.1:8788/v1` 有效，仓库仅本人使用。
- `jira-ticket/scripts/jira-config.json`：不入库，示例见 `jira-config.example.json`。

## 同步方式

本仓库内容与 `~/.dsh/skills` 保持一致（本地 Skills 目录为准，全量镜像覆盖）。

## Use with CC Switch

1. Open **Skills → Discover → Repository management**.
2. Add `woshidougege/cc-switch-skills` on branch `main`.
3. Install the skills you need and choose the target applications.
4. After changing this repository, use **Check updates** in CC Switch.
