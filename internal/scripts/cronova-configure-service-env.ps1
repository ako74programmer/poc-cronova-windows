[CmdletBinding()]
param(
    [string[]]$ServiceName = @('CronovaExecutor'),
    # Extra NAME=VALUE pairs to add or override.
    [string[]]$Extra = @()
)

# Services run as LocalSystem and do not see the installing user's environment
# (JAVA_HOME, user PATH entries for Maven/Python/npm). Capture the toolchain
# here and store it as the service environment so DAG tasks find the tools.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$vars = [ordered]@{}
$detect = Join-Path $PSScriptRoot '..\..\scripts\windows\detect-toolchain.ps1'
if (Test-Path $detect) {
    foreach ($line in @(& $detect)) {
        if ($line -match '^(?<k>[A-Z_]+)=(?<v>.+)$') { $vars[$Matches.k] = $Matches.v }
    }
}

function Resolve-Home([string]$Current, [string]$Detected, [string]$Exe) {
    foreach ($candidate in @($Current, $Detected)) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate "bin\$Exe"))) { return $candidate }
    }
    $cmd = Get-Command $Exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return Split-Path -Parent (Split-Path -Parent $cmd.Source) }
    return $null
}

$javaHome = Resolve-Home $env:JAVA_HOME ($vars['CRONOVA_JAVA_HOME']) 'java.exe'
$mavenHome = Resolve-Home $env:MAVEN_HOME ($vars['CRONOVA_MAVEN_HOME']) 'mvn.cmd'

$pathDirs = New-Object System.Collections.Generic.List[string]
function Add-PathDir([string]$Dir) {
    if ($Dir -and (Test-Path -LiteralPath $Dir) -and -not $pathDirs.Contains($Dir)) { $pathDirs.Add($Dir) }
}

if ($javaHome) { Add-PathDir (Join-Path $javaHome 'bin') }
if ($mavenHome) { Add-PathDir (Join-Path $mavenHome 'bin') }
foreach ($key in 'CRONOVA_PYTHON', 'CRONOVA_NODE', 'CRONOVA_NPM') {
    if ($vars.Contains($key)) { Add-PathDir (Split-Path -Parent $vars[$key]) }
}
if ($vars.Contains('CRONOVA_PYTHON')) { Add-PathDir (Join-Path (Split-Path -Parent $vars['CRONOVA_PYTHON']) 'Scripts') }
foreach ($exe in 'git.exe', 'go.exe') {
    $cmd = Get-Command $exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { Add-PathDir (Split-Path -Parent $cmd.Source) }
}
foreach ($dir in ([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';')) { Add-PathDir $dir }

$envBlock = [ordered]@{}
if ($javaHome) { $envBlock['JAVA_HOME'] = $javaHome } else { Write-Warning 'JDK not found; Java/Maven DAG tasks will fail under the service.' }
if ($mavenHome) { $envBlock['MAVEN_HOME'] = $mavenHome } else { Write-Warning 'Maven not found; Maven DAG tasks will fail under the service.' }
foreach ($key in 'CRONOVA_PYTHON', 'CRONOVA_NODE', 'CRONOVA_NPM') {
    if ($vars.Contains($key)) { $envBlock[$key] = $vars[$key] }
}
$envBlock['PATH'] = ($pathDirs -join ';')
foreach ($pair in $Extra) {
    if ($pair -match '^(?<k>[^=]+)=(?<v>.*)$') { $envBlock[$Matches.k] = $Matches.v }
}

$multi = [string[]]@($envBlock.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" })
foreach ($name in $ServiceName) {
    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$name"
    if (-not (Test-Path $key)) { throw "Service registry key not found: $key" }
    New-ItemProperty -Path $key -Name 'Environment' -PropertyType MultiString -Value $multi -Force | Out-Null
    Write-Host "Configured environment for service ${name}:"
    $envBlock.GetEnumerator() | Where-Object Key -ne 'PATH' | ForEach-Object { Write-Host "  $($_.Key)=$($_.Value)" }
    Write-Host "  PATH=<$($pathDirs.Count) entries>"
}
