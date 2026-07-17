#==========================================================
# HALS - Entity Query Engine
# Version : 0.2.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSEntity {

    param(

        [string]$Asset,
        [string]$Provider,
        [string]$Category,
        [string]$Name

    )

    foreach ($A in $Global:HALSInventory.Assets) {

        if ($Asset) {
            if ($A.Name -notlike "*$Asset*") {
                continue
            }
        }

        foreach ($Entity in $A.Entities) {

            if ($Provider) {
                if ($Entity.Provider -notlike "*$Provider*") {
                    continue
                }
            }

            if ($Category) {
                if ($Entity.Category -notlike "*$Category*") {
                    continue
                }
            }

            if ($Name) {
                if ($Entity.Name -notlike "*$Name*") {
                    continue
                }
            }

            [PSCustomObject]@{

                Asset       = $A.Name
                Provider    = $Entity.Provider
                Category    = $Entity.Category
                Name        = $Entity.Name
                Value       = $Entity.Value
                Type        = $Entity.Type
                Writable    = $Entity.Writable
                LastUpdated = $Entity.LastUpdated

            }

        }

    }

}

Export-ModuleMember -Function Get-HALSEntity