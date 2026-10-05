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

$files = Get-ChildItem -LiteralPath $artifactsPath -File -Recurse |
    Where-Object { $_.Name -ne 'manifest.json' } |
    ForEach-Object { $_.FullName.Substring($artifactsPath.Length).TrimStart('\', '/') -replace '\\', '/' } |
    Sort-Object

$manifest = [ordered]@{
    config = $settings.ConfigPath
    artifacts = $artifactsPath
    files = @($files)
} | ConvertTo-Json -Depth 8

$manifest | Set-Content -LiteralPath (Join-Path $artifactsPath 'manifest.json') -Encoding UTF8

Write-Output 'Archived fullstack results'