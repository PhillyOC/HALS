#==========================================================
# HALS - AI Inventory Serializer
# Version : 2.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-HALSAIInventory {

    param(

        [Parameter(Mandatory)]
        $Inventory

    )

    $SourceAssets = @()

    if ($Inventory.PSObject.Properties["Assets"] -and $null -ne $Inventory.Assets) {
        $SourceAssets = @($Inventory.Assets | Where-Object { $null -ne $_ })
    }

    $Assets = @(foreach ($Asset in $SourceAssets) {

        #
        # Status
        #

        $Status = $null
        $Entities = @()

        if ($Asset.PSObject.Properties["Entities"] -and $null -ne $Asset.Entities) {
            $Entities = @($Asset.Entities)
        }

        if ($Entities.Count -gt 0) {

            $StatusEntity = $Entities |
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

        foreach ($Entity in $Entities) {

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

        $Sources = @()
        if ($Asset.PSObject.Properties["Sources"] -and $null -ne $Asset.Sources) {
            $Sources = @($Asset.Sources | Sort-Object -Unique)
        }

        $CapabilityNames = @()
        if ($Asset.PSObject.Properties["Capabilities"] -and $null -ne $Asset.Capabilities) {
            $CapabilityNames = @(
                $Asset.Capabilities |
                Select-Object -ExpandProperty Name -Unique
            )
        }

        #
        # AI Asset
        #

        [PSCustomObject]@{

            Name = $Asset.Name

            Category = $Asset.Category

            Manufacturer = $Asset.Manufacturer

            Providers = $Sources

            Capabilities = $CapabilityNames

            Status = $Status

            Facts = $Facts

        }

    })

    #
    # AI Inventory
    #

    [PSCustomObject]@{

        Generated = Get-Date

        AssetCount = @($Assets).Count

        Assets = @($Assets)

    }

}

Export-ModuleMember -Function ConvertTo-HALSAIInventory
