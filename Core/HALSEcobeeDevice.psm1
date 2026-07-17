#==========================================================
# HALS - Ecobee Device Converter
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-HALSEcobeeDevice {

    param(

        [Parameter(Mandatory)]
        $Device,

        [Parameter(Mandatory)]
        [hashtable]$Knowledge

    )

    $Name  = if (-not [string]::IsNullOrWhiteSpace($Device.Name)) { $Device.Name } else { "Ecobee Thermostat" }
    $MAC   = "ECOBEE:$($Device.ThermostatId)"
    $Known = $false

    if ($Knowledge.ContainsKey($MAC)) {

        $Known = $true
        $Entry = $Knowledge[$MAC]

        if ($Entry.FriendlyName) { $Name = $Entry.FriendlyName }

    }

    #
    # Build a human-readable status string
    #

    $StatusParts = @()
    if ($Device.HvacMode)    { $StatusParts += $Device.HvacMode }
    if ($Device.CurrentTemp) { $StatusParts += "$($Device.CurrentTemp) degreesF" }
    $Status = $StatusParts -join "  .  "

    #
    # Entities - thermostat readings for HALSAI context
    #

    $Entities = @()

    if ($null -ne $Device.CurrentTemp) {
        $Entities += [PSCustomObject]@{
            Name        = "temperature.current"
            Type        = "Capability"
            Provider    = "Ecobee"
            Category    = "Temperature"
            Value       = $Device.CurrentTemp
            Writable    = $false
            LastUpdated = $null
            Raw         = $Device.CurrentTemp
        }
    }

    if ($null -ne $Device.HvacMode) {
        $Entities += [PSCustomObject]@{
            Name        = "hvac.mode"
            Type        = "Capability"
            Provider    = "Ecobee"
            Category    = "Climate"
            Value       = $Device.HvacMode
            Writable    = $true
            LastUpdated = $null
            Raw         = $Device.HvacMode
        }
    }

    if ($null -ne $Device.SetpointHeat) {
        $Entities += [PSCustomObject]@{
            Name        = "temperature.setpointHeat"
            Type        = "Capability"
            Provider    = "Ecobee"
            Category    = "Temperature"
            Value       = $Device.SetpointHeat
            Writable    = $true
            LastUpdated = $null
            Raw         = $Device.SetpointHeat
        }
    }

    if ($null -ne $Device.SetpointCool) {
        $Entities += [PSCustomObject]@{
            Name        = "temperature.setpointCool"
            Type        = "Capability"
            Provider    = "Ecobee"
            Category    = "Temperature"
            Value       = $Device.SetpointCool
            Writable    = $true
            LastUpdated = $null
            Raw         = $Device.SetpointCool
        }
    }

    #
    # Each remote sensor also becomes a HALS device
    #

    $SensorDevices = @()

    foreach ($Sensor in $Device.Sensors) {

        $SensorMAC  = "ECOBEE:$($Device.ThermostatId):$($Sensor.SensorId)"
        $SensorName = $Sensor.Name
        $SensorKnown = $false

        if ($Knowledge.ContainsKey($SensorMAC)) {
            $SensorKnown = $true
            $SensorEntry = $Knowledge[$SensorMAC]
            if ($SensorEntry.FriendlyName) { $SensorName = $SensorEntry.FriendlyName }
        }

        $SensorEntities = @()

        if ($null -ne $Sensor.Temperature) {
            $SensorEntities += [PSCustomObject]@{
                Name     = "temperature.current"
                Type     = "Capability"
                Provider = "Ecobee"
                Category = "Temperature"
                Value    = $Sensor.Temperature
                Writable = $false
                Raw      = $Sensor.Temperature
            }
        }

        if ($null -ne $Sensor.Occupied) {
            $SensorEntities += [PSCustomObject]@{
                Name     = "occupancy.occupied"
                Type     = "Capability"
                Provider = "Ecobee"
                Category = "Occupancy"
                Value    = $Sensor.Occupied
                Writable = $false
                Raw      = $Sensor.Occupied
            }
        }

        $SensorDevices += [PSCustomObject]@{
            Name            = $SensorName
            Category        = "Sensor"
            Known           = $SensorKnown
            Hostname        = $null
            IP              = $null
            MAC             = $SensorMAC
            Manufacturer    = "Ecobee"
            Source          = "Ecobee"
            Status          = if ($null -ne $Sensor.Temperature) { "$($Sensor.Temperature) degreesF" } else { "" }
            Entities        = $SensorEntities
            RawProviderData = $Sensor
        }

    }

    $ThermostatDevice = [PSCustomObject]@{
        Name            = $Name
        Category        = "Thermostat"
        Known           = $Known
        Hostname        = $null
        IP              = $null
        MAC             = $MAC
        Manufacturer    = "Ecobee"
        Source          = "Ecobee"
        Status          = $Status
        ThermostatId    = $Device.ThermostatId
        Entities        = $Entities
        RawProviderData = $Device
    }

    #
    # Return thermostat + all its sensors as a flat array
    #

    return @($ThermostatDevice) + $SensorDevices

}

Export-ModuleMember -Function ConvertTo-HALSEcobeeDevice
