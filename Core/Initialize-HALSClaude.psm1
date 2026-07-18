#==========================================================
# HALS - Claude API Setup Wizard
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-HALSClaude {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS CLAUDE SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Get-Command Resolve-HALSAIProviderCommand -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "AI\HALSAIProviderRegistry.psm1") -Force -Global
    }
    $null = Resolve-HALSAIProviderCommand -Provider Claude

    #------------------------------------------------------
    # Step 1 : API Key
    #------------------------------------------------------

    Write-Host "Step 1 : Get your Anthropic API key." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         If you don't have one yet:" -ForegroundColor Gray
    Write-Host "           https://console.anthropic.com/settings/keys" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "         Create a new key, copy it, and paste it below." -ForegroundColor Gray
    Write-Host "         Your key starts with: sk-ant-" -ForegroundColor Gray
    Write-Host ""

    do {

        $ApiKey = (Read-Host "Anthropic API Key").Trim()

        if ([string]::IsNullOrWhiteSpace($ApiKey)) {

            Write-Host "API key cannot be empty." -ForegroundColor Red

        }
        elseif (-not $ApiKey.StartsWith("sk-ant-")) {

            Write-Host "Warning: key doesn't start with 'sk-ant-' - double-check you copied the full key." -ForegroundColor Yellow
            $Confirm = (Read-Host "Use this key anyway? (Y/N)").Trim().ToUpper()
            if ($Confirm -eq "Y") { break }

        }
        else {

            break

        }

    } while ($true)

    #------------------------------------------------------
    # Step 2 : Model
    #------------------------------------------------------

    Write-Host ""
    Write-Host "Step 2 : Choose a Claude model." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Available models:" -ForegroundColor Gray
    Write-Host "           [1] claude-opus-4-5        (most capable)" -ForegroundColor Gray
    Write-Host "           [2] claude-sonnet-4-5      (balanced, recommended)" -ForegroundColor Gray
    Write-Host "           [3] claude-haiku-4-5       (fastest, lowest cost)" -ForegroundColor Gray
    Write-Host "           [4] claude-sonnet-3-7      (previous gen sonnet)" -ForegroundColor Gray
    Write-Host "           [5] Enter model name manually" -ForegroundColor Gray
    Write-Host ""

    do {

        $ModelChoice = (Read-Host "Choice [1-5]").Trim()

        $Model = switch ($ModelChoice) {
            "1" { "claude-opus-4-5"   }
            "2" { "claude-sonnet-4-5" }
            "3" { "claude-haiku-4-5"  }
            "4" { "claude-sonnet-3-7" }
            "5" {
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
    Write-Host "Step 3 : Testing connection to Anthropic API..." -ForegroundColor Yellow
    Write-Host ""

    $TestConfig = [PSCustomObject]@{
        ApiKey = $ApiKey
        Model  = $Model
    }

    try {

        $Result = Invoke-HALSAIProvider `
            -Provider Claude `
            -Configuration $TestConfig `
            -Prompt "Reply with exactly: HALS Claude initialization successful."

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
    # Step 4 : Save configuration
    #------------------------------------------------------

    $ConfigPath = "$(Get-HALSRoot)\Config\AI.json"

    $Existing = @{}

    if (Test-Path $ConfigPath) {

        $Existing = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable

    }

    $Existing["Claude"] = @{
        ApiKey = $ApiKey
        Model  = $Model
    }

    #------------------------------------------------------
    # Step 5 : Set as active provider?
    #------------------------------------------------------

    Write-Host "Step 4 : Set Claude as the active HALSAI provider?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Current provider: $($Existing['Provider'])" -ForegroundColor Gray
    Write-Host ""

    $SetActive = (Read-Host "Switch to Claude now? (Y/N)").Trim().ToUpper()

    if ($SetActive -eq "Y") {

        $Existing["Provider"] = "Claude"
        Write-Host ""
        Write-Host "Active provider set to Claude." -ForegroundColor Green

    }
    else {

        Write-Host ""
        Write-Host "Provider unchanged. To switch later, run:" -ForegroundColor Gray
        Write-Host "  Switch-HALSAIProvider -Provider Claude" -ForegroundColor Cyan

    }

    $Existing |
        ConvertTo-Json -Depth 10 |
        Set-Content $ConfigPath

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Claude setup complete." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Run Ask-HALSAI to use HALSAI with Claude." -ForegroundColor Green
    Write-Host ""

}

function Initialize-Claude { Initialize-HALSClaude }

Export-ModuleMember -Function Initialize-HALSClaude, Initialize-Claude

