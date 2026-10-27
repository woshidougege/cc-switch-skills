---
name: ssg-sales-ops-branch-workflow
description: 仅适用于 ssg-sales-ops 后端 auth/admin 两个服务和 ssg_sales_ops 前端：分服务选择 auth-release/admin-release，创建独立分支，处理双 MR、cherry-pick、冲突与验收。
---

# SSG Sales Ops 前后端分支工作流

## 适用范围

| 仓库 | 远端识别 |
|---|---|
| 后端 | `dataagent/ssg-sales-ops.git` |
| 前端 | `dataagent/ssg_sales_ops.git` |

后端是同一仓库中的两个服务，不是同一个交付目标：

| 服务 | 代码范围 | 开发基线 | MR 目标 |
|---|---|---|---|
| auth | `smartop-service/auth` | `origin/auth-release` | `auth-release` |
| admin | `smartop-service/admin` | `origin/admin-release` | `admin-release` |

后端修改共享模块或同时影响两个服务时，必须按两个目标分别建立分支和 MR，不能只投其中一个分支。

操作前检查：

```powershell
git rev-parse --show-toplevel
git remote get-url origin
git status --short --branch
```

同时确认：

- 涉及用户可见的主工作区/worktree 切换已获得确认；子 Agent 的内部隔离由 Codex 环境管理。
- 当前任务是否允许子 Agent 并行写入。
- 没有覆盖未提交改动。

## 通用规则

1. 每个独立功能或缺陷修复创建独立开发分支；同一修复的多次提交复用该分支。
2. 分支必须从对应远端最新目标基线创建，不用本地旧分支。
3. 不同服务、不同功能或不同问题不混入同一个交付分支。
4. 环境分支之间不整分支互合；变化通过独立 patch 和 MR 推进。
5. 主 Agent 独占 branch、commit、cherry-pick、push、MR 等 Git 操作。
6. 子 Agent 默认只读；并行写代码时使用主 Agent 分配的互斥文件范围或 Codex 管理的独立 fork。需要切换用户可见 worktree 时再单独确认。
7. 创建 MR 可按任务执行；合并、部署、发布和任何生产动作必须获得用户明确授权。
8. MR 描述说明改了什么、为什么改，不要求 Jira，也不强制完整模板。

## 后端：auth 与 admin 分流

### auth 服务

```powershell
git fetch origin --prune
git switch -c feature/<topic>-auth origin/auth-release
```

- 功能分支：`feature/<topic>-auth`
- 修复分支：`fix/<topic>-auth`
- MR 目标：`auth-release`
- 禁止把 `admin-release` 合并进 auth 分支。

### admin 服务

```powershell
git fetch origin --prune
git switch -c feature/<topic>-admin origin/admin-release
```

- 功能分支：`feature/<topic>-admin`
- 修复分支：`fix/<topic>-admin`
- MR 目标：`admin-release`
- 禁止把 `auth-release` 合并进 admin 分支。

### 共享模块或跨服务改动

`smartop-api`、`smartop-common`、`smartop-component`、根配置等改动先追踪实际使用方：

1. 只被一个服务使用：投对应服务的 release 分支。
2. 同时影响两个服务：分别从 `origin/auth-release`、`origin/admin-release` 创建两个独立分支。
3. 两个分支应用同一份必要 patch，并分别向 `auth-release`、`admin-release` 提 MR。
4. 两个 MR 分别验收，不能假设一个服务通过就代表另一个也通过。
5. 无法确认影响范围时停止并请求用户确认。

### 后端冲突

只同步当前 MR 自己的目标分支，并在对应当前分支解决：

```powershell
# auth
git fetch origin --prune
git merge origin/auth-release

# admin
git fetch origin --prune
git merge origin/admin-release
```

不得用另一服务的 release 分支解决冲突。

## 前端规则

### 环境分支

| 环境 | 分支 |
|---|---|
| TST | `develop` |
| UAT | `release` |
| 生产 | `master` |

### 双独立分支

同一项前端改动必须从两个目标基线各建独立分支，禁止只建一个共用分支后依次提 MR：

1. 从最新 `origin/master` 创建生产分支。
2. 从最新 `origin/develop` 创建 TST 分支。
3. 两个分支分别应用同一份改动。
4. 分别向 `master`、`develop` 创建 MR。
5. 两个 MR 的标题、描述、改动文件列表和实际业务改动必须一致。

推荐命名：

```text
feature/<topic>-master
feature/<topic>-develop
fix/<topic>-master
fix/<topic>-develop
```

### 开发与 cherry-pick

先在一个目标分支完成规范提交，再应用到另一个目标分支：

```powershell
git fetch origin --prune

git switch -c feature/<topic>-master origin/master
# 实现、验证并提交
$canonicalCommit = git rev-parse HEAD

git switch -c feature/<topic>-develop origin/develop
git cherry-pick $canonicalCommit
```

冲突只在当前目标的独立分支解决，不让 `master`、`develop`、`release` 之间互相合并。

默认只要求 `master`、`develop` 两个 MR。只有用户明确要求交付 UAT 时，才从最新 `origin/release` 创建第三个独立分支并沿用同一 patch 和验收要求。

## 冲突处理

1. 每个目标分支从自己的最新远端基线创建。
2. 使用同一笔提交 cherry-pick，或应用同一份 patch。
3. 只允许同步当前 MR 自己的目标分支；禁止合并其他环境或其他服务分支。
4. 冲突解决后重新检查文件范围、业务逻辑、文案和测试结果。
5. Patch ID 不一致时不得提交最终 MR；先定位差异，无法收敛时停止并请求用户决定。

禁止：

```text
develop -> master
master -> develop
release -> master/develop
auth-release <-> admin-release
任何环境分支整分支互合
```

## MR 验收

### 后端每个服务的 MR

- IDEA Build 通过。
- MR 目标与改动服务一致：auth → `auth-release`，admin → `admin-release`。
- 改动文件在预期服务或共享模块范围内。
- MR 可合并。
- 不包含本地配置、开发者请求头或开发者模式代码。
- 需要运行时的改动完成对应服务的接口或业务验证。

### 前端两个 MR

- 两边都通过 `npm run type-check`。
- 两边改动文件列表一致。
- 两边最终 Patch ID 一致；提交 hash 可以不同。
- 两边 MR 标题和描述一致。
- 两个 MR 均可合并。
- 在真实 Chrome 中验证笔记本、1K、2K 宽度；type-check/build 不能替代页面验证。
- 已确认没有执行 `develop -> master`、`master -> develop` 或其他环境分支整分支合并。
- MR 可合并不等于授权合并或部署。

比较最终变更：

```powershell
git diff origin/master...feature/<topic>-master | git patch-id --stable
git diff origin/develop...feature/<topic>-develop | git patch-id --stable
```

两条输出必须一致；否则停止提交最终 MR 并定位差异。