#==========================================================
# HALS - Google Nest Provider
# Version : 1.0.0
#
# Auth : OAuth 2.0 via Google Device Access API
# Docs : https://developers.google.com/nest/device-access
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Connect
#----------------------------------------------------------

function Connect-GoogleNest {

    $AccessToken = Get-HALSOAuthAccessToken -Provider "GoogleNest"

    return @{
        Headers = @{
            Authorization = "Bearer $AccessToken"
            "Content-Type" = "application/json"
        }
    }

}

#----------------------------------------------------------
# Build URI
#----------------------------------------------------------

function Get-NestUri {

    param(
        [Parameter(Mandatory)]
        [string]$ProjectId,

        [string]$Path = ""
    )

    $Base = "https://smartdevicemanagement.googleapis.com/v1/enterprises/$ProjectId"

    if ($Path) { return "$Base/$($Path.TrimStart('/'))" }

    return $Base

}

#----------------------------------------------------------
# Devices
#----------------------------------------------------------

function Get-GoogleNestDevices {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$ProjectId
    )

    $Uri = Get-NestUri -ProjectId $ProjectId -Path "devices"

    $Response = Invoke-RestMethod `
        -Uri $Uri `
        -Headers $Connection.Headers `
        -Method Get

    if ($Response.PSObject.Properties["devices"]) {
        return $Response.devices
    }

    return @()

}

#----------------------------------------------------------
# Structures (homes/rooms)
#----------------------------------------------------------

function Get-GoogleNestStructures {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$ProjectId
    )

    $Uri = Get-NestUri -ProjectId $ProjectId -Path "structures"

    $Response = Invoke-RestMethod `
        -Uri $Uri `
        -Headers $Connection.Headers `
        -Method Get

    if ($Response.PSObject.Properties["structures"]) {
        return $Response.structures
    }

    return @()

}

#----------------------------------------------------------
# Inventory
#----------------------------------------------------------

function Get-GoogleNestInventory {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$ProjectId
    )

    $Devices = Get-GoogleNestDevices `
        -Connection $Connection `
        -ProjectId $ProjectId

    foreach ($Device in $Devices) {

        #
        # Device type is the last segment of the type string.
        # e.g. "sdm.devices.types.THERMOSTAT" -> "THERMOSTAT"
        #

        $TypeRaw = ""
        if ($Device.PSObject.Properties["type"]) {
            $TypeRaw = $Device.type.Split(".")[-1].ToLower()
        }

        $DisplayName = ""
        if ($Device.PSObject.Properties["traits"] -and
            $Device.traits.PSObject.Properties["sdm.devices.traits.Info"]) {
            $DisplayName = $Device.traits."sdm.devices.traits.Info".customName
        }

        if ([string]::IsNullOrWhiteSpace($DisplayName)) {
            $DisplayName = $TypeRaw
        }

        #
        # Pull connectivity state if present
        #

        $Online = $null
        if ($Device.PSObject.Properties["traits"] -and
            $Device.traits.PSObject.Properties["sdm.devices.traits.Connectivity"]) {
            $Online = $Device.traits."sdm.devices.traits.Connectivity".status
        }

        [PSCustomObject]@{
            DeviceId     = $Device.name
            DisplayName  = $DisplayName
            Type         = $TypeRaw
            Online       = $Online
            Traits       = if ($Device.PSObject.Properties["traits"]) { $Device.traits } else { $null }
            Raw          = $Device
        }

    }

}

#----------------------------------------------------------
# Execute Trait Command
#----------------------------------------------------------

function Invoke-GoogleNestCommand {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$DeviceName,

        [Parameter(Mandatory)]
        [string]$Command,

        [hashtable]$Params = @{}
    )

    $Uri = "https://smartdevicemanagement.googleapis.com/v1/$($DeviceName):executeCommand"

    $Body = @{
        command = $Command
        params  = $Params
    } | ConvertTo-Json -Depth 10

    Invoke-RestMethod `
        -Uri $Uri `
        -Headers $Connection.Headers `
        -Method Post `
        -Body $Body

}

Export-ModuleMember `
    -Function Connect-GoogleNest,
              Get-GoogleNestDevices,
              Get-GoogleNestStructures,
              Get-GoogleNestInventory,
              Invoke-GoogleNestCommand
