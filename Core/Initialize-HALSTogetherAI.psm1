#==========================================================
# HALS - Together AI Setup Wizard
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-HALSTogetherAI {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS TOGETHER AI SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    #------------------------------------------------------
    # Step 1 : API Key
    #------------------------------------------------------

    Write-Host "Step 1 : Get your Together AI API key." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Sign up and generate a key at:" -ForegroundColor Gray
    Write-Host "           https://api.together.xyz/settings/api-keys" -ForegroundColor Cyan
    Write-Host ""

    do {

        $ApiKey = (Read-Host "Together AI API Key").Trim()

        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            Write-Host "API key cannot be empty." -ForegroundColor Red
        }

    } while ([string]::IsNullOrWhiteSpace($ApiKey))

    #------------------------------------------------------
    # Step 2 : Model
    #------------------------------------------------------

    Write-Host ""
    Write-Host "Step 2 : Choose a model." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Popular models on Together AI:" -ForegroundColor Gray
    Write-Host "           [1] meta-llama/Llama-3.3-70B-Instruct-Turbo      (recommended)" -ForegroundColor Gray
    Write-Host "           [2] meta-llama/Llama-3.2-3B-Instruct-Turbo      (fast, low cost)" -ForegroundColor Gray
    Write-Host "           [3] Qwen/Qwen3-235B-A22B-fp8-tput                (Qwen3 flagship)" -ForegroundColor Gray
    Write-Host "           [4] deepseek-ai/DeepSeek-V3                      (strong reasoning)" -ForegroundColor Gray
    Write-Host "           [5] google/gemma-3-27b-it                        (Google Gemma 3)" -ForegroundColor Gray
    Write-Host "           [6] Enter model name manually" -ForegroundColor Gray
    Write-Host ""
    Write-Host "         Full model list: https://docs.together.ai/docs/serverless-models" -ForegroundColor DarkGray
    Write-Host ""

    do {

        $ModelChoice = (Read-Host "Choice [1-6]").Trim()

        $Model = switch ($ModelChoice) {
            "1" { "meta-llama/Llama-3.3-70B-Instruct-Turbo"   }
            "2" { "meta-llama/Llama-3.2-3B-Instruct-Turbo"    }
            "3" { "Qwen/Qwen3-235B-A22B-fp8-tput"             }
            "4" { "deepseek-ai/DeepSeek-V3"                   }
            "5" { "google/gemma-3-27b-it"                     }
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
    Write-Host "Step 3 : Testing connection to Together AI..." -ForegroundColor Yellow
    Write-Host ""

    $TestConfig = [PSCustomObject]@{
        ApiKey = $ApiKey
        Model  = $Model
    }

    try {

        $Result = Invoke-TogetherAI `
            -Configuration $TestConfig `
            -Prompt "Reply with exactly: HALS Together AI initialization successful."

        Write-Host "Connection OK." -ForegroundColor Green
        Write-Host $Result -ForegroundColor Cyan
        Write-Host ""

    }
    catch {

        Write-Host "Connection failed:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Check your API key and model name, then try again." -ForegroundColor Yellow
        throw

    }

    #------------------------------------------------------
    # Step 4 : Save and optionally activate
    #------------------------------------------------------

    $ConfigPath = "$(Get-HALSRoot)\Config\AI.json"
    $Existing   = if (Test-Path $ConfigPath) {
        Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    } else { @{} }

    $Existing["TogetherAI"] = @{
        ApiKey = $ApiKey
        Model  = $Model
    }

    Write-Host "Step 4 : Set Together AI as the active HALSAI provider?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Current provider: $($Existing['Provider'])" -ForegroundColor Gray
    Write-Host ""

    $SetActive = (Read-Host "Switch to Together AI now? (Y/N)").Trim().ToUpper()

    if ($SetActive -eq "Y") {
        $Existing["Provider"] = "TogetherAI"
        Write-Host ""
        Write-Host "Active provider set to Together AI." -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "To switch later: Switch-HALSAIProvider -Provider TogetherAI" -ForegroundColor Cyan
    }

    $Existing | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Together AI setup complete." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Run Ask-HALSAI to use HALSAI with Together AI." -ForegroundColor Green
    Write-Host ""

}

Export-ModuleMember -Function Initialize-HALSTogetherAI
