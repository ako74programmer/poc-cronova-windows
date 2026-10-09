[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [switch]$Start,
    [switch]$FreePort,
    [string]$AdminUser,
    [string]$AdminPassword,
    # Optional default AI endpoint for AI DAG tasks (e.g. http://127.0.0.1:4141/v1). Tokens belong in the UI provider config.
    [string]$AiBaseUrl,
    [string]$AiModel
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'cronova-service-common.ps1')

function Ensure-AdminUser {
    param(
        [Parameter(Mandatory = $true)][string]$CliPath,
        [Parameter(Mandatory = $true)][string]$DbPath,
        [Parameter(Mandatory = $true)][string]$Username,
        [Parameter(Mandatory = $true)][string]$Password
    )

    if ([string]::IsNullOrWhiteSpace($Username)) {
        throw 'Admin user name cannot be empty.'
    }
    if ([string]::IsNullOrWhiteSpace($Password)) {
        throw 'Admin password cannot be empty.'
    }

    # Native stderr (e.g. "user already exists") must not become a terminating error.
    $ErrorActionPreference = 'Continue'

    & $CliPath users add $Username -role admin -password $Password -db $DbPath | Out-Host
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Seeded admin user '$Username'."
        $ErrorActionPreference = 'Stop'
        return
    }

    & $CliPath users passwd $Username -password $Password -db $DbPath | Out-Host
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) {
        throw "Seeding admin user '$Username' failed with exit code $LASTEXITCODE."
    }

    Write-Host "Updated admin password for '$Username'."
}

$resolvedSource = Resolve-CronovaPackageSource -SourcePath $Source
$sourceRoot = $resolvedSource.Root
$sourceCleanup = $resolvedSource.Cleanup

try {
    $data = Join-Path $env:ProgramData 'Cronova'
    $install = Join-Path $env:ProgramFiles 'Cronova'
    $dbPath = Join-Path $data 'cronova.db'

    Stop-CronovaService -Name 'Cronova' -ForceKill
    Stop-CronovaService -Name 'CronovaExecutor' -ForceKill

    New-Item -ItemType Directory -Force -Path $install, $data, "$data\dags", "$data\projects", "$data\workspaces", "$data\logs", "$data\state" | Out-Null
    Copy-Item (Join-Path $sourceRoot 'cronova.exe') (Join-Path $install 'cronova.exe') -Force
    Copy-Item (Join-Path $sourceRoot 'cronova-executor.exe') (Join-Path $install 'cronova-executor.exe') -Force

    $config = Join-Path $data 'cronova.yaml'
    if (-not (Test-Path $config)) {
        Copy-Item (Join-Path $sourceRoot 'cronova.yaml') $config
    }

    Copy-Item (Join-Path $sourceRoot 'dags\*.yaml') "$data\dags" -Force -ErrorAction SilentlyContinue

    # DAG tasks use paths relative to the executor working dir (= $data).
    foreach ($dir in @('internal\scripts', 'scripts\sdlc', 'prompts', 'templates', 'configs', 'contracts', 'e2e\playwright')) {
        $src = Join-Path $sourceRoot $dir
        if (-not (Test-Path $src)) { continue }
        $dst = Join-Path $data $dir
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item (Join-Path $src '*') $dst -Recurse -Force
    }
    & (Join-Path $data 'internal\scripts\cronova-verify-dag-paths.ps1') -Root $data

    $exec = Join-Path $install 'cronova-executor.exe'
    $sched = Join-Path $install 'cronova.exe'
    $execBin = ('"{0}" -sock 127.0.0.1:19090 -state-dir "{1}" -workdir "{2}"' -f $exec, (Join-Path $data 'state'), $data)
    $schedBin = ('"{0}" serve -config "{1}" -db "{2}" -dags "{3}" -logs "{4}" -projects "{5}" -workspaces "{6}" -executor tcp://127.0.0.1:19090' -f $sched, $config, $dbPath, (Join-Path $data 'dags'), (Join-Path $data 'logs'), (Join-Path $data 'projects'), (Join-Path $data 'workspaces'))

    if (-not (Get-Service -Name 'CronovaExecutor' -ErrorAction SilentlyContinue)) {
        New-Service -Name 'CronovaExecutor' -BinaryPathName $execBin -StartupType Automatic | Out-Null
    } else {
        Set-CronovaServiceCommandLine -Name 'CronovaExecutor' -BinaryPath $execBin
    }

    if (-not (Get-Service -Name 'Cronova' -ErrorAction SilentlyContinue)) {
        New-Service -Name 'Cronova' -BinaryPathName $schedBin -StartupType Automatic -DependsOn 'CronovaExecutor' | Out-Null
    } else {
        Set-CronovaServiceCommandLine -Name 'Cronova' -BinaryPath $schedBin -DependsOn 'CronovaExecutor'
    }

    Invoke-CronovaSc -Arguments @('failure', 'CronovaExecutor', 'actions=', 'restart/60000/restart/60000//60000', 'reset=', '86400') -Action 'Configuring CronovaExecutor recovery' | Out-Null
    Invoke-CronovaSc -Arguments @('failure', 'Cronova', 'actions=', 'restart/60000/restart/60000//60000', 'reset=', '86400') -Action 'Configuring Cronova recovery' | Out-Null

    $serviceEnv = @("CRONOVA_DB=$dbPath")
    $allow = @('CRONOVA_DB')
    if ($AiBaseUrl) { $serviceEnv += "CRONOVA_AI_BASE_URL=$AiBaseUrl"; $allow += 'CRONOVA_AI_BASE_URL' }
    if ($AiModel) { $serviceEnv += "CRONOVA_AI_MODEL=$AiModel"; $allow += 'CRONOVA_AI_MODEL' }
    $serviceEnv += "CRONOVA_TASK_ENV_ALLOWLIST=$($allow -join ',')"
    & (Join-Path $PSScriptRoot 'cronova-configure-service-env.ps1') -ServiceName 'CronovaExecutor' -Extra $serviceEnv

    if ($PSBoundParameters.ContainsKey('AdminUser') -or $PSBoundParameters.ContainsKey('AdminPassword')) {
        if (-not ($PSBoundParameters.ContainsKey('AdminUser') -and $PSBoundParameters.ContainsKey('AdminPassword'))) {
            throw 'Provide both -AdminUser and -AdminPassword together.'
        }

        Ensure-AdminUser -CliPath $sched -DbPath $dbPath -Username $AdminUser -Password ${AdminPassword}
    }

    Write-Host "Installed Cronova to $install with data in $data"
    if ($Start) {
        Assert-CronovaPortFree -Port (Get-CronovaHttpPort -ConfigPath $config) -FreePort:$FreePort
        Start-CronovaService -Name 'CronovaExecutor'
        Start-Sleep -Seconds 2
        Start-CronovaService -Name 'Cronova'
    }

    foreach ($name in 'CronovaExecutor', 'Cronova') {
        $state = Get-CronovaServiceState -Name $name
        if (-not $state) { throw "Service $name is not registered after installation." }
        if ($Start -and $state -ne 'RUNNING') { throw "Service $name is $state after installation; expected RUNNING." }
        Get-Service -Name $name
    }
}
finally {
    if ($sourceCleanup) {
        & $sourceCleanup $sourceRoot
    }
}