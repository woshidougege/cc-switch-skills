# CC Switch Skills

Personal Codex Skills for discovery and update checks in CC Switch.

## Included skills

- `dev-requirements`：通用开发硬规则，包含 PowerShell、文件/IDE 工具边界、worktree 和验证要求。
- `ssg-sales-ops-branch-workflow`：SSG Sales Ops 前后端分支流程；后端 auth/admin 分服务选择 `auth-release`/`admin-release`，前端维护 `master`/`develop` 双独立 MR。
- `codex-dev-efficiency`：复杂开发任务的子 Agent 并行、工具组合、集成和验收策略。
- `idea-mcp`：主工作区 IDEA 构建/运行/调试；worktree 使用 PowerShell `mvn`。
- `jira-ticket`：Jira 查询、预览、提交和截图证据流程。
- `weekly-daily-report`：Git 提交采集、日报 Excel 和周报生成。

## Skill boundaries

- 强制开发规则以 `dev-requirements` 为主。
- 分支、cherry-pick、冲突和 MR 验收以 `ssg-sales-ops-branch-workflow` 为主。
- 如何并行、委派和组合 Codex 能力以 `codex-dev-efficiency` 为主。
- Jira、周报、IDEA 的专有流程由各自 Skill 负责，不在其他 Skill 重复。

## Use with CC Switch

1. Open **Skills → Discover → Repository management**.
2. Add `woshidougege/cc-switch-skills` on branch `main`.
3. Install the skills you need and choose the target applications.
4. After changing this repository, use **Check updates** in CC Switch.
