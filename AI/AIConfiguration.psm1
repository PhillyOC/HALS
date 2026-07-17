#==========================================================
# HALS - AI Configuration
# Version : 4.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSAIConfiguration {

    $Path = "$(Get-HALSRoot)\Config\AI.json"

    if (-not (Test-Path $Path)) {
        throw "AI configuration file not found: $Path"
    }

    $Configuration = Get-Content -Path $Path -Raw | ConvertFrom-Json

    if (-not $Configuration.Provider) {
        throw "AI configuration is missing the Provider property."
    }

    switch ($Configuration.Provider) {

        "OpenAI" {

            if (-not $Configuration.OpenAI) {
                throw "OpenAI configuration section missing. Run Initialize-OpenAI."
            }
            if (-not $Configuration.OpenAI.ApiKey) {
                throw "OpenAI ApiKey missing. Run Initialize-OpenAI."
            }
            if (-not $Configuration.OpenAI.Model) {
                throw "OpenAI Model missing. Run Initialize-OpenAI."
            }

        }

        "Claude" {

            if (-not $Configuration.Claude) {
                throw "Claude configuration section missing. Run Initialize-HALSClaude."
            }
            if (-not $Configuration.Claude.ApiKey) {
                throw "Claude ApiKey missing. Run Initialize-HALSClaude."
            }
            if (-not $Configuration.Claude.Model) {
                throw "Claude Model missing. Run Initialize-HALSClaude."
            }

        }

        "Gemini" {

            if (-not $Configuration.Gemini) {
                throw "Gemini configuration section missing. Run Initialize-HALSGemini."
            }
            if (-not $Configuration.Gemini.ApiKey) {
                throw "Gemini ApiKey missing. Run Initialize-HALSGemini."
            }
            if (-not $Configuration.Gemini.Model) {
                throw "Gemini Model missing. Run Initialize-HALSGemini."
            }

        }

        "TogetherAI" {

            if (-not $Configuration.TogetherAI) {
                throw "TogetherAI configuration section missing. Run Initialize-HALSTogetherAI."
            }
            if (-not $Configuration.TogetherAI.ApiKey) {
                throw "TogetherAI ApiKey missing. Run Initialize-HALSTogetherAI."
            }
            if (-not $Configuration.TogetherAI.Model) {
                throw "TogetherAI Model missing. Run Initialize-HALSTogetherAI."
            }

        }

        "Mistral" {

            if (-not $Configuration.Mistral) {
                throw "Mistral configuration section missing. Run Initialize-HALSMistral."
            }
            if (-not $Configuration.Mistral.ApiKey) {
                throw "Mistral ApiKey missing. Run Initialize-HALSMistral."
            }
            if (-not $Configuration.Mistral.Model) {
                throw "Mistral Model missing. Run Initialize-HALSMistral."
            }

        }

        "Ollama" {

            if (-not $Configuration.Ollama) {
                throw "Ollama configuration section missing. Run Initialize-HALSOllama."
            }
            if (-not $Configuration.Ollama.Model) {
                throw "Ollama Model missing. Run Initialize-HALSOllama."
            }

        }

        default {

            throw "Unsupported AI Provider: '$($Configuration.Provider)'. Valid values: OpenAI, Claude, Gemini, TogetherAI, Mistral, Ollama."

        }

    }

    return $Configuration

}

Export-ModuleMember -Function Get-HALSAIConfiguration
