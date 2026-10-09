Set-StrictMode -Version Latest

# Shared by cronova-user-install.ps1 / cronova-user.ps1 (per-user, no admin).

$script:CronovaUserTaskName = 'Cronova (user)'

function Get-CronovaUserProcesses {
    param([Parameter(Mandatory = $true)][string]$InstallDir)
    $dir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\') + '\'
    @(Get-CimInstance Win32_Process -Filter "Name='cronova.exe' OR Name='cronova-executor.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($dir, [StringComparison]::OrdinalIgnoreCase) })
}

function Get-CronovaUserPort {
    param([Parameter(Mandatory = $true)][string]$DataDir)
    $config = Join-Path $DataDir 'cronova.yaml'
    if (Test-Path $config) {
        $m = Select-String -LiteralPath $config -Pattern '^http:\s*\S*:(\d+)' | Select-Object -First 1
        if ($m) { return [int]$m.Matches[0].Groups[1].Value }
    }
    return 8090
}

function Assert-CronovaUserPortFree {
    param([Parameter(Mandatory = $true)][int]$Port, [Parameter(Mandatory = $true)][string]$InstallDir)
    $mine = @(Get-CronovaUserProcesses -InstallDir $InstallDir | ForEach-Object { [int]$_.ProcessId })
    foreach ($owner in @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique)) {
        if ($mine -contains [int]$owner) { continue }
        $proc = Get-Process -Id $owner -ErrorAction SilentlyContinue
        $desc = if ($proc) { "$($proc.ProcessName) (PID $owner)" } else { "PID $owner" }
        throw "Port $Port is already in use by $desc. Choose another port with -Port (e.g. -Port 8091)."
    }
}

function Get-CronovaUserLauncher {
    param([Parameter(Mandatory = $true)][string]$DataDir)
    Join-Path $DataDir 'internal\scripts\cronova-user-run.ps1'
}

function Register-CronovaUserTask {
    param([Parameter(Mandatory = $true)][string]$InstallDir, [Parameter(Mandatory = $true)][string]$DataDir)
    $launcher = Get-CronovaUserLauncher -DataDir $DataDir
    $arg = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -InstallDir "{1}" -DataDir "{2}"' -f $launcher, $InstallDir, $DataDir
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg -WorkingDirectory $DataDir
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
        -MultipleInstances IgnoreNew -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    try {
        Register-ScheduledTask -TaskName $script:CronovaUserTaskName -Action $action -Trigger $trigger -Settings $settings `
            -Principal $principal -Description 'Cronova scheduler + executor (per-user install)' -Force | Out-Null
        Write-Host "Registered logon task '$($script:CronovaUserTaskName)' (autostart + restart on failure)."
    }
    catch {
        # Fallback when policy blocks Task Scheduler: Startup folder shortcut (no restart-on-failure).
        Write-Warning "Scheduled Task registration failed ($($_.Exception.Message)); using a Startup folder shortcut instead."
        $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Cronova.lnk'
        $sh = New-Object -ComObject WScript.Shell
        $s = $sh.CreateShortcut($lnk)
        $s.TargetPath = 'powershell.exe'
        $s.Arguments = $arg
        $s.WorkingDirectory = $DataDir
        $s.WindowStyle = 7
        $s.Save()
    }
}

function Unregister-CronovaUserTask {
    if (Get-ScheduledTask -TaskName $script:CronovaUserTaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $script:CronovaUserTaskName -Confirm:$false
    }
    Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'Cronova.lnk') -Force -ErrorAction SilentlyContinue
}

function Wait-CronovaUserHttp {
    param([Parameter(Mandatory = $true)][int]$Port, [int]$TimeoutSeconds = 60)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest "http://127.0.0.1:$Port/" -UseBasicParsing -TimeoutSec 3
            if ($r.StatusCode -eq 200) { return $true }
        }
        catch { }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Start-CronovaUser {
    param([Parameter(Mandatory = $true)][string]$InstallDir, [Parameter(Mandatory = $true)][string]$DataDir)
    if (Get-CronovaUserProcesses -InstallDir $InstallDir) {
        Write-Host 'Cronova (per-user) is already running.'
        return
    }
    $port = Get-CronovaUserPort -DataDir $DataDir
    Assert-CronovaUserPortFree -Port $port -InstallDir $InstallDir
    if (Get-ScheduledTask -TaskName $script:CronovaUserTaskName -ErrorAction SilentlyContinue) {
        Start-ScheduledTask -TaskName $script:CronovaUserTaskName
    }
    else {
        Start-Process powershell.exe -WindowStyle Hidden -WorkingDirectory $DataDir -ArgumentList @(
            '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', (Get-CronovaUserLauncher -DataDir $DataDir),
            '-InstallDir', $InstallDir, '-DataDir', $DataDir) | Out-Null
    }
    if (-not (Wait-CronovaUserHttp -Port $port)) {
        throw "Cronova did not answer on http://127.0.0.1:$port/ within 60s. See $(Join-Path $DataDir 'logs\cronova-user.log')."
    }
    Write-Host "Cronova (per-user) is running: http://127.0.0.1:$port/"
}

function Stop-CronovaUser {
    param([Parameter(Mandatory = $true)][string]$InstallDir)
    if (Get-ScheduledTask -TaskName $script:CronovaUserTaskName -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $script:CronovaUserTaskName -ErrorAction SilentlyContinue
    }
    # Scheduler first, then executor (mirrors service stop order).
    foreach ($name in 'cronova.exe', 'cronova-executor.exe') {
        foreach ($p in @(Get-CronovaUserProcesses -InstallDir $InstallDir | Where-Object Name -eq $name)) {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        }
    }
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-CronovaUserProcesses -InstallDir $InstallDir) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }
    if (Get-CronovaUserProcesses -InstallDir $InstallDir) { throw 'Cronova (per-user) processes did not stop.' }
}
