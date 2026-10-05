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

$jarPath = Resolve-SdlcRepoPath -Path $settings.BackendJar -RepoRoot $settings.RepoRoot
if (-not (Test-Path -LiteralPath $jarPath -PathType Leaf)) {
    throw "Configured backend JAR not found: $jarPath"
}

$java = Get-ConfiguredCommand 'java'

$runtimePath = Join-Path $artifactsPath 'runtime'
New-Item -ItemType Directory -Force -Path $runtimePath | Out-Null

$logPath = Join-Path $runtimePath 'backend.log'
$errorPath = Join-Path $runtimePath 'backend.log.err'
$pidPath = Join-Path $runtimePath 'backend.pid'

$javaArgs = @('-jar', $jarPath, "--server.address=$($settings.BackendHost)", "--server.port=$($settings.BackendPort)")
if (-not [string]::IsNullOrWhiteSpace($settings.BackendProfile)) {
    $javaArgs += "--spring.profiles.active=$($settings.BackendProfile)"
}

$process = Start-Process -FilePath $java -ArgumentList (ConvertTo-NativeArgumentString $javaArgs) -RedirectStandardOutput $logPath -RedirectStandardError $errorPath -PassThru
$process.Id | Set-Content -LiteralPath $pidPath -Encoding UTF8

Write-Output "Started backend PID $($process.Id)"