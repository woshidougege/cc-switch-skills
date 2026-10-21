<#
.SYNOPSIS
  创建 Jira 单据。默认只预览；确认后加 -Submit 才真正提交。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Summary,
    [string]$Description = '',
    [string]$DescriptionFile = '',
    [string]$Project = '',
    [string]$IssueType = '',
    [string]$Assignee = '',
    [string]$Reporter = '',
    [string]$Priority = '',
    [string]$Labels = '',
    [string]$Components = '',
    [string]$TestPhase = '',
    [string]$CreationSource = '',
    [string]$BugCategory = '',
    [switch]$Submit
)
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'jira-config.json'
$cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
function Use-Or([string]$value, [string]$fallback) { if ([string]::IsNullOrWhiteSpace($value)) { return $fallback }; return $value }
if ($DescriptionFile) { $Description = Get-Content $DescriptionFile -Raw -Encoding UTF8 }
if ([string]::IsNullOrWhiteSpace($Description)) { throw '必须提供 -Description 或 -DescriptionFile。' }
$projectKey = Use-Or $Project $cfg.projectKey
$issueTypeName = Use-Or $IssueType $cfg.issueType
if (-not $projectKey -or -not $issueTypeName) { throw '缺少项目或问题类型。' }
$fields = [ordered]@{ project = @{ key = $projectKey }; issuetype = @{ name = $issueTypeName }; summary = $Summary; description = $Description }
$assignee = Use-Or $Assignee $cfg.assignee; if ($assignee) { $fields['assignee'] = @{ name = $assignee } }
$reporter = Use-Or $Reporter $cfg.reporter; if ($reporter) { $fields['reporter'] = @{ name = $reporter } }
$priority = Use-Or $Priority $cfg.priority; if ($priority) { $fields['priority'] = @{ name = $priority } }
$labels = Use-Or $Labels $cfg.labels; if ($labels) { $fields['labels'] = @($labels.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$components = Use-Or $Components $cfg.components; if ($components) { $fields['components'] = @($components.Split(',') | ForEach-Object { @{ name = $_.Trim() } }) }
$isDefaultBugForm = ($projectKey -eq $cfg.projectKey) -and ($issueTypeName -eq $cfg.issueType)
$testPhase = Use-Or $TestPhase $cfg.testPhase
if (($isDefaultBugForm -or $TestPhase) -and $testPhase -and $cfg.testPhaseField) { $fields[$cfg.testPhaseField] = @{ value = $testPhase } }
$creationSource = Use-Or $CreationSource $cfg.creationSource
if (($isDefaultBugForm -or $CreationSource) -and $creationSource -and $cfg.creationSourceField) { $fields[$cfg.creationSourceField] = @{ value = $creationSource } }
$bugCategory = Use-Or $BugCategory $cfg.bugCategory
if (($isDefaultBugForm -or $BugCategory) -and $bugCategory -and $cfg.bugCategoryField) { $fields[$cfg.bugCategoryField] = @{ value = $bugCategory } }
$payload = @{ fields = $fields } | ConvertTo-Json -Depth 8
Write-Host ''; Write-Host '========== 将要提交到 Jira 的内容 ==========' -ForegroundColor Cyan
Write-Host "站点     : $($cfg.baseUrl)"; Write-Host "项目/类型: $projectKey / $issueTypeName"; Write-Host "经办人   : $(Use-Or $assignee '（Jira 默认）')"; Write-Host "报告人   : $(Use-Or $reporter '（= 提单账号）')"; Write-Host "标签     : $(Use-Or $labels '-')"; Write-Host "组件     : $(Use-Or $components '-')"; Write-Host "优先级   : $(Use-Or $priority '（Jira 默认）')"
if ($isDefaultBugForm) { Write-Host "测试阶段 : $(Use-Or $testPhase '（未配置！SSGAI Bug 必填）')"; Write-Host "创建来源 : $(Use-Or $creationSource '-')"; Write-Host "Bug 分类 : $(Use-Or $bugCategory '-')" } else { Write-Host '自定义字段: 非默认项目/类型，跳过 SSGAI 专用字段' -ForegroundColor DarkGray }
Write-Host ''; Write-Host '标题：'; Write-Host $Summary; Write-Host ''; Write-Host '正文：'; Write-Host $Description; Write-Host '===========================================' -ForegroundColor Cyan; Write-Host ''
if (-not $Submit) { Write-Host '【预览模式】没有提交。确认无误后加 -Submit。' -ForegroundColor Yellow; return }
if ($isDefaultBugForm -and -not $testPhase) { throw 'Test Phase 没配。' }
$envName = if ($cfg.apiTokenEnv) { $cfg.apiTokenEnv } else { 'JIRA_API_TOKEN' }
$token = [Environment]::GetEnvironmentVariable($envName); if ([string]::IsNullOrWhiteSpace($token)) { $token = $cfg.apiToken }; if ([string]::IsNullOrWhiteSpace($token)) { throw '未配置 Jira Token。' }
$headers = @{ Accept = 'application/json' }
if ($cfg.authType -eq 'basic') { $username = if ($cfg.username) { $cfg.username } else { $env:JIRA_USERNAME }; $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$username`:$token")); $headers['Authorization'] = "Basic $b64" } else { $headers['Authorization'] = "Bearer $token" }
try { $resp = Invoke-RestMethod -Uri "$($cfg.baseUrl.TrimEnd('/'))/rest/api/2/issue" -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($payload)) } catch { $detail = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { '' }; throw "提单失败: $($_.Exception.Message)`n$detail" }
Write-Host ("✅ 已建单: $($resp.key)") -ForegroundColor Green; Write-Host ("   $($cfg.baseUrl.TrimEnd('/'))/browse/$($resp.key)") -ForegroundColor Green