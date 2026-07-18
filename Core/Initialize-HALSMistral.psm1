#==========================================================
# HALS - Mistral AI Setup Wizard
# Version : 1.0.0
#
# Mistral uses an OpenAI-compatible chat completions
# endpoint. Generate a key at https://console.mistral.ai/
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-HALSMistral {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS MISTRAL AI SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Get-Command Invoke-Mistral -ErrorAction SilentlyContinue)) {
        if (Get-Command Import-HALSAIProvider -ErrorAction SilentlyContinue) {
            Import-HALSAIProvider -Provider Mistral
        }
        else {
            Import-Module (Join-Path (Get-HALSRoot) "AI\Providers\Mistral.psm1") -Force -Global
        }
    }

    #------------------------------------------------------
    # Step 1 : API Key
    #------------------------------------------------------

    Write-Host "Step 1 : Get your Mistral API key." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Sign in to La Plateforme and create a key:" -ForegroundColor Gray
    Write-Host "           https://console.mistral.ai/api-keys/" -ForegroundColor Cyan
    Write-Host ""

    do {

        $ApiKey = (Read-Host "Mistral API Key").Trim()

        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            Write-Host "API key cannot be empty." -ForegroundColor Red
        }

    } while ([string]::IsNullOrWhiteSpace($ApiKey))

    #------------------------------------------------------
    # Step 2 : Model
    #------------------------------------------------------

    Write-Host ""
    Write-Host "Step 2 : Choose a Mistral model." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Available models:" -ForegroundColor Gray
    Write-Host "           [1] mistral-large-latest    (most capable)" -ForegroundColor Gray
    Write-Host "           [2] mistral-small-latest    (fast, low cost)" -ForegroundColor Gray
    Write-Host "           [3] codestral-latest         (code specialist)" -ForegroundColor Gray
    Write-Host "           [4] magistral-medium-latest  (reasoning)" -ForegroundColor Gray
    Write-Host "           [5] devstral-latest          (agent/dev tasks)" -ForegroundColor Gray
    Write-Host "           [6] Enter model name manually" -ForegroundColor Gray
    Write-Host ""

    do {

        $ModelChoice = (Read-Host "Choice [1-6]").Trim()

        $Model = switch ($ModelChoice) {
            "1" { "mistral-large-latest"   }
            "2" { "mistral-small-latest"   }
            "3" { "codestral-latest"       }
            "4" { "magistral-medium-latest"}
            "5" { "devstral-latest"        }
            "6" {
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
            -Provider Mistral `
            -Configuration $TestConfig

        Write-Host "Connection OK. HALSAI system prompt accepted." -ForegroundColor Green
        Write-Host $Result -ForegroundColor Cyan
        Write-Host ""

    }
    catch {

        Write-Host "Connection failed:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Check your API key and try again." -ForegroundColor Yellow
        throw

    }

    #------------------------------------------------------
    # Step 4 : Save and optionally activate
    #------------------------------------------------------

    $ConfigPath = "$(Get-HALSRoot)\Config\AI.json"
    $Existing   = if (Test-Path $ConfigPath) {
        Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    } else { @{} }

    $Existing["Mistral"] = @{
        ApiKey = $ApiKey
        Model  = $Model
    }

    Write-Host "Step 4 : Set Mistral as the active HALSAI provider?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Current provider: $($Existing['Provider'])" -ForegroundColor Gray
    Write-Host ""

    $SetActive = (Read-Host "Switch to Mistral now? (Y/N)").Trim().ToUpper()

    if ($SetActive -eq "Y") {
        $Existing["Provider"] = "Mistral"
        Write-Host ""
        Write-Host "Active provider set to Mistral." -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "To switch later: Switch-HALSAIProvider -Provider Mistral" -ForegroundColor Cyan
    }

    $Existing | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Mistral setup complete." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Run Ask-HALSAI to use HALSAI with Mistral." -ForegroundColor Green
    Write-Host ""

}

function Initialize-Mistral { Initialize-HALSMistral }

Export-ModuleMember -Function Initialize-HALSMistral, Initialize-Mistral
