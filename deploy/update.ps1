[CmdletBinding()]
param(
  [string]$Source = (Split-Path -Parent $PSScriptRoot),
  [string]$InstallDir = "$env:ProgramFiles\Cronova"
)
$ErrorActionPreference = "Stop"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Run update.ps1 from an elevated PowerShell session."
}
foreach ($name in "Cronova", "CronovaExecutor") { sc.exe stop $name 2>$null | Out-Null }
foreach ($name in "cronova.exe", "cronova-executor.exe") {
  $src = Join-Path $Source $name
  if (-not (Test-Path $src)) { throw "Missing update binary: $src" }
  $dst = Join-Path $InstallDir $name
  $tmp = "$dst.new"
  Copy-Item $src $tmp -Force
  Move-Item $tmp $dst -Force
}
sc.exe start CronovaExecutor | Out-Null
sc.exe start Cronova | Out-Null
Write-Host "Cronova updated; configuration and ProgramData were preserved."
