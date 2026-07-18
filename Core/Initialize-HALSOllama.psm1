#==========================================================
# HALS - Ollama (Local) Setup Wizard
# Version : 1.1.0
#
# Ollama runs locally and exposes an OpenAI-compatible
# endpoint. No API key is required by default.
# Install : https://ollama.com/download
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-HALSOllama {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS OLLAMA SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Get-Command Resolve-HALSAIProviderCommand -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "AI\HALSAIProviderRegistry.psm1") -Force -Global
    }

    $GetModels = Resolve-HALSAIProviderCommand -Provider Ollama -RequiredCommand Get-OllamaModels
    $null = Resolve-HALSAIProviderCommand -Provider Ollama -RequiredCommand Invoke-Ollama

    #------------------------------------------------------
    # Step 1 : Base URL
    #------------------------------------------------------

    Write-Host "Step 1 : Where is Ollama running?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Default: http://localhost:11434" -ForegroundColor Gray
    Write-Host "         Press Enter to accept, or type a remote host URL." -ForegroundColor Gray
    Write-Host ""

    $BaseUrl = (Read-Host "Base URL [http://localhost:11434]").Trim()

    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        $BaseUrl = "http://localhost:11434"
    }

    $BaseUrl = $BaseUrl.TrimEnd('/')

    #------------------------------------------------------
    # Step 2 : Verify Ollama is reachable
    #------------------------------------------------------

    Write-Host ""
    Write-Host "Step 2 : Checking Ollama at $BaseUrl ..." -ForegroundColor Yellow

    $PulledModels = @(& $GetModels -BaseUrl $BaseUrl)

    if ($PulledModels.Count -eq 0) {

        Write-Host ""
        Write-Host "         Could not reach Ollama or no models are pulled." -ForegroundColor Red
        Write-Host "         Make sure Ollama is running:" -ForegroundColor Yellow
        Write-Host "           ollama serve" -ForegroundColor Cyan
        Write-Host "         Then pull at least one model:" -ForegroundColor Yellow
        Write-Host "           ollama pull llama3.1" -ForegroundColor Cyan
        Write-Host ""
        throw "Ollama not reachable or no models available at $BaseUrl."

    }

    Write-Host "         Ollama is running. Found $($PulledModels.Count) pulled model(s)." -ForegroundColor Green

    #------------------------------------------------------
    # Step 3 : API Key (optional)
    #------------------------------------------------------

    Write-Host ""
    Write-Host "Step 3 : API key (optional)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Ollama does not require a key by default." -ForegroundColor Gray
    Write-Host "         Press Enter to skip." -ForegroundColor Gray
    Write-Host ""

    $ApiKey = (Read-Host "API Key [leave blank]").Trim()

    #------------------------------------------------------
    # Step 4 : Model selection from live list
    #------------------------------------------------------

    Write-Host ""
    Write-Host "Step 4 : Choose a model." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Models currently pulled on this Ollama instance:" -ForegroundColor Gray
    Write-Host ""

    for ($i = 0; $i -lt $PulledModels.Count; $i++) {
        Write-Host ("           [$($i+1)] " + $PulledModels[$i]) -ForegroundColor Gray
    }

    $ManualOption = $PulledModels.Count + 1
    Write-Host ("           [$ManualOption] Enter model name manually") -ForegroundColor Gray
    Write-Host ""
    Write-Host "         To add more models: ollama pull <name>" -ForegroundColor DarkGray
    Write-Host "         Browse models at:   https://ollama.com/library" -ForegroundColor DarkGray
    Write-Host ""

    $Model = $null

    do {

        $Raw = (Read-Host "Choice [1-$ManualOption]").Trim()

        if ($Raw -match '^\d+$') {

            $Idx = [int]$Raw

            if ($Idx -ge 1 -and $Idx -le $PulledModels.Count) {

                $Model = $PulledModels[$Idx - 1]

            }
            elseif ($Idx -eq $ManualOption) {

                $Custom = (Read-Host "Model name (e.g. llama3.1:8b)").Trim()
                if (-not [string]::IsNullOrWhiteSpace($Custom)) {
                    $Model = $Custom
                }

            }

        }

        if ([string]::IsNullOrWhiteSpace($Model)) {
            Write-Host "Please choose a number between 1 and $ManualOption." -ForegroundColor Red
        }

    } until (-not [string]::IsNullOrWhiteSpace($Model))

    #------------------------------------------------------
    # Step 5 : Test connection
    #------------------------------------------------------

    Write-Host ""
    Write-Host "Step 5 : Testing $Model ..." -ForegroundColor Yellow
    Write-Host ""

    $TestConfig = [PSCustomObject]@{
        ApiKey  = $ApiKey
        Model   = $Model
        BaseUrl = $BaseUrl
    }

    try {

        $Result = Invoke-HALSAIProvider `
            -Provider Ollama `
            -Configuration $TestConfig `
            -Prompt "Reply with exactly: HALS Ollama initialization successful."

        Write-Host "Connection OK." -ForegroundColor Green
        Write-Host $Result.Trim() -ForegroundColor Cyan
        Write-Host ""

    }
    catch {

        Write-Host "Test failed:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""
        throw

    }

    #------------------------------------------------------
    # Step 6 : Save and optionally activate
    #------------------------------------------------------

    $ConfigPath = "$(Get-HALSRoot)\Config\AI.json"
    $Existing   = if (Test-Path $ConfigPath) {
        Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    }
    else { @{} }

    $Existing["Ollama"] = @{
        ApiKey  = $ApiKey
        Model   = $Model
        BaseUrl = $BaseUrl
        TimeoutSec = 300
    }

    Write-Host "Step 6 : Set Ollama as the active HALSAI provider?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Current provider: $($Existing['Provider'])" -ForegroundColor Gray
    Write-Host ""

    $SetActive = (Read-Host "Switch to Ollama now? (Y/N)").Trim().ToUpper()

    if ($SetActive -eq "Y") {
        $Existing["Provider"] = "Ollama"
        Write-Host ""
        Write-Host "Active provider set to Ollama  [$Model]." -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "To switch later: Switch-HALSAIProvider -Provider Ollama" -ForegroundColor Cyan
    }

    $Existing | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Ollama setup complete." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Run Ask-HALSAI to use HALSAI with $Model." -ForegroundColor Green
    Write-Host ""

}

function Initialize-Ollama { Initialize-HALSOllama }

Export-ModuleMember -Function Initialize-HALSOllama, Initialize-Ollama

