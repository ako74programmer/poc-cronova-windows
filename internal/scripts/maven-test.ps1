[CmdletBinding()]
param(
    [Alias('w')][string]$Workspace,
    [Alias('p')][string]$Project = 'demo'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot
if (-not $Workspace) { $Workspace = Join-Path $repo 'workspaces\springboot-demo' }
$projectDir = Resolve-RepoPath (Join-Path $Workspace $Project)
if (-not (Test-Path -LiteralPath $projectDir -PathType Container)) { throw "Project directory not found: $projectDir" }
$m2 = Join-Path $repo '.m2\repository'
New-Item -ItemType Directory -Force -Path $m2 | Out-Null
Set-JavaMavenToolchain
Write-ToolchainRuntime (Join-Path $projectDir 'toolchain-runtime.txt')
$maven = Get-ConfiguredCommand 'maven'
$mavenArgs = @('-B', "-Dmaven.repo.local=$m2", 'test')
Write-Output "Running: $maven $($mavenArgs -join ' ') in $projectDir"
Invoke-Native $maven $mavenArgs $projectDir
Write-Output "Maven tests succeeded: $projectDir"