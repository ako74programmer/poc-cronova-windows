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

$npm = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
if (-not $npm) { $npm = Get-Command 'npm' -ErrorAction SilentlyContinue }
if (-not $npm) { throw 'Required command not found: npm' }

$npx = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
if (-not $npx) { $npx = Get-Command 'npx' -ErrorAction SilentlyContinue }
if (-not $npx) { throw 'Required command not found: npx' }

if ([string]::IsNullOrWhiteSpace($settings.PlaywrightDirectory) -or [string]::IsNullOrWhiteSpace($settings.PlaywrightBrowser)) {
    throw 'Playwright directory/browser are not configured'
}

$e2ePath = Resolve-SdlcRepoPath -Path $settings.PlaywrightDirectory -RepoRoot $settings.RepoRoot
$packageJsonPath = Join-Path $e2ePath 'package.json'
if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
    throw "Playwright package.json is missing: $e2ePath"
}

$packageLockPath = Join-Path $e2ePath 'package-lock.json'
if (-not (Test-Path -LiteralPath $packageLockPath -PathType Leaf)) {
    throw 'Playwright package-lock.json is required for a reproducible install'
}

$logPath = Join-Path $artifactsPath 'logs\playwright-install.log'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

Write-Output "Running npm ci in $e2ePath"
$base = Join-Path ([IO.Path]::GetTempPath()) ("playwright-install-" + [guid]::NewGuid().ToString('N'))
$stdoutFile = "$base.out"
$stderrFile = "$base.err"
try {
    $process = Start-Process -FilePath $npm.Source -ArgumentList (ConvertTo-NativeArgumentString @('ci')) -WorkingDirectory $e2ePath -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    $stdout = if (Test-Path -LiteralPath $stdoutFile) { [IO.File]::ReadAllText($stdoutFile) } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrFile) { [IO.File]::ReadAllText($stderrFile) } else { '' }
    [IO.File]::WriteAllText($logPath, $stdout + $stderr, [Text.UTF8Encoding]::new($false))
    if ($stdout) { [Console]::Out.Write($stdout) }
    if ($stderr) { [Console]::Error.Write($stderr) }
    if ([int]$process.ExitCode -ne 0) {
        throw "$($npm.Source) failed with exit code $($process.ExitCode)"
    }
} finally {
    Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}

Write-Output "Installing Playwright browser $($settings.PlaywrightBrowser)"
Invoke-Native -FilePath $npx.Source -ArgumentList @('playwright', 'install', $settings.PlaywrightBrowser) -WorkingDirectory $e2ePath