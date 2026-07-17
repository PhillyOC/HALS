#==========================================================
# HALS - AI Engine
# Version : 3.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ask-HALSAI {

    param(

        [string]$Question = "Analyze my home."

    )

    #------------------------------------------------------
    # Configuration
    #------------------------------------------------------

    $Configuration = Get-HALSAIConfiguration

    #------------------------------------------------------
    # Inventory
    #------------------------------------------------------

    $AIInventory = ConvertTo-HALSAIInventory `
        -Inventory $Global:HALSInventory

    #------------------------------------------------------
    # Context
    #------------------------------------------------------

    $Context = Get-HALSAIContext `
        -Inventory $AIInventory

    #------------------------------------------------------
    # Prompt
    #------------------------------------------------------

    $Prompt = New-HALSAIPrompt `
        -Context $Context `
        -Question $Question

    #------------------------------------------------------
    # Provider
    #------------------------------------------------------

    switch ($Configuration.Provider) {

        "OpenAI" {

            return Invoke-OpenAI `
                -Configuration $Configuration.OpenAI `
                -Prompt $Prompt

        }

        default {

            throw "Unsupported AI Provider: $($Configuration.Provider)"

        }

    }

}

Export-ModuleMember -Function Ask-HALSAI