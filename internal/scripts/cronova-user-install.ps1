[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\Cronova'),
    [string]$DataDir = (Join-Path $env:LOCALAPPDATA 'Cronova'),
    [int]$Port = 8090,
    [string]$AdminUser = 'admin',
    [string]$AdminPassword,
    [string]$AiBaseUrl,
    [string]$AiModel,
    [switch]$NoStart
)

# Per-user install (no administrator rights): binaries in %LOCALAPPDATA%\Programs\Cronova,
# data in %LOCALAPPDATA%\Cronova, started at logon by a per-user Scheduled Task that
# restarts it on failure. Listens on 127.0.0.1 only (no firewall prompt).

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'cronova-user-common.ps1')

$sourceRoot = (Resolve-Path $Source).Path
foreach ($exe in 'cronova.exe', 'cronova-executor.exe') {
    if (-not (Test-Path (Join-Path $sourceRoot $exe))) { throw "Source does not contain $exe : $sourceRoot" }
}

Assert-CronovaUserPortFree -Port $Port -InstallDir $InstallDir

$wasRunning = [bool](Get-CronovaUserProcesses -InstallDir $InstallDir)
Stop-CronovaUser -InstallDir $InstallDir

New-Item -ItemType Directory -Force -Path $InstallDir, $DataDir | Out-Null
foreach ($d in 'dags', 'logs', 'state', 'projects', 'workspaces') { New-Item -ItemType Directory -Force -Path (Join-Path $DataDir $d) | Out-Null }
Copy-Item (Join-Path $sourceRoot 'cronova.exe'), (Join-Path $sourceRoot 'cronova-executor.exe') $InstallDir -Force

$config = Join-Path $DataDir 'cronova.yaml'
if (-not (Test-Path $config)) {
    $text = [IO.File]::ReadAllText((Join-Path $sourceRoot 'cronova.yaml'))
    $text = [regex]::Replace($text, '(?m)^http:\s*\S+', "http: 127.0.0.1:$Port")
    [IO.File]::WriteAllText($config, $text, [Text.UTF8Encoding]::new($false))
}
elseif ($PSBoundParameters.ContainsKey('Port')) {
    $text = [IO.File]::ReadAllText($config)
    $text = [regex]::Replace($text, '(?m)^http:\s*\S+', "http: 127.0.0.1:$Port")
    [IO.File]::WriteAllText($config, $text, [Text.UTF8Encoding]::new($false))
}

Copy-Item (Join-Path $sourceRoot 'dags\*.yaml') (Join-Path $DataDir 'dags') -Force -ErrorAction SilentlyContinue
foreach ($dir in @('internal\scripts', 'scripts\sdlc', 'scripts\windows', 'prompts', 'templates', 'configs', 'contracts', 'e2e\playwright')) {
    $src = Join-Path $sourceRoot $dir
    if (-not (Test-Path $src)) { continue }
    $dst = Join-Path $DataDir $dir
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Copy-Item (Join-Path $src '*') $dst -Recurse -Force
}
& (Join-Path $DataDir 'internal\scripts\cronova-verify-dag-paths.ps1') -Root $DataDir

# Tool locations for DAG tasks (the logon task gets a clean environment).
$envFile = Join-Path $DataDir 'cronova.env'
$lines = [System.Collections.Generic.List[string]]::new()
$detect = Join-Path $DataDir 'scripts\windows\detect-toolchain.ps1'
if (Test-Path $detect) {
    foreach ($line in @(& $detect)) { if ($line -match '^[A-Z_]+=.+$') { $lines.Add($line) } }
}
$allow = @()
if ($AiBaseUrl) { $lines.Add("CRONOVA_AI_BASE_URL=$AiBaseUrl"); $allow += 'CRONOVA_AI_BASE_URL' }
if ($AiModel) { $lines.Add("CRONOVA_AI_MODEL=$AiModel"); $allow += 'CRONOVA_AI_MODEL' }
if ($allow) { $lines.Add("CRONOVA_TASK_ENV_ALLOWLIST=$($allow -join ',')") }
[IO.File]::WriteAllLines($envFile, $lines, [Text.UTF8Encoding]::new($false))

$db = Join-Path $DataDir 'cronova.db'
if ($AdminPassword) {
    $cli = Join-Path $InstallDir 'cronova.exe'
    $ErrorActionPreference = 'Continue'
    & $cli users add $AdminUser -role admin -password $AdminPassword -db $db 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { & $cli users passwd $AdminUser -password $AdminPassword -db $db 2>&1 | Out-Host }
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) { throw "Setting Cronova user '$AdminUser' failed with exit code $LASTEXITCODE." }
}

Register-CronovaUserTask -InstallDir $InstallDir -DataDir $DataDir

Write-Host "Installed Cronova (per-user) to $InstallDir with data in $DataDir"
if (-not $NoStart -or $wasRunning) {
    Start-CronovaUser -InstallDir $InstallDir -DataDir $DataDir
}
