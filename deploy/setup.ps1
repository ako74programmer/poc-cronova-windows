[CmdletBinding()]
param(
    # auto: service install when elevated (or after a UAC prompt), otherwise per-user.
    [ValidateSet('auto', 'service', 'user')][string]$Mode = 'auto',
    [int]$Port = 8090,
    [string]$AdminUser = 'admin',
    # Cronova console password. If omitted, a random one is generated and printed once.
    [string]$AdminPassword,
    [string]$AiBaseUrl,
    [string]$AiModel,
    # Do not offer the UAC prompt in auto mode (go straight to per-user).
    [switch]$NoElevate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Lives at the root of the release ZIP (copied there by scripts\package.ps1).
$root = if (Test-Path (Join-Path $PSScriptRoot 'cronova.exe')) { $PSScriptRoot } else { Split-Path $PSScriptRoot -Parent }

# Files extracted from a downloaded ZIP carry Mark-of-the-Web; unblock them so
# nested scripts are not rejected.
Get-ChildItem -LiteralPath $root -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
$elevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$canElevate = [bool]($identity.Groups | Where-Object { $_.Value -eq 'S-1-5-32-544' })

if (-not $AdminPassword) {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    $bytes = New-Object byte[] 16
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $AdminPassword = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    $generated = $true
}
else { $generated = $false }

$selected = $Mode
if ($Mode -eq 'auto') {
    if ($elevated) { $selected = 'service' }
    elseif ($canElevate -and -not $NoElevate) {
        Write-Host 'You are a member of Administrators. Installing as Windows Services (recommended) needs a UAC confirmation.'
        $answer = Read-Host 'Install as Windows Services? [Y]es / [n]o = install for the current user only'
        $selected = if ($answer -match '^(n|no|nie)$') { 'user' } else { 'elevate' }
    }
    else {
        Write-Host 'No administrator rights: installing for the current user only (no Windows Services).'
        $selected = 'user'
    }
}

if ($selected -eq 'elevate' -or ($selected -eq 'service' -and -not $elevated)) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Mode', 'service',
        '-Port', $Port, '-AdminUser', $AdminUser, '-AdminPassword', $AdminPassword)
    if ($AiBaseUrl) { $argList += @('-AiBaseUrl', $AiBaseUrl) }
    if ($AiModel) { $argList += @('-AiModel', $AiModel) }
    try {
        $p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList $argList
    }
    catch {
        if ($Mode -eq 'service') { throw 'Administrator rights were not granted; service install cancelled.' }
        Write-Warning 'UAC prompt was declined: installing for the current user only.'
        $selected = 'user'
        $p = $null
    }
    if ($p) {
        if ($p.ExitCode -ne 0) { throw "Service installation failed (exit code $($p.ExitCode)). See the elevated window output / $env:TEMP\cronova-setup.log." }
        $selected = 'done'
    }
}

switch ($selected) {
    'service' {
        Start-Transcript -Path (Join-Path $env:TEMP 'cronova-setup.log') -Force | Out-Null
        try {
            $owner = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
                ForEach-Object { Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue } |
                Where-Object { $_.ProcessName -ne 'cronova' } | Select-Object -First 1
            if ($owner) {
                throw "Port $Port is already in use by $($owner.ProcessName) (PID $($owner.Id)). Rerun setup with another port, e.g. -Port $($Port + 1)."
            }
            $installArgs = @{ Source = $root; Start = $true; Port = $Port; AdminUser = $AdminUser; AdminPassword = $AdminPassword }
            if ($AiBaseUrl) { $installArgs.AiBaseUrl = $AiBaseUrl }
            if ($AiModel) { $installArgs.AiModel = $AiModel }
            & (Join-Path $root 'deploy\install.ps1') @installArgs
        }
        catch {
            Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
            Stop-Transcript | Out-Null
            Read-Host 'Press Enter to close' | Out-Null
            exit 1
        }
        Stop-Transcript | Out-Null
    }
    'user' {
        $userArgs = @{ Source = $root; Port = $Port; AdminUser = $AdminUser; AdminPassword = $AdminPassword }
        if ($AiBaseUrl) { $userArgs.AiBaseUrl = $AiBaseUrl }
        if ($AiModel) { $userArgs.AiModel = $AiModel }
        & (Join-Path $root 'internal\scripts\cronova-user-install.ps1') @userArgs
    }
}

if ($selected -in 'service', 'done', 'user') {
    $url = "http://127.0.0.1:$Port/"
    Write-Host ''
    Write-Host "Cronova console: $url" -ForegroundColor Green
    Write-Host "Login: $AdminUser"
    if ($generated) { Write-Host "Password (generated, shown once): $AdminPassword" -ForegroundColor Yellow }
    if ($selected -eq 'user') {
        Write-Host 'Manage it with: powershell -ExecutionPolicy Bypass -File internal\scripts\cronova-user.ps1 status|stop|start|uninstall'
    }
}
