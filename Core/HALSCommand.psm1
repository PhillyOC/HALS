#==========================================================
# HALS - Command Model
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-HALSCommand {

    param(

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Description,

        [string]$Risk = "Low"

    )

    [PSCustomObject]@{

        Name = $Name

        Provider = $Provider

        Description = $Description

        Risk = $Risk

    }

}

Export-ModuleMember -Function New-HALSCommand