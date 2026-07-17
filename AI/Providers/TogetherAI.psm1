#==========================================================
# HALS - Together AI Provider
# Version : 1.0.0
#
# Together AI uses an OpenAI-compatible chat completions
# endpoint. Any model on the Together platform works.
# Docs : https://docs.together.ai/reference/chat-completions
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-TogetherAI {

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
        -Uri "https://api.together.xyz/v1/chat/completions" `
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

    throw "Together AI returned no text response."

}

Export-ModuleMember -Function Invoke-TogetherAI
