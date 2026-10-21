<#
.SYNOPSIS
  查询 Jira 单据：默认查指派给我；也可查与我相关、关键词、项目/状态或自定义 JQL。
#>
[CmdletBinding()]
param(
    [string]$Query = '',
    [string]$Project = '',
    [string]$Status = '',
    [string]$Jql = '',
    [switch]$Mine,
    [switch]$Related,
    [int]$Limit = 20,
    [switch]$Open
)
$ErrorActionPreference = 'Stop'
if ($Mine -and $Related) { throw '不能同时使用 -Mine 和 -Related。' }
$configPath = Join-Path $PSScriptRoot 'jira-config.json'
$cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$base = $cfg.baseUrl.TrimEnd('/')
$envName = if ($cfg.apiTokenEnv) { $cfg.apiTokenEnv } else { 'JIRA_API_TOKEN' }
$token = [Environment]::GetEnvironmentVariable($envName)
if ([string]::IsNullOrWhiteSpace($token)) { $token = $cfg.apiToken }
if ([string]::IsNullOrWhiteSpace($token)) { throw "未配置 Jira Token。请设置 $envName 或填写 jira-config.json 的 apiToken。" }
$headers = @{ Accept = 'application/json' }
if ($cfg.authType -eq 'basic') {
    $username = if ($cfg.username) { $cfg.username } else { $env:JIRA_USERNAME }
    if (-not $username) { throw 'Basic 认证需要用户名。' }
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$username`:$token"))
    $headers['Authorization'] = "Basic $b64"
} else { $headers['Authorization'] = "Bearer $token" }
$finalJql = ''
if ($Jql) { $finalJql = $Jql.Trim() } else {
    $clauses = @()
    if ($Project) { $clauses += "project = $($Project.Trim())" }
    if ($Status) { $clauses += "status = `"$($Status.Replace('"','\"').Trim())`"" }
    if ($Mine) { $clauses += 'assignee = currentUser()' }
    elseif ($Related) { $clauses += '(reporter = currentUser() OR assignee = currentUser() OR creator = currentUser() OR watcher = currentUser())' }
    elseif ($Query) { $safe = ($Query -replace '[\[\]{}()^~*?\\+!"'']',' ').Trim(); if (-not $safe) { throw '查询关键字没有可用字符。' }; $clauses += "text ~ `"$safe`"" }
    else { $clauses += 'assignee = currentUser()' }
    $finalJql = $clauses -join ' AND '
}
if ($finalJql -notmatch '(?i)\bORDER\s+BY\b') { $finalJql += ' ORDER BY updated DESC' }
$fields = 'key,summary,status,assignee,reporter,creator,priority,updated,project,issuetype'
$url = "$base/rest/api/2/search?maxResults=$Limit&fields=$fields&jql=" + [uri]::EscapeDataString($finalJql)
try { $resp = Invoke-RestMethod -Uri $url -Headers $headers -Method Get } catch { Write-Host ('搜索失败: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
Write-Host ('JQL: ' + $finalJql) -ForegroundColor DarkGray
if ($resp.total -eq 0) { Write-Host '没有找到匹配单据。' -ForegroundColor Green; return }
Write-Host ("找到 $($resp.total) 条，显示前 $($resp.issues.Count) 条：") -ForegroundColor Cyan
foreach ($i in $resp.issues) {
    $assignee = if ($i.fields.assignee) { $i.fields.assignee.name } else { '-' }
    $reporter = if ($i.fields.reporter) { $i.fields.reporter.name } else { '-' }
    $type = if ($i.fields.issuetype) { $i.fields.issuetype.name } else { '-' }
    Write-Host ("  $($i.key)  [$($i.fields.status.name)] [$type] $($i.fields.summary)")
    Write-Host ("      经办: $assignee  报告人: $reporter  更新: $($i.fields.updated)") -ForegroundColor Gray
    Write-Host ("      $base/browse/$($i.key)") -ForegroundColor DarkCyan
}
if ($Open -and $resp.issues.Count -gt 0) { Start-Process ("$base/browse/$($resp.issues[0].key)") }