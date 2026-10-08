[CmdletBinding()]
param(
    [string]$Source = (Split-Path $PSScriptRoot -Parent),
    [switch]$Start,
    [switch]$FreePort,
    [string]$AdminUser = 'admin',
    [string]$AdminPassword = 'admin123',
    [switch]$PurgeData,
    [string]$AiBaseUrl,
    [string]$AiModel
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path $PSScriptRoot -Parent
$forceCleanScript = Join-Path $repoRoot 'internal\scripts\cronova-force-clean-services.ps1'
$installScript = Join-Path $PSScriptRoot 'install.ps1'

& $forceCleanScript

if ($PurgeData) {
    Remove-Item (Join-Path $env:ProgramData 'Cronova') -Recurse -Force -ErrorAction SilentlyContinue
}

& $installScript -Source $Source -AdminUser $AdminUser -AdminPassword $AdminPassword -Start:$Start -FreePort:$FreePort -AiBaseUrl $AiBaseUrl -AiModel $AiModel
