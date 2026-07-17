#==========================================================
# HALS - AI Inventory Serializer
# Version : 2.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-HALSAIInventory {

    param(

        [Parameter(Mandatory)]
        $Inventory

    )

    $Assets = foreach ($Asset in $Inventory.Assets) {

        #
        # Status
        #

        $Status = $null

        if ($Asset.Entities) {

            $StatusEntity = $Asset.Entities |
                Where-Object {

                    $_.Name -match "switch|contact|motion|presence|lock|alarm|smoke|water|temperature"

                } |
                Select-Object -First 1

            if ($StatusEntity) {
                $Status = $StatusEntity.Value
            }

        }

        #
        # Facts
        #

        $Facts = @()

        foreach ($Entity in $Asset.Entities) {

            if ($null -eq $Entity.Value) {
                continue
            }

            switch -Wildcard ($Entity.Name.ToLower()) {

                "*battery*" {

                    $Facts += [PSCustomObject]@{
                        Name  = "Battery"
                        Value = $Entity.Value
                    }

                }

                "*firmware*" {

                    $Facts += [PSCustomObject]@{
                        Name  = "Firmware"
                        Value = $Entity.Value
                    }

                }

                "*temperature*" {

                    $Facts += [PSCustomObject]@{
                        Name  = "Temperature"
                        Value = $Entity.Value
                    }

                }

                "*humidity*" {

                    $Facts += [PSCustomObject]@{
                        Name  = "Humidity"
                        Value = $Entity.Value
                    }

                }

                "*signal*" {

                    $Facts += [PSCustomObject]@{
                        Name  = "Signal"
                        Value = $Entity.Value
                    }

                }

                "*rssi*" {

                    $Facts += [PSCustomObject]@{
                        Name  = "RSSI"
                        Value = $Entity.Value
                    }

                }

            }

        }

        #
        # AI Asset
        #

        [PSCustomObject]@{

            Name = $Asset.Name

            Category = $Asset.Category

            Manufacturer = $Asset.Manufacturer

            Providers = @($Asset.Sources | Sort-Object -Unique)

            Capabilities = @(
                $Asset.Capabilities |
                Select-Object -ExpandProperty Name -Unique
            )

            Status = $Status

            Facts = $Facts

        }

    }

    #
    # AI Inventory
    #

    [PSCustomObject]@{

        Generated = Get-Date

        AssetCount = $Assets.Count

        Assets = $Assets

    }

}

Export-ModuleMember -Function ConvertTo-HALSAIInventory