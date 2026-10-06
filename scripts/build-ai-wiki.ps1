# Regenerate the embedded AI wiki knowledge base and rebuild cronova.
# Run this after changing docs, DAGs, or workflow scripts.
$ErrorActionPreference = "Stop"

function Assert-PatternAbsent {
  param(
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Description,
    [switch]$CaseSensitive
  )

  $params = @{
    Path    = "internal\aiwiki\knowledge-base.json"
    Pattern = $Pattern
  }
  if (-not $CaseSensitive) {
    $params["CaseSensitive"] = $false
  }
  if (Select-String @params) {
    throw "knowledge-base.json still contains forbidden pattern: $Description"
  }
}

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# On Windows the 'python3' shim often opens the Microsoft Store; prefer 'python'.
$py = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } elseif (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { $null }
if (-not $py) { Write-Error "python not found"; exit 1 }

Write-Host "==> regenerating knowledge base with $py..."
& $py internal/ai-wiki/build_knowledge_base.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> validating knowledge base..."
Assert-PatternAbsent -Pattern '#!/usr/bin/env bash' -Description 'bash shebang'
Assert-PatternAbsent -Pattern 'bash /c/Users/' -Description 'developer-specific Git Bash workflow path'
Assert-PatternAbsent -Pattern 'C:/Users/Andrzej' -Description 'developer-specific absolute Windows path'

Write-Host "==> building cronova..."
& go build -trimpath -ldflags "-s -w -X main.version=dev" -o cronova ./cmd/cronova
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> done: ./cronova"
