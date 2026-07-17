#==========================================================
# HALS - Executor
# Version : 2.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-HALSPlan {

    param(

        [Parameter(Mandatory)]
        $Plan

    )

    foreach ($Action in $Plan.Actions) {

        #
        # Policy
        #

        if (-not (Test-HALSAction $Action)) {

            Write-Warning "$($Action.Command) denied by policy."

            continue

        }

        #
        # Validate Command
        #

        $SupportedCommands = @(
            "TurnOnLight",
            "TurnOffLight",
            "ToggleLight",
            "SetBrightness",
            "SetColor",
            "SetColorTemperature",
            "ActivateSiren",
            "DeactivateSiren"
        )

        if ($Action.Command -notin $SupportedCommands) {

            throw "Unknown HALS command: $($Action.Command)"

        }

        #
        # Dispatch
        #

        switch ($Action.Provider) {

            "SmartThings" {

                Invoke-SmartThingsAction `
                    -Action $Action

            }

            default {

                Write-Warning "Unknown provider: $($Action.Provider)"

            }

        }

    }

}

Export-ModuleMember -Function Invoke-HALSPlan