#==========================================================
# HALS - Google Gemini Setup Wizard
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-HALSGemini {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS GEMINI SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

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
    Write-Host "           [1] gemini-2.5-pro-preview-06-05    (most capable)" -ForegroundColor Gray
    Write-Host "           [2] gemini-2.5-flash-preview-05-20  (fast, efficient)" -ForegroundColor Gray
    Write-Host "           [3] gemini-2.0-flash                (stable, fast)" -ForegroundColor Gray
    Write-Host "           [4] Enter model name manually" -ForegroundColor Gray
    Write-Host ""

    do {

        $ModelChoice = (Read-Host "Choice [1-4]").Trim()

        $Model = switch ($ModelChoice) {
            "1" { "gemini-2.5-pro-preview-06-05"   }
            "2" { "gemini-2.5-flash-preview-05-20" }
            "3" { "gemini-2.0-flash"               }
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
    Write-Host "Step 3 : Testing connection to Gemini API..." -ForegroundColor Yellow
    Write-Host ""

    $TestConfig = [PSCustomObject]@{
        ApiKey = $ApiKey
        Model  = $Model
    }

    try {

        $Result = Invoke-Gemini `
            -Configuration $TestConfig `
            -Prompt "Reply with exactly: HALS Gemini initialization successful."

        Write-Host "Connection OK." -ForegroundColor Green
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
