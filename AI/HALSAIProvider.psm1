#==========================================================
# HALS - AI Provider Switcher
# Version : 3.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Switch-HALSAIProvider {

    param(

        [Parameter(Mandatory)]
        [ValidateSet("OpenAI","Claude","Gemini","TogetherAI","Mistral","Ollama")]
        [string]$Provider

    )

    $ConfigPath = "$(Get-HALSRoot)\Config\AI.json"

    if (-not (Test-Path $ConfigPath)) {
        throw "AI configuration not found. Run a provider setup wizard first."
    }

    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    $Section = $Config.($Provider)

    $SetupCommand = @{
        "OpenAI"     = "Initialize-OpenAI"
        "Claude"     = "Initialize-HALSClaude"
        "Gemini"     = "Initialize-HALSGemini"
        "TogetherAI" = "Initialize-HALSTogetherAI"
        "Mistral"    = "Initialize-HALSMistral"
        "Ollama"     = "Initialize-HALSOllama"
    }

    $HasKey = $Section -and
              $Section.PSObject.Properties["ApiKey"] -and
              -not [string]::IsNullOrWhiteSpace($Section.ApiKey)

    $HasModel = $Section -and
                $Section.PSObject.Properties["Model"] -and
                -not [string]::IsNullOrWhiteSpace($Section.Model)

    if ($Provider -eq "Ollama") {
        if (-not $HasModel) {
            throw "$Provider is not configured. Run $($SetupCommand[$Provider]) first."
        }
    }
    else {
        if (-not $HasKey) {
            throw "$Provider is not configured. Run $($SetupCommand[$Provider]) first."
        }
    }

    $Previous           = $Config.Provider
    $Config.Provider    = $Provider

    $Config |
        ConvertTo-Json -Depth 10 |
        Set-Content $ConfigPath

    $ModelInfo = ""
    if ($HasModel) {
        $ModelInfo = "  [$($Section.Model)]"
    }

    Write-Host ""
    Write-Host "AI provider switched:" -ForegroundColor Cyan
    Write-Host ("  " + $Previous.PadRight(14) + "->  $Provider$ModelInfo") -ForegroundColor Green
    Write-Host ""
    Write-Host "Ask-HALSAI will now use $Provider." -ForegroundColor Green
    Write-Host ""

}

Export-ModuleMember -Function Switch-HALSAIProvider
