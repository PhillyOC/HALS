#==========================================================
# HALS - Philips Hue Device Converter
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-HALSPhilipsHueDevice {

    param(

        [Parameter(Mandatory)]
        $Device,

        [Parameter(Mandatory)]
        [hashtable]$Knowledge

    )

    $Name  = if (-not [string]::IsNullOrWhiteSpace($Device.Name)) { $Device.Name } else { "Hue Light" }
    $MAC   = "HUE:$($Device.LightId)"
    $Known = $false

    if ($Knowledge.ContainsKey($MAC)) {

        $Known = $true
        $Entry = $Knowledge[$MAC]

        if ($Entry.FriendlyName) { $Name = $Entry.FriendlyName }

    }

    #
    # Append room name to display if not already in the light's name
    #

    $DisplayName = $Name
    if (-not [string]::IsNullOrWhiteSpace($Device.Room) -and
        $Name -notmatch [regex]::Escape($Device.Room)) {
        $DisplayName = "$($Device.Room) $Name"
    }

    #
    # Entities for HALSAI context
    #

    $Entities = @(
        [PSCustomObject]@{
            Name        = "switch.on"
            Type        = "Capability"
            Provider    = "PhilipsHue"
            Category    = "Power"
            Value       = $Device.State
            Writable    = $true
            LastUpdated = $null
            Raw         = $Device.State
        }
    )

    if ($null -ne $Device.Brightness) {
        $Entities += [PSCustomObject]@{
            Name        = "switchLevel.brightness"
            Type        = "Capability"
            Provider    = "PhilipsHue"
            Category    = "Brightness"
            Value       = $Device.Brightness
            Writable    = $true
            LastUpdated = $null
            Raw         = $Device.Brightness
        }
    }

    if ($null -ne $Device.ColorTemp) {
        $Entities += [PSCustomObject]@{
            Name        = "colorTemperature.mirek"
            Type        = "Capability"
            Provider    = "PhilipsHue"
            Category    = "ColorTemperature"
            Value       = $Device.ColorTemp
            Writable    = $true
            LastUpdated = $null
            Raw         = $Device.ColorTemp
        }
    }

    [PSCustomObject]@{

        Name            = $DisplayName
        Category        = "Light Bulb"
        Known           = $Known

        Hostname        = $null
        IP              = $null
        MAC             = $MAC

        Manufacturer    = "Philips"
        Source          = "PhilipsHue"

        Status          = $Device.State
        Room            = $Device.Room
        LightId         = $Device.LightId

        Entities        = $Entities
        RawProviderData = $Device

    }

}

Export-ModuleMember -Function ConvertTo-HALSPhilipsHueDevice
