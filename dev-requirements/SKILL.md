---
name: dev-requirements
description: 开发 ssg-sales-ops、metadata、spark 等同级目录项目时的通用要求：中文、PowerShell、原生文件编辑、主工作区 IDEA MCP build、worktree 使用 mvn、临时文件入 .tmp、后端 auth/admin 分服务 MR、前端 master/develop 双 MR、验证分级（非必要不开浏览器，默认不做页面验证）；以及数据库硬规则——默认个人账号 p_renxp4，服务账号 a_appconnect 必须逐次申请（各环境的服务账号明文密码已写在 Skill 内，不必再解 jasypt）。
---

# 团队开发要求（通用）

> 硬规则：`ssg-sales-ops` 的 auth 服务只投 `auth-release`，admin 服务只投 `admin-release`，两者是两个服务；前端同一改动必须从 `master`、`develop` 各自独立拉分支并分别提 MR，绝不互合环境分支。

## 数据库访问（第 0 条硬规则）

**平时一律用个人账号 `p_renxp4`；服务账号 `a_appconnect` 每次使用前必须单独申请，用户明确同意后才能连。下面已经把各环境服务账号密码解好写着，不要再自己去解 jasypt。**

### 账号、权限与申请

| 账号 | 身份 | 什么时候能用 |
|---|---|---|
| `p_renxp4` / `K7~pL2=zR9;vT4_` | 个人账号 | **默认全用它**：排查、核对、修数、导出、写探针、只读分析 |
| `a_appconnect` / 见下表 | 项目服务账号（应用 datasource 身份） | **必须先申请**：回复里写清 ①哪套环境 ②为什么个人账号不够（缺对象权限 / 要复现服务侧行为 / 验证权限或 RLS）③要跑什么范围，等用户明确同意（"可以 / 同意 / 用吧"）后才连 |
| 应用自己启动（`mvn spring-boot:run`、IDEA 起 admin/auth、flyway） | Spring 用项目配置 | 不需要申请，这是服务自身行为，不是人工连库 |

- 未经同意用 `a_appconnect` 查任何东西 = 违规，立刻停手并报告。
- 个人账号权限不够时先报告缺哪张表/哪个 schema/哪一列，**不许**为了推进任务私自换成服务账号。
- 服务账号用完即弃：不写进临时脚本、`.env`、探针类，不保留长连接。
- 服务账号跑过的写操作（UPDATE/DELETE/DDL）必须先给语句预览并拿到确认，只读也一样要先说清用途。

### 服务账号明文密码（已解密，直接用）

| 环境 | 地址 | 库 | 账号 | 密码 | 出处 |
|---|---|---|---|---|---|
| 生产 | `10.62.79.215:5432` | ssg_ops_agent | a_appconnect | `sIN0dTD%Js56` | admin、auth 各自的 `application-lmp-*-prod.yml`（原文 `ENC(hb7JlW3K/RyADKFniNrPeJvrqnIgSMcj)`） |
| 预发 | `10.62.79.221:5432` | ssg_ops_agent | a_appconnect | `xhZt31tTr#Hz` | `application-lmp-*-pre.yml`、`admin/application-lmp-sy-dev.yml`（明文） |
| tst / dev | `10.62.79.148:5432` | ssg_ops_agent | a_appconnect | `VK0C:XFWf8RV` | `application-lmp-*-tst.yml`、`reston-dev.yml`（明文） |
| sy-dev(196) | `10.196.155.93:5432` | ops_agent | a_appconnect | `GjYE%NUOW3lH` | `auth/application-lmp-sy-dev.yml`（明文） |

**实测（2026-11-12）**：生产 / 预发 / tst 三套用上表密码均登录成功（`current_user=a_appconnect`、`current_database=ssg_ops_agent`），生产明文与密文解出来的一致，可直接用。

### 其他连接（同一份配置，同样已解密）

| 用途 | 地址 | 账号 | 密码 |
|---|---|---|---|
| LUDP Trino 源（Trino→PG 定时同步的 SOURCE） | `pbi-presto-row.ludp.lenovo.com:443` / hive | `p49_g1189` | `Ai_portal@@` |
| LUDP keystore（SSL） | `classpath:keystore/ludp-row-prd-keystore.jks` | — | `abcd-1234` |

### 真需要解新密文时（一般用不上）

`jasypt.encryptor.password=2c8d34a64e38ade6ba2c7441caf32377`，algorithm `PBEWithMD5AndDES`，iv `NoIvGenerator`；用 `~/.m2/repository/org/jasypt/jasypt/1.9.3/jasypt-1.9.3.jar` 的 `StandardPBEStringEncryptor`（`setPassword`+`setAlgorithm`+`setIvGenerator(new NoIvGenerator())`）解即可。**不要再为此现查现试**。

### 连接写法（密码含 `~ = ; _ % :`，必须按此处理）

| 方式 | 正确写法 |
|---|---|
| psql | `$env:PGPASSWORD='K7~pL2=zR9;vT4_'`（服务账号同理换密码）后再 `psql -h 10.62.79.215 -p 5432 -U p_renxp4 -d ssg_ops_agent -c "..."`；PowerShell 必须单引号，否则 `;` `~` `%` 会被解析 |
| JDBC | `props.setProperty("user","p_renxp4")` + `props.setProperty("password","K7~pL2=zR9;vT4_")`，**禁止把账号密码拼进 JDBC URL**（`;` `=` `%` `:` 都会破坏 URL 解析） |
| Python (psycopg) | `psycopg.connect(host=..., dbname=..., user="p_renxp4", password=os.environ["PGPASSWORD"])` |
| DataGrip / IDEA 数据库面板 | user 填账号，密码直接粘，不要 URL 编码 |

执行任何 `psql` / JDBC / psycopg 之前自检两件事：① user 是 `p_renxp4`，或 ② user 是 `a_appconnect` 且本轮已经拿到用户同意。日志和回复里不回显密码明文，用 `$env:PGPASSWORD` / 环境变量传递。

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
17. **非必要不开浏览器。** `bsk_*` 是最贵的一类工具——一次页面动作就占一个 step，一个 step 8–15 秒。本机 2026-11-09~11 三天实测：4333 次浏览器调用、1574 个 step、合计 6h17m，占全部 step 的 17%、墙钟的 13%，个别轮次超过 40%；单是 `bsk_session` 就被调了 1956 次。所以浏览器不是"验证手段之一"，是**最后一档手段**。按改动类型取最小够用的一组：
    - 后端逻辑 / 接口 / DAO / SQL：IDEA build 或 `mvn -q compile` + 目标接口真实调用一次；不启浏览器。
    - 纯文案 / 权限 key / 常量 / 配置：只跑 `npm run type-check`；不 build、不截图。
    - 前端逻辑（不改样式）：`type-check` + 目标页面加载一次，确认无 console error 即可。
    - 前端视觉 / 布局 / 响应式：`type-check` 仍必做；**浏览器截图默认不做**，仅当用户明确要求，或改动涉及栅格/断点/多分辨率且无法用 DOM 文本判断时才做。
    开浏览器前必须同时满足三条：① 用户明确要求或点名要看；② 无法用 type-check / build / DOM 文本 / 接口返回判断；③ 动作能压进一次 `run_code` 批量取证。任一条不满足就不开。
    开了就控制步数：一次验证 ≤10 个浏览器 step，超过说明是在用步数换确定性，停下来合并。
18. 确实需要页面验证时：只验一个宽度（1440×900）；用户没点名"三宽度"就不做 1920/2560。一次验证放进一次 `run_code` 批量取证（开页面 → 连点 → 连截 → 读 console/network），禁止"点一下截一张"各占一步。默认优先 TST，除非用户明确只做本地验证。

## 部署与联调

19. 部署很麻烦：能热部署就优先热部署触发，实在不行才重启本地服务。
20. 热部署/启动完成后，再做联调验证；检查原始日志和业务结果，不能只看“请求成功”。