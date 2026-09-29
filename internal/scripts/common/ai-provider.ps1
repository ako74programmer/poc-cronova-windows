Set-StrictMode -Version 3.0

function Resolve-AiProvider([string]$Database, [string]$ProviderId) {
    if ($env:CRONOVA_AI_BASE_URL -and $env:CRONOVA_AI_MODEL) {
        return @($env:CRONOVA_AI_BASE_URL, $env:CRONOVA_AI_MODEL, $env:CRONOVA_AI_TOKEN)
    }
    if (-not (Test-Path -LiteralPath $Database)) { return $null }
    $python = if ($env:CRONOVA_PYTHON) { $env:CRONOVA_PYTHON } else { 'python' }
    $query = @'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
cur = con.cursor()
provider_id = sys.argv[2]
row = cur.execute("SELECT base_url, model, token FROM ai_providers WHERE id=?", (provider_id,)).fetchone() if provider_id else cur.execute("SELECT base_url, model, token FROM ai_providers WHERE is_default=1 LIMIT 1").fetchone()
if row: print("|".join(str(x or "") for x in row))
'@
    $result = $query | & $python - $Database $ProviderId 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $result) { return $null }
    return (($result | Select-Object -First 1) -split '\|', 3)
}
