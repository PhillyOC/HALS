#==========================================================
# HALS - AI Configuration
# Version : 4.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Get-HALSAIProviderRegistry -ErrorAction SilentlyContinue)) {
    Import-Module "$(Get-HALSRoot)\AI\HALSAIProviderRegistry.psm1" -Global
}

function Get-HALSAIConfiguration {

    param(
        [switch]$Optional
    )

    $Configuration = Import-HALSAIConfiguration -Optional:$Optional
    if (-not $Configuration) {
        return $null
    }

    if (-not $Configuration.PSObject.Properties["Provider"] -or
        [string]::IsNullOrWhiteSpace([string]$Configuration.Provider)) {
        if ($Optional) {
            return $null
        }
        throw "AI configuration is missing the Provider property."
    }

    $Provider = Get-HALSAIProvider -Provider $Configuration.Provider
    $Section = if ($Configuration.PSObject.Properties[$Provider.Key]) {
        $Configuration.($Provider.Key)
    }
    else {
        $null
    }

    if (-not $Section) {
        throw "$($Provider.Name) configuration section missing. Run $($Provider.SetupCommand)."
    }

    if (-not (Test-HALSAIProviderConfigured -Provider $Provider.Key -Configuration $Section)) {
        $MissingSetting = if (
            $Provider.RequiresApiKey -and (
                -not $Section.PSObject.Properties["ApiKey"] -or
                [string]::IsNullOrWhiteSpace([string]$Section.ApiKey)
            )
        ) { "ApiKey" } else { "Model" }

        throw "$($Provider.Name) $MissingSetting missing. Run $($Provider.SetupCommand)."
    }

    return $Configuration

}

Export-ModuleMember -Function Get-HALSAIConfiguration
