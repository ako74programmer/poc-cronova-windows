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

$npx = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
if (-not $npx) { $npx = Get-Command 'npx' -ErrorAction SilentlyContinue }
if (-not $npx) { throw 'Required command not found: npx' }

$e2ePath = Resolve-SdlcRepoPath -Path $settings.PlaywrightDirectory -RepoRoot $settings.RepoRoot
$logPath = Join-Path $artifactsPath 'logs\playwright.log'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

$previousFrontendUrl = $env:FRONTEND_URL
$previousApiUrl = $env:API_URL
$previousPlaywrightBaseUrl = $env:PLAYWRIGHT_BASE_URL
if (-not [string]::IsNullOrWhiteSpace($settings.PlaywrightBaseUrl)) {
    $env:FRONTEND_URL = $settings.PlaywrightBaseUrl
    $env:PLAYWRIGHT_BASE_URL = $settings.PlaywrightBaseUrl
}
if (-not [string]::IsNullOrWhiteSpace($settings.PlaywrightApiUrl)) {
    $env:API_URL = $settings.PlaywrightApiUrl
}

Write-Output "Running Playwright E2E in $e2ePath"
$base = Join-Path ([IO.Path]::GetTempPath()) ("fullstack-playwright-" + [guid]::NewGuid().ToString('N'))
$stdoutFile = "$base.out"
$stderrFile = "$base.err"
try {
    $process = Start-Process -FilePath $npx.Source -ArgumentList (ConvertTo-NativeArgumentString @('playwright', 'test')) -WorkingDirectory $e2ePath -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    $stdout = if (Test-Path -LiteralPath $stdoutFile) { [IO.File]::ReadAllText($stdoutFile) } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrFile) { [IO.File]::ReadAllText($stderrFile) } else { '' }
    [IO.File]::WriteAllText($logPath, $stdout + $stderr, [Text.UTF8Encoding]::new($false))
    if ($stdout) { [Console]::Out.Write($stdout) }
    if ($stderr) { [Console]::Error.Write($stderr) }
    if ([int]$process.ExitCode -ne 0) {
        throw "$($npx.Source) failed with exit code $($process.ExitCode)"
    }
} finally {
    $env:FRONTEND_URL = $previousFrontendUrl
    $env:API_URL = $previousApiUrl
    $env:PLAYWRIGHT_BASE_URL = $previousPlaywrightBaseUrl
    Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}