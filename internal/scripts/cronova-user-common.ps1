Set-StrictMode -Version Latest

# Shared by cronova-user-install.ps1 / cronova-user.ps1 (per-user, no admin).

$script:CronovaUserTaskName = 'Cronova (user)'

function Get-CronovaUserDatabasePath {
    param(
        [Parameter(Mandatory = $true)][string]$DataDir,
        [Parameter(Mandatory = $true)][string]$ConfigPath
    )
    # Keep this in sync with cronova's built-in defaultConfig(). The installed
    # config normally contains this explicit value, but older configs may omit it.
    $configured = 'data/cronova.db'
    if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
        $match = Select-String -LiteralPath $ConfigPath -Pattern '^\s*db:\s*(?<value>.*?)(?:\s+#.*)?\s*$' | Select-Object -First 1
        if ($match) {
            $configured = $match.Matches[0].Groups['value'].Value.Trim()
            if ($configured.Length -ge 2 -and (($configured[0] -eq '"' -and $configured[-1] -eq '"') -or ($configured[0] -eq "'" -and $configured[-1] -eq "'"))) {
                $configured = $configured.Substring(1, $configured.Length - 2)
            }
            if (-not $configured) { throw "The db: value in '$ConfigPath' is empty." }
        }
    }
    if ([IO.Path]::IsPathRooted($configured)) { return [IO.Path]::GetFullPath($configured) }
    return [IO.Path]::GetFullPath((Join-Path $DataDir $configured))
}

function Move-CronovaUserDatabaseToConfiguredPath {
    param(
        [Parameter(Mandatory = $true)][string]$DataDir,
        [Parameter(Mandatory = $true)][string]$DatabasePath
    )
    $legacy = [IO.Path]::GetFullPath((Join-Path $DataDir 'cronova.db'))
    $target = [IO.Path]::GetFullPath($DatabasePath)
    if ([string]::Equals($legacy, $target, [StringComparison]::OrdinalIgnoreCase)) { return }

    $sourceFiles = @($legacy, ($legacy + '-wal'), ($legacy + '-shm'), ($legacy + '-journal'))
    $targetFiles = @($target, ($target + '-wal'), ($target + '-shm'), ($target + '-journal'))
    $existingSources = @($sourceFiles | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if (-not $existingSources.Count) { return }
    $conflicts = @($targetFiles | Where-Object { Test-Path -LiteralPath $_ })
    if ($conflicts.Count) {
        throw "Cannot migrate the legacy per-user database: both '$legacy' and target database files exist. No files were changed; back up and reconcile them manually."
    }

    $parent = Split-Path -Parent $target
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $moved = [System.Collections.Generic.List[int]]::new()
    try {
        for ($i = 0; $i -lt $sourceFiles.Count; $i++) {
            if (Test-Path -LiteralPath $sourceFiles[$i] -PathType Leaf) {
                Move-Item -LiteralPath $sourceFiles[$i] -Destination $targetFiles[$i] -ErrorAction Stop
                $moved.Add($i)
            }
        }
    }
    catch {
        $migrationError = $_
        $rollbackErrors = @()
        for ($i = $moved.Count - 1; $i -ge 0; $i--) {
            $index = $moved[$i]
            try { Move-Item -LiteralPath $targetFiles[$index] -Destination $sourceFiles[$index] -ErrorAction Stop }
            catch { $rollbackErrors += $_.Exception.Message }
        }
        if ($rollbackErrors.Count) {
            throw "Database migration failed and rollback was incomplete. Original error: $($migrationError.Exception.Message). Rollback errors: $($rollbackErrors -join '; '). Do not restart Cronova until the database files have been inspected."
        }
        throw $migrationError
    }
    Write-Host "Moved the existing per-user database to the configured location: $target"
}

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
