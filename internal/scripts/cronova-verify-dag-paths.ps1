[CmdletBinding()]
param(
    # Root that DAG tasks run from (package root or installed data dir).
    [Parameter(Mandatory = $true)][string]$Root,
    # Directory with DAG YAML files; defaults to <Root>\dags.
    [string]$DagsDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $DagsDir) { $DagsDir = Join-Path $Root 'dags' }

# Relative file references used by DAG commands (scripts, prompts, templates, configs, ...).
$pattern = '(?i)(?<![\w:\\/])(internal[\\/]+scripts|scripts|prompts|templates|configs|contracts|e2e|deploy)[\\/]+[\w\.\-\\/]+'
$dags = @(Get-ChildItem -LiteralPath $DagsDir -Filter '*.yaml' -File)
if ($dags.Count -eq 0) { throw "No DAG files found in $DagsDir" }

$checked = 0
$missing = New-Object System.Collections.Generic.List[string]
foreach ($dag in $dags) {
    $text = Get-Content -LiteralPath $dag.FullName -Raw
    foreach ($match in [regex]::Matches($text, $pattern)) {
        $relative = ($match.Value.TrimEnd('.', '/', '\') -replace '[\\/]+', '\')
        $checked++
        if (-not (Test-Path -LiteralPath (Join-Path $Root $relative))) {
            $missing.Add("$($dag.Name): $relative")
        }
    }
}

$unique = @($missing | Sort-Object -Unique)
if ($unique.Count -gt 0) {
    $unique | ForEach-Object { Write-Host "Missing DAG dependency: $_" -ForegroundColor Red }
    throw "DAG dependency check failed: $($unique.Count) missing path(s) under $Root"
}

Write-Host "DAG dependency check OK: $($dags.Count) DAG(s), $checked reference(s) under $Root"
