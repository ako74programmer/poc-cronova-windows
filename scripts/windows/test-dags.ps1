[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dagDir = Join-Path $RepoRoot 'dags'
$dagFiles = Get-ChildItem -Path $dagDir -File | Where-Object { $_.Extension -in @('.yaml', '.yml') } | Sort-Object Name
if (-not $dagFiles) {
    throw "No DAG files found in $dagDir"
}

$allowedTypes = @('powershell', 'python', 'sql', 'jar', 'http', 'subdag', 'shell')
$issues = @()

foreach ($file in $dagFiles) {
    $lines = Get-Content $file.FullName
    foreach ($line in $lines) {
        if ($line -match '^\s*type:\s*(.+?)\s*$') {
            $taskType = $Matches[1].Trim().Trim('"''')
            if ($allowedTypes -notcontains $taskType) {
                $issues += "$($file.Name): unsupported task type '$taskType'"
            }
        }
        if ($line -match '^\s*command:\s*["'']?&\s+\.\\internal\\scripts\\([^\s"'']+)') {
            $scriptName = $Matches[1]
            $scriptPath = Join-Path $RepoRoot "internal\scripts\$scriptName"
            if (-not (Test-Path $scriptPath)) {
                $issues += "$($file.Name): missing runtime script internal\\scripts\\$scriptName"
            }
        }
        if ($line -match 'prompts[\\/](.+?\.txt)') {
            $promptRelative = Join-Path 'prompts' $Matches[1]
            $promptPath = Join-Path $RepoRoot $promptRelative
            if (-not (Test-Path $promptPath)) {
                $issues += "$($file.Name): missing prompt $promptRelative"
            }
        }
    }
}

if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Error $_ }
    throw "DAG validation failed for $($issues.Count) issue(s)."
}

Write-Host "Validated $($dagFiles.Count) DAG file(s)."
