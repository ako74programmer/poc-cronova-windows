[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Config,
    [string]$Workspace,
    [string]$Artifacts
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot
. (Join-Path $repo 'scripts\sdlc\common\AngularConfig.ps1')

$settings = Get-AngularSdlcConfig -Config $Config
$configPath = $settings.ConfigPath
$workspacePath = if ($Workspace) { Resolve-SdlcRepoPath -Path $Workspace -RepoRoot $settings.RepoRoot } else { $settings.WorkspacePath }
$artifactsPath = if ($Artifacts) { Resolve-SdlcRepoPath -Path $Artifacts -RepoRoot $settings.RepoRoot } else { $settings.ArtifactsPath }

if ([string]::IsNullOrWhiteSpace($workspacePath)) {
    throw 'Workspace path could not be resolved from config or parameters.'
}

if ([string]::IsNullOrWhiteSpace($artifactsPath)) {
    throw 'Artifacts path could not be resolved from config or parameters.'
}

New-Item -ItemType Directory -Force -Path $workspacePath | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $artifactsPath 'logs') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $artifactsPath 'reports') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $artifactsPath 'metadata') | Out-Null

$configText = Get-Content -LiteralPath $configPath -Raw
if ($configText -match '(/c/Users/|/home/|/tmp/|/var/|systemd|launchd)') {
    throw 'Configuration contains a non-portable Unix/private path.'
}

if (-not $settings.ProjectId) {
    throw 'Angular config lacks project.id.'
}

if ($settings.ProjectKind -ne 'angular') {
    throw 'Config kind must be angular.'
}

$runtimeFile = Join-Path $artifactsPath 'metadata\runtime.txt'
@(
    "workspace=$workspacePath"
    "artifacts=$artifactsPath"
    "config=$configPath"
) | Set-Content -LiteralPath $runtimeFile -Encoding UTF8

$node = Get-Command 'node.exe' -ErrorAction SilentlyContinue
if (-not $node) { $node = Get-Command 'node' -ErrorAction SilentlyContinue }
if (-not $node) { throw 'Required command not found: node' }

$npm = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
if (-not $npm) { $npm = Get-Command 'npm' -ErrorAction SilentlyContinue }
if (-not $npm) { throw 'Required command not found: npm' }

$nodeVersion = (& $node.Source --version).Trim()
$npmVersion = (& $npm.Source --version).Trim()

$nodeVersion | Set-Content -LiteralPath (Join-Path $artifactsPath 'metadata\node-version.txt') -Encoding UTF8
$npmVersion | Set-Content -LiteralPath (Join-Path $artifactsPath 'metadata\npm-version.txt') -Encoding UTF8

Write-Output $nodeVersion
Write-Output $npmVersion
Write-Output "Angular configuration is valid: $configPath"