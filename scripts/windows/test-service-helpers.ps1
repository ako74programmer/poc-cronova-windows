[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'internal\scripts\cronova-service-common.ps1')

$results = [ordered]@{
    StopRequested = $false
    ScActions = [System.Collections.Generic.List[string]]::new()
    KilledPid = $null
    StateCalls = 0
}

$serviceObject = [pscustomobject]@{ Name = 'Cronova'; Status = 'Running' }
$states = [System.Collections.Generic.Queue[string]]::new()
$states.Enqueue('RUNNING')
$states.Enqueue('RUNNING')
$states.Enqueue('STOPPED')

$serviceGetter = {
    param($name)
    if ($name -eq 'Cronova') { return $serviceObject }
    return $null
}

$stateGetter = {
    param($name)
    $results.StateCalls++
    if ($states.Count -gt 0) {
        return $states.Dequeue()
    }
    return 'STOPPED'
}

$serviceStopper = {
    param($name)
    $results.StopRequested = $true
}

$scRunner = {
    param([string[]]$arguments)
    $results.ScActions.Add(($arguments -join ' '))
    return @()
}

Stop-CronovaService -Name 'Cronova' -ForceKill -TimeoutSeconds 1 -ServiceGetter $serviceGetter -StateGetter $stateGetter -ServiceStopper $serviceStopper -ScRunner $scRunner
if (-not $results.StopRequested) {
    throw 'Expected Stop-CronovaService to invoke service stopper.'
}
if ($results.ScActions.Count -eq 0 -or $results.ScActions[0] -ne 'stop Cronova') {
    throw 'Expected Stop-CronovaService to invoke sc stop fallback.'
}

$deleteStates = [System.Collections.Generic.Queue[string]]::new()
$deleteStates.Enqueue('STOPPED')
$deleteStates.Enqueue($null)
$deleteStateGetter = {
    param($name)
    if ($deleteStates.Count -gt 0) {
        return $deleteStates.Dequeue()
    }
    return $null
}

$results.ScActions.Clear()
Remove-CronovaService -Name 'Cronova' -ForceKill -ServiceGetter $serviceGetter -StateGetter $deleteStateGetter -ScRunner $scRunner -ServiceStopper $serviceStopper
if ($results.ScActions.Count -lt 1) {
    throw 'Expected Remove-CronovaService to call delete operation.'
}
if ($results.ScActions[0] -ne 'delete Cronova') {
    throw 'Expected Remove-CronovaService to delete the service.'
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('cronova-helper-test-' + [guid]::NewGuid())
$sourceDir = Join-Path $tempRoot 'source'
$zipContainerDir = Join-Path $tempRoot 'zip-container'
$extractSeed = Join-Path $tempRoot 'extract-seed'
$zipStage = Join-Path $tempRoot 'zip-stage'
New-Item -ItemType Directory -Force -Path $sourceDir, $zipContainerDir, $extractSeed, $zipStage | Out-Null
try {
    Set-Content -LiteralPath (Join-Path $sourceDir 'cronova.exe') -Value 'exe'
    Set-Content -LiteralPath (Join-Path $sourceDir 'cronova-executor.exe') -Value 'executor'
    Set-Content -LiteralPath (Join-Path $sourceDir 'cronova.yaml') -Value 'config'
    New-Item -ItemType Directory -Force -Path (Join-Path $sourceDir 'dags') | Out-Null
    Set-Content -LiteralPath (Join-Path $sourceDir 'dags\sample.yaml') -Value 'name: sample'

    $direct = Resolve-CronovaPackageSource -SourcePath $sourceDir
    if ($direct.Root -ne (Resolve-Path $sourceDir).Path) {
        throw 'Direct source resolution returned unexpected root.'
    }
    if ($direct.Cleanup) {
        throw 'Direct source resolution should not require cleanup.'
    }

    Copy-Item -LiteralPath (Join-Path $sourceDir '*') -Destination $extractSeed -Recurse
    Copy-Item -LiteralPath (Join-Path $sourceDir '*') -Destination $zipStage -Recurse
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Join-Path $tempRoot 'cronova_windows_amd64.zip'
    if (Test-Path $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($zipStage, $zipPath)
    if (-not (Test-Path $zipPath)) {
        throw 'Expected ZIP package to be created for source resolution test.'
    }
    Copy-Item -LiteralPath $zipPath -Destination (Join-Path $zipContainerDir 'cronova_windows_amd64.zip') -Force

    $zipInspectDir = Join-Path $tempRoot 'zip-inspect'
    Expand-Archive -LiteralPath (Join-Path $zipContainerDir 'cronova_windows_amd64.zip') -DestinationPath $zipInspectDir -Force
    Get-ChildItem -LiteralPath $zipInspectDir -Recurse | ForEach-Object { Write-Host $_.FullName }

    $zipResolved = Resolve-CronovaPackageSource -SourcePath $zipContainerDir
    if (-not (Test-Path (Join-Path $zipResolved.Root 'cronova.exe'))) {
        throw 'ZIP source resolution did not expose cronova.exe.'
    }
    & $zipResolved.Cleanup $zipResolved.Root
    if (Test-Path $zipResolved.Root) {
        throw 'ZIP source cleanup did not remove extracted directory.'
    }
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Service helper simulations passed.'
