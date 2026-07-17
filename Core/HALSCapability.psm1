#==========================================================
# HALS - Capability Module
# Version : 0.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-HALSCapability {

    param(

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Provider,

        [string]$Category = "General",

        [bool]$Readable = $true,

        [bool]$Writable = $false,

        [string]$Command = "",

        [object[]]$AllowedValues = @(),

        $Minimum = $null,

        $Maximum = $null,

        $Step = $null

    )

    [PSCustomObject]@{

        Name          = $Name

        Provider      = $Provider

        Category      = $Category

        Readable      = $Readable

        Writable      = $Writable

        Command       = $Command

        AllowedValues = $AllowedValues

        Minimum       = $Minimum

        Maximum       = $Maximum

        Step          = $Step

    }

}

Export-ModuleMember -Function New-HALSCapability