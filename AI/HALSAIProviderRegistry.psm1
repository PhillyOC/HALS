#==========================================================
# HALS - AI Provider Registry
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script:HALSAIProviders = @(
    [PSCustomObject]@{
        Key            = "OpenAI"
        Name           = "OpenAI"
        InvokeCommand  = "Invoke-OpenAI"
        SetupCommand   = "Initialize-OpenAI"
        ModulePath     = "AI\Providers\OpenAI.psm1"
        SetupModule    = "AI\Initialize-HALSAI.psm1"
        RequiresApiKey = $true
    }
    [PSCustomObject]@{
        Key            = "Claude"
        Name           = "Anthropic Claude"
        InvokeCommand  = "Invoke-Claude"
        SetupCommand   = "Initialize-Claude"
        ModulePath     = "AI\Providers\Claude.psm1"
        SetupModule    = "Core\Initialize-HALSClaude.psm1"
        RequiresApiKey = $true
    }
    [PSCustomObject]@{
        Key            = "Gemini"
        Name           = "Google Gemini"
        InvokeCommand  = "Invoke-Gemini"
        SetupCommand   = "Initialize-Gemini"
        ModulePath     = "AI\Providers\Gemini.psm1"
        SetupModule    = "Core\Initialize-HALSGemini.psm1"
        RequiresApiKey = $true
    }
    [PSCustomObject]@{
        Key            = "TogetherAI"
        Name           = "Together AI"
        InvokeCommand  = "Invoke-TogetherAI"
        SetupCommand   = "Initialize-TogetherAI"
        ModulePath     = "AI\Providers\TogetherAI.psm1"
        SetupModule    = "Core\Initialize-HALSTogetherAI.psm1"
        RequiresApiKey = $true
    }
    [PSCustomObject]@{
        Key            = "Mistral"
        Name           = "Mistral"
        InvokeCommand  = "Invoke-Mistral"
        SetupCommand   = "Initialize-Mistral"
        ModulePath     = "AI\Providers\Mistral.psm1"
        SetupModule    = "Core\Initialize-HALSMistral.psm1"
        RequiresApiKey = $true
    }
    [PSCustomObject]@{
        Key            = "Ollama"
        Name           = "Local / Ollama"
        InvokeCommand  = "Invoke-Ollama"
        SetupCommand   = "Initialize-Ollama"
        ModulePath     = "AI\Providers\Ollama.psm1"
        SetupModule    = "Core\Initialize-HALSOllama.psm1"
        RequiresApiKey = $false
    }
)

function Get-HALSAIProviderRegistry {

    return @($Script:HALSAIProviders)

}

function Get-HALSRegisteredAIProviders {

    return Get-HALSAIProviderRegistry

}

function Get-HALSAIProvider {

    param(
        [Parameter(Mandatory)]
        [string]$Provider
    )

    $Match = $Script:HALSAIProviders |
        Where-Object { $_.Key -ieq $Provider } |
        Select-Object -First 1

    if (-not $Match) {
        $ValidProviders = ($Script:HALSAIProviders.Key -join ", ")
        throw "Unsupported AI provider: '$Provider'. Valid values: $ValidProviders."
    }

    return $Match

}

function Import-HALSAIConfiguration {

    param(
        [switch]$Optional
    )

    $Path = "$(Get-HALSRoot)\Config\AI.json"

    if (-not (Test-Path -LiteralPath $Path)) {
        if ($Optional) {
            return $null
        }

        throw "AI configuration file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json

}

function Test-HALSAIProviderConfigured {

    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        $Configuration
    )

    $ProviderMetadata = Get-HALSAIProvider -Provider $Provider
    $Section = if ($Configuration.PSObject.Properties[$ProviderMetadata.Key]) {
        $Configuration.($ProviderMetadata.Key)
    }
    else {
        $Configuration
    }

    if (-not $Section) {
        return $false
    }

    $HasModel = $Section.PSObject.Properties["Model"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Section.Model)

    if (-not $HasModel) {
        return $false
    }

    if (-not $ProviderMetadata.RequiresApiKey) {
        return $true
    }

    return [bool](
        $Section.PSObject.Properties["ApiKey"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Section.ApiKey)
    )

}

function Import-HALSAIProvider {

    param(
        [Parameter(Mandatory)][string]$Provider,
        [switch]$Setup
    )

    $ProviderMetadata = Get-HALSAIProvider -Provider $Provider
    $Paths = @($ProviderMetadata.ModulePath)
    if ($Setup -and $ProviderMetadata.SetupModule -ne $ProviderMetadata.ModulePath) {
        $Paths += $ProviderMetadata.SetupModule
    }

    foreach ($RelativePath in $Paths) {
        $Path = Join-Path (Get-HALSRoot) $RelativePath
        if (-not (Test-Path $Path)) {
            throw "AI provider module not found: $Path"
        }

        Import-Module $Path -Force -Global
    }
}

function Invoke-HALSAIProvider {

    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        $Configuration,

        [Parameter(Mandatory)]
        [string]$Prompt
    )

    $ProviderMetadata = Get-HALSAIProvider -Provider $Provider
    $ProviderConfiguration = if ($Configuration.PSObject.Properties[$ProviderMetadata.Key]) {
        $Configuration.($ProviderMetadata.Key)
    }
    else {
        $Configuration
    }

    if (-not (Test-HALSAIProviderConfigured -Provider $ProviderMetadata.Key -Configuration $ProviderConfiguration)) {
        throw "$($ProviderMetadata.Name) is not configured. Run $($ProviderMetadata.SetupCommand)."
    }

    if (-not (Get-Command $ProviderMetadata.InvokeCommand -ErrorAction SilentlyContinue)) {
        Import-HALSAIProvider -Provider $ProviderMetadata.Key
    }

    if (-not (Get-Command $ProviderMetadata.InvokeCommand -ErrorAction SilentlyContinue)) {
        throw "AI provider invoke command is unavailable after module import: $($ProviderMetadata.InvokeCommand)"
    }

    return & $ProviderMetadata.InvokeCommand `
        -Configuration $ProviderConfiguration `
        -Prompt $Prompt

}

function Send-HALSAIProviderInitialization {

    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        $Configuration
    )

    if (-not (Get-Command New-HALSAIProviderInitializationPrompt -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "AI\HALSAIPrompt.psm1") -Force
    }

    $Prompt = New-HALSAIProviderInitializationPrompt

    return Invoke-HALSAIProvider `
        -Provider $Provider `
        -Configuration $Configuration `
        -Prompt $Prompt

}

Export-ModuleMember -Function Get-HALSAIProviderRegistry,
                              Get-HALSRegisteredAIProviders,
                              Get-HALSAIProvider,
                              Import-HALSAIConfiguration,
                              Test-HALSAIProviderConfigured,
                              Import-HALSAIProvider,
                              Invoke-HALSAIProvider,
                              Send-HALSAIProviderInitialization
