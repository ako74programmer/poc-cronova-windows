[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$targets = @(
    (Join-Path $RepoRoot 'scripts\windows\app.ps1'),
    (Join-Path $RepoRoot 'scripts\windows\detect-toolchain.ps1'),
    (Join-Path $RepoRoot 'scripts\build-ai-wiki.ps1')
)
$targets += Get-ChildItem -Path (Join-Path $RepoRoot 'internal\scripts') -Filter *.ps1 -File -Recurse | ForEach-Object { $_.FullName }
$targets = $targets | Sort-Object -Unique

$errorsFound = @()
foreach ($file in $targets) {
    $null = $tokens = $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        foreach ($parseError in $parseErrors) {
            $errorsFound += "${file}:$($parseError.Extent.StartLineNumber): $($parseError.Message)"
        }
    }
}

if ($errorsFound.Count -gt 0) {
    $errorsFound | ForEach-Object { Write-Error $_ }
    throw "PowerShell syntax validation failed for $($errorsFound.Count) issue(s)."
}

Write-Host "Validated $($targets.Count) PowerShell script(s)."
