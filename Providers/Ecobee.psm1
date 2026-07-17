#==========================================================
# HALS - Ecobee Provider
# Version : 1.0.0
#
# Auth : OAuth 2.0 PIN flow - user enters a 4-digit PIN
#        at ecobee.com/home. No redirect URI required.
# Docs : https://www.ecobee.com/home/developer/api/introduction/auth-overview.shtml
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$EcobeeBaseUri = "https://api.ecobee.com"
$EcobeeApiVer  = "1"

#----------------------------------------------------------
# Connect
#----------------------------------------------------------

function Connect-Ecobee {

    $AccessToken = Get-HALSOAuthAccessToken -Provider "Ecobee"

    return @{
        Headers = @{
            Authorization  = "Bearer $AccessToken"
            "Content-Type" = "application/json;charset=UTF-8"
        }
    }

}

#----------------------------------------------------------
# Thermostats
#----------------------------------------------------------

function Get-EcobeeThermostats {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    #
    # Request a broad selection so we get runtime + settings + sensors
    #

    $Selection = @{
        selection = @{
            selectionType   = "registered"
            selectionMatch  = ""
            includeSensors  = $true
            includeRuntime  = $true
            includeSettings = $true
            includeEquipmentStatus = $true
        }
    } | ConvertTo-Json -Depth 10 -Compress

    $Uri = "$EcobeeBaseUri/$EcobeeApiVer/thermostat?json=$([Uri]::EscapeDataString($Selection))"

    $Response = Invoke-RestMethod `
        -Uri $Uri `
        -Headers $Connection.Headers `
        -Method Get

    if ($Response.PSObject.Properties["thermostatList"]) {
        return $Response.thermostatList
    }

    return @()

}

#----------------------------------------------------------
# Inventory
#----------------------------------------------------------

function Get-EcobeeInventory {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $Thermostats = Get-EcobeeThermostats -Connection $Connection

    foreach ($Thermostat in $Thermostats) {

        $CurrentTemp = $null
        $HvacMode    = $null
        $SetpointH   = $null
        $SetpointC   = $null

        if ($Thermostat.PSObject.Properties["runtime"]) {
            $RT          = $Thermostat.runtime
            $CurrentTemp = if ($RT.PSObject.Properties["actualTemperature"]) {
                [Math]::Round($RT.actualTemperature / 10, 1)   # ecobee reports in tenths of  degreesF
            } else { $null }
            $SetpointH = if ($RT.PSObject.Properties["desiredHeat"]) {
                [Math]::Round($RT.desiredHeat / 10, 1)
            } else { $null }
            $SetpointC = if ($RT.PSObject.Properties["desiredCool"]) {
                [Math]::Round($RT.desiredCool / 10, 1)
            } else { $null }
        }

        if ($Thermostat.PSObject.Properties["settings"] -and
            $Thermostat.settings.PSObject.Properties["hvacMode"]) {
            $HvacMode = $Thermostat.settings.hvacMode
        }

        #
        # Remote sensors (temperature/occupancy probes)
        #

        $Sensors = @()

        if ($Thermostat.PSObject.Properties["remoteSensors"]) {

            foreach ($Sensor in $Thermostat.remoteSensors) {

                $SensorTemp    = $null
                $SensorOccupy  = $null

                foreach ($Cap in $Sensor.capability) {
                    if ($Cap.type -eq "temperature" -and $Cap.value -ne "unknown") {
                        $SensorTemp = [Math]::Round([int]$Cap.value / 10, 1)
                    }
                    if ($Cap.type -eq "occupancy") {
                        $SensorOccupy = $Cap.value -eq "true"
                    }
                }

                $Sensors += [PSCustomObject]@{
                    SensorId    = $Sensor.id
                    Name        = $Sensor.name
                    Type        = $Sensor.type
                    Temperature = $SensorTemp
                    Occupied    = $SensorOccupy
                }

            }

        }

        [PSCustomObject]@{
            ThermostatId = $Thermostat.identifier
            Name         = $Thermostat.name
            CurrentTemp  = $CurrentTemp
            HvacMode     = $HvacMode
            SetpointHeat = $SetpointH
            SetpointCool = $SetpointC
            Sensors      = $Sensors
            Raw          = $Thermostat
        }

    }

}

#----------------------------------------------------------
# Set HVAC mode
#----------------------------------------------------------

function Set-EcobeeHvacMode {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$ThermostatId,

        [Parameter(Mandatory)]
        [ValidateSet("auto","cool","heat","off","auxHeatOnly")]
        [string]$Mode
    )

    $Body = @{
        selection = @{
            selectionType  = "thermostats"
            selectionMatch = $ThermostatId
        }
        thermostat = @{
            settings = @{
                hvacMode = $Mode
            }
        }
    } | ConvertTo-Json -Depth 10

    Invoke-RestMethod `
        -Uri "$EcobeeBaseUri/$EcobeeApiVer/thermostat" `
        -Headers $Connection.Headers `
        -Method Post `
        -Body $Body

}

Export-ModuleMember `
    -Function Connect-Ecobee,
              Get-EcobeeThermostats,
              Get-EcobeeInventory,
              Set-EcobeeHvacMode
