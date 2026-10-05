[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$IncludeLogs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Clear-DirectoryContents {
    param(
        [Parameter(Mandatory=$true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return
    }

    Get-ChildItem -LiteralPath $Path -Force | ForEach-Object {
        $target = $_.FullName
        if ($PSCmdlet.ShouldProcess($target, 'Remove')) {
            Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
        }
    }
}

function Remove-FileIfExists {
    param(
        [Parameter(Mandatory=$true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Remove')) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    }
}

function Assert-CronovaNotRunning {
    $running = @(Get-Process -Name 'cronova' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        $ids = ($running | Select-Object -ExpandProperty Id) -join ', '
        throw "Cannot reset test state while cronova is running. Stop process 'cronova' first. Active PID(s): $ids"
    }
}

$repo = Get-RepoRoot

$dbFile = Join-Path $repo 'data\cronova.db'
$workspaceRoot = Join-Path $repo 'workspaces'
$artifactRoot = Join-Path $repo 'artifacts'
$tmpRoot = Join-Path $repo '.tmp'
$m2Root = Join-Path $repo '.m2'
$logRoot = Join-Path $repo 'logs'

Write-Output "Resetting test state under $repo"
Write-Output "- remove DB: $dbFile"
Write-Output "- clear workspaces: $workspaceRoot"
Write-Output "- clear artifacts: $artifactRoot"
Write-Output "- clear temp: $tmpRoot"
Write-Output "- clear local Maven cache: $m2Root"
if ($IncludeLogs) {
    Write-Output "- clear logs: $logRoot"
}

Assert-CronovaNotRunning

Remove-FileIfExists -Path $dbFile
Clear-DirectoryContents -Path $workspaceRoot
Clear-DirectoryContents -Path $artifactRoot
Clear-DirectoryContents -Path $tmpRoot
Clear-DirectoryContents -Path $m2Root

if ($IncludeLogs) {
    Clear-DirectoryContents -Path $logRoot
}

Write-Output 'Reset complete.'