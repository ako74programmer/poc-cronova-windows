[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run scripts/windows/test-services.ps1 from an elevated PowerShell session.'
}

function Invoke-SC {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Action
    )

    & sc.exe @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "$Action failed with exit code $LASTEXITCODE."
    }
}

function Get-ServiceState {
    param([Parameter(Mandatory = $true)][string]$Name)

    $output = & sc.exe query $Name 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    foreach ($line in $output) {
        if ($line -match 'STATE\s*:\s*\d+\s+(\w+)') {
            return $Matches[1]
        }
    }
    return $null
}

function Wait-ServiceState {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Expected,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $state = Get-ServiceState -Name $Name
        if ($state -eq $Expected) {
            return
        }
        Start-Sleep -Seconds 1
    }

    throw "Service $Name did not reach state $Expected within $TimeoutSeconds seconds."
}

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$PackageScript = Join-Path $RepoRoot 'scripts\package.ps1'
$InstallScript = Join-Path $RepoRoot 'deploy\install.ps1'
$UninstallScript = Join-Path $RepoRoot 'deploy\uninstall.ps1'
$DistDir = Join-Path $RepoRoot 'dist'

try {
    & $PackageScript
    if ($LASTEXITCODE -ne 0) {
        throw "Packaging failed with exit code $LASTEXITCODE"
    }

    & $InstallScript -Source $DistDir -Start
    if ($LASTEXITCODE -ne 0) {
        throw "Install failed with exit code $LASTEXITCODE"
    }

    Wait-ServiceState -Name 'CronovaExecutor' -Expected 'RUNNING' -TimeoutSeconds 30
    Wait-ServiceState -Name 'Cronova' -Expected 'RUNNING' -TimeoutSeconds 30

    Invoke-SC -Arguments @('query', 'CronovaExecutor') -Action 'Query CronovaExecutor service'
    Invoke-SC -Arguments @('query', 'Cronova') -Action 'Query Cronova service'

    Invoke-SC -Arguments @('stop', 'Cronova') -Action 'Stop Cronova service'
    Wait-ServiceState -Name 'Cronova' -Expected 'STOPPED' -TimeoutSeconds 30

    Invoke-SC -Arguments @('stop', 'CronovaExecutor') -Action 'Stop CronovaExecutor service'
    Wait-ServiceState -Name 'CronovaExecutor' -Expected 'STOPPED' -TimeoutSeconds 30

    Write-Host 'Validated install -> start -> status -> stop service lifecycle.'
} finally {
    & $UninstallScript -Purge
}
