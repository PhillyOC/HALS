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

function Test-HALSEcobeeConfigured {

    $Path = Join-Path (Get-HALSRoot) "Secrets\OAuth\Ecobee.json"
    if (-not (Test-Path $Path)) { return $false }

    try {
        $Config = Get-Content $Path -Raw | ConvertFrom-Json
        return (
            $Config.PSObject.Properties["Authorized"] -and
            $Config.Authorized
        )
    }
    catch {
        return $false
    }
}

function Initialize-Ecobee {
    if (-not (Get-Command Initialize-HALSEcobeeOAuth -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\Initialize-HALSEcobeeOAuth.psm1") -Force
    }
    Initialize-HALSEcobeeOAuth
}

function Invoke-HALSEcobeeInventory {

    param([Parameter(Mandatory)]$Knowledge)

    if (-not (Get-Command ConvertTo-HALSEcobeeDevice -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSEcobeeDevice.psm1") -Force
    }

    $Connection = Connect-Ecobee
    $Raw = @(Get-EcobeeInventory -Connection $Connection)
    $Devices = @($Raw | ForEach-Object {
        ConvertTo-HALSEcobeeDevice -Device $_ -Knowledge $Knowledge
    } | ForEach-Object { $_ })

    [PSCustomObject]@{
        Devices = $Devices
        Connection = $Connection
        Data = $Raw
    }
}

Export-ModuleMember -Function `
    Test-HALSEcobeeConfigured,
    Initialize-Ecobee,
    Invoke-HALSEcobeeInventory

if (Get-Command Register-HALSDeviceProvider -ErrorAction SilentlyContinue) {
    Register-HALSDeviceProvider `
        -Key "Ecobee" `
        -Name "Ecobee" `
        -TestConfiguredCommand "Test-HALSEcobeeConfigured" `
        -InventoryCommand "Invoke-HALSEcobeeInventory" `
        -SetupCommands @(
            @{ Name = "Initialize-Ecobee"; Description = "Set up Ecobee" }
        ) `
        -Order 60
}
