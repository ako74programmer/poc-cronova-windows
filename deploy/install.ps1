[CmdletBinding()]
param(
  [string]$Source = (Split-Path $PSScriptRoot -Parent),
  [switch]$Start,
  [switch]$FreePort,
  [int]$Port,
  [string]$AdminUser,
  [string]$AdminPassword,
  [string]$AiBaseUrl,
  [string]$AiModel
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$script = Join-Path (Split-Path $PSScriptRoot -Parent) 'internal\scripts\cronova-install-from-source.ps1'
& $script @PSBoundParameters
