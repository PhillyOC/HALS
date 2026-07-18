#==========================================================
# HALS - AI Provider Initialization
# Version : 3.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Get-HALSAIProviderRegistry -ErrorAction SilentlyContinue)) {
    Import-Module "$(Get-HALSRoot)\AI\HALSAIProviderRegistry.psm1" -Global
}

function Initialize-OpenAI {

    $ConfigPath = "$(Get-HALSRoot)\Config\AI.json"
    $ConfigDirectory = Split-Path -Parent $ConfigPath

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS OPENAI SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Get-Command Invoke-OpenAI -ErrorAction SilentlyContinue)) {
        if (Get-Command Import-HALSAIProvider -ErrorAction SilentlyContinue) {
            Import-HALSAIProvider -Provider OpenAI -Setup
        }
        else {
            Import-Module (Join-Path (Get-HALSRoot) "AI\Providers\OpenAI.psm1") -Force -Global
        }
    }

    Write-Host "Step 1 : Get your OpenAI API key." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Create a key at:" -ForegroundColor Gray
    Write-Host "           https://platform.openai.com/api-keys" -ForegroundColor Cyan
    Write-Host ""

    do {
        $ApiKey = Get-HALSSanitizedSecret -Value (Read-Host "OpenAI API Key" -MaskInput)
        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            Write-Host "API key cannot be empty." -ForegroundColor Red
        }
    } while ([string]::IsNullOrWhiteSpace($ApiKey))

    Write-Host ""
    Write-Host "Step 2 : Choose an OpenAI model." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Enter the model name exactly (for example gpt-5.6)." -ForegroundColor Gray
    Write-Host "         Press Enter to use the default model." -ForegroundColor Gray
    Write-Host ""

    do {
        $Model = (Read-Host "OpenAI model [gpt-5.5]").Trim()
        if ([string]::IsNullOrWhiteSpace($Model)) {
            $Model = "gpt-5.5"
            break
        }

        if ($Model -match '^\d+$') {
            Write-Host "That looks like a menu number, not a model name." -ForegroundColor Yellow
            Write-Host "Type the model name itself (for example gpt-5.6) or press Enter for the default." -ForegroundColor Gray
            $Model = $null
        }
    } while ([string]::IsNullOrWhiteSpace($Model))

    $OpenAIConfiguration = [PSCustomObject]@{
        ApiKey = $ApiKey
        Model  = $Model
    }

    Write-Host ""
    Write-Host "Step 3 : Sending HALSAI system prompt and testing connection..." -ForegroundColor Yellow
    Write-Host ""

    try {

        $Result = Send-HALSAIProviderInitialization `
            -Provider OpenAI `
            -Configuration $OpenAIConfiguration

        Write-Host "Connection OK. HALSAI system prompt accepted." -ForegroundColor Green
        Write-Host $Result -ForegroundColor Cyan
        Write-Host ""

    }
    catch {

        Write-Host "OpenAI initialization failed." -ForegroundColor Red
        Write-Host (Format-HALSAIProviderError -ErrorRecord $_) -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Check the API key and model name, then try again." -ForegroundColor Yellow
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

    $CurrentProvider = [string]$Existing["Provider"]
    $HasActiveProvider = -not [string]::IsNullOrWhiteSpace($CurrentProvider)

    Write-Host "Step 4 : Set OpenAI as the active HALSAI provider?" -ForegroundColor Yellow
    Write-Host ""

    if ($HasActiveProvider) {
        Write-Host "         Current provider: $CurrentProvider" -ForegroundColor Gray
        Write-Host ""
    }

    if (-not $HasActiveProvider -or
        (Read-Host "Switch to OpenAI now? (Y/N)").Trim().ToUpper() -eq "Y") {
        $Existing["Provider"] = "OpenAI"
        Write-Host ""
        Write-Host "Active provider set to OpenAI  [$Model]." -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "Provider unchanged. To switch later, run:" -ForegroundColor Gray
        Write-Host "  Switch-HALSAIProvider -Provider OpenAI" -ForegroundColor Cyan
    }

    if (-not (Test-Path $ConfigDirectory)) {
        $null = New-Item -ItemType Directory -Path $ConfigDirectory -Force
    }

    $Existing |
        ConvertTo-Json -Depth 10 |
        Set-Content $ConfigPath

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " OpenAI setup complete." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Run Ask-HALSAI to use HALSAI with OpenAI." -ForegroundColor Green
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
