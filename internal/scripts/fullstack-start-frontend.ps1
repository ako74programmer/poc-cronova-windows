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

$distPath = Resolve-SdlcRepoPath -Path $settings.FrontendDist -RepoRoot $settings.RepoRoot
if (-not (Test-Path -LiteralPath $distPath -PathType Container)) {
    throw "Configured frontend dist not found: $distPath"
}

$npx = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
if (-not $npx) { $npx = Get-Command 'npx' -ErrorAction SilentlyContinue }
if (-not $npx) { throw 'Required command not found: npx' }

$runtimePath = Join-Path $artifactsPath 'runtime'
New-Item -ItemType Directory -Force -Path $runtimePath | Out-Null

$logPath = Join-Path $runtimePath 'frontend.log'
$errorPath = Join-Path $runtimePath 'frontend.log.err'
$pidPath = Join-Path $runtimePath 'frontend.pid'

$process = Start-Process -FilePath $npx.Source -ArgumentList (ConvertTo-NativeArgumentString @('--yes', 'http-server', $distPath, '-a', $settings.FrontendHost, '-p', $settings.FrontendPort)) -RedirectStandardOutput $logPath -RedirectStandardError $errorPath -PassThru
$process.Id | Set-Content -LiteralPath $pidPath -Encoding UTF8

Write-Output "Started frontend PID $($process.Id)"