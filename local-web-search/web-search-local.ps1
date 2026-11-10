<#
.SYNOPSIS
  Local web search with no API key, using this machine's own browser / network.
.DESCRIPTION
  Backends:
    browser (default) Headless Chrome renders the SERP; results parsed from the DOM.
    rss               Bing RSS endpoint over plain HTTP (fast, no browser process).
  A normal desktop User-Agent is sent, otherwise Bing randomly serves junk SERPs to
  HeadlessChrome. Every browser run is validated (search box matches the query and at
  least one organic result exists) and retried up to 3 times; if it still fails the
  script falls back to the RSS backend.
.PARAMETER Query
  Search query (any language; it is percent-encoded).
.PARAMETER Max
  Maximum number of results to emit (default 8).
.PARAMETER KeepProfile
  Do not use incognito. Use this when you deliberately want the shared Chrome profile
  (e.g. a copied, logged-in profile) instead of a clean per-run context.
.PARAMETER AsJson
  Emit JSON instead of objects, easier to consume from scripts/agents.
.EXAMPLE
  .\web-search-local.ps1 -Query "deepseek harness" -Max 5 -AsJson
  .\web-search-local.ps1 -Query "2026年 新能源汽车 销量" -Backend browser
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Query,
  [ValidateSet('rss', 'browser')][string]$Backend = 'browser',
  [int]$Max = 8,
  [string]$ChromePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe',
  [switch]$KeepProfile,
  [switch]$AsJson
)

$script:UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
$script:ProfileDir = Join-Path $env:TEMP 'dsh-chrome-search-profile'

function ConvertFrom-BingRedirect([string]$url) {
  if ($url -notmatch 'bing\.com/ck/a') { return $url }
  $m = [regex]::Match($url, '[?&]u=a1([^&]+)')
  if (-not $m.Success) { return $url }
  $b64 = $m.Groups[1].Value.Replace('-', '+').Replace('_', '/')
  switch ($b64.Length % 4) { 2 { $b64 += '==' } 3 { $b64 += '=' } }
  try { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) } catch { return $url }
}

function ConvertTo-PlainText([string]$html) {
  return (($html -replace '<[^>]+>', ' ') -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '\s+', ' ').Trim()
}

function Get-RssResults([string]$q, [int]$max) {
  $url = 'https://www.bing.com/search?q=' + [uri]::EscapeDataString($q) + '&format=rss'
  $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
  [xml]$xml = $resp.Content
  $items = @($xml.rss.channel.item) | Select-Object -First $max
  $i = 0
  foreach ($it in $items) {
    $i++
    [pscustomobject]@{
      Rank    = $i
      Title   = ConvertTo-PlainText ([string]$it.title)
      Url     = ConvertFrom-BingRedirect ([string]$it.link)
      Snippet = ConvertTo-PlainText ([string]$it.description)
      Backend = 'bing-rss'
    }
  }
}

function Get-BrowserResults([string]$q, [int]$max, [string]$chrome, [bool]$keepProfile) {
  if (-not (Test-Path $chrome)) { throw "Chrome not found: $chrome" }
  $url = 'https://www.bing.com/search?q=' + [uri]::EscapeDataString($q)
  $rxBlock = [regex]'(?s)<li class="b_algo".*?</li>'
  $rxLink = [regex]'<h2[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>'
  $rxSnip = [regex]'<p class="[^"]*b_lineclamp[^"]*"[^>]*>(.*?)</p>'
  $rxBox = [regex]'id="sb_form_q"[^>]*value="([^"]*)"'
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $tmp = Join-Path $env:TEMP ('dsh-serp-' + [guid]::NewGuid().ToString('N') + '.html')
    $chromeArgs = @(
      '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
      ("--user-data-dir=" + $ProfileDir), ("--user-agent=" + $UserAgent),
      '--virtual-time-budget=20000', '--dump-dom', $url
    )
    if (-not $keepProfile) { $chromeArgs = @('--incognito') + $chromeArgs }
    & $chrome @chromeArgs 2>$null | Out-File -FilePath $tmp -Encoding utf8
    $html = ''
    if (Test-Path $tmp) { $html = Get-Content -Raw -Path $tmp; Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    if (-not $html) { continue }

    $box = $rxBox.Match($html)
    $echoed = if ($box.Success) { (ConvertTo-PlainText $box.Groups[1].Value) } else { '' }
    $wanted = ConvertTo-PlainText $q
    if ($echoed -and $echoed -ne $wanted) { continue }   # Bing replayed a different SERP

    $results = @()
    foreach ($b in $rxBlock.Matches($html)) {
      $m = $rxLink.Match($b.Value)
      if (-not $m.Success) { continue }
      $s = $rxSnip.Match($b.Value)
      $results += [pscustomobject]@{
        Rank    = $results.Count + 1
        Title   = ConvertTo-PlainText $m.Groups[2].Value
        Url     = ConvertFrom-BingRedirect (($m.Groups[1].Value) -replace '&amp;', '&')
        Snippet = $(if ($s.Success) { ConvertTo-PlainText $s.Groups[1].Value } else { '' })
        Backend = 'chrome-headless'
      }
      if ($results.Count -ge $max) { break }
    }
    if ($results.Count -gt 0) { return $results }
  }
  throw 'Headless Chrome returned no usable SERP after 3 attempts'
}

$items = @()
$used = ''
try {
  if ($Backend -eq 'browser') {
    $items = @(Get-BrowserResults $Query $Max $ChromePath $KeepProfile.IsPresent); $used = 'chrome-headless'
  } else {
    $items = @(Get-RssResults $Query $Max); $used = 'bing-rss'
  }
} catch {
  Write-Warning "backend '$Backend' failed: $($_.Exception.Message); falling back to bing-rss"
  $items = @(Get-RssResults $Query $Max); $used = 'bing-rss'
}

if ($AsJson) {
  [pscustomobject]@{ Query = $Query; Backend = $used; Count = $items.Count; Results = $items } | ConvertTo-Json -Depth 5
} else {
  $items
}
