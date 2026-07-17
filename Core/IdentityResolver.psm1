#==========================================================
# HALS - Identity Resolver
# Version : 0.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-HALSIdentity {

    param(

        [Parameter(Mandatory)]
        $Device,

        [Parameter(Mandatory)]
        $Assets

    )

    #
    # 1. Exact MAC Match
    #

    foreach ($Asset in $Assets) {

        foreach ($Entity in $Asset.Entities) {

            if ($Entity.Name -eq "mac" -or
                $Entity.Name -eq "MAC Address") {

                if ($Entity.Value -eq $Device.MAC) {
                    return $Asset
                }

            }

        }

    }

    #
    # 2. Exact Friendly Name
    #

    foreach ($Asset in $Assets) {

        if ($Asset.Name -ieq $Device.Name) {
            return $Asset
        }

    }

    #
    # 3. Hostname
    #

    if ($Device.Hostname) {

        foreach ($Asset in $Assets) {

            foreach ($Entity in $Asset.Entities) {

                if ($Entity.Name -eq "hostname") {

                    if ($Entity.Value -ieq $Device.Hostname) {
                        return $Asset
                    }

                }

            }

        }

    }

    #
    # No Match
    #

    return $null

}

Export-ModuleMember -Function Resolve-HALSIdentity