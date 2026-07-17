#==========================================================
# HALS - Home Assistant Device
# Version : 1.0.1
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-HALSHomeAssistantDevice {

    param(

        [Parameter(Mandatory)]
        $Device,

        [Parameter(Mandatory)]
        [hashtable]$Knowledge

    )

    #
    # Friendly Name
    #

    $Name = $Device.FriendlyName

    if ([string]::IsNullOrWhiteSpace($Name)) {

        $Name = $Device.EntityId

    }

    #
    # Category
    #

    $Category = switch ($Device.Domain) {

        "light"         { "Light Bulb" }

        "switch"        { "Switch" }

        "sensor"        { "Sensor" }

        "binary_sensor" { "Sensor" }

        "lock"          { "Lock" }

        "fan"           { "Fan" }

        "climate"       { "Climate" }

        "camera"        { "Camera" }

        "cover"         { "Cover" }

        "scene"         { "Scene" }

        "script"        { "Script" }

        "automation"    { "Automation" }

        "media_player"  { "Media Player" }

        default         { "Home Assistant Entity" }

    }

    #
    # Known Device Lookup
    #

    $KnowledgeKey = "HA:$($Device.EntityId)"
    $Known = $false

    if ($Knowledge.ContainsKey($KnowledgeKey)) {

        $Known = $true

        if ($Knowledge[$KnowledgeKey].FriendlyName) {

            $Name = $Knowledge[$KnowledgeKey].FriendlyName

        }

        if ($Knowledge[$KnowledgeKey].Category) {

            $Category = $Knowledge[$KnowledgeKey].Category

        }

    }

    #
    # Return HALS Device
    #

    [PSCustomObject]@{

        Name            = $Name

        Category        = $Category

        Known           = $Known

        Hostname        = $null

        IP              = $null

        MAC             = "HA:$($Device.EntityId)"

        Manufacturer    = "Home Assistant"

        Source          = "HomeAssistant"

        Status          = $Device.State

        EntityId        = $Device.EntityId

        Domain          = $Device.Domain

        Attributes      = $Device.Attributes

        Entities        = @()

        RawProviderData = $Device

    }

}

Export-ModuleMember -Function ConvertTo-HALSHomeAssistantDevice
