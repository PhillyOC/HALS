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

    $Root = Get-HALSRoot
    $OAuthPath = Join-Path $Root "Secrets\OAuth\SmartThings.json"
    $PatPath = Join-Path $Root "Secrets\SmartThings.json"

    if (-not (Get-Command Test-HALSOAuthCredentialsConfigured -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force -ErrorAction SilentlyContinue
    }

    $OAuthReady = $false
    if (Test-Path -LiteralPath $OAuthPath) {
        try {
            $OAuthConfig = Get-Content -LiteralPath $OAuthPath -Raw | ConvertFrom-Json
            $OAuthReady = (Test-HALSOAuthCredentialsConfigured -Configuration $OAuthConfig) -and
                (($OAuthConfig.PSObject.Properties["Authorized"] -and $OAuthConfig.Authorized) -or
                 ($OAuthConfig.PSObject.Properties["AccessToken"] -and
                  -not [string]::IsNullOrWhiteSpace([string]$OAuthConfig.AccessToken)))
        }
        catch {
            $OAuthReady = $false
        }
    }

    if ($OAuthReady) {
        try {
            $AccessToken = Get-HALSOAuthAccessToken `
                -Provider "SmartThings"

            Write-Host "      Using SmartThings OAuth" `
                -ForegroundColor DarkGray

            return @{
                Headers = @{
                    Authorization = "Bearer $AccessToken"
                    Accept        = "application/json"
                }
            }
        }
        catch {
            throw "SmartThings OAuth failed: $($_.Exception.Message) Run Reconnect-SmartThingsOAuth or Initialize-SmartThings to reauthorize."
        }
    }

    if (Test-Path -LiteralPath $OAuthPath) {
        throw "SmartThings OAuth is not finished. Run Reconnect-SmartThingsOAuth or Initialize-SmartThings (option 1)."
    }

    if (Test-Path -LiteralPath $PatPath) {

        Write-Host "      Using legacy SmartThings PAT. Run Initialize-SmartThings for OAuth." `
            -ForegroundColor DarkYellow

        $Secrets = Get-Content -LiteralPath $PatPath -Raw | ConvertFrom-Json

        if ([string]::IsNullOrWhiteSpace($Secrets.Token)) {
            throw "SmartThings PAT file exists but Token is empty. Run Initialize-SmartThings."
        }

        return @{
            Headers = @{
                Authorization = "Bearer $($Secrets.Token)"
                Accept        = "application/json"
            }
        }
    }

    throw "SmartThings is not configured. Run Initialize-SmartThings."

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

    if (-not (Get-Command Test-HALSOAuthCredentialsConfigured -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force -ErrorAction SilentlyContinue
    }

    $Root = Get-HALSRoot
    $PatPath = Join-Path $Root "Secrets\SmartThings.json"
    $OAuthPath = Join-Path $Root "Secrets\OAuth\SmartThings.json"

    if (Test-Path $OAuthPath) {
        try {
            $Config = Get-Content $OAuthPath -Raw | ConvertFrom-Json
            if ((Test-HALSOAuthCredentialsConfigured -Configuration $Config) -and
                (($Config.PSObject.Properties["Authorized"] -and $Config.Authorized) -or
                 ($Config.PSObject.Properties["AccessToken"] -and
                  -not [string]::IsNullOrWhiteSpace($Config.AccessToken)))) {
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

function Test-HALSSmartThingsOAuthPending {

    if (-not (Get-Command Test-HALSOAuthCredentialsConfigured -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force -ErrorAction SilentlyContinue
    }

    $OAuthPath = Join-Path (Get-HALSRoot) "Secrets\OAuth\SmartThings.json"
    if (-not (Test-Path -LiteralPath $OAuthPath)) {
        return $false
    }

    try {
        $Config = Get-Content -LiteralPath $OAuthPath -Raw | ConvertFrom-Json
        if (-not (Test-HALSOAuthCredentialsConfigured -Configuration $Config)) {
            return $false
        }

        $Authorized = $Config.PSObject.Properties["Authorized"] -and $Config.Authorized
        $HasToken = $Config.PSObject.Properties["AccessToken"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Config.AccessToken)

        return -not $Authorized -and -not $HasToken
    }
    catch {
        return $false
    }

}

function Restore-SmartThingsOAuth {

    if (-not (Get-Command Start-HALSSmartThingsOAuthLogin -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSSmartThingsOAuth.psm1") -Force
        Import-Module (Join-Path (Get-HALSRoot) "Core\Complete-HALSSmartThingsOAuth.psm1") -Force
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force
    }

    $Configuration = Get-HALSOAuthConfiguration -Provider "SmartThings"
    if (-not (Get-Command Update-HALSSmartThingsOAuthConfiguration -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSSmartThingsOAuth.psm1") -Force -WarningAction SilentlyContinue
    }

    $Configuration = Update-HALSSmartThingsOAuthConfiguration -Configuration $Configuration

    if (-not (Test-HALSOAuthCredentialsConfigured -Configuration $Configuration)) {
        throw "SmartThings OAuth is not configured. Run Initialize-SmartThings first."
    }

    $Configuration.Authorized = $false
    $Configuration.AccessToken = ""
    $Configuration.RefreshToken = ""
    $Configuration.AccessTokenExpires = $null
    Save-HALSOAuthConfiguration -Provider "SmartThings" -Configuration $Configuration

    Write-Host ""
    Write-Host "Re-authorizing SmartThings OAuth..." -ForegroundColor Cyan
    Write-Host ""

    if ($Configuration.PSObject.Properties["CallbackMode"] -and
        [string]$Configuration.CallbackMode -eq "Tunnel") {
        Start-HALSSmartThingsOAuthTunnelLogin -Configuration $Configuration
        return
    }

    Start-HALSSmartThingsOAuthLogin -Configuration $Configuration

}

function Initialize-SmartThings {

    param(
        [switch]$UseTunnel
    )

    Write-Host ""
    Write-Host "HALS SmartThings setup" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  OAuth is the recommended long-term authentication method." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [1] OAuth (recommended)"
    Write-Host "  [2] Personal access token (legacy, expires quickly)"
    Write-Host ""

    $Choice = (Read-Host "Authentication method [1-2] [1]").Trim()
    if ([string]::IsNullOrWhiteSpace($Choice)) {
        $Choice = "1"
    }

    if ($Choice -eq "1") {
        if (-not (Get-Command Initialize-HALSSmartThingsOAuth -ErrorAction SilentlyContinue)) {
            Import-Module (Join-Path (Get-HALSRoot) "Core\Initialize-HALSSmartThingsOAuth.psm1") -Force
            Import-Module (Join-Path (Get-HALSRoot) "Core\Complete-HALSSmartThingsOAuth.psm1") -Force
        }
        Initialize-HALSSmartThingsOAuth -UseTunnel:$UseTunnel
        return
    }

    if ($Choice -ne "2") {
        throw "Invalid SmartThings authentication method."
    }

    $Token = Read-HALSSecretInput `
        -Prompt "SmartThings personal access token" `
        -Hint "Paste the full SmartThings personal access token (legacy; OAuth is recommended)." `
        -MinimumLength 20

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
    Test-HALSSmartThingsOAuthPending,
    Initialize-SmartThings,
    Restore-SmartThingsOAuth,
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
