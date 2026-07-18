#==========================================================
# HALS - Google Gemini Setup Wizard
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Format-HALSAIProviderError -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path (Get-HALSRoot) "AI\HALSAIProviderRegistry.psm1") -Force -Global
}

function Initialize-HALSGemini {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS GEMINI SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Get-Command Invoke-Gemini -ErrorAction SilentlyContinue)) {
        if (Get-Command Import-HALSAIProvider -ErrorAction SilentlyContinue) {
            Import-HALSAIProvider -Provider Gemini
        }
        else {
            Import-Module (Join-Path (Get-HALSRoot) "AI\Providers\Gemini.psm1") -Force -Global
        }
    }

    #------------------------------------------------------
    # Step 1 : API Key
    #------------------------------------------------------

    Write-Host "Step 1 : Get your Google Gemini API key." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Generate a key at Google AI Studio:" -ForegroundColor Gray
    Write-Host "           https://aistudio.google.com/app/apikey" -ForegroundColor Cyan
    Write-Host ""

    do {

        $ApiKey = (Read-Host "Gemini API Key").Trim()

        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            Write-Host "API key cannot be empty." -ForegroundColor Red
        }

    } while ([string]::IsNullOrWhiteSpace($ApiKey))

    #------------------------------------------------------
    # Step 2 : Model
    #------------------------------------------------------

    Write-Host ""
    Write-Host "Step 2 : Choose a Gemini model." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Available models:" -ForegroundColor Gray
    Write-Host "           [1] gemini-2.5-pro          (most capable)" -ForegroundColor Gray
    Write-Host "           [2] gemini-2.5-flash        (fast, efficient)" -ForegroundColor Gray
    Write-Host "           [3] gemini-2.0-flash        (stable, fast)" -ForegroundColor Gray
    Write-Host "           [4] Enter model name manually" -ForegroundColor Gray
    Write-Host ""

    do {

        $ModelChoice = (Read-Host "Choice [1-4]").Trim()

        $Model = switch ($ModelChoice) {
            "1" { "gemini-2.5-pro"   }
            "2" { "gemini-2.5-flash" }
            "3" { "gemini-2.0-flash" }
            "4" {
                $Custom = (Read-Host "Model name").Trim()
                if ([string]::IsNullOrWhiteSpace($Custom)) { $null } else { $Custom }
            }
            default { $null }
        }

    } until (-not [string]::IsNullOrWhiteSpace($Model))

    #------------------------------------------------------
    # Step 3 : Test connection
    #------------------------------------------------------

    Write-Host ""
    Write-Host "Step 3 : Sending HALSAI system prompt and testing connection..." -ForegroundColor Yellow
    Write-Host ""

    $TestConfig = [PSCustomObject]@{
        ApiKey = $ApiKey
        Model  = $Model
    }

    try {

        $Result = Send-HALSAIProviderInitialization `
            -Provider Gemini `
            -Configuration $TestConfig

        Write-Host "Connection OK. HALSAI system prompt accepted." -ForegroundColor Green
        Write-Host $Result -ForegroundColor Cyan
        Write-Host ""

    }
    catch {

        Write-Host "Connection failed:" -ForegroundColor Red
        Write-Host (Format-HALSAIProviderError -ErrorRecord $_) -ForegroundColor Yellow
        Write-Host ""
        Write-Host "If the error mentions SERVICE_DISABLED, enable the Gemini API in Google Cloud Console," -ForegroundColor Yellow
        Write-Host "then wait a few minutes and try again." -ForegroundColor Yellow
        throw

    }

    #------------------------------------------------------
    # Step 4 : Save and optionally activate
    #------------------------------------------------------

    $ConfigPath = "$(Get-HALSRoot)\Config\AI.json"
    $ConfigDirectory = Split-Path -Parent $ConfigPath
    $Existing   = if (Test-Path $ConfigPath) {
        Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    } else { @{} }

    $Existing["Gemini"] = @{
        ApiKey = $ApiKey
        Model  = $Model
    }

    Write-Host "Step 4 : Set Gemini as the active HALSAI provider?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Current provider: $($Existing['Provider'])" -ForegroundColor Gray
    Write-Host ""

    $SetActive = (Read-Host "Switch to Gemini now? (Y/N)").Trim().ToUpper()

    if ($SetActive -eq "Y") {
        $Existing["Provider"] = "Gemini"
        Write-Host ""
        Write-Host "Active provider set to Gemini." -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "To switch later: Switch-HALSAIProvider -Provider Gemini" -ForegroundColor Cyan
    }

    if (-not (Test-Path $ConfigDirectory)) {
        $null = New-Item -ItemType Directory -Path $ConfigDirectory -Force
    }

    $Existing | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Gemini setup complete." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Run Ask-HALSAI to use HALSAI with Gemini." -ForegroundColor Green
    Write-Host ""

}

function Initialize-Gemini { Initialize-HALSGemini }

Export-ModuleMember -Function Initialize-HALSGemini, Initialize-Gemini
