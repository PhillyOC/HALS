#==========================================================
# HALS - Google Gemini Provider
# Version : 1.0.0
#
# Uses the Gemini API (generateContent endpoint).
# Docs : https://ai.google.dev/api/generate-content
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

    $Response = Invoke-RestMethod `
        -Method Post `
        -Uri $Uri `
        -ContentType "application/json" `
        -Body $Body

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

Export-ModuleMember -Function Invoke-Gemini
