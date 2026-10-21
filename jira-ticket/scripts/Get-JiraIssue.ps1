<#
.SYNOPSIS
  查看指定 Jira 单据的摘要、状态、经办人、描述和最近评论。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Key,
    [int]$CommentLimit = 5,
    [switch]$Open
)
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'jira-config.json'
$cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$base = $cfg.baseUrl.TrimEnd('/')
$envName = if ($cfg.apiTokenEnv) { $cfg.apiTokenEnv } else { 'JIRA_API_TOKEN' }
$token = [Environment]::GetEnvironmentVariable($envName); if ([string]::IsNullOrWhiteSpace($token)) { $token = $cfg.apiToken }; if ([string]::IsNullOrWhiteSpace($token)) { throw '未配置 Jira Token。' }
$headers = @{ Accept = 'application/json' }
if ($cfg.authType -eq 'basic') { $username = if ($cfg.username) { $cfg.username } else { $env:JIRA_USERNAME }; $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$username`:$token")); $headers['Authorization'] = "Basic $b64" } else { $headers['Authorization'] = "Bearer $token" }
$fields = 'summary,status,assignee,reporter,creator,priority,project,issuetype,updated,description,comment'
$issue = Invoke-RestMethod -Uri "$base/rest/api/2/issue/${Key}?fields=$fields" -Headers $headers -Method Get
$f = $issue.fields
Write-Host "单据: $($issue.key)" -ForegroundColor Cyan; Write-Host "标题: $($f.summary)"; Write-Host "项目/类型: $($f.project.key) / $($f.issuetype.name)"; Write-Host "状态: $($f.status.name)   优先级: $(if ($f.priority) { $f.priority.name } else { '-' })"; Write-Host "经办: $(if ($f.assignee) { $f.assignee.name } else { '-' })   报告人: $(if ($f.reporter) { $f.reporter.name } else { '-' })"; Write-Host "更新: $($f.updated)"; Write-Host "链接: $base/browse/$($issue.key)" -ForegroundColor DarkCyan; Write-Host ''; Write-Host '描述:' -ForegroundColor Cyan; Write-Host ($f.description ?? '')
$comments = @($f.comment.comments); if ($comments.Count -gt 0) { Write-Host ''; Write-Host "最近 $([Math]::Min($CommentLimit, $comments.Count)) 条评论:" -ForegroundColor Cyan; for ($idx = [Math]::Max(0, $comments.Count - $CommentLimit); $idx -lt $comments.Count; $idx++) { $c = $comments[$idx]; Write-Host ("- " + $(if ($c.author) { $c.author.name } else { '-' }) + " @ " + $c.updated) -ForegroundColor Gray; Write-Host ($c.body ?? '') } }
if ($Open) { Start-Process ("$base/browse/$($issue.key)") }