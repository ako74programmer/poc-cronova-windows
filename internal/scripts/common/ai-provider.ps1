Set-StrictMode -Version 3.0

function Resolve-AiProvider([string]$Database, [string]$ProviderId, [string]$Python) {
    if ($env:CRONOVA_AI_BASE_URL -and $env:CRONOVA_AI_MODEL) {
        return @($env:CRONOVA_AI_BASE_URL, $env:CRONOVA_AI_MODEL, $env:CRONOVA_AI_TOKEN)
    }
    if (-not (Test-Path -LiteralPath $Database -PathType Leaf)) { return $null }
    $python = if ($Python) { $Python } elseif ($env:CRONOVA_PYTHON) { $env:CRONOVA_PYTHON } else { 'python' }
    $queryFile = Join-Path ([IO.Path]::GetTempPath()) ("cronova-provider-" + [guid]::NewGuid().ToString('N') + '.py')
    $query = @'
import sqlite3, sys

db = sys.argv[1]
provider_id = sys.argv[2] if len(sys.argv) > 2 else ""
try:
    con = sqlite3.connect(db)
    cur = con.cursor()
    row = None
    if provider_id:
        row = cur.execute("SELECT base_url, model, token FROM ai_providers WHERE id=?", (provider_id,)).fetchone()
    if row is None and (not provider_id or provider_id.lower() == "default"):
        row = cur.execute("SELECT base_url, model, token FROM ai_providers WHERE is_default=1 LIMIT 1").fetchone()
    if row:
        print("|".join(str(x or "") for x in row))
finally:
    try:
        con.close()
    except Exception:
        pass
'@
    try {
        Set-Content -LiteralPath $queryFile -Value $query -Encoding UTF8
        $result = & $python $queryFile $Database $ProviderId
        $exitCode = if (Test-Path variable:LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
        if ($exitCode -ne 0 -or -not $result) { return $null }
        $line = ($result | Select-Object -First 1).ToString()
        $parts = $line -split '\|', 3
        if ($parts.Count -lt 2 -or -not $parts[0] -or -not $parts[1]) { return $null }
        return @($parts[0], $parts[1], $(if ($parts.Count -ge 3) { $parts[2] } else { '' }))
    } finally {
        Remove-Item -LiteralPath $queryFile -Force -ErrorAction SilentlyContinue
    }
}
