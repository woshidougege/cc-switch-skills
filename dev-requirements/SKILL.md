---
name: dev-requirements
description: 开发 ssg-sales-ops、metadata、spark 等同级目录项目时的通用开发要求：中文回复、PowerShell、原生读写文件（不用 IDEA MCP 文件接口）、用 IDEA MCP build 编译（不用 mvn）、临时脚本入 .tmp、worktree 先征询、分支与 MR 约定、不提交本地开发者模式代码、热部署优先。
---

# 团队开发要求（通用）

## 工具与文件

1. 全程中文回复（代码、命令、技术术语除外）。
2. Windows 原生环境：命令显式用 PowerShell，禁止交给 bash/sh。
3. 读写/编辑文件用原生能力（PowerShell 原生读写），不要用 IDEA MCP 的文件接口（慢）；IDEA MCP 只用于构建和调试。
4. 编译不要用 mvn 命令，调用 IDEA MCP 的 build。
5. 临时脚本写到 git 忽略的目录（如 `.tmp/`），不要散落在仓库。
6. 工作区选择（主工作区还是 worktree）看情况，动手前先询问确认，不要自行决定。

## 分支与提交

7. 同级目录下的项目，按各自主开发分支拉最新代码：
   - ssg-sales-ops → `admin-release`
   - metadata → `main`
   - spark → `main`
8. 开发完提 MR，描述写清楚改动和原因。
9. `git commit` 不加任何 AI 署名（无 Co-Authored-By / Codex 之类）。
10. 本地联调/开发者模式代码绝不提交：如 `vite.config.ts` 里的开发者 user 头、`.env.development.local` 等，否则所有人打开前端都变开发者。

## 部署与联调

11. 部署很麻烦：能热部署就优先热部署触发，实在不行才重启本地服务。
12. 热部署/启动完成后，再做联调验证（连本地后端测）。