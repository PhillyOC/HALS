#==========================================================
# HALS - OpenAI Provider
# Version : 2.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-OpenAI {

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
        Authorization = "Bearer $($Configuration.ApiKey)"
        "Content-Type" = "application/json"
    }

    #------------------------------------------------------
    # Request
    #------------------------------------------------------

    $Body = @{
        model = $Configuration.Model
        input = $Prompt
    } | ConvertTo-Json -Depth 10

    #------------------------------------------------------
    # Invoke API
    #------------------------------------------------------

    $Response = Invoke-RestMethod `
        -Method Post `
        -Uri "https://api.openai.com/v1/responses" `
        -Headers $Headers `
        -Body $Body

    #------------------------------------------------------
    # Extract Assistant Response
    #------------------------------------------------------

    foreach ($Output in $Response.output) {

        if ($Output.type -ne "message") {
            continue
        }

        foreach ($Content in $Output.content) {

            if ($Content.type -eq "output_text") {

                return $Content.text

            }

        }

    }

    throw "OpenAI returned no assistant response."

}

Export-ModuleMember -Function Invoke-OpenAI