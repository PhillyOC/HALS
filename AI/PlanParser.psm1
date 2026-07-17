#==========================================================
# HALS - Plan Parser
# Version : 2.1.1
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertFrom-HALSAIPlan {

    param(

        [Parameter(Mandatory)]
        [string]$Json

    )

    try {

        $Plan = $Json | ConvertFrom-Json

    }

    catch {

        throw "AI did not return valid JSON."

    }

    if (-not $Plan.PSObject.Properties["Actions"]) {

        throw "Execution plan does not contain an Actions property."

    }

    if ($null -eq $Plan.Actions) {

        Write-Warning "HALSAI returned a null Actions collection."

        return (New-HALSPlan -Actions @())

    }

    $Normalized = @()

    foreach ($Action in @($Plan.Actions)) {

        if ($null -eq $Action) {
            continue
        }

        $Provider = if ($Action.PSObject.Properties["Provider"]) {
            $Action.Provider
        }
        else {
            "Unknown"
        }

        $Device = if ($Action.PSObject.Properties["Device"]) {
            $Action.Device
        }
        else {
            ""
        }

        if (-not $Action.PSObject.Properties["Command"]) {

            Write-Warning "Skipping action with no Command."
            continue

        }

        $Command = $Action.Command

        $Parameters = @{}

        if ($Action.PSObject.Properties["Parameters"] -and
            $null -ne $Action.Parameters) {

            foreach ($Property in $Action.Parameters.PSObject.Properties) {

                $Parameters[$Property.Name] = $Property.Value

            }

        }

        $Risk = "Low"

        if ($Action.PSObject.Properties["Risk"] -and $Action.Risk) {

            $Risk = $Action.Risk

        }

        $ConfirmationRequired = $false

        if ($Action.PSObject.Properties["ConfirmationRequired"]) {

            $ConfirmationRequired = [bool]$Action.ConfirmationRequired

        }

        $Normalized += New-HALSAction `
            -Provider $Provider `
            -Device $Device `
            -Command $Command `
            -Parameters $Parameters `
            -Risk $Risk `
            -ConfirmationRequired $ConfirmationRequired

    }

    if ($Normalized.Count -eq 0) {

        Write-Warning "HALSAI produced no executable actions."

        return (New-HALSPlan -Actions @())

    }

    return (New-HALSPlan -Actions $Normalized)

}

Export-ModuleMember -Function ConvertFrom-HALSAIPlan