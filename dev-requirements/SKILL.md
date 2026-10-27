---
name: dev-requirements
description: 开发 ssg-sales-ops、metadata、spark 等同级目录项目时的通用要求：中文、PowerShell、原生文件编辑、主工作区 IDEA MCP build、worktree 使用 mvn、临时文件入 .tmp、后端 auth/admin 分服务 MR、前端 master/develop 双 MR、真实浏览器验证。
---

# 团队开发要求（通用）

> 硬规则：`ssg-sales-ops` 的 auth 服务只投 `auth-release`，admin 服务只投 `admin-release`，两者是两个服务；前端同一改动必须从 `master`、`develop` 各自独立拉分支并分别提 MR，绝不互合环境分支。

## 工具与文件

1. 全程中文回复（代码、命令、技术术语除外）。
2. Windows 原生环境：每次 shell/exec/terminal 调用都显式使用 PowerShell，禁止 bash/sh/cmd，禁止依赖工具默认 shell。
3. 检查、读取和编辑文件优先使用 Codex 原生文件能力；没有原生工具时使用 PowerShell。IDEA MCP 禁止用于文件写入。
4. 构建按工作区选择：主工作区优先当前会话可发现的 native IDE MCP build，失败后再用 `idea-mcp` wrapper；worktree 无法可靠调用 IDEA，必须使用 PowerShell 执行 `mvn`。不要在 worktree 中等待 IDEA。
5. 临时脚本、描述、截图中间件写入 git 忽略的 `.tmp/`，完成后清理，不散落在仓库。
6. 涉及用户可见的主工作区/worktree 切换时必须先征得确认。子 Agent 的内部隔离由当前 Codex 环境管理，不额外等同于切换用户主工作区。

## 分支与 MR

7. `ssg-sales-ops` 后端按服务分流，不能因为同属一个仓库就统一投 `admin-release`：

| 服务 | 代码范围 | 开发基线 | MR 目标 |
|---|---|---|---|
| auth | `smartop-service/auth` 及仅 auth 使用的代码 | `origin/auth-release` | `auth-release` |
| admin | `smartop-service/admin` 及仅 admin 使用的代码 | `origin/admin-release` | `admin-release` |
| 共享模块/同时影响两服务 | `smartop-api`、`smartop-common`、`smartop-component`、根配置等 | 分别从两个目标基线建分支 | 分别提 `auth-release`、`admin-release` MR |

无法判断影响范围时先做调用链检查；仍不确定则停止并向用户确认，不能猜目标分支。

8. 每个服务从各自最新远端基线创建独立开发分支。auth 分支禁止合并 `admin-release`，admin 分支禁止合并 `auth-release`。
9. 前端 `ssg_sales_ops` 同一项改动必须分别从最新 `origin/master`、`origin/develop` 创建两个独立分支，应用同一份改动，并分别向 `master`、`develop` 提两个内容一致的 MR。
10. 前端两个 MR 的标题、描述、改动文件列表和最终 Patch ID 必须一致；提交 hash 可以不同。Patch ID 不一致时不得自行放行，必须定位差异或请求用户决定。
11. 禁止 `develop ↔ master` 或任何环境分支整分支互合传播改动；变化通过独立 patch 和各自冲突处理推进。
12. 其他同级项目按各自基线拉最新代码：
    - metadata → `main`
    - spark → `main`
13. 完整分支、cherry-pick、冲突和验收流程以 `ssg-sales-ops-branch-workflow` 为准。
14. 开发完提 MR，描述写清改动和原因。创建 MR 可按任务执行；合并、部署、发布或触发生产动作必须获得用户明确授权。
15. `git commit` 不加任何 AI 署名（无 Co-Authored-By / Codex 之类）。
16. 本地联调/开发者模式代码绝不提交：如 `vite.config.ts` 里的开发者 user 头、`.env.*.local`、本地 profile 等，否则会影响所有使用者。
17. UI 改动不能只靠 type-check/build；按项目 Skill 在真实 Chrome 中验证笔记本、1K、2K 宽度，默认优先 TST，除非用户明确只做本地验证。

## 部署与联调

18. 部署很麻烦：能热部署就优先热部署触发，实在不行才重启本地服务。
19. 热部署/启动完成后，再做联调验证；检查原始日志和业务结果，不能只看“请求成功”。