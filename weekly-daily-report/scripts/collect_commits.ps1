<#
.SYNOPSIS
  遍历工作目录下所有 git 仓库，按日期聚合【指定作者】的提交记录。

.DESCRIPTION
  - 不限分支：时间范围内的提交都算（--all）。主分支仅用于对照，不做过滤。
  - 同一仓库的多个 worktree 共享对象库，按提交哈希去重，避免重复计数。
  - 过滤纯合并提交（没有独立工作内容）。

.EXAMPLE
  .\collect_commits.ps1 -WorkDir "C:\Users\63588\lenovo" -Since 2026-09-01 -Until 2026-10-01 `
      -Authors "renxp4@lenovo.com","renxiangpeng@lenovo.com"
#>
param(
    [Parameter(Mandatory = $true)][string]$WorkDir,
    [Parameter(Mandatory = $true)][string]$Since,
    [Parameter(Mandatory = $true)][string]$Until,
    [Parameter(Mandatory = $true)][string[]]$Authors,
    [string]$OutDir = ""
)

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $WorkDir "report-workspace\commits-$Since"
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$seen = @{}
$rows = @()

foreach ($dir in Get-ChildItem $WorkDir -Directory) {
    if ($dir.Name -eq "report-workspace") { continue }
    if (-not (Test-Path (Join-Path $dir.FullName ".git"))) { continue }

    $repo = $dir.Name
    $count = 0
    foreach ($author in $Authors) {
        $log = git -C $dir.FullName log --all --since=$Since --until=$Until --author=$author `
               --format="%H|%ad|%an|%s" --date=short 2>$null
        foreach ($line in $log) {
            $parts = $line -split '\|', 4
            if ($parts.Count -lt 4) { continue }
            if ($seen.ContainsKey($parts[0])) { continue }
            $seen[$parts[0]] = $true
            $rows += [PSCustomObject]@{ Hash = $parts[0]; Date = $parts[1]; Author = $parts[2]; Repo = $repo; Subject = $parts[3] }
            $count++
        }
    }
    Write-Host ("{0,-32} {1,5} 条" -f $repo, $count)
}

# 过滤纯合并提交
$clean = $rows | Where-Object {
    $_.Subject -notmatch '^Merge ' -and
    $_.Subject -notmatch '^chore\(merge\)' -and
    $_.Subject -notmatch 'Revert "Merge' -and
    $_.Subject -notmatch '^index on ' -and
    $_.Subject -notmatch '^On feature/'
}

$all   = Join-Path $OutDir "commits-all.txt"
$cleanPath = Join-Path $OutDir "commits-clean.txt"
$rows  | Sort-Object Date, Repo | ForEach-Object { "$($_.Date)|$($_.Repo)|$($_.Subject)" } | Set-Content $all -Encoding UTF8
$clean | Sort-Object Date, Repo | ForEach-Object { "$($_.Date)|$($_.Repo)|$($_.Subject)" } | Set-Content $cleanPath -Encoding UTF8

Write-Host ""
Write-Host "指定作者提交共 $($rows.Count) 条，过滤合并后 $($clean.Count) 条"
Write-Host "全部记录: $all"
Write-Host "过滤后  : $cleanPath"
Write-Host ""
Write-Host "按日期统计:"
$clean | Group-Object Date | Sort-Object Name | ForEach-Object { "  {0}  {1,3} 条" -f $_.Name, $_.Count }