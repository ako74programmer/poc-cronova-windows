[CmdletBinding()]
param(
    [string]$CronovaExe,
    [string]$DatabasePath = 'C:\ProgramData\Cronova\cronova.db',
    [string]$Username = 'admin',
    [string]$Password = 'admin123'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($CronovaExe)) {
    $programFilesExe = Join-Path $env:ProgramFiles 'Cronova\cronova.exe'
    if (Test-Path $programFilesExe) {
        $CronovaExe = $programFilesExe
    }
}

if ([string]::IsNullOrWhiteSpace($CronovaExe)) {
    throw 'Provide -CronovaExe or install Cronova to C:\Program Files\Cronova first.'
}

if (-not (Test-Path $CronovaExe)) {
    throw "cronova.exe not found: $CronovaExe"
}

if ([string]::IsNullOrWhiteSpace($DatabasePath)) {
    throw 'Database path cannot be empty.'
}

$dbDir = Split-Path -Parent $DatabasePath
if ($dbDir -and -not (Test-Path $dbDir)) {
    New-Item -ItemType Directory -Force -Path $dbDir | Out-Null
}

& $CronovaExe users add $Username -role admin -password $Password -db $DatabasePath | Out-Host
if ($LASTEXITCODE -eq 0) {
    Write-Host "Seeded admin user '$Username' in $DatabasePath"
    exit 0
}

& $CronovaExe users passwd $Username -password $Password -db $DatabasePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Failed to seed admin user '$Username' in $DatabasePath (exit code $LASTEXITCODE)."
}

Write-Host "Updated admin password for '$Username' in $DatabasePath"
