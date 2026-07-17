#==========================================================
# HALS - Mistral AI Provider
# Version : 1.0.0
#
# Mistral exposes an OpenAI-compatible chat completions
# endpoint, so we use the same request shape as Together AI.
# Docs : https://docs.mistral.ai/api/#tag/chat
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Mistral {

    param(

        [Parameter(Mandatory)]
        $Configuration,

        [Parameter(Mandatory)]
        [string]$Prompt

    )

    #------------------------------------------------------
    # Headers
    #------------------------------------------------------

    $Headers = @{
        Authorization  = "Bearer $($Configuration.ApiKey)"
        "Content-Type" = "application/json"
        Accept         = "application/json"
    }

    #------------------------------------------------------
    # Request  (OpenAI-compatible schema)
    #------------------------------------------------------

    $Body = @{
        model    = $Configuration.Model
        messages = @(
            @{
                role    = "user"
                content = $Prompt
            }
        )
        max_tokens  = 4096
        temperature = 0.2
    } | ConvertTo-Json -Depth 10

    #------------------------------------------------------
    # Invoke
    #------------------------------------------------------

    $Response = Invoke-RestMethod `
        -Method Post `
        -Uri "https://api.mistral.ai/v1/chat/completions" `
        -Headers $Headers `
        -Body $Body

    #------------------------------------------------------
    # Extract from choices[0].message.content
    #------------------------------------------------------

    if ($Response.PSObject.Properties["choices"] -and
        $Response.choices.Count -gt 0) {

        $Choice = $Response.choices[0]

        if ($Choice.PSObject.Properties["message"] -and
            $Choice.message.PSObject.Properties["content"]) {

            return $Choice.message.content

        }

    }

    throw "Mistral returned no text response."

}

Export-ModuleMember -Function Invoke-Mistral
