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
$workspacePath = if ($Workspace) { Resolve-SdlcRepoPath -Path $Workspace -RepoRoot $settings.RepoRoot } else { $settings.WorkspacePath }
$artifactsPath = if ($Artifacts) { Resolve-SdlcRepoPath -Path $Artifacts -RepoRoot $settings.RepoRoot } else { $settings.ArtifactsPath }

if ([string]::IsNullOrWhiteSpace($workspacePath)) {
    throw 'Workspace path could not be resolved from config or parameters.'
}

if ([string]::IsNullOrWhiteSpace($artifactsPath)) {
    throw 'Artifacts path could not be resolved from config or parameters.'
}

$npm = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
if (-not $npm) { $npm = Get-Command 'npm' -ErrorAction SilentlyContinue }
if (-not $npm) { throw 'Required command not found: npm' }

$node = Get-Command 'node.exe' -ErrorAction SilentlyContinue
if (-not $node) { $node = Get-Command 'node' -ErrorAction SilentlyContinue }
if (-not $node) { throw 'Required command not found: node' }

$packageJsonPath = Join-Path $workspacePath 'package.json'
if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
    throw "package.json not found in $workspacePath"
}

$logPath = Join-Path $artifactsPath 'logs\angular-unit-tests.log'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

$chromeBin = $env:CHROME_BIN
if ([string]::IsNullOrWhiteSpace($chromeBin)) {
    $puppeteerCheck = Start-Process -FilePath $node.Source -ArgumentList (ConvertTo-NativeArgumentString @('-e', 'require("puppeteer")')) -WorkingDirectory $workspacePath -Wait -PassThru -NoNewWindow
    if ([int]$puppeteerCheck.ExitCode -eq 0) {
        $baseChrome = Join-Path ([IO.Path]::GetTempPath()) ("angular-chrome-" + [guid]::NewGuid().ToString('N'))
        $chromeStdoutFile = "$baseChrome.out"
        $chromeStderrFile = "$baseChrome.err"
        try {
            $chromeProcess = Start-Process -FilePath $node.Source -ArgumentList (ConvertTo-NativeArgumentString @('-e', 'process.stdout.write(require("puppeteer").executablePath())')) -WorkingDirectory $workspacePath -Wait -PassThru -NoNewWindow -RedirectStandardOutput $chromeStdoutFile -RedirectStandardError $chromeStderrFile
            if ([int]$chromeProcess.ExitCode -eq 0 -and (Test-Path -LiteralPath $chromeStdoutFile)) {
                $chromeBin = [IO.File]::ReadAllText($chromeStdoutFile).Trim()
            }
        } finally {
            Remove-Item -LiteralPath $chromeStdoutFile, $chromeStderrFile -Force -ErrorAction SilentlyContinue
        }
        if (-not [string]::IsNullOrWhiteSpace($chromeBin)) {
            $env:CHROME_BIN = $chromeBin
            Write-Output "Using Puppeteer Chrome: $chromeBin"
        }
    }
}

Write-Output "Running npm test -- --watch=false in $workspacePath"
$base = Join-Path ([IO.Path]::GetTempPath()) ("angular-test-" + [guid]::NewGuid().ToString('N'))
$stdoutFile = "$base.out"
$stderrFile = "$base.err"
try {
    $process = Start-Process -FilePath $npm.Source -ArgumentList (ConvertTo-NativeArgumentString @('test', '--', '--watch=false')) -WorkingDirectory $workspacePath -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
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