[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Config,
    [string]$Artifacts
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot
. (Join-Path $repo 'scripts\sdlc\common\FullstackConfig.ps1')

$settings = Get-FullstackSdlcConfig -Config $Config
$artifactsPath = if ($Artifacts) { Resolve-SdlcRepoPath -Path $Artifacts -RepoRoot $settings.RepoRoot } else { $settings.ArtifactsPath }

if ([string]::IsNullOrWhiteSpace($artifactsPath)) {
    throw 'Artifacts path could not be resolved from config or parameters.'
}

$logsPath = Join-Path $artifactsPath 'logs'
New-Item -ItemType Directory -Force -Path $logsPath | Out-Null

foreach ($name in @('frontend', 'backend')) {
    $sourcePath = Join-Path $artifactsPath "runtime\$name.log"
    if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
        Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $logsPath "$name.log") -Force
        Write-Output "Collected $name log"
    }
}