#==========================================================
# HALS - Ollama (Local) Provider
# Version : 1.1.0
#
# Ollama exposes an OpenAI-compatible chat completions
# endpoint on localhost:11434 by default.
# Docs : https://github.com/ollama/ollama/blob/main/docs/openai.md
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# List models available on a running Ollama instance
#----------------------------------------------------------

function Get-OllamaModels {

    param(
        [string]$BaseUrl = "http://localhost:11434"
    )

    try {

        $Response = Invoke-RestMethod `
            -Uri "$($BaseUrl.TrimEnd('/'))/api/tags" `
            -Method Get `
            -TimeoutSec 5

        if ($Response.PSObject.Properties["models"]) {
            return @($Response.models | Select-Object -ExpandProperty name)
        }

    }
    catch {
        # Ollama not running or unreachable - return empty
    }

    return @()

}

#----------------------------------------------------------
# Invoke
#----------------------------------------------------------

function Invoke-Ollama {

    param(

        [Parameter(Mandatory)]
        $Configuration,

        [Parameter(Mandatory)]
        [string]$Prompt

    )

    $BaseUrl = "http://localhost:11434"

    if ($Configuration.PSObject.Properties["BaseUrl"] -and
        -not [string]::IsNullOrWhiteSpace($Configuration.BaseUrl)) {
        $BaseUrl = $Configuration.BaseUrl.TrimEnd('/')
    }

    $TimeoutSec = 300
    if ($Configuration.PSObject.Properties["TimeoutSec"] -and $Configuration.TimeoutSec) {
        $TimeoutSec = [int]$Configuration.TimeoutSec
    }

    $Uri = "$BaseUrl/v1/chat/completions"

    $Headers = @{ "Content-Type" = "application/json" }

    if ($Configuration.PSObject.Properties["ApiKey"] -and
        -not [string]::IsNullOrWhiteSpace($Configuration.ApiKey)) {
        $Headers["Authorization"] = "Bearer $($Configuration.ApiKey)"
    }

    $Body = @{
        model    = $Configuration.Model
        messages = @(
            @{ role = "user"; content = $Prompt }
        )
        temperature = 0.2
    } | ConvertTo-Json -Depth 10

    try {

        $Response = Invoke-RestMethod `
            -Method Post `
            -Uri $Uri `
            -Headers $Headers `
            -Body $Body `
            -TimeoutSec $TimeoutSec

    }
    catch [System.Threading.Tasks.TaskCanceledException] {

        throw "Ollama did not respond within $TimeoutSec seconds. Try a smaller model or increase Ollama.TimeoutSec in Config\AI.json."

    }
    catch [System.Net.Http.HttpRequestException] {

        throw "Could not reach Ollama at $BaseUrl. Is the Ollama service running? Start it with 'ollama serve' or the Ollama desktop app."

    }
    catch {

        #
        # Catch model-not-found and other API errors with a clear message.
        # Ollama returns 404 when the model is not pulled.
        #

        $msg = $_.Exception.Message
        if ($msg -match "404|not found|model") {
            throw "Ollama model '$($Configuration.Model)' was not found. Run: ollama pull $($Configuration.Model)"
        }
        throw

    }

    if ($Response.PSObject.Properties["choices"] -and
        $Response.choices.Count -gt 0) {

        $Choice = $Response.choices[0]

        if ($Choice.PSObject.Properties["message"] -and
            $Choice.message.PSObject.Properties["content"]) {

            return $Choice.message.content

        }

    }

    throw "Ollama returned no text response."

}

Export-ModuleMember -Function Invoke-Ollama, Get-OllamaModels
