#==========================================================
# HALS - Philips Hue Provider
# Version : 1.0.0
#
# Auth : Local bridge API - username token obtained once
#        via the bridge button press flow.
# Docs : https://developers.meethue.com/develop/hue-api-v2/
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Connect
#----------------------------------------------------------

function Connect-PhilipsHue {

    $Secrets = Get-Content "$(Get-HALSRoot)\Secrets\PhilipsHue.json" -Raw |
        ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($Secrets.BridgeIp)) {
        throw "Philips Hue BridgeIp is missing from PhilipsHue.json. Run Initialize-HALSPhilipsHue."
    }

    if ([string]::IsNullOrWhiteSpace($Secrets.Username)) {
        throw "Philips Hue Username is missing from PhilipsHue.json. Run Initialize-HALSPhilipsHue."
    }

    return @{
        BridgeIp = $Secrets.BridgeIp
        Username = $Secrets.Username
        BaseUri  = "https://$($Secrets.BridgeIp)/clip/v2"
        Headers  = @{
            "hue-application-key" = $Secrets.Username
            "Content-Type"        = "application/json"
        }
    }

}

#----------------------------------------------------------
# Build URI
#----------------------------------------------------------

function Get-HueUri {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$Resource
    )

    "$($Connection.BaseUri)/resource/$($Resource.TrimStart('/'))"

}

#----------------------------------------------------------
# GET helper (ignores self-signed cert on bridge)
#----------------------------------------------------------

function Invoke-HueRequest {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$Resource,

        [string]$Method = "Get",

        $Body = $null
    )

    $Params = @{
        Uri                  = Get-HueUri -Connection $Connection -Resource $Resource
        Headers              = $Connection.Headers
        Method               = $Method
        SkipCertificateCheck = $true
    }

    if ($Body) {
        $Params["Body"] = ($Body | ConvertTo-Json -Depth 10)
    }

    $Response = Invoke-RestMethod @Params

    if ($Response.PSObject.Properties["data"]) {
        return $Response.data
    }

    return $Response

}

#----------------------------------------------------------
# Lights
#----------------------------------------------------------

function Get-PhilipsHueLights {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    Invoke-HueRequest -Connection $Connection -Resource "light"

}

#----------------------------------------------------------
# Rooms
#----------------------------------------------------------

function Get-PhilipsHueRooms {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    Invoke-HueRequest -Connection $Connection -Resource "room"

}

#----------------------------------------------------------
# Scenes
#----------------------------------------------------------

function Get-PhilipsHueScenes {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    Invoke-HueRequest -Connection $Connection -Resource "scene"

}

#----------------------------------------------------------
# Inventory
#----------------------------------------------------------

function Get-PhilipsHueInventory {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $Lights = Get-PhilipsHueLights -Connection $Connection
    $Rooms  = Get-PhilipsHueRooms  -Connection $Connection

    #
    # Build room lookup so each light can report its room name
    #

    $RoomByLightId = @{}

    foreach ($Room in $Rooms) {

        if (-not $Room.PSObject.Properties["children"]) { continue }

        foreach ($Child in $Room.children) {

            if ($Child.rtype -eq "device") {
                $RoomByLightId[$Child.rid] = $Room.metadata.name
            }

        }

    }

    foreach ($Light in $Lights) {

        $Name = ""
        if ($Light.PSObject.Properties["metadata"] -and
            $Light.metadata.PSObject.Properties["name"]) {
            $Name = $Light.metadata.name
        }

        $State = "unknown"
        if ($Light.PSObject.Properties["on"] -and
            $Light.on.PSObject.Properties["on"]) {
            $State = if ($Light.on.on) { "on" } else { "off" }
        }

        $Brightness = $null
        if ($Light.PSObject.Properties["dimming"] -and
            $Light.dimming.PSObject.Properties["brightness"]) {
            $Brightness = [Math]::Round($Light.dimming.brightness)
        }

        $ColorTemp = $null
        if ($Light.PSObject.Properties["color_temperature"] -and
            $Light.color_temperature.PSObject.Properties["mirek"]) {
            $ColorTemp = $Light.color_temperature.mirek
        }

        $Room = ""
        if ($Light.PSObject.Properties["owner"] -and
            $RoomByLightId.ContainsKey($Light.owner.rid)) {
            $Room = $RoomByLightId[$Light.owner.rid]
        }

        [PSCustomObject]@{
            LightId     = $Light.id
            Name        = $Name
            Room        = $Room
            State       = $State
            Brightness  = $Brightness
            ColorTemp   = $ColorTemp
            Raw         = $Light
        }

    }

}

#----------------------------------------------------------
# Control a light
#----------------------------------------------------------

function Set-PhilipsHueLight {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$LightId,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    Invoke-HueRequest `
        -Connection $Connection `
        -Resource "light/$LightId" `
        -Method "Put" `
        -Body $State

}

Export-ModuleMember `
    -Function Connect-PhilipsHue,
              Get-PhilipsHueLights,
              Get-PhilipsHueRooms,
              Get-PhilipsHueScenes,
              Get-PhilipsHueInventory,
              Set-PhilipsHueLight
