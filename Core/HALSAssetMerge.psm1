#==========================================================
# HALS - Asset Merge Engine
# Version : 0.2.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Merge-HALSAssets {

    param(

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Object[]]$Devices

    )

    $Assets = @{}

    foreach ($Device in $Devices) {

        #--------------------------------------------------
        # Identity
        #--------------------------------------------------

        $Key = $Device.MAC

        if ([string]::IsNullOrWhiteSpace($Key)) {
            $Key = $Device.Name
        }

        #--------------------------------------------------
        # New Asset
        #--------------------------------------------------

        if (-not $Assets.ContainsKey($Key)) {

            $Assets[$Key] = New-HALSAsset `
                -Name $Device.Name `
                -Category $Device.Category `
                -Manufacturer $Device.Manufacturer `
                -Entities @() `
                -Capabilities @() `
                -Sources @()

        }

        #--------------------------------------------------
        # Provider
        #--------------------------------------------------

        if ($Device.Source -notin $Assets[$Key].Sources) {

            $Assets[$Key].Sources += $Device.Source

        }

        #--------------------------------------------------
        # Entities
        #--------------------------------------------------

        if ($Device.Entities) {

            $Assets[$Key].Entities += $Device.Entities

        }

        #--------------------------------------------------
        # Capabilities
        #--------------------------------------------------

        $Capabilities = Get-HALSCapabilities `
            -Device $Device

        if ($Capabilities) {

            $Assets[$Key].Capabilities += $Capabilities

        }

    }

    # Always return Object[] so zero- and one-asset inventories keep .Count under StrictMode.
    return @($Assets.Values)

}

Export-ModuleMember -Function Merge-HALSAssets