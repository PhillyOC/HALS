#==========================================================
# HALS - AI Provider Initialization
# Version : 3.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

        $Result = Invoke-OpenAI `
            -Configuration $OpenAIConfiguration `
            -Prompt "Reply with exactly: HALSAI initialization successful."

        Write-Host ""
        Write-Host "OpenAI connection successful." -ForegroundColor Green
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

    Write-Host ""
    Write-Host "HALSAI provider setup" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] OpenAI" -ForegroundColor White
    Write-Host "  [2] Anthropic Claude" -ForegroundColor White
    Write-Host "  [3] Google Gemini" -ForegroundColor White
    Write-Host "  [4] Together AI" -ForegroundColor White
    Write-Host "  [5] Mistral" -ForegroundColor White
    Write-Host "  [6] Local Ollama" -ForegroundColor White
    Write-Host ""

    $Command = switch ((Read-Host "Choose a provider [1-6]").Trim()) {
        "1" { "Initialize-OpenAI" }
        "2" { "Initialize-HALSClaude" }
        "3" { "Initialize-HALSGemini" }
        "4" { "Initialize-HALSTogetherAI" }
        "5" { "Initialize-HALSMistral" }
        "6" { "Initialize-HALSOllama" }
        default { $null }
    }

    if (-not $Command) {
        Write-Host "Invalid provider selection." -ForegroundColor Yellow
        return $false
    }

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Provider setup command is unavailable: $Command"
    }

    & $Command

}

Export-ModuleMember -Function Initialize-HALSAI, Initialize-OpenAI