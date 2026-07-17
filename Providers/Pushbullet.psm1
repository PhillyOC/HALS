#==========================================================
# HALS - Pushbullet Provider
# Version : 1.0.0
#
# Auth  : OAuth 2.0 authorization_code flow
#         Token endpoint uses JSON body (not form-encoded)
#         Access tokens do not expire on a fixed schedule
# Docs  : https://docs.pushbullet.com/#oauth2
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PushbulletApiBase = "https://api.pushbullet.com/v2"

#----------------------------------------------------------
# Connect
#----------------------------------------------------------

function Connect-Pushbullet {

    $AccessToken = Get-HALSOAuthAccessToken -Provider "Pushbullet"

    return @{
        Headers = @{
            "Access-Token" = $AccessToken
            "Content-Type" = "application/json"
        }
    }

}

#----------------------------------------------------------
# Current User
#----------------------------------------------------------

function Get-PushbulletUser {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    Invoke-RestMethod `
        -Uri "$PushbulletApiBase/users/me" `
        -Headers $Connection.Headers `
        -Method Get

}

#----------------------------------------------------------
# Devices
#----------------------------------------------------------

function Get-PushbulletDevices {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $Response = Invoke-RestMethod `
        -Uri "$PushbulletApiBase/devices" `
        -Headers $Connection.Headers `
        -Method Get

    if ($Response.PSObject.Properties["devices"]) {
        return @($Response.devices | Where-Object { $_.active -eq $true })
    }

    return @()

}

#----------------------------------------------------------
# Send Push (note)
#----------------------------------------------------------

function Send-PushbulletNote {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Body,

        [string]$DeviceIden = ""
    )

    $Payload = @{
        type  = "note"
        title = $Title
        body  = $Body
    }

    if (-not [string]::IsNullOrWhiteSpace($DeviceIden)) {
        $Payload["device_iden"] = $DeviceIden
    }

    Invoke-RestMethod `
        -Uri "$PushbulletApiBase/pushes" `
        -Headers $Connection.Headers `
        -Method Post `
        -Body ($Payload | ConvertTo-Json -Depth 5)

}

#----------------------------------------------------------
# Send Push (link)
#----------------------------------------------------------

function Send-PushbulletLink {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Url,

        [string]$Body       = "",
        [string]$DeviceIden = ""
    )

    $Payload = @{
        type  = "link"
        title = $Title
        url   = $Url
        body  = $Body
    }

    if (-not [string]::IsNullOrWhiteSpace($DeviceIden)) {
        $Payload["device_iden"] = $DeviceIden
    }

    Invoke-RestMethod `
        -Uri "$PushbulletApiBase/pushes" `
        -Headers $Connection.Headers `
        -Method Post `
        -Body ($Payload | ConvertTo-Json -Depth 5)

}

#----------------------------------------------------------
# List recent pushes
#----------------------------------------------------------

function Get-PushbulletPushes {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [int]$Limit = 10
    )

    $Response = Invoke-RestMethod `
        -Uri "$PushbulletApiBase/pushes?active=true&limit=$Limit" `
        -Headers $Connection.Headers `
        -Method Get

    if ($Response.PSObject.Properties["pushes"]) {
        return $Response.pushes
    }

    return @()

}

#----------------------------------------------------------
# Inventory (devices visible to HALSAI)
#----------------------------------------------------------

function Get-PushbulletInventory {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $User    = Get-PushbulletUser    -Connection $Connection
    $Devices = Get-PushbulletDevices -Connection $Connection

    foreach ($Device in $Devices) {

        $Name = ""
        if ($Device.PSObject.Properties["nickname"] -and
            -not [string]::IsNullOrWhiteSpace($Device.nickname)) {
            $Name = $Device.nickname
        }
        elseif ($Device.PSObject.Properties["model"] -and
                -not [string]::IsNullOrWhiteSpace($Device.model)) {
            $Name = $Device.model
        }
        else {
            $Name = $Device.iden
        }

        [PSCustomObject]@{
            DeviceIden   = $Device.iden
            Name         = $Name
            Icon         = if ($Device.PSObject.Properties["icon"])  { $Device.icon  } else { "" }
            Manufacturer = if ($Device.PSObject.Properties["manufacturer"]) { $Device.manufacturer } else { "" }
            Model        = if ($Device.PSObject.Properties["model"]) { $Device.model } else { "" }
            AppVersion   = if ($Device.PSObject.Properties["app_version"]) { $Device.app_version } else { $null }
            HasSms       = if ($Device.PSObject.Properties["has_sms"]) { $Device.has_sms } else { $false }
            AccountEmail = $User.email
            Raw          = $Device
        }

    }

}

Export-ModuleMember `
    -Function Connect-Pushbullet,
              Get-PushbulletUser,
              Get-PushbulletDevices,
              Get-PushbulletInventory,
              Get-PushbulletPushes,
              Send-PushbulletNote,
              Send-PushbulletLink

function Test-HALSPushbulletConfigured {

    $Path = Join-Path (Get-HALSRoot) "Secrets\OAuth\Pushbullet.json"
    if (-not (Test-Path $Path)) { return $false }

    try {
        $Config = Get-Content $Path -Raw | ConvertFrom-Json
        return (
            ($Config.PSObject.Properties["Authorized"] -and $Config.Authorized) -or
            ($Config.PSObject.Properties["AccessToken"] -and
             -not [string]::IsNullOrWhiteSpace($Config.AccessToken))
        )
    }
    catch {
        return $false
    }
}

function Initialize-Pushbullet {
    if (-not (Get-Command Initialize-HALSPushbullet -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\Initialize-HALSPushbullet.psm1") -Force
    }
    Initialize-HALSPushbullet
}

function Invoke-HALSPushbulletInventory {

    param([Parameter(Mandatory)]$Knowledge)

    $Connection = Connect-Pushbullet
    $Raw = @(Get-PushbulletInventory -Connection $Connection)

    [PSCustomObject]@{
        Devices = @()
        Connection = $Connection
        Data = $Raw
    }
}

Export-ModuleMember -Function `
    Test-HALSPushbulletConfigured,
    Initialize-Pushbullet,
    Invoke-HALSPushbulletInventory

if (Get-Command Register-HALSDeviceProvider -ErrorAction SilentlyContinue) {
    Register-HALSDeviceProvider `
        -Key "Pushbullet" `
        -Name "Pushbullet" `
        -TestConfiguredCommand "Test-HALSPushbulletConfigured" `
        -InventoryCommand "Invoke-HALSPushbulletInventory" `
        -SetupCommands @(
            @{ Name = "Initialize-Pushbullet"; Description = "Set up Pushbullet" }
        ) `
        -Order 70
}
