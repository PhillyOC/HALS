#==========================================================
# HALS - AI Engine
# Version : 6.0.0
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
    # Verify Inventory
    #------------------------------------------------------

    if (-not $Global:HALSInventory) {
        throw "HALS inventory has not been built."
    }

    #------------------------------------------------------
    # Build AI Inventory
    #------------------------------------------------------

    $Global:HALSAIInventory = ConvertTo-HALSAIInventory `
        -Inventory $Global:HALSInventory

    #------------------------------------------------------
    # Build Context
    #------------------------------------------------------

    $Context = Get-HALSAIContext

    #------------------------------------------------------
    # Build Prompt
    #------------------------------------------------------

    $Prompt = New-HALSAIPrompt `
        -Context $Context `
        -Question $Question

    #------------------------------------------------------
    # AI
    #------------------------------------------------------

    switch ($Configuration.Provider) {

        "OpenAI" {

            $Response = Invoke-OpenAI `
                -Configuration $Configuration.OpenAI `
                -Prompt $Prompt

        }

        "Claude" {

            $Response = Invoke-Claude `
                -Configuration $Configuration.Claude `
                -Prompt $Prompt

        }

        "Gemini" {

            $Response = Invoke-Gemini `
                -Configuration $Configuration.Gemini `
                -Prompt $Prompt

        }

        "TogetherAI" {

            $Response = Invoke-TogetherAI `
                -Configuration $Configuration.TogetherAI `
                -Prompt $Prompt

        }

        "Mistral" {

            $Response = Invoke-Mistral `
                -Configuration $Configuration.Mistral `
                -Prompt $Prompt

        }

        "Ollama" {

            $Response = Invoke-Ollama `
                -Configuration $Configuration.Ollama `
                -Prompt $Prompt

        }

        default {

            throw "Unsupported AI Provider: $($Configuration.Provider)"

        }

    }

    $Response = $Response.Trim()

    #------------------------------------------------------
    # Extract JSON from response
    #
    # Handles three response shapes from the AI:
    #   1. Pure JSON               { "Type": ...  }
    #   2. Preamble + JSON         One sentence.\n{ "Type": ... }
    #   3. Fenced JSON             ```json\n{ ... }\n```
    #
    # In cases 1 and 2 the preamble (if any) is printed as
    # commentary before the execution plan is processed.
    # In case 3 the fence is stripped silently.
    #------------------------------------------------------

    $Preamble = ""
    $Json     = ""

    # Case 3: strip markdown fences first
    if ($Response -match '(?s)^```(?:json)?\s*(\{.*\})\s*```$') {

        $Json = $Matches[1].Trim()

    }
    # Cases 1 & 2: find the first { that opens a top-level JSON object
    elseif ($Response -match '(?s)(\{.*\})') {

        $JsonStart = $Response.IndexOf('{')

        if ($JsonStart -gt 0) {

            # There is text before the JSON - treat it as commentary
            $Preamble = $Response.Substring(0, $JsonStart).Trim()

        }

        $Json = $Response.Substring($JsonStart).Trim()

    }

    #------------------------------------------------------
    # Execution plan path
    #------------------------------------------------------

    if (-not [string]::IsNullOrWhiteSpace($Json)) {

        # Print optional AI commentary before the plan
        if (-not [string]::IsNullOrWhiteSpace($Preamble)) {

            Write-Host ""
            Write-Host $Preamble -ForegroundColor Cyan

        }

        Write-Host ""
        Write-Host "================ RAW AI RESPONSE ================" -ForegroundColor DarkYellow
        Write-Host $Json
        Write-Host "=================================================" -ForegroundColor DarkYellow
        Write-Host ""

        $Plan = ConvertFrom-HALSAIPlan -Json $Json

        if ($Plan.Actions.Count -eq 0) {

            Write-Warning "Execution plan contains zero actions."
            return

        }

        if (Test-HALSExecutionPlan $Plan) {

            Write-Host ""
            Write-Host "Execution Plan Generated" -ForegroundColor Cyan
            Write-Host ""

            $Plan.Actions | Format-Table

            Write-Host ""

            $Execute = Read-Host "Execute this plan? (Y/N)"

            if ($Execute -match "^[Yy]") {

                Invoke-HALSPlan -Plan $Plan

            }

            return

        }

    }

    #------------------------------------------------------
    # Pure information response
    #------------------------------------------------------

    Write-Host $Response

}

Export-ModuleMember -Function Ask-HALSAI
