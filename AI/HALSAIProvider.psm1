#==========================================================
# HALS - AI Provider Switcher / Remover
# Version : 3.1.0
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

function Remove-HALSAIProvider {

    param(
        [Parameter(Mandatory)]
        [string]$Provider
    )

    $ProviderMetadata = Get-HALSAIProvider -Provider $Provider
    $ConfigPath = Join-Path (Get-HALSRoot) "Config\AI.json"

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Write-Host "$($ProviderMetadata.Name) is not configured." -ForegroundColor DarkGray
        return
    }

    $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

    if (-not $Config.PSObject.Properties[$ProviderMetadata.Key]) {
        Write-Host "$($ProviderMetadata.Name) is not configured." -ForegroundColor DarkGray
        return
    }

    $null = $Config.PSObject.Properties.Remove($ProviderMetadata.Key)

    $WasActive = $Config.PSObject.Properties["Provider"] -and
        [string]$Config.Provider -ieq $ProviderMetadata.Key

    if ($WasActive) {
        $Replacement = $null
        foreach ($Candidate in @(Get-HALSAIProviderRegistry)) {
            if ($Candidate.Key -ieq $ProviderMetadata.Key) { continue }
            if (-not $Config.PSObject.Properties[$Candidate.Key]) { continue }
            if (Test-HALSAIProviderConfigured -Provider $Candidate.Key -Configuration $Config.($Candidate.Key)) {
                $Replacement = $Candidate.Key
                break
            }
        }

        if ($Replacement) {
            $Config.Provider = $Replacement
        }
        else {
            $Config.Provider = $null
        }
    }

    $RemainingConfigured = @(
        Get-HALSAIProviderRegistry |
            Where-Object {
                $Config.PSObject.Properties[$_.Key] -and
                (Test-HALSAIProviderConfigured -Provider $_.Key -Configuration $Config.($_.Key))
            }
    )

    if ($RemainingConfigured.Count -eq 0 -and
        ($null -eq $Config.Provider -or [string]::IsNullOrWhiteSpace([string]$Config.Provider))) {
        Remove-Item -LiteralPath $ConfigPath -Force
        Write-Host ""
        Write-Host "Removed $($ProviderMetadata.Name). No AI providers remain configured." -ForegroundColor Green
        Write-Host "Run Initialize-HALSAI to add one later." -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    $Config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigPath

    Write-Host ""
    Write-Host "Removed $($ProviderMetadata.Name) from AI configuration." -ForegroundColor Green
    if ($WasActive -and $Config.Provider) {
        Write-Host "Active provider is now $($Config.Provider)." -ForegroundColor DarkGray
    }
    elseif ($WasActive) {
        Write-Host "No active AI provider. Run Initialize-HALSAI or Switch-HALSAIProvider." -ForegroundColor DarkGray
    }
    Write-Host ""
}

Export-ModuleMember -Function Switch-HALSAIProvider, Remove-HALSAIProvider
