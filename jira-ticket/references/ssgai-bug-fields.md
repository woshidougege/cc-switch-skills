# SSGAI · Bug 字段速查

> 数据来源：`GET /rest/api/2/issue/createmeta/SSGAI/issuetypes/1`（2026-10 实测）。
> 换项目 / 换 Jira 实例时，字段 ID 可能不同，用同一接口重新拉一次即可。

## 必填

| fieldId | 名称 | 类型 | 脚本默认值 |
|---|---|---|---|
| `project` | Project | project | `SSGAI` |
| `issuetype` | Issue Type | issuetype | `Bug` |
| `summary` | Summary | string | 由调用方提供 |
| `reporter` | Reporter | user | 空 = 提单账号（Jira 会用当前用户兜底） |
| **`customfield_18201`** | **Test Phase** | option | **`Pre-Production Test`（必填！漏了 400）** |

## 常用可选

| fieldId | 名称 | 允许值 |
|---|---|---|
| `priority` | 优先级 | `Critical` `High` `Medium` `Low` `Highest` `Lowest` `P1` `P2` `P3` `P4` |
| `components` | Component/s | `BDS AI Agent(BDSAI)` `CDM-FI(CDMFI)` `I&C ROW(INCROW)` `Magellan DI Hub(DIPORTAL)` `Service Portfolio Enablement Platform(SPEP)` `SSG portal` |
| `labels` | 标签 | 自由文本（逗号分隔），例如 `Bookings_Raw` `DataMind_AI` `sdq-probe` |
| `assignee` | 经办人 | itcode，如 `renxp4` `zhangqp5` `qiuping` |
| `customfield_11850` | Bug Category | `Authorization` `Biz Design Issue` `IT Design Issue` `Configuration` `Code Bug` `Previous Release Issue` `Partner Issue` `Product Issue` `Data Issue` `Data Migration` `Integration` `IT Transport` `Network / Infrastructure Issue` `System Performance Issue` `Environment Readiness` `Others` |
| `customfield_14593` | Creation Source | `Manual` `AI Generated(DTIT Agent)` `AI Generated(Datamind)` `AI Generated(Smart Sales AI tool)` `AI Generated(<Agent/AI Tool Name>)` `OTHER` …（共 28 项） |
| `customfield_18200` | Reject Reason | `ID Request` `Change Request` `Out of Scope` `Test Script Issue` `Wrong Test Data` `Question` `Cannot Reproduce` `Incomplete Description` `Wrong User Operation` `Duplicated` `Won't Fix` |
| `customfield_18403` | Sub-Workstream | `SSC` `Service Entitlement` `Service Upsell` `E2E` `OF` `MM` `GL` `PP` `Planning` …（共 32 项） |

## Test Phase 全部可选值（15 个）

```
DEV Test | Standalone SIT | E2E SIT | UAT | Standalone UAT | E2E UAT
Smoke Test | Regression Test | Pre-Production Test | Auto Test
Performance Test | Product Regression Test | Project Regression Test
Cutover | PPS
```

## 自定义字段 ID 覆盖

如果换到别的项目，字段 ID 会变。改 `scripts/jira-config.json` 里的：

- `testPhaseField`（默认 `customfield_18201`）
- `creationSourceField`（默认 `customfield_14593`）
- `bugCategoryField`（默认 `customfield_11850`）

## 建单接口

```
POST {baseUrl}/rest/api/2/issue
Authorization: Bearer <PAT>
Content-Type: application/json; charset=utf-8

{
  "fields": {
    "project":   { "key": "SSGAI" },
    "issuetype": { "name": "Bug" },
    "summary":   "标题",
    "description": "正文（Jira Wiki 格式）",
    "assignee":  { "name": "renxp4" },
    "labels":    ["sdq-probe", "auto"],
    "components":[ { "name": "SSG portal" } ],
    "customfield_18201": { "value": "Pre-Production Test" }
  }
}
```

正文支持 Jira Wiki 标记：`h3. 标题`、`*粗体*`、`* 列表项`、`{code}...{code}`、`{code:sql}...{code}`。