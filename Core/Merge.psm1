#==========================================================
# HALS - Merge Engine
# Version : 0.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Merge-HALSDevices {

    param(

        [Parameter(Mandatory)]
        $UniFiDevices,

        [Parameter(Mandatory)]
        $SmartThingsDevices

    )

    $Merged = @($UniFiDevices)

    foreach ($ST in $SmartThingsDevices) {

        #
        # Try to match an existing HALS device
        #

        $Existing = $Merged | Where-Object {

            $_.Name -ieq $ST.Name

        } | Select-Object -First 1

        #
        # Already known?
        #

        if ($Existing) {

            #
            # Enrich the existing device
            #

            Add-Member `
                -InputObject $Existing `
                -NotePropertyName SmartThings `
                -NotePropertyValue $ST.NativeDevice `
                -Force

        }
        else {

            #
            # Brand new HALS device
            #

            $Merged += $ST

        }

    }

    return $Merged

}

Export-ModuleMember -Function Merge-HALSDevices