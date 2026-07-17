#==========================================================
# HALS - Asset Module
# Version : 0.2.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-HALSAsset {

    param(

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Category,

        [string]$Room,

        [string]$Manufacturer,

        [string[]]$Tags = @(),

        [string[]]$Aliases = @(),

        [string]$Notes = "",

        [Object[]]$Entities = @(),

        [Object[]]$Capabilities = @(),

        [string[]]$Sources = @()

    )

    [PSCustomObject]@{

        Name         = $Name
        Category     = $Category

        Room         = $Room

        Manufacturer = $Manufacturer

        Tags         = $Tags
        Aliases      = $Aliases
        Notes        = $Notes

        Sources      = $Sources

        Entities     = $Entities

        Capabilities = $Capabilities

    }

}

Export-ModuleMember -Function New-HALSAsset