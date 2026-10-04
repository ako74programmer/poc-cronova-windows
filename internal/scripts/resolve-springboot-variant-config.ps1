[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Variant
)

$ErrorActionPreference = 'Stop'

$variantMap = [ordered]@{
    'rest' = 'configs/sdlc-springboot.yaml'
    'crud' = 'configs/sdlc-springboot-crud.yaml'
    'h2' = 'configs/sdlc-springboot-h2.yaml'
    'security' = 'configs/sdlc-springboot-security.yaml'
}

$normalizedVariant = $Variant.Trim().ToLowerInvariant()
if (-not $variantMap.Contains($normalizedVariant)) {
    $supported = ($variantMap.Keys | Sort-Object) -join ', '
    throw "Unsupported Spring Boot variant '$Variant'. Supported variants: $supported"
}

Write-Output $variantMap[$normalizedVariant]