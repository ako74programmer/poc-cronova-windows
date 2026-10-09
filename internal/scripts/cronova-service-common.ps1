Set-StrictMode -Version Latest

function Invoke-CronovaSc {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$Action = 'sc.exe command',
        [switch]$IgnoreExitCode,
        [scriptblock]$Runner
    )

    if ($Runner) {
        $output = & $Runner ([string[]]$Arguments)
        $exitCode = 0
    }
    else {
        $output = & sc.exe @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }

    if ($output) {
        $output | Out-Host
    }
    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        throw "$Action failed with exit code $exitCode."
    }
    return ,$output
}

function Set-CronovaServiceCommandLine {
    # sc.exe config binPath= "<quoted exe> args" is unreliable from PowerShell 5.1
    # (native-arg quoting yields ERROR_INVALID_COMMAND_LINE 1639), so write the
    # SCM registry values directly and verify them.
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$BinaryPath,
        [string[]]$DependsOn
    )

    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (-not (Test-Path $key)) { throw "Service $Name is not registered; cannot update its command line." }
    Set-ItemProperty -Path $key -Name ImagePath -Value $BinaryPath -Type ExpandString
    if ($PSBoundParameters.ContainsKey('DependsOn')) {
        Set-ItemProperty -Path $key -Name DependOnService -Value ([string[]]$DependsOn) -Type MultiString
    }
    $actual = (Get-ItemProperty -Path $key -Name ImagePath).ImagePath
    if ($actual -ne $BinaryPath) { throw "Updating $Name command line failed: ImagePath is '$actual'." }
}

function Get-CronovaServiceState {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [scriptblock]$QueryRunner
    )

    $output = if ($QueryRunner) {
        & $QueryRunner $Name
    }
    else {
        & sc.exe query $Name 2>$null
    }

    if (-not $QueryRunner -and $LASTEXITCODE -ne 0) {
        return $null
    }
    if (-not $output) {
        return $null
    }

    foreach ($line in $output) {
        if ($line -match 'STATE\s*:\s*\d+\s+(\w+)') {
            return $Matches[1]
        }
    }
    return $null
}

function Get-CronovaServicePid {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [scriptblock]$QueryExRunner
    )

    $output = if ($QueryExRunner) {
        & $QueryExRunner $Name
    }
    else {
        & sc.exe queryex $Name 2>$null
    }

    if (-not $QueryExRunner -and $LASTEXITCODE -ne 0) {
        return $null
    }
    if (-not $output) {
        return $null
    }

    foreach ($line in $output) {
        if ($line -match 'PID\s*:\s*(\d+)') {
            return [int]$Matches[1]
        }
    }
    return $null
}

function Wait-CronovaServiceState {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowEmptyCollection()][string[]]$DesiredStates = @(),
        [int]$TimeoutSeconds = 20,
        [scriptblock]$StateGetter,
        [int]$PollMilliseconds = 500
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $state = if ($StateGetter) {
            & $StateGetter $Name
        }
        else {
            Get-CronovaServiceState -Name $Name
        }

        if (-not $state -or $DesiredStates -contains $state) {
            return $state
        }

        Start-Sleep -Milliseconds $PollMilliseconds
    }

    if ($StateGetter) {
        return & $StateGetter $Name
    }

    return Get-CronovaServiceState -Name $Name
}

function Stop-CronovaServiceProcess {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [scriptblock]$PidGetter,
        [scriptblock]$ProcessStopper
    )

    $servicePid = if ($PidGetter) {
        & $PidGetter $Name
    }
    else {
        Get-CronovaServicePid -Name $Name
    }

    if ($servicePid -and $servicePid -gt 0) {
        Write-Warning "Force stopping process for service ${Name}: PID $servicePid"
        if ($ProcessStopper) {
            & $ProcessStopper $servicePid
        }
        else {
            Stop-Process -Id $servicePid -Force
        }
        Start-Sleep -Seconds 1
    }
}

function Stop-CronovaService {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$TimeoutSeconds = 20,
        [switch]$ForceKill,
        [scriptblock]$ServiceGetter,
        [scriptblock]$StateGetter,
        [scriptblock]$ScRunner,
        [scriptblock]$PidGetter,
        [scriptblock]$ProcessStopper,
        [scriptblock]$ServiceStopper
    )

    $service = if ($ServiceGetter) {
        & $ServiceGetter $Name
    }
    else {
        Get-Service -Name $Name -ErrorAction SilentlyContinue
    }

    if (-not $service) {
        return
    }

    $state = if ($StateGetter) {
        & $StateGetter $Name
    }
    else {
        Get-CronovaServiceState -Name $Name
    }

    if ($state -and $state -ne 'STOPPED') {
        try {
            if ($ServiceStopper) {
                & $ServiceStopper $Name
            }
            else {
                $service.Stop()
            }
        }
        catch {
            Write-Warning "ServiceController.Stop() $Name failed: $($_.Exception.Message)"
        }

        Invoke-CronovaSc -Arguments @('stop', $Name) -Action "Stopping service $Name" -IgnoreExitCode -Runner $ScRunner | Out-Null
    }

    $state = Wait-CronovaServiceState -Name $Name -DesiredStates @('STOPPED') -TimeoutSeconds $TimeoutSeconds -StateGetter $StateGetter -PollMilliseconds 250
    if ($state -eq 'STOPPED' -or -not $state) {
        return
    }

    if ($ForceKill) {
        Stop-CronovaServiceProcess -Name $Name -PidGetter $PidGetter -ProcessStopper $ProcessStopper
        $state = Wait-CronovaServiceState -Name $Name -DesiredStates @('STOPPED') -TimeoutSeconds 5 -StateGetter $StateGetter -PollMilliseconds 250
        if ($state -eq 'STOPPED' -or -not $state) {
            return
        }
    }

    throw "Service $Name did not stop. Last state: $state"
}

function Remove-CronovaService {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$ForceKill,
        [scriptblock]$ServiceGetter,
        [scriptblock]$StateGetter,
        [scriptblock]$ScRunner,
        [scriptblock]$PidGetter,
        [scriptblock]$ProcessStopper,
        [scriptblock]$ServiceStopper
    )

    Stop-CronovaService -Name $Name -ForceKill:$ForceKill -ServiceGetter $ServiceGetter -StateGetter $StateGetter -ScRunner $ScRunner -PidGetter $PidGetter -ProcessStopper $ProcessStopper -ServiceStopper $ServiceStopper
    Invoke-CronovaSc -Arguments @('delete', $Name) -Action "Deleting service $Name" -IgnoreExitCode -Runner $ScRunner | Out-Null
    Wait-CronovaServiceState -Name $Name -DesiredStates @() -TimeoutSeconds 10 -StateGetter $StateGetter | Out-Null
}

function Get-CronovaHttpPort {
    param([Parameter(Mandatory = $true)][string]$ConfigPath)

    $port = 8090
    if (Test-Path $ConfigPath) {
        foreach ($line in Get-Content $ConfigPath) {
            if ($line -match '^\s*http\s*:\s*["'']?[^"''\s]*:(\d+)') {
                $port = [int]$Matches[1]
                break
            }
        }
    }
    return $port
}

function Assert-CronovaPortFree {
    param(
        [Parameter(Mandatory = $true)][int]$Port,
        [switch]$FreePort
    )

    $owners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique)
    foreach ($ownerPid in $owners) {
        $proc = Get-Process -Id $ownerPid -ErrorAction SilentlyContinue
        $desc = if ($proc) { "$($proc.ProcessName) (PID $ownerPid, $($proc.Path))" } else { "PID $ownerPid" }
        if ($FreePort) {
            Write-Warning "Port $Port is held by $desc - stopping it."
            Stop-Process -Id $ownerPid -Force
            Start-Sleep -Seconds 1
        }
        else {
            throw "Port $Port is already in use by $desc. Stop that process, change 'http:' in the Cronova config, or rerun with -FreePort."
        }
    }
}

function Start-CronovaService {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$TimeoutSeconds = 20,
        [int]$RetrySeconds = 45
    )

    # A force-killed scheduler leaves a DB lease (~15s); retry until it expires.
    $deadline = (Get-Date).AddSeconds($RetrySeconds)
    while ($true) {
        $lastError = $null
        try {
            Start-Service -Name $Name -ErrorAction Stop
        }
        catch {
            $lastError = $_.Exception.Message
        }

        $state = Wait-CronovaServiceState -Name $Name -DesiredStates @('RUNNING', 'STOPPED') -TimeoutSeconds $TimeoutSeconds
        if ($state -eq 'RUNNING') {
            Start-Sleep -Seconds 3
            $state = Get-CronovaServiceState -Name $Name
            if ($state -eq 'RUNNING') {
                return
            }
        }

        if ((Get-Date) -ge $deadline) {
            if (-not $lastError) { $lastError = "last state: $state" }
            throw "Starting service $Name failed: $lastError. Check Event Viewer (System log) and the Cronova logs directory."
        }

        Write-Warning "Service $Name did not start ($state); retrying in 5s..."
        Start-Sleep -Seconds 5
    }
}

function Resolve-CronovaPackageSource {
    param([Parameter(Mandatory = $true)][string]$SourcePath)

    $resolved = (Resolve-Path $SourcePath).Path
    $directExe = Join-Path $resolved 'cronova.exe'
    $zipPath = Join-Path $resolved 'cronova_windows_amd64.zip'

    # Source checkout: rebuild so stale binaries are never installed as services.
    if ((Test-Path (Join-Path $resolved 'go.mod')) -and (Test-Path (Join-Path $resolved 'cmd\cronova-executor'))) {
        if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
            throw "Source is a Go checkout but 'go' is not on PATH; cannot rebuild cronova.exe/cronova-executor.exe: $resolved"
        }
        Push-Location $resolved
        try {
            $env:GOOS = 'windows'
            foreach ($target in @(@{ Out = 'cronova.exe'; Pkg = './cmd/cronova' }, @{ Out = 'cronova-executor.exe'; Pkg = './cmd/cronova-executor' })) {
                Write-Host "Building $($target.Out) from $($target.Pkg)..."
                & go build -o $target.Out $target.Pkg
                if ($LASTEXITCODE -ne 0) { throw "go build $($target.Pkg) failed with exit code $LASTEXITCODE." }
            }
        } finally {
            Pop-Location
        }
    }

    if (Test-Path $directExe) {
        return @{ Root = $resolved; Cleanup = $null }
    }

    if (-not (Test-Path $zipPath)) {
        throw "Source must contain cronova.exe or cronova_windows_amd64.zip: $resolved"
    }

    $extractDir = Join-Path ([IO.Path]::GetTempPath()) ("cronova-install-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

    $packageRoot = $extractDir
    if (-not (Test-Path (Join-Path $packageRoot 'cronova.exe'))) {
        $nestedExe = Get-ChildItem -LiteralPath $extractDir -Recurse -Filter 'cronova.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($nestedExe) {
            $packageRoot = Split-Path -Parent $nestedExe.FullName
        }
    }

    if (-not (Test-Path (Join-Path $packageRoot 'cronova.exe'))) {
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        throw "Expanded package does not contain cronova.exe: $zipPath"
    }

    return @{
        Root = $packageRoot
        Cleanup = { param($Path) Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
