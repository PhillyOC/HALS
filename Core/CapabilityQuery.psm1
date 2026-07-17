#==========================================================
# HALS - Capability Query Engine
# Version : 0.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSCapability {

    param(

        [string]$Asset,

        [string]$Provider,

        [string]$Category,

        [string]$Name,

        [switch]$Writable

    )

    foreach ($A in $Global:HALSInventory.Assets) {

        if ($Asset) {

            if ($A.Name -notlike "*$Asset*") {
                continue
            }

        }

        foreach ($Capability in $A.Capabilities) {

            if ($Provider) {

                if ($Capability.Provider -notlike "*$Provider*") {
                    continue
                }

            }

            if ($Category) {

                if ($Capability.Category -notlike "*$Category*") {
                    continue
                }

            }

            if ($Name) {

                if ($Capability.Name -notlike "*$Name*") {
                    continue
                }

            }

            if ($Writable) {

                if (-not $Capability.Writable) {
                    continue
                }

            }

            [PSCustomObject]@{

                Asset = $A.Name

                Name = $Capability.Name

                Category = $Capability.Category

                Provider = $Capability.Provider

                Writable = $Capability.Writable

                Command = $Capability.Command

                Values = ($Capability.AllowedValues -join ",")

                Minimum = $Capability.Minimum

                Maximum = $Capability.Maximum

                Step = $Capability.Step

            }

        }

    }

}

Export-ModuleMember -Function Get-HALSCapability