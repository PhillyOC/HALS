#==========================================================
# HALS - SmartThings Provider
# Version : 0.4.1
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Connect
#----------------------------------------------------------

function Connect-SmartThings {

    #
    # Prefer OAuth.
    # Fall back to the legacy PAT until
    # OAuth authorization has been completed.
    #

    try {

        $AccessToken = Get-HALSOAuthAccessToken `
            -Provider "SmartThings"

        Write-Host "      Using SmartThings OAuth" `
            -ForegroundColor DarkGray

    }
    catch {

        Write-Host "      OAuth unavailable. Using legacy PAT." `
            -ForegroundColor DarkYellow

        $Secrets = Get-Content `
            "$(Get-HALSRoot)\Secrets\SmartThings.json" `
            -Raw |
            ConvertFrom-Json

        if ([string]::IsNullOrWhiteSpace($Secrets.Token)) {

            throw "No SmartThings authentication method is available."

        }

        $AccessToken = $Secrets.Token

    }

    return @{

        Headers = @{

            Authorization = "Bearer $AccessToken"
            Accept        = "application/json"

        }

    }

}

#----------------------------------------------------------
# Devices
#----------------------------------------------------------

function Get-SmartThingsDevices {

    param(

        [Parameter(Mandatory)]
        $Connection

    )

    (
        Invoke-RestMethod `
            -Uri "https://api.smartthings.com/v1/devices" `
            -Headers $Connection.Headers `
            -Method Get
    ).items

}

#----------------------------------------------------------
# Device Status
#----------------------------------------------------------

function Get-SmartThingsDeviceStatus {

    param(

        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$DeviceId

    )

    Invoke-RestMethod `
        -Uri "https://api.smartthings.com/v1/devices/$DeviceId/status" `
        -Headers $Connection.Headers `
        -Method Get

}

#----------------------------------------------------------
# Inventory
#----------------------------------------------------------

function Get-SmartThingsInventory {

    param(

        [Parameter(Mandatory)]
        $Connection

    )

    $Devices = Get-SmartThingsDevices `
        -Connection $Connection

    foreach ($Device in $Devices) {

        $Status = Get-SmartThingsDeviceStatus `
            -Connection $Connection `
            -DeviceId $Device.deviceId

        [PSCustomObject]@{

            Label = if ($Device.PSObject.Properties["label"]) {
                $Device.label
            }
            else {
                ""
            }

            Name = if ($Device.PSObject.Properties["name"]) {
                $Device.name
            }
            else {
                ""
            }

            DeviceId = $Device.deviceId

            Manufacturer = if ($Device.PSObject.Properties["manufacturerName"]) {
                $Device.manufacturerName
            }
            else {
                ""
            }

            Type = if ($Device.PSObject.Properties["type"]) {
                $Device.type
            }
            else {
                ""
            }

            RoomId = if ($Device.PSObject.Properties["roomId"]) {
                $Device.roomId
            }
            else {
                $null
            }

            Status = $Status

        }

    }

}

#----------------------------------------------------------
# Execute Command
#----------------------------------------------------------

function Invoke-SmartThingsCommand {

    param(

        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$DeviceId,

        [Parameter(Mandatory)]
        [string]$Capability,

        [Parameter(Mandatory)]
        [string]$Command,

        [Object[]]$Arguments = @()

    )

    $Body = @{

        commands = @(
            @{

                component  = "main"
                capability = $Capability
                command    = $Command
                arguments  = $Arguments

            }
        )

    }

    Invoke-RestMethod `
        -Uri "https://api.smartthings.com/v1/devices/$DeviceId/commands" `
        -Headers $Connection.Headers `
        -Method Post `
        -ContentType "application/json" `
        -Body ($Body | ConvertTo-Json -Depth 10)

}

Export-ModuleMember `
    -Function Connect-SmartThings,
              Get-SmartThingsDevices,
              Get-SmartThingsDeviceStatus,
              Get-SmartThingsInventory,
              Invoke-SmartThingsCommand
