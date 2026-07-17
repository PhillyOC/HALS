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

function Test-HALSSmartThingsConfigured {

    $Root = Get-HALSRoot
    $PatPath = Join-Path $Root "Secrets\SmartThings.json"
    $OAuthPath = Join-Path $Root "Secrets\OAuth\SmartThings.json"

    if (Test-Path $OAuthPath) {
        try {
            $Config = Get-Content $OAuthPath -Raw | ConvertFrom-Json
            if (($Config.PSObject.Properties["Authorized"] -and $Config.Authorized) -or
                ($Config.PSObject.Properties["AccessToken"] -and
                 -not [string]::IsNullOrWhiteSpace($Config.AccessToken))) {
                return $true
            }
        }
        catch { }
    }

    if (Test-Path $PatPath) {
        try {
            $Config = Get-Content $PatPath -Raw | ConvertFrom-Json
            return -not [string]::IsNullOrWhiteSpace($Config.Token)
        }
        catch { }
    }

    return $false
}

function Initialize-SmartThings {

    Write-Host ""
    Write-Host "HALS SmartThings setup" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] OAuth (recommended)"
    Write-Host "  [2] Personal access token"
    Write-Host ""

    $Choice = (Read-Host "Authentication method [1-2]").Trim()

    if ($Choice -eq "1") {
        if (-not (Get-Command Initialize-HALSSmartThingsOAuth -ErrorAction SilentlyContinue)) {
            Import-Module (Join-Path (Get-HALSRoot) "Core\Initialize-HALSSmartThingsOAuth.psm1") -Force
            Import-Module (Join-Path (Get-HALSRoot) "Core\Complete-HALSSmartThingsOAuth.psm1") -Force
        }
        Initialize-HALSSmartThingsOAuth
        return
    }

    if ($Choice -ne "2") {
        throw "Invalid SmartThings authentication method."
    }

    $Token = (Read-Host "SmartThings personal access token" -MaskInput).Trim()
    if ([string]::IsNullOrWhiteSpace($Token)) {
        throw "SmartThings token cannot be empty."
    }

    $Folder = Join-Path (Get-HALSRoot) "Secrets"
    if (-not (Test-Path $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }

    @{ Token = $Token } |
        ConvertTo-Json |
        Set-Content -Path (Join-Path $Folder "SmartThings.json")

    Write-Host ""
    Write-Host "SmartThings configuration saved." -ForegroundColor Green
    Write-Host ""
}

function Invoke-HALSSmartThingsInventory {

    param([Parameter(Mandatory)]$Knowledge)

    if (-not (Get-Command ConvertTo-HALSSmartThingsDevice -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSSmartThingsDevice.psm1") -Force
    }

    $Connection = Connect-SmartThings
    $Global:HALSSmartThingsConnection = $Connection
    $Raw = @(Get-SmartThingsInventory -Connection $Connection)
    $Devices = @($Raw | ForEach-Object {
        ConvertTo-HALSSmartThingsDevice -Device $_ -Knowledge $Knowledge
    })

    [PSCustomObject]@{
        Devices    = $Devices
        Connection = $Connection
        Data       = $Raw
    }
}

function Get-HALSSmartThingsPermissions {

    param([Parameter(Mandatory)]$Inventory)

    @(
        New-HALSPermission -Provider SmartThings -Name "Read Devices" -Granted $true -Description "Read SmartThings devices."
        New-HALSPermission -Provider SmartThings -Name "Read Rooms" -Granted $true
        New-HALSPermission -Provider SmartThings -Name "Execute Commands" -Granted $true
        New-HALSPermission -Provider SmartThings -Name "Firmware Management" -Granted $false
        New-HALSPermission -Provider SmartThings -Name "Driver Management" -Granted $false
    )
}

Export-ModuleMember -Function `
    Test-HALSSmartThingsConfigured,
    Initialize-SmartThings,
    Invoke-HALSSmartThingsInventory,
    Get-HALSSmartThingsPermissions

if (Get-Command Register-HALSDeviceProvider -ErrorAction SilentlyContinue) {
    Register-HALSDeviceProvider `
        -Key "SmartThings" `
        -Name "SmartThings" `
        -TestConfiguredCommand "Test-HALSSmartThingsConfigured" `
        -InventoryCommand "Invoke-HALSSmartThingsInventory" `
        -CommandCatalogCommand "Get-HALSSmartThingsCommands" `
        -PermissionCatalogCommand "Get-HALSSmartThingsPermissions" `
        -ActionHandlerCommand "Invoke-SmartThingsAction" `
        -SetupCommands @(
            @{ Name = "Initialize-SmartThings"; Description = "Set up SmartThings" }
        ) `
        -Order 20
}
