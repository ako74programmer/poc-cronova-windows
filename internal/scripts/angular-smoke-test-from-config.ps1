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
$artifactsPath = if ($Artifacts) { Resolve-SdlcRepoPath -Path $Artifacts -RepoRoot $settings.RepoRoot } else { $settings.ArtifactsPath }

if ([string]::IsNullOrWhiteSpace($artifactsPath)) {
    throw 'Artifacts path could not be resolved from config or parameters.'
}

$indexPath = Join-Path $artifactsPath 'dist\browser\index.html'
if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
    throw 'frontend artifact missing'
}

$indexContent = Get-Content -LiteralPath $indexPath -Raw
if ($indexContent -notmatch '(?i)<html') {
    throw 'index.html is not valid HTML'
}

Write-Output 'Angular artifact smoke test passed'