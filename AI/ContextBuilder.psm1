#==========================================================
# HALS - Context Builder
# Version : 6.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSAIContext {

    if (-not $Global:HALSAIInventory) {
        throw "HALSAI inventory has not been built."
    }

    #------------------------------------------------------
    # Build Permission Model
    #------------------------------------------------------

    $Permissions = Get-HALSPermissions `
        -Inventory $Global:HALSInventory

    #------------------------------------------------------
    # Build Command Model
    #------------------------------------------------------

    $Commands = Get-HALSCommands

    #------------------------------------------------------
    # Provider Health
    #------------------------------------------------------

    $ProviderHealth = @()

    if (Get-Command Get-HALSProviderHealth -ErrorAction SilentlyContinue) {

        $ProviderHealth = Get-HALSProviderHealth

    }

    #------------------------------------------------------
    # Known Devices
    #------------------------------------------------------

    $KnownDevices = @()

    if (Get-Command Get-HALSKnownDevices -ErrorAction SilentlyContinue) {

        $KnownDevices = Get-HALSKnownDevices

    }

    #------------------------------------------------------
    # Observations
    #------------------------------------------------------

    $Observations = @()

    if (Get-Command Get-HALSObservations -ErrorAction SilentlyContinue) {

        $Observations = Get-HALSObservations

    }

    #------------------------------------------------------
    # Evidence
    #------------------------------------------------------

    $Evidence = @()

    if (Get-Command Get-HALSEvidence -ErrorAction SilentlyContinue) {

        $Evidence = Get-HALSEvidence

    }

    #------------------------------------------------------
    # Experiments
    #------------------------------------------------------

    $Experiments = @()

    if (Get-Command Get-HALSExperiments -ErrorAction SilentlyContinue) {

        $Experiments = Get-HALSExperiments

    }

    #------------------------------------------------------
    # AI Context
    #------------------------------------------------------

    $Context = [PSCustomObject]@{

        Inventory      = $Global:HALSAIInventory

        Permissions    = $Permissions

        Commands       = $Commands

        ProviderHealth = $ProviderHealth

        KnownDevices   = $KnownDevices

        Observations   = $Observations

        Evidence       = $Evidence

        Experiments    = $Experiments

    }

    return (

        $Context |
        ConvertTo-Json -Depth 20

    )

}

Export-ModuleMember -Function Get-HALSAIContext