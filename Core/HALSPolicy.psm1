#==========================================================
# HALS - Policy Engine
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-HALSAction {

    param(

        [Parameter(Mandatory)]
        $Action

    )

    switch ($Action.Risk) {

        "Critical" {

            return $false

        }

        default {

            return $true

        }

    }

}

Export-ModuleMember -Function Test-HALSAction