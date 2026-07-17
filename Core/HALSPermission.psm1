#==========================================================
# HALS - Permission Model
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-HALSPermission {

    param(

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Name,

        [bool]$Granted = $false,

        [string]$Description = "",

        [string]$Scope = ""

    )

    [PSCustomObject]@{

        Provider = $Provider

        Name = $Name

        Granted = $Granted

        Scope = $Scope

        Description = $Description

    }

}

Export-ModuleMember -Function New-HALSPermission