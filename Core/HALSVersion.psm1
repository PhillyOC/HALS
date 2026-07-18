#==========================================================
# HALS - Version
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSVersion {

    $Path = Join-Path (Get-HALSRoot) "VERSION"
    if (Test-Path -LiteralPath $Path) {
        $Value = (Get-Content -LiteralPath $Path -Raw).Trim()
        if (-not [string]::IsNullOrWhiteSpace($Value)) {
            return $Value
        }
    }

    return "0.0.0-dev"
}

Export-ModuleMember -Function Get-HALSVersion
