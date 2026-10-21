<#
.SYNOPSIS
  校验 Jira API Token 是否可用，并打印账号信息、PAT 信息和建单权限。
#>
[CmdletBinding()]
param([string]$ApiToken = '')
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'jira-config.json'
$cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$envName = if ($cfg.apiTokenEnv) { $cfg.apiTokenEnv } else { 'JIRA_API_TOKEN' }
$token = $ApiToken; if ([string]::IsNullOrWhiteSpace($token)) { $token = [Environment]::GetEnvironmentVariable($envName) }; if ([string]::IsNullOrWhiteSpace($token)) { $token = $cfg.apiToken }; if ([string]::IsNullOrWhiteSpace($token)) { throw "未配置 Jira Token。请设置 $envName 或填写 jira-config.json 的 apiToken。" }
$base = $cfg.baseUrl.TrimEnd('/')
$headers = @{ Accept = 'application/json' }
if ($cfg.authType -eq 'basic') { $username = if ($cfg.username) { $cfg.username } else { $env:JIRA_USERNAME }; if (-not $username) { throw 'Basic 认证需要用户名。' }; $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$username`:$token")); $headers['Authorization'] = "Basic $b64" } else { $headers['Authorization'] = "Bearer $token" }
try { $me = Invoke-RestMethod -Uri "$base/rest/api/2/myself" -Headers $headers -Method Get; Write-Host '✅ Token 可用' -ForegroundColor Green; Write-Host "账号     : $($me.name)"; Write-Host "显示名   : $($me.displayName)"; Write-Host "邮箱     : $($me.emailAddress)" } catch { Write-Host ('❌ Token 校验失败: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
try { $perm = Invoke-RestMethod -Uri "$base/rest/api/2/mypermissions?projectKey=$($cfg.projectKey)" -Headers $headers -Method Get; $can = $perm.permissions.CREATE_ISSUES.havePermission; Write-Host ("建单权限 : " + $(if ($can) { '有' } else { '无' })) } catch { }
try { $meta = Invoke-RestMethod -Uri "$base/rest/api/2/issue/createmeta/$($cfg.projectKey)/issuetypes/1" -Headers $headers -Method Get; $req = @($meta.values | Where-Object { $_.required } | ForEach-Object { $_.fieldId }); Write-Host ("必填项   : " + ($req -join ', ')) } catch { }