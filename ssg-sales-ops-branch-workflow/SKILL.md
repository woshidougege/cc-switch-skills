---
name: ssg-sales-ops-branch-workflow
description: 仅适用于 ssg-sales-ops 后端 auth/admin 两个服务和 ssg_sales_ops 前端：分服务选择 auth-release/admin-release，创建独立分支，创建前端 master/develop 双 MR 与后端 release MR（GitLab API、中文描述、409 复用），完成 cherry-pick 收尾与 patch-id 一致性校验。
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

## Steps

按以下顺序执行；每一步的命令和参数在对应章节展开。

1. 前置检查：`git rev-parse --show-toplevel`、`git remote get-url origin`、`git status --short --branch`，确认仓库、当前分支和工作区状态。
2. 选基线建分支：auth → `origin/auth-release`，admin → `origin/admin-release`，前端生产 → `origin/master`，前端 TST → `origin/develop`；先 `git fetch origin --prune`，再 `git switch -c feature/<topic>-<target> origin/<target>`。
3. 实现并验证；提交信息先写入 `.tmp/commit-msg.txt`（UTF-8），再用 `git commit -F .tmp/commit-msg.txt`，不要用 bash heredoc。
4. 前端第二个目标分支：先 `git stash push -m autogen -- components.d.ts`，再建分支并 `git cherry-pick <canonicalCommit>`；切分支失败时先清状态，不要继续 cherry-pick。
5. 两条前端分支分别跑 `npm run type-check`，并用 `git patch-id --stable` 比对补丁 id。
6. 中文 MR 描述写入 `.tmp/mr-<target>-desc.md`（UTF-8 无 BOM），由 `.tmp/create-mr.ps1` 读取拼 JSON。
7. 用 `git credential fill` 取 `gitlab.xpaas.lenovo.com` 的 token，POST `/api/v4/projects/{urlencoded path}/merge_requests`；409 时查询并复用已有 MR。
8. 回查每个 MR 的 `state`、`merge_status`、`has_conflicts`，把链接和 target 回填给用户；合并、部署仍需单独授权。

## 通用规则

1. 每个独立功能或缺陷修复创建独立开发分支；同一修复的多次提交复用该分支。
2. 分支必须从对应远端最新目标基线创建，不用本地旧分支。
3. 不同服务、不同功能或不同问题不混入同一个交付分支。
4. 环境分支之间不整分支互合；变化通过独立 patch 和 MR 推进。
5. 主 Agent 独占 branch、commit、cherry-pick、push、MR 等 Git 操作。
6. 子 Agent 默认只读；并行写代码时使用主 Agent 分配的互斥文件范围或 Codex 管理的独立 fork。需要切换用户可见 worktree 时再单独确认。
7. 创建 MR 可按任务执行；合并、部署、发布和任何生产动作必须获得用户明确授权。
8. MR 描述说明改了什么、为什么改，不要求 Jira，也不强制完整模板。
9. MR 通过 GitLab REST API 创建并回填链接，不在浏览器里手工填；同一 source→target 已存在（409）时复用已有 MR，不重复建单。
10. 提交信息、MR 描述先落成 `.tmp` 下的 UTF-8 文件再交给 git 或 GitLab API，不把多行中文直接拼进命令行。

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

# 切分支前清掉生成文件，避免 dirty tree 阻止切换
git stash push -m autogen -- components.d.ts
git switch -c feature/<topic>-develop origin/develop
git cherry-pick $canonicalCommit
```

不要用 `;` 把 `git switch` 和 `git cherry-pick` 串成一条命令：切分支失败后 cherry-pick 仍会在错误分支执行，并留下 `CHERRY_PICK_HEAD`。分步执行并检查每一步的结果。

冲突只在当前目标的独立分支解决，不让 `master`、`develop`、`release` 之间互相合并。

默认只要求 `master`、`develop` 两个 MR。只有用户明确要求交付 UAT 时，才从最新 `origin/release` 创建第三个独立分支并沿用同一 patch 和验收要求。

### cherry-pick 收尾

`components.d.ts` 由 `npm run type-check` 或前端构建自动生成，不是业务改动。它留在工作区时会以 `Please commit your changes or stash them before you switch branches.` 阻止切分支。

```powershell
git status --short --branch
git stash push -m autogen -- components.d.ts
git status --short
```

- 只 stash 生成文件；如果 `git status` 里还有其他生成文件，按同样方式逐个加到 `--` 后面。
- 未跟踪文件（例如本地 `vite.e2e.config.ts`）不阻止切换，但提交前要确认它们不进入 commit。
- stash 中的 `components.d.ts` 可由 type-check 重新生成；需要恢复时用 `git stash pop`。

如果切分支报 `fatal: cannot switch branch while cherry-picking`：

```powershell
Test-Path .git/CHERRY_PICK_HEAD
git cherry-pick --quit
git status --short --branch
git switch -c feature/<topic>-develop origin/develop
git cherry-pick <canonicalCommit>
```

- `git cherry-pick --quit` 只清 cherry-pick/sequencer 状态，不动工作区；不要用 `git reset --hard` 强行清状态。
- `--quit` 后如果仍有上一次 cherry-pick 带入的改动，先确认是保留还是丢弃，再重建分支。
- 重建前确认同名分支不存在，避免 `git switch -c` 因分支已存在再次失败。

第二个分支提交后同样跑 `npm run type-check` 并推送：

```powershell
git push -u origin feature/<topic>-develop
npm run type-check
```

## 创建 GitLab MR（REST API）

固定组合：前端 `master`、`develop` 各一个 MR；后端按服务向 `admin-release` 或 `auth-release` 一个 MR。全部用 GitLab REST API 创建，描述用中文。

### 1. 用 git credential fill 取 token

```powershell
$nl = [char]10
$in = 'protocol=https' + $nl + 'host=gitlab.xpaas.lenovo.com' + $nl + $nl
$cred = $in | git credential fill 2>$null
$token = (($cred | Where-Object { $_ -match '^password=' }) -replace '^password=','').Trim()
if (-not $token) { throw 'git credential fill 未返回 password（token）' }
"token_len=$($token.Length)"
```

- `host` 必须是 `gitlab.xpaas.lenovo.com`；返回的 `password` 就是 GitLab token，`username` 是账号邮箱，不要混用。
- 不要把 token 写进脚本、命令行参数、MR 描述或提交；只打印长度或前缀确认取到。

### 2. 中文描述先写成 UTF-8 文件

路径固定在仓库的 `.tmp` 下，按目标命名：

```text
.tmp/mr-admin-release-desc.md
.tmp/mr-auth-release-desc.md
.tmp/mr-master-desc.md
.tmp/mr-develop-desc.md
```

- 用原生文件编辑写入 Markdown，编码 UTF-8、不带 BOM；不要用 here-string 或多行中文直接拼进 PowerShell 命令。
- 描述写清改了什么、为什么改、影响范围、验证方式；不要求 Jira，也不强制模板。
- 前端 `master`、`develop` 两个 MR 使用同一份描述文本；后端按服务写。

提交前校验编码和内容：

```powershell
$bytes = [System.IO.File]::ReadAllBytes('.tmp/mr-develop-desc.md')
$bytes[0..2]   # 239 187 191 表示带 UTF-8 BOM，需要重写
$d = Get-Content -Raw -Encoding UTF8 '.tmp/mr-develop-desc.md'
$d.Length
[int][char]$d[0]   # 35 = '#'，正常
```

### 3. 建 MR 脚本 `.tmp/create-mr.ps1`

```powershell
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Target,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$DescFile
)

$ErrorActionPreference = 'Stop'

# 1. 从本机 git 凭据取 token（password 字段）
$nl = [char]10
$in = 'protocol=https' + $nl + 'host=gitlab.xpaas.lenovo.com' + $nl + $nl
$cred = $in | git credential fill 2>$null
$token = (($cred | Where-Object { $_ -match '^password=' }) -replace '^password=','').Trim()
if (-not $token) { throw 'git credential fill 未返回 password（token）' }

# 2. 读取 UTF-8 描述并拼 JSON
$desc = Get-Content -Raw -Encoding UTF8 $DescFile
$body = @{
    title         = $Title
    source_branch = $Source
    target_branch = $Target
    description   = $desc
} | ConvertTo-Json -Depth 5 -Compress

$base = 'https://gitlab.xpaas.lenovo.com/api/v4/projects/' + $Project + '/merge_requests'
$headers = @{ 'PRIVATE-TOKEN' = $token }

# 3. POST；409 表示同一 source→target 已有 opened MR，改为查询复用
'POST {0} [{1} -> {2}] desc_len={3}' -f $Project, $Source, $Target, $desc.Length
try {
    $mr = Invoke-RestMethod -Method Post -Uri $base -Headers $headers `
        -ContentType 'application/json; charset=utf-8' `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
    'CREATED !{0} {1} [{2} -> {3}] state={4}' -f $mr.iid, $mr.web_url, $Source, $Target, $mr.state
}
catch {
    $code = $null
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code -ne 409) { throw }

    $query = $base + '?state=opened' +
        '&source_branch=' + [uri]::EscapeDataString($Source) +
        '&target_branch=' + [uri]::EscapeDataString($Target)
    $existing = @(Invoke-RestMethod -Method Get -Uri $query -Headers $headers | Where-Object { $_.iid })
    if ($existing.Count -eq 0) { throw '409 但未查询到已存在的 MR，需人工确认' }

    foreach ($item in $existing) {
        'EXISTING !{0} {1} [{2} -> {3}] state={4}' -f $item.iid, $item.web_url, $item.source_branch, $item.target_branch, $item.state
    }
}
```

- 脚本放在仓库根目录的 `.tmp/create-mr.ps1`，所有命令从仓库根目录执行。
- `$Project` 传 URL 编码后的路径（`%2F` 不能写成 `/`）；`$DescFile` 用相对路径。
- 查询参数里的分支名必须 URL 编码，`feature/x` 中的 `/` 会由 `[uri]::EscapeDataString` 转成 `%2F`。

### 4. 调用：三个 MR 的目标

| 仓库 | `-Project` | `-Source` 示例 | `-Target` |
|---|---|---|---|
| 后端 admin | `dataagent%2Fssg-sales-ops` | `feature/<topic>-admin` | `admin-release` |
| 后端 auth | `dataagent%2Fssg-sales-ops` | `feature/<topic>-auth` | `auth-release` |
| 前端生产 | `dataagent%2Fssg_sales_ops` | `feature/<topic>-master` | `master` |
| 前端 TST | `dataagent%2Fssg_sales_ops` | `feature/<topic>-develop` | `develop` |

```powershell
# 后端 admin（仓库 ssg-sales-ops）
& ./.tmp/create-mr.ps1 `
  -Project 'dataagent%2Fssg-sales-ops' `
  -Source 'feature/<topic>-admin' `
  -Target 'admin-release' `
  -Title 'feat(admin): ...' `
  -DescFile '.tmp/mr-admin-release-desc.md'

# 前端 master（仓库 ssg_sales_ops）
& ./.tmp/create-mr.ps1 `
  -Project 'dataagent%2Fssg_sales_ops' `
  -Source 'feature/<topic>-master' `
  -Target 'master' `
  -Title 'feat(...): ...' `
  -DescFile '.tmp/mr-master-desc.md'

# 前端 develop
& ./.tmp/create-mr.ps1 `
  -Project 'dataagent%2Fssg_sales_ops' `
  -Source 'feature/<topic>-develop' `
  -Target 'develop' `
  -Title 'feat(...): ...' `
  -DescFile '.tmp/mr-develop-desc.md'
```

auth 服务同理：`-Project 'dataagent%2Fssg-sales-ops'`、`-Target 'auth-release'`、`-DescFile '.tmp/mr-auth-release-desc.md'`。

### 5. 409 是正常情况：查询并复用

GitLab 对同一 `source_branch -> target_branch` 只允许一个 opened MR；重复 POST 返回 `(409) Conflict`。这不是失败：

1. 脚本捕获 409 后 GET `/merge_requests?state=opened&source_branch=...&target_branch=...`。
2. 命中已有 MR 就打印 `EXISTING !<iid> <web_url>` 并复用，不重复建单。
3. 不要关闭旧 MR 重开，也不要把 409 当网络错误反复重试。
4. 查询不到却返回 409 时停下来人工确认，可能是分支名或 Project 路径写错。

### 6. 回查并回填链接

```powershell
$Project = 'dataagent%2Fssg_sales_ops'
$Iid = 773
$uri = 'https://gitlab.xpaas.lenovo.com/api/v4/projects/' + $Project + '/merge_requests/' + $Iid
$mr = Invoke-RestMethod -Uri $uri -Headers @{ 'PRIVATE-TOKEN' = $token }
'!{0} [{1} -> {2}] state={3} merge={4} conflicts={5}' -f $mr.iid, $mr.source_branch, $mr.target_branch, $mr.state, $mr.merge_status, $mr.has_conflicts
```

- 用 `iid`、`state`、`merge_status`、`has_conflicts`、`source_branch`、`target_branch` 等 ASCII 字段判断结果。
- PowerShell 5.1 对没有 charset 的 JSON 响应可能按 ISO-8859-1 解码，中文标题会显示成 `æéå...`；这是终端显示问题，以 `web_url` 在浏览器查看为准，不要据此改 MR 描述。
- 最终回复给出每个 MR 的 `!iid`、链接、source→target 和 state。

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
- 回查 `state=opened`、`has_conflicts=False`；刚创建时 `merge_status` 可能为 `checking`，稍后复测。

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

两条输出的第一列必须一致（第二列是 `0000000000000000000000000000000000000000` 占位，不参与比较）；否则停止提交最终 MR 并定位差异。

## Pitfalls

1. **PowerShell 不支持 bash heredoc。** `git commit -q -F - <<'EOF'` 会触发 `ParserError`。把提交信息写入 `.tmp/commit-msg.txt`，改用 `git commit -F .tmp/commit-msg.txt`。
2. **中文描述直接拼进命令会报 `{"error":"description is invalid"}`。** 先把描述写成 `.tmp/mr-<target>-desc.md`（UTF-8 无 BOM），脚本用 `Get-Content -Raw -Encoding UTF8` 读取再 `ConvertTo-Json`；不要用 here-string 或命令参数传多行中文。
3. **重复建单返回 `(409) Conflict` 是正常现象。** 说明同一 source→target 已有 opened MR；改为 `GET /merge_requests?state=opened&source_branch=...&target_branch=...` 查询并复用，不要重复 POST，也不要关闭旧 MR 重开。
4. **生成文件让工作区变脏，切分支被拒。** `components.d.ts` 是 type-check/构建产物，切分支前执行 `git stash push -m autogen -- components.d.ts`；未跟踪的 `vite.e2e.config.ts` 不阻止切换，但不要提交。
5. **`fatal: cannot switch branch while cherry-picking`。** 上一次 cherry-pick 中途失败留下 `.git/CHERRY_PICK_HEAD`；用 `git cherry-pick --quit` 清 sequencer 状态（不要用 `git reset --hard`），确认 `git status --short` 干净后重建分支再 cherry-pick。
6. **不要把 `git switch` 和 `git cherry-pick` 用 `;` 串起来。** 切分支失败后 cherry-pick 仍会在原分支执行，制造残留状态；分步执行并检查退出结果。
7. **POST 前不核对 source/target。** 曾出现把 admin 分支的 payload 发到前端 master 目标的情况；调用脚本时逐条确认仓库、`source_branch`、`target_branch` 三元组，脚本也会打印 `POST ... [source -> target]` 供核对。
8. **回查 MR 时中文显示成 `æéå...`。** PowerShell 5.1 对无 charset 的 JSON 可能按 ISO-8859-1 解码，属于显示问题；以 `web_url` 在浏览器查看为准，判断状态用 ASCII 字段，不要因此改描述。

## Verification

完成前逐条执行并保留结果：

```powershell
# 1. 工作区与分支
git status --short --branch

# 2. 两条前端分支类型检查
git switch feature/<topic>-master
npm run type-check
git switch feature/<topic>-develop
npm run type-check

# 3. 补丁一致性（第一列必须相同）
git diff origin/master...feature/<topic>-master | git patch-id --stable
git diff origin/develop...feature/<topic>-develop | git patch-id --stable
```

- `git status --short` 只应出现已知生成文件；`components.d.ts` 不应进入提交。
- 两个 patch-id 第一列一致；不一致停止建/改 MR，先定位差异。
- 三个 MR 回查 `state=opened`、`has_conflicts=False`；target 分别为 `master`、`develop`、`admin-release`（auth 服务为 `auth-release`）。
- 每个 MR 的 `web_url` 已回填给用户；中文描述在浏览器中正常显示、长度非 0。
- 未执行任何合并、部署或生产动作。
