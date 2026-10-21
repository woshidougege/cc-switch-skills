---
name: jira-ticket
description: 通过联想 XPaaS Jira REST API 辅助建单、查指派给自己的单、查与自己相关的单、按关键词/项目/状态搜索以及查看单据详情。默认只预览，用户确认后才提交。
---

# Jira 助手（XPaaS）

把 Jira 当作通用协作系统使用：**先查重和相关单，再决定是否建单**。默认只预览，用户确认后才提交，不会静默建单。

## 首次配置

配置文件在 `scripts/jira-config.json`。

推荐优先使用环境变量保存 Token：

```powershell
$env:JIRA_API_TOKEN = "<your-jira-pat>"
```

也可以填写 `scripts/jira-config.json` 的 `apiToken`。**不要把真实 Token 提交到仓库、贴进对话或写进 Jira 正文。**

检查配置：

```powershell
pwsh -File scripts/Verify-JiraKey.ps1
```

## 查询单据

默认查询“指派给我”的单：

```powershell
pwsh -File scripts/Search-Jira.ps1 -Mine
```

查询“与我相关”的单（报告人、经办人、创建人、关注人）：

```powershell
pwsh -File scripts/Search-Jira.ps1 -Related
```

按关键词搜索：

```powershell
pwsh -File scripts/Search-Jira.ps1 -Query "metadata 同步"
```

按项目和状态搜索：

```powershell
pwsh -File scripts/Search-Jira.ps1 -Project SSGAI -Status Open
```

高级 JQL：

```powershell
pwsh -File scripts/Search-Jira.ps1 -Jql "project = SSGAI AND assignee = currentUser() ORDER BY updated DESC"
```

查看某张单的详情：

```powershell
pwsh -File scripts/Get-JiraIssue.ps1 -Key SSGAI-681
```

常用参数：

- `-Limit 20`：返回条数
- `-Open`：打开第一条匹配单
- `-Project SSGAI`：限定项目
- `-Status Open`：限定状态
- `-Jql "..."`：自定义 JQL，优先级最高

## 创建单据

### 1. 先查重

```powershell
pwsh -File scripts/Search-Jira.ps1 -Query "关键词"
```

有同类单时优先告诉用户单号，不要重复开。

### 2. 写正文

正文写到 UTF-8 文本文件，建议包含：

```text
【问题现象】
【复现步骤】
【期望结果】
【实际结果】
【影响范围】
【初步原因】
【补充信息】
```

不要编造复现步骤、错误码或影响面；不确定就写“待确认”。

### 3. 预览

```powershell
pwsh -File scripts/New-JiraIssue.ps1 `
  -Summary "问题标题" `
  -DescriptionFile .\jira-desc.txt
```

预览会打印项目、类型、经办人、标签、测试阶段、标题和正文，但不会提交。

### 4. 用户确认后提交

```powershell
pwsh -File scripts/New-JiraIssue.ps1 `
  -Summary "问题标题" `
  -DescriptionFile .\jira-desc.txt `
  -Submit
```

成功后会返回 `SSGAI-xxx` 和浏览器链接。

## 非 SSGAI / 非 Bug 建单

默认项目、类型和自定义字段来自 `jira-config.json`。其他项目用参数覆盖：

```powershell
pwsh -File scripts/New-JiraIssue.ps1 `
  -Project OTHER `
  -IssueType Task `
  -Summary "任务标题" `
  -DescriptionFile .\jira-desc.txt
```

非默认项目/类型会自动跳过 SSGAI 专用的 Test Phase、Creation Source、Bug Category 字段。

## 附件与 Jira 页面

- 不要把 `zip`、需要解压的包作为唯一证据。
- 优先逐张上传 PNG/JPG，并把图片用 Jira Wiki 语法内嵌到描述或备注：

```text
!image-name.png!
```

- Jira 单页应能直接看到关键截图，不能依赖下载后解压。
- 上传附件使用 Jira REST API：

```text
POST /rest/api/2/issue/{key}/attachments
X-Atlassian-Token: no-check
```

## 共享给同事

共享前必须去掉 `scripts/jira-config.json` 中的真实凭据：

- `apiToken` 置空；
- `username` 按需置空；
- 保留 `apiTokenEnv`，让每个人配置自己的 `JIRA_API_TOKEN`；
- 不要把带真实 Token 的 zip 发给别人。

## SSGAI Bug 字段

SSGAI Bug 的必填自定义字段和可选值见 `references/ssgai-bug-fields.md`。默认：

- Test Phase：`Pre-Production Test`
- Creation Source：`AI Generated(Smart Sales AI tool)`
- 标签：`sdq-probe,auto`

示例单写法和信息密度参考 `references/example-ssgai-671.md`。

## 硬性约束

- **没经用户确认，不许 `-Submit`。**
- 不要伪造复现步骤、错误信息或影响面。
- 不要把 Token、Cookie、密码写进 Jira 正文或附件。
- 不要用 `zip` 作为唯一证据，确保 Jira 页面能直接查看关键信息。