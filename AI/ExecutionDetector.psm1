#==========================================================
# HALS - Execution Detector
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-HALSExecutionPlan {

    param(

        [Parameter(Mandatory)]
        $Object

    )

    return (

        $Object.PSObject.Properties["Type"] -and
        $Object.Type -eq "ExecutionPlan"

    )

}

Export-ModuleMember -Function Test-HALSExecutionPlan