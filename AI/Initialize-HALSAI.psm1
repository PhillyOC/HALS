#==========================================================
# HALS - AI Provider Initialization
# Version : 3.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Get-HALSAIProviderRegistry -ErrorAction SilentlyContinue)) {
    Import-Module "$(Get-HALSRoot)\AI\HALSAIProviderRegistry.psm1" -Global
}

function Initialize-OpenAI {

    $ConfigPath = "$(Get-HALSRoot)\Config\AI.json"

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS OPENAI SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    do {
        $ApiKey = (Read-Host "OpenAI API Key").Trim()
        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            Write-Host "API key cannot be empty." -ForegroundColor Red
        }
    } while ([string]::IsNullOrWhiteSpace($ApiKey))

    $Model = (Read-Host "OpenAI model [gpt-5.5]").Trim()
    if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-5.5" }

    $OpenAIConfiguration = [PSCustomObject]@{
        ApiKey = $ApiKey
        Model  = $Model
    }

    try {

        $Result = Send-HALSAIProviderInitialization `
            -Provider OpenAI `
            -Configuration $OpenAIConfiguration

        Write-Host ""
        Write-Host "OpenAI connection successful. HALSAI system prompt accepted." -ForegroundColor Green
        Write-Host $Result -ForegroundColor Cyan
        Write-Host ""

    }
    catch {

        Write-Host ""
        Write-Host "OpenAI initialization failed." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""

        return $false

    }

    $Existing = @{}
    if (Test-Path $ConfigPath) {
        $Existing = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    }

    $Existing["OpenAI"] = @{
        ApiKey = $ApiKey
        Model  = $Model
    }

    $CurrentProvider = $Existing["Provider"]
    $Prompt = if ($CurrentProvider) {
        "Set OpenAI as active instead of $CurrentProvider? (Y/N)"
    }
    else {
        "Set OpenAI as the active provider? (Y/N)"
    }

    if ((Read-Host $Prompt).Trim().ToUpper() -eq "Y" -or -not $CurrentProvider) {
        $Existing["Provider"] = "OpenAI"
    }

    $Existing |
        ConvertTo-Json -Depth 10 |
        Set-Content $ConfigPath

    Write-Host ""
    Write-Host "OpenAI configuration saved." -ForegroundColor Green
    Write-Host ""

    return $true

}

function Initialize-HALSAI {

    $Providers = @(Get-HALSAIProviderRegistry)

    Write-Host ""
    Write-Host "HALSAI provider setup" -ForegroundColor Cyan
    Write-Host ""

    for ($Index = 0; $Index -lt $Providers.Count; $Index++) {
        Write-Host "  [$($Index + 1)] $($Providers[$Index].Name)" -ForegroundColor White
    }

    Write-Host ""

    $SelectionText = (Read-Host "Choose a provider [1-$($Providers.Count)]").Trim()
    $Selection = 0

    if (-not [int]::TryParse($SelectionText, [ref]$Selection) -or
        $Selection -lt 1 -or
        $Selection -gt $Providers.Count) {
        Write-Host "Invalid provider selection." -ForegroundColor Yellow
        return $false
    }

    $Command = $Providers[$Selection - 1].SetupCommand

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Import-HALSAIProvider -Provider $Providers[$Selection - 1].Key -Setup
    }

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Provider setup command is unavailable after module import: $Command"
    }

    & $Command

}

Export-ModuleMember -Function Initialize-HALSAI, Initialize-OpenAI