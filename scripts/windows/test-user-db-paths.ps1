[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $repoRoot 'internal\scripts\cronova-user-common.ps1')

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('cronova-user-db-' + [guid]::NewGuid().ToString('N'))
$dataDir = Join-Path $testRoot 'user data'
$config = Join-Path $dataDir 'cronova.yaml'
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
try {
    Set-Content -LiteralPath $config -Value 'db: data/cronova.db' -Encoding UTF8
    $expected = [IO.Path]::GetFullPath((Join-Path $dataDir 'data\cronova.db'))
    $actual = Get-CronovaUserDatabasePath -DataDir $dataDir -ConfigPath $config
    if (-not [string]::Equals($expected, $actual, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Relative YAML db path resolved incorrectly: expected '$expected', got '$actual'."
    }

    Set-Content -LiteralPath $config -Value "db: 'custom folder/cronova.db'" -Encoding UTF8
    $customExpected = [IO.Path]::GetFullPath((Join-Path $dataDir 'custom folder\cronova.db'))
    $customActual = Get-CronovaUserDatabasePath -DataDir $dataDir -ConfigPath $config
    if (-not [string]::Equals($customExpected, $customActual, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Quoted relative YAML db path resolved incorrectly: expected '$customExpected', got '$customActual'."
    }

    Set-Content -LiteralPath $config -Value 'db: data/cronova.db' -Encoding UTF8
    $legacy = Join-Path $dataDir 'cronova.db'
    $target = Join-Path $dataDir 'data\cronova.db'
    Set-Content -LiteralPath $legacy -Value 'legacy database bytes' -NoNewline
    Set-Content -LiteralPath ($legacy + '-wal') -Value 'legacy wal bytes' -NoNewline
    Set-Content -LiteralPath ($legacy + '-journal') -Value 'legacy journal bytes' -NoNewline
    $dbPath = Get-CronovaUserDatabasePath -DataDir $dataDir -ConfigPath $config
    Move-CronovaUserDatabaseToConfiguredPath -DataDir $dataDir -DatabasePath $dbPath
    if (-not (Test-Path -LiteralPath $target) -or (Get-Content -LiteralPath $target -Raw) -ne 'legacy database bytes') {
        throw 'Legacy database was not moved to the configured db: path.'
    }
    if (-not (Test-Path -LiteralPath ($target + '-wal')) -or (Get-Content -LiteralPath ($target + '-wal') -Raw) -ne 'legacy wal bytes') {
        throw 'Legacy SQLite WAL sidecar was not moved with the database.'
    }
    if (-not (Test-Path -LiteralPath ($target + '-journal')) -or (Get-Content -LiteralPath ($target + '-journal') -Raw) -ne 'legacy journal bytes') {
        throw 'Legacy SQLite rollback journal was not moved with the database.'
    }
    if (Test-Path -LiteralPath $legacy) { throw 'Legacy database file still exists after migration.' }

    Set-Content -LiteralPath $legacy -Value 'keep legacy' -NoNewline
    Set-Content -LiteralPath $target -Value 'keep configured' -NoNewline
    $threw = $false
    try { Move-CronovaUserDatabaseToConfiguredPath -DataDir $dataDir -DatabasePath $dbPath }
    catch { $threw = $_.Exception.Message -match 'both .* and target database files exist' }
    if (-not $threw) { throw 'Expected a clear error when both legacy and configured databases exist.' }
    if ((Get-Content -LiteralPath $legacy -Raw) -ne 'keep legacy' -or (Get-Content -LiteralPath $target -Raw) -ne 'keep configured') {
        throw 'Database conflict handling changed one of the existing files.'
    }
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Per-user database path and migration tests passed.'
