---
name: ssg-sales-ops-branch-workflow
description: 仅适用于 ssg-sales-ops 后端和 ssg_sales_ops 前端的开发分支创建、目标分支选择与分支管理。
---

# SSG Sales Ops 前后端分支工作流

## 适用范围

仅适用于以下两个仓库：

| 仓库 | 远端识别 |
|---|---|
| 后端 | `dataagent/ssg-sales-ops.git` |
| 前端 | `dataagent/ssg_sales_ops.git` |

操作前确认仓库远端和工作区状态：

```powershell
git remote get-url origin
git status --short --branch
```

不要覆盖未提交改动。

## 基本规则

1. 每个独立功能或缺陷修复创建一个开发分支，同一功能或修复的多次提交复用该分支。
2. 分支必须从远端最新指定基线创建，不使用本地旧分支作为基线。
3. 不同功能、不同问题不要混入同一个开发分支。
4. 环境分支之间不互相整分支合并，变更通过 MR 按目标环境推进。
5. MR 描述简单说明本次改了什么即可，不要求 Jira，也不强制套用完整模板。

## 后端

### 分支与目标

| 项目 | 分支 |
|---|---|
| 开发基线 | `origin/admin-release` |
| MR 目标 | `admin-release` |

功能使用 `feature/<topic>`，缺陷修复使用 `fix/<topic>`：

```powershell
git fetch origin --prune
git switch -c feature/<topic> origin/admin-release
```

完成开发后创建目标为 `admin-release` 的 MR。

后端只有一个目标分支，如果 MR 冲突，可以把最新 `origin/admin-release` 合回当前开发分支解决。

## 前端

### 环境分支

| 环境 | 分支 |
|---|---|
| tst | `develop` |
| uat | `release` |
| prod | `master` |

### 开发分支

功能和修复统一从远端最新 `origin/master` 创建，避免把 `develop` 或 `release` 中尚未上线的其他内容作为开发基线。

```powershell
git fetch origin --prune
git switch -c feature/<topic> origin/master
```

缺陷修复使用 `fix/<topic>`。

同一项变更只创建一个主开发分支，后续按实际发布环境创建对应 MR，不要求一次把所有 MR 都建出来。

### 环境推进

默认先发 tst；用户明确指定 uat 或 prod 时，再按指定目标推进。

```text
feature/<topic> → develop（tst）
feature/<topic> → release（uat）
feature/<topic> → master（prod）
```

同一个主开发分支依次向需要发布的环境分支创建 MR。`develop`、`release`、`master` 之间不要互相整分支合并。

## 冲突处理

不要把目标环境分支合回共用开发分支，避免把该环境里的其他变更带入后续环境。

前端遇到冲突时，只在发生冲突的环境处理：

```powershell
git fetch origin --prune
git switch -c tmp/<topic>-<target> origin/<target>
git merge feature/<topic>
```

解决冲突并验证后，从该临时分支创建目标为当前环境分支的 MR。

其他环境继续使用原来的 `feature/<topic>` 分支；如果后续环境也冲突，再按同样方式单独创建临时分支处理。
