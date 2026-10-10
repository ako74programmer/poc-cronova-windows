<#
.SYNOPSIS
  Author side: check, build and package Cronova into one ZIP for another developer.

.DESCRIPTION
  1. scripts\windows\check-all.ps1 (skip with -SkipChecks)
  2. scripts\windows\test-package-smoke.ps1 (builds dist\cronova_windows_amd64.zip
     + SHA256SUMS via scripts\package.ps1 and verifies its contents)
  3. prints the ZIP path, version and SHA-256 to send to the recipient.
  The recipient extracts the ZIP and double-clicks setup.cmd.
#>
[CmdletBinding()]
param(
    [string]$Version,
    [switch]$SkipChecks
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root

$dirty = git status --porcelain
if ($dirty) { Write-Warning 'Working tree has uncommitted changes; the version will be marked -dirty.' }

if (-not $SkipChecks) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\windows\check-all.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Checks failed; release aborted.' }
}

if ($Version) { $env:CRONOVA_RELEASE_VERSION = $Version }
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\windows\test-package-smoke.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Package smoke test failed; release aborted.' }
}
finally { Remove-Item Env:\CRONOVA_RELEASE_VERSION -ErrorAction SilentlyContinue }

$zip = Join-Path $root 'dist\cronova_windows_amd64.zip'
$sum = (Get-Content (Join-Path $root 'dist\SHA256SUMS') -Raw).Split(' ')[0]
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    $entry = $archive.Entries | Where-Object FullName -eq 'VERSION'
    $reader = [IO.StreamReader]::new($entry.Open()); $ver = $reader.ReadToEnd(); $reader.Close()
}
finally { $archive.Dispose() }

Write-Host ''
Write-Host "Release ready: $zip" -ForegroundColor Green
Write-Host "Version : $ver"
Write-Host "Size    : $([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB"
Write-Host "SHA-256 : $sum"
Write-Host 'Send the ZIP; send the SHA-256 separately (recipient: Get-FileHash .\cronova_windows_amd64.zip).'
Write-Host 'Recipient: extract the ZIP and double-click setup.cmd (see README-INSTALL.md for Polish or README-INSTALL.en.md for English).'
