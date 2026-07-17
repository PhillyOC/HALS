#==========================================================
# HALS - AI Provider Switcher
# Version : 3.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Get-HALSAIProviderRegistry -ErrorAction SilentlyContinue)) {
    Import-Module "$(Get-HALSRoot)\AI\HALSAIProviderRegistry.psm1" -Global
}

function Switch-HALSAIProvider {

    param(

        [Parameter(Mandatory)]
        [string]$Provider

    )

    $ProviderMetadata = Get-HALSAIProvider -Provider $Provider
    $ConfigPath = "$(Get-HALSRoot)\Config\AI.json"

    $Config = Import-HALSAIConfiguration
    $Section = if ($Config.PSObject.Properties[$ProviderMetadata.Key]) {
        $Config.($ProviderMetadata.Key)
    }
    else {
        $null
    }

    if (-not $Section -or
        -not (Test-HALSAIProviderConfigured -Provider $ProviderMetadata.Key -Configuration $Section)) {
        throw "$($ProviderMetadata.Name) is not configured. Run $($ProviderMetadata.SetupCommand) first."
    }

    $Previous = $Config.Provider
    $Config.Provider = $ProviderMetadata.Key

    $Config |
        ConvertTo-Json -Depth 10 |
        Set-Content $ConfigPath

    $ModelInfo = ""
    if ($Section.PSObject.Properties["Model"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Section.Model)) {
        $ModelInfo = "  [$($Section.Model)]"
    }

    Write-Host ""
    Write-Host "AI provider switched:" -ForegroundColor Cyan
    Write-Host ("  " + ([string]$Previous).PadRight(14) + "->  $($ProviderMetadata.Key)$ModelInfo") -ForegroundColor Green
    Write-Host ""
    Write-Host "Ask-HALSAI will now use $($ProviderMetadata.Key)." -ForegroundColor Green
    Write-Host ""

}

Export-ModuleMember -Function Switch-HALSAIProvider
