# Regenerate the embedded AI wiki knowledge base and rebuild cronova.
# Run this after changing docs, DAGs, or workflow scripts.
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# On Windows the 'python3' shim often opens the Microsoft Store; prefer 'python'.
$py = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } elseif (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { $null }
if (-not $py) { Write-Error "python not found"; exit 1 }

Write-Host "==> regenerating knowledge base with $py..."
& $py internal/ai-wiki/build_knowledge_base.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> building cronova..."
& go build -trimpath -ldflags "-s -w -X main.version=dev" -o cronova ./cmd/cronova
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> done: ./cronova"
