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

        $Command = Get-HALSCommands |
            Where-Object {
                $_.Provider -eq $Action.Provider -and
                $_.Name -eq $Action.Command
            } |
            Select-Object -First 1

        if (-not $Command) {
            throw "Unknown HALS command for provider '$($Action.Provider)': $($Action.Command)"
        }

        #
        # Dispatch
        #

        Invoke-HALSRegisteredProviderAction -Action $Action

    }

}

Export-ModuleMember -Function Invoke-HALSPlan