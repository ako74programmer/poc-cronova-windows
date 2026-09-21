[CmdletBinding()]
param([string]$Version = "", [string]$Output = "dist")
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Version) { $Version = (git -C $Root describe --tags --always --dirty 2>$null); if (-not $Version) { $Version = "dev" } }
$Stage = Join-Path ([IO.Path]::GetTempPath()) ("cronova-package-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $Stage, (Join-Path $Root $Output) | Out-Null
try {
  $env:CGO_ENABLED = "0"; $env:GOOS = "windows"; $env:GOARCH = "amd64"
  $ld = "-s -w -X main.version=$Version"
  go build -trimpath -ldflags $ld -o (Join-Path $Stage "cronova.exe") (Join-Path $Root "./cmd/cronova")
  go build -trimpath -ldflags $ld -o (Join-Path $Stage "cronova-executor.exe") (Join-Path $Root "./cmd/cronova-executor")
  New-Item -ItemType Directory -Force -Path (Join-Path $Stage "deploy"), (Join-Path $Stage "dags"), (Join-Path $Stage "docs"), (Join-Path $Stage "configs"), (Join-Path $Stage "contracts"), (Join-Path $Stage "scripts\sdlc"), (Join-Path $Stage "e2e\playwright") | Out-Null
  Copy-Item (Join-Path $Root "deploy/install.ps1") (Join-Path $Stage "deploy")
  Copy-Item (Join-Path $Root "deploy/uninstall.ps1") (Join-Path $Stage "deploy")
  Copy-Item (Join-Path $Root "deploy/update.ps1") (Join-Path $Stage "deploy")
  Copy-Item (Join-Path $Root "cronova.yaml") (Join-Path $Stage "cronova.yaml")
  Copy-Item (Join-Path $Root "dags/*.yaml") (Join-Path $Stage "dags")
  Copy-Item (Join-Path $Root "docs/DEPLOY.md") (Join-Path $Stage "docs")
  Copy-Item (Join-Path $Root "configs/*") (Join-Path $Stage "configs") -Recurse
  Copy-Item (Join-Path $Root "contracts/*") (Join-Path $Stage "contracts") -Recurse
  Copy-Item (Join-Path $Root "scripts/sdlc/*") (Join-Path $Stage "scripts\sdlc") -Recurse
  Copy-Item (Join-Path $Root "e2e/playwright/*") (Join-Path $Stage "e2e\playwright") -Recurse
  Set-Content -NoNewline -Path (Join-Path $Stage "VERSION") -Value $Version
  $OutFile = Join-Path (Join-Path $Root $Output) "cronova_windows_amd64.zip"
  if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
  Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $OutFile
  Get-FileHash $OutFile -Algorithm SHA256 | Format-List
  Write-Host "Created $OutFile"
} finally { Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue }
