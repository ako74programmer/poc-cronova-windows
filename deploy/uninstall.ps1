[CmdletBinding()]
param([switch]$Purge)
$ErrorActionPreference = "Stop"
sc.exe stop Cronova 2>$null | Out-Null
sc.exe stop CronovaExecutor 2>$null | Out-Null
sc.exe delete Cronova 2>$null | Out-Null
sc.exe delete CronovaExecutor 2>$null | Out-Null
$Install = Join-Path $env:ProgramFiles "Cronova"
Remove-Item $Install -Recurse -Force -ErrorAction SilentlyContinue
if ($Purge) { Remove-Item (Join-Path $env:ProgramData "Cronova") -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "Cronova removed including data." }
else { Write-Host "Cronova binaries and services removed; data retained under $env:ProgramData\Cronova." }
