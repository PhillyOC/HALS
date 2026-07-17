#==========================================================
# HALS - Planner
# Version : 2.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-HALSPlan {

    param(

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Object[]]$Actions

    )

    [PSCustomObject]@{

        #
        # Execution Detector looks for this.
        #

        Type = "ExecutionPlan"

        Created = Get-Date

        ActionCount = $Actions.Count

        Actions = $Actions

    }

}

Export-ModuleMember -Function New-HALSPlan