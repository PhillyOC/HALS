#==========================================================
# HALS - Google Gemini Setup Wizard
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSGeminiSetupModels {

    param(
        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    $Preferred = @(
        "gemini-2.5-flash",
        "gemini-2.5-pro",
        "gemini-2.0-flash"
    )

    $Available = @(Get-GeminiModels -ApiKey $ApiKey)

    if ($Available.Count -eq 0) {
        return @($Preferred)
    }

    $Sorted = @()

    foreach ($Model in $Preferred) {
        if ($Available -contains $Model) {
            $Sorted += $Model
        }
    }

    foreach ($Model in ($Available | Sort-Object)) {
        if ($Sorted -notcontains $Model) {
            $Sorted += $Model
        }
    }

    return @($Sorted)

}

function Write-HALSGeminiConnectionError {

    param(
        [Parameter(Mandatory)]
        $ErrorRecord
    )

    $Message = if (Get-Command Get-GeminiErrorMessage -ErrorAction SilentlyContinue) {
        Get-GeminiErrorMessage -ErrorRecord $ErrorRecord
    }
    else {
        $ErrorRecord.Exception.Message
    }

    Write-Host "Connection failed:" -ForegroundColor Red
    Write-Host $Message -ForegroundColor Yellow
    Write-Host ""

    if ($Message -match 'not found|NOT_FOUND|404') {
        Write-Host "That model name is not available for your API key." -ForegroundColor Yellow
        Write-Host "Run Initialize-HALSGemini again and pick a model from the live list." -ForegroundColor Yellow
    }
    elseif ($Message -match 'depleted|RESOURCE_EXHAUSTED|429|quota|billing') {
        Write-Host "Your Google AI project needs billing or quota restored." -ForegroundColor Yellow
        Write-Host "Manage it at https://aistudio.google.com/app/apikey" -ForegroundColor Cyan
    }
    else {
        Write-Host "Check your API key and try again." -ForegroundColor Yellow
    }

}

function Initialize-HALSGemini {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS GEMINI SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Get-Command Resolve-HALSAIProviderCommand -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "AI\HALSAIProviderRegistry.psm1") -Force -Global
    }

    $GetModels = Resolve-HALSAIProviderCommand -Provider Gemini -RequiredCommand Get-GeminiModels
    $null = Resolve-HALSAIProviderCommand -Provider Gemini

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

    $Models = @(Get-HALSGeminiSetupModels -ApiKey $ApiKey)
    $ManualOption = $Models.Count + 1

    if ($Models.Count -gt 0) {
        Write-Host "         Models available to your API key:" -ForegroundColor Gray
        for ($Index = 0; $Index -lt $Models.Count; $Index++) {
            Write-Host "           [$($Index + 1)] $($Models[$Index])" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "         Could not load the live model list. Using common defaults:" -ForegroundColor DarkYellow
        $Models = @("gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash")
        $ManualOption = $Models.Count + 1
        for ($Index = 0; $Index -lt $Models.Count; $Index++) {
            Write-Host "           [$($Index + 1)] $($Models[$Index])" -ForegroundColor Gray
        }
    }

    Write-Host "           [$ManualOption] Enter model name manually" -ForegroundColor Gray
    Write-Host ""

    do {

        $ModelChoice = (Read-Host "Choice [1-$ManualOption]").Trim()
        $Model = $null

        if ($ModelChoice -match '^\d+$') {

            $Idx = [int]$ModelChoice

            if ($Idx -ge 1 -and $Idx -le $Models.Count) {
                $Model = $Models[$Idx - 1]
            }
            elseif ($Idx -eq $ManualOption) {
                $Custom = (Read-Host "Model name").Trim()
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

        $Result = Invoke-HALSAIProvider `
            -Provider Gemini `
            -Configuration $TestConfig `
            -Prompt "Reply with exactly: HALS Gemini initialization successful."

        Write-Host "Connection OK." -ForegroundColor Green
        Write-Host $Result -ForegroundColor Cyan
        Write-Host ""

    }
    catch {

        Write-HALSGeminiConnectionError -ErrorRecord $_
        return

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
        Write-Host "Active provider set to Gemini  [$Model]." -ForegroundColor Green
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
