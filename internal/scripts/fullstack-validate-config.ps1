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
$configPath = $settings.ConfigPath
$artifactsPath = if ($Artifacts) { Resolve-SdlcRepoPath -Path $Artifacts -RepoRoot $settings.RepoRoot } else { $settings.ArtifactsPath }

if ([string]::IsNullOrWhiteSpace($artifactsPath)) {
    throw 'Artifacts path could not be resolved from config or parameters.'
}

New-Item -ItemType Directory -Force -Path (Join-Path $artifactsPath 'logs') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $artifactsPath 'reports') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $artifactsPath 'metadata') | Out-Null

$python = Get-ConfiguredCommand 'python'

$angularConfigPath = Resolve-SdlcRepoPath -Path $settings.AngularConfig -RepoRoot $settings.RepoRoot
$springbootConfigPath = Resolve-SdlcRepoPath -Path $settings.SpringbootConfig -RepoRoot $settings.RepoRoot
$openApiPath = Resolve-SdlcRepoPath -Path $settings.OpenApiFile -RepoRoot $settings.RepoRoot

foreach ($path in @($angularConfigPath, $springbootConfigPath, $openApiPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Configured file not found: $path"
    }
}

$logPath = Join-Path $artifactsPath 'logs\contract-validation.log'
$scriptPath = Join-Path $repo 'scripts\sdlc\integration\generate_contract_app.py'

$base = Join-Path ([IO.Path]::GetTempPath()) ("fullstack-validate-" + [guid]::NewGuid().ToString('N'))
$stdoutFile = "$base.out"
$stderrFile = "$base.err"
try {
    $process = Start-Process -FilePath $python -ArgumentList (ConvertTo-NativeArgumentString @($scriptPath, '--contract', $openApiPath)) -WorkingDirectory $repo -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    $stdout = if (Test-Path -LiteralPath $stdoutFile) { [IO.File]::ReadAllText($stdoutFile) } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrFile) { [IO.File]::ReadAllText($stderrFile) } else { '' }
    [IO.File]::WriteAllText($logPath, $stdout + $stderr, [Text.UTF8Encoding]::new($false))
    if ($stdout) { [Console]::Out.Write($stdout) }
    if ($stderr) { [Console]::Error.Write($stderr) }
    if ([int]$process.ExitCode -ne 0) {
        throw 'Contract validation failed'
    }
} finally {
    Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}

Write-Output "Full-stack configuration is valid: $configPath"