[CmdletBinding()]
param(
  [string]$Source = (Split-Path -Parent $PSScriptRoot),
  [string]$InstallDir = "$env:ProgramFiles\Cronova"
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$script = Join-Path (Split-Path $PSScriptRoot -Parent) 'internal\scripts\cronova-update.ps1'
& $script -Source $Source -InstallDir $InstallDir
