#==========================================================
# HALS - Action Model
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-HALSAction {

    param(

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Device,

        [Parameter(Mandatory)]
        [string]$Command,

        [hashtable]$Parameters = @{},

        [string]$Risk = "Low",

        [bool]$ConfirmationRequired = $false

    )

    [PSCustomObject]@{

        Provider = $Provider

        Device = $Device

        Command = $Command

        Parameters = $Parameters

        Risk = $Risk

        ConfirmationRequired = $ConfirmationRequired

    }

}

Export-ModuleMember -Function New-HALSAction