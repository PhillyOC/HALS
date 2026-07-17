#==========================================================
# HALS - Claude (Anthropic) Provider
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Claude {

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
        "x-api-key"         = $Configuration.ApiKey
        "anthropic-version" = "2023-06-01"
        "Content-Type"      = "application/json"
    }

    #------------------------------------------------------
    # Request
    #------------------------------------------------------

    $Body = @{
        model      = $Configuration.Model
        max_tokens = 4096
        messages   = @(
            @{
                role    = "user"
                content = $Prompt
            }
        )
    } | ConvertTo-Json -Depth 10

    #------------------------------------------------------
    # Invoke API
    #------------------------------------------------------

    $Response = Invoke-RestMethod `
        -Method Post `
        -Uri "https://api.anthropic.com/v1/messages" `
        -Headers $Headers `
        -Body $Body

    #------------------------------------------------------
    # Extract Assistant Response
    #------------------------------------------------------

    foreach ($Block in $Response.content) {

        if ($Block.type -eq "text") {

            return $Block.text

        }

    }

    throw "Claude returned no text response."

}

Export-ModuleMember -Function Invoke-Claude
