<#
.SYNOPSIS
  Mirrors the canonical documentation into internal\docs\docs (embedded in cronova.exe).

.DESCRIPTION
  Sources of truth:
    docs\**            -> internal\docs\docs\**   (except historical audit/test reports)
    README.md          -> internal\docs\docs\README.md     (console "README" doc)
    README.pl.md       -> internal\docs\docs\README.pl.md
  docs\README.md is the docs-folder index for GitHub only and is not embedded,
  because the console's README.md slot is the project README.
  The mirror is replaced completely, so deleted docs disappear from it too.

.PARAMETER Check
  Do not write; exit 1 if the mirror differs from the sources (for CI).
#>
[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$src = Join-Path $root 'docs'
$dst = Join-Path $root 'internal\docs\docs'
$exclude = '^(WINDOWS_AUDIT_.*|WINDOWS_.*TEST.*|README)\.md$'

$want = @{}
Get-ChildItem $src -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($src.Length + 1)
  if ($rel -notmatch '\\' -and $_.Name -match $exclude) { return }
  $want[$rel] = $_.FullName
}
$want['README.md'] = Join-Path $root 'README.md'
$want['README.pl.md'] = Join-Path $root 'README.pl.md'

if ($Check) {
  $diff = @()
  $have = @{}
  if (Test-Path $dst) {
    Get-ChildItem $dst -Recurse -File | ForEach-Object { $have[$_.FullName.Substring($dst.Length + 1)] = $_.FullName }
  }
  foreach ($k in $want.Keys) {
    if (-not $have.ContainsKey($k)) { $diff += "missing: $k"; continue }
    if ((Get-FileHash $want[$k]).Hash -ne (Get-FileHash $have[$k]).Hash) { $diff += "differs: $k" }
  }
  foreach ($k in $have.Keys) { if (-not $want.ContainsKey($k)) { $diff += "extra:   $k" } }
  if ($diff) {
    $diff | Sort-Object | ForEach-Object { Write-Host $_ }
    Write-Error 'internal\docs\docs is out of sync: run internal\scripts\sync-embedded-docs.ps1'
    exit 1
  }
  Write-Host "embedded docs in sync ($($want.Count) files)"
  exit 0
}

if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
foreach ($k in $want.Keys) {
  $target = Join-Path $dst $k
  New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
  Copy-Item -LiteralPath $want[$k] -Destination $target
}
Write-Host "synced $($want.Count) files into internal\docs\docs"
