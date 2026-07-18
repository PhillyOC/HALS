#==========================================================
# HALS - Google Gemini Provider
# Version : 1.1.0
#
# Uses the Gemini API (generateContent endpoint).
# Docs : https://ai.google.dev/api/generate-content
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-GeminiErrorMessage {

    param(
        [Parameter(Mandatory)]
        $ErrorRecord
    )

    $Message = $ErrorRecord.Exception.Message

    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
        try {
            $Body = $ErrorRecord.ErrorDetails.Message | ConvertFrom-Json
            if ($Body.error.message) {
                return [string]$Body.error.message
            }
        }
        catch {
            # Fall back to the exception message.
        }
    }

    return $Message

}

function Get-GeminiModels {

    param(
        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    try {

        $Uri = "https://generativelanguage.googleapis.com/v1beta/models?key=$ApiKey"

        $Response = Invoke-RestMethod `
            -Method Get `
            -Uri $Uri `
            -TimeoutSec 15

        if (-not ($Response.PSObject.Properties["models"])) {
            return @()
        }

        return @(
            $Response.models |
                Where-Object {
                    $_.supportedGenerationMethods -contains "generateContent"
                } |
                ForEach-Object {
                    $Name = [string]$_.name
                    if ($Name.StartsWith("models/")) {
                        $Name = $Name.Substring(7)
                    }
                    $Name
                } |
                Sort-Object -Unique
        )

    }
    catch {
        return @()
    }

}

function Invoke-Gemini {

    param(

        [Parameter(Mandatory)]
        $Configuration,

        [Parameter(Mandatory)]
        [string]$Prompt

    )

    #------------------------------------------------------
    # Request
    # Gemini uses ?key= query param, not a Bearer header
    #------------------------------------------------------

    $Uri = "https://generativelanguage.googleapis.com/v1beta/models/$($Configuration.Model):generateContent?key=$($Configuration.ApiKey)"

    $Body = @{
        contents = @(
            @{
                parts = @(
                    @{ text = $Prompt }
                )
            }
        )
        generationConfig = @{
            temperature     = 0.2
            maxOutputTokens = 4096
        }
    } | ConvertTo-Json -Depth 10

    #------------------------------------------------------
    # Invoke
    #------------------------------------------------------

    try {

        $Response = Invoke-RestMethod `
            -Method Post `
            -Uri $Uri `
            -ContentType "application/json" `
            -Body $Body

    }
    catch {

        $Message = Get-GeminiErrorMessage -ErrorRecord $_

        if ($Message -match 'not found|NOT_FOUND|404') {
            throw "Gemini model '$($Configuration.Model)' is not available for generateContent. Run Initialize-HALSGemini again and choose a model from your account's model list."
        }

        if ($Message -match 'depleted|RESOURCE_EXHAUSTED|429|quota') {
            throw "Google AI billing or quota limit reached: $Message"
        }

        throw $Message

    }

    #------------------------------------------------------
    # Extract text from candidates[0].content.parts[0].text
    #------------------------------------------------------

    if ($Response.PSObject.Properties["candidates"] -and
        $Response.candidates.Count -gt 0) {

        $Candidate = $Response.candidates[0]

        if ($Candidate.PSObject.Properties["content"] -and
            $Candidate.content.PSObject.Properties["parts"] -and
            $Candidate.content.parts.Count -gt 0) {

            return $Candidate.content.parts[0].text

        }

    }

    throw "Gemini returned no text response."

}

Export-ModuleMember -Function Get-GeminiModels, Invoke-Gemini
