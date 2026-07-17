function Connect-UniFi {
    param(
        [Parameter(Mandatory)]
        [string]$Host,

        [Parameter()]
        [int]$Port = 8443,

        [Parameter()]
        [string]$Site = "default",

        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$Password
    )

    $Body = @{
        username = $Username
        password = $Password
        remember = $true
    } | ConvertTo-Json

    Invoke-RestMethod `
        -Method Post `
        -Uri "https://$Host`:$Port/api/login" `
        -SkipCertificateCheck `
        -ContentType "application/json" `
        -Body $Body `
        -SessionVariable Session | Out-Null

    [PSCustomObject]@{
        Host      = $Host
        Port      = $Port
        Site      = $Site
        Session   = $Session
        Connected = Get-Date
    }
}


Export-ModuleMember -Function Connect-UniFi

function Connect-HALSConfiguredUniFi {

    $Config = $null
    $ConfigPath = Join-Path (Get-HALSRoot) "Secrets\UniFi.json"

    if (Test-Path $ConfigPath) {
        $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    }
    elseif ($env:HALS_UNIFI_HOST -and $env:HALS_UNIFI_USERNAME -and $env:HALS_UNIFI_PASSWORD) {
        $Config = [PSCustomObject]@{
            Host     = $env:HALS_UNIFI_HOST
            Port     = if ($env:HALS_UNIFI_PORT) { [int]$env:HALS_UNIFI_PORT } else { 8443 }
            Site     = if ($env:HALS_UNIFI_SITE) { $env:HALS_UNIFI_SITE } else { "default" }
            Username = $env:HALS_UNIFI_USERNAME
            Password = $env:HALS_UNIFI_PASSWORD
        }
    }
    else {
        return $null
    }

    $Parameters = @{
        Host     = [string]$Config.Host
        Username = [string]$Config.Username
        Password = [string]$Config.Password
        Port     = if ($Config.PSObject.Properties["Port"] -and $Config.Port) { [int]$Config.Port } else { 8443 }
        Site     = if ($Config.PSObject.Properties["Site"] -and $Config.Site) { [string]$Config.Site } else { "default" }
    }

    Connect-UniFi @Parameters
}

Export-ModuleMember -Function Connect-HALSConfiguredUniFi
function Get-UniFiInfrastructure {
    param(
        [Parameter(Mandatory)]
        $Session,

        [Parameter(Mandatory)]
        [string]$Host
    )

    return (Invoke-RestMethod `
        -Method Get `
        -Uri "https://$Host`:8443/api/s/default/stat/device" `
        -WebSession $Session `
        -SkipCertificateCheck).data
}

Export-ModuleMember -Function Get-UniFiInfrastructure
function Get-UniFiClients {
    param(
        [Parameter(Mandatory)]
        $Session,

        [Parameter(Mandatory)]
        [string]$Host
    )

    return (Invoke-RestMethod `
        -Method Get `
        -Uri "https://$Host`:8443/api/s/default/stat/sta" `
        -WebSession $Session `
        -SkipCertificateCheck).data
}

Export-ModuleMember -Function Get-UniFiClients
function ConvertFrom-UniFiClient {
    param(
        [Parameter(Mandatory)]
        $Client
    )

    [PSCustomObject]@{
        Name         = if ($Client.name) { $Client.name } else { $Client.hostname }
        Hostname     = $Client.hostname
        IP           = $Client.ip
        MAC          = $Client.mac
        Manufacturer = $Client.oui
        Source       = "UniFi"
    }
}

Export-ModuleMember -Function ConvertFrom-UniFiClient

function Test-HALSUniFiConfigured {
    $ConfigPath = Join-Path (Get-HALSRoot) "Secrets\UniFi.json"
    (Test-Path $ConfigPath) -or
        ($env:HALS_UNIFI_HOST -and $env:HALS_UNIFI_USERNAME -and $env:HALS_UNIFI_PASSWORD)
}

function Initialize-UniFi {

    $Root = Get-HALSRoot
    $Folder = Join-Path $Root "Secrets"
    $Path = Join-Path $Folder "UniFi.json"

    Write-Host ""
    Write-Host "HALS UniFi setup" -ForegroundColor Cyan
    Write-Host ""

    $HostName = (Read-Host "Controller host").Trim()
    $PortText = (Read-Host "Controller port [8443]").Trim()
    $Site = (Read-Host "Site [default]").Trim()
    $Username = (Read-Host "Username").Trim()
    $Password = Read-Host "Password" -MaskInput

    if ([string]::IsNullOrWhiteSpace($HostName) -or
        [string]::IsNullOrWhiteSpace($Username) -or
        [string]::IsNullOrWhiteSpace($Password)) {
        throw "Host, username, and password are required."
    }

    if ([string]::IsNullOrWhiteSpace($Site)) { $Site = "default" }
    $Port = if ($PortText) { [int]$PortText } else { 8443 }

    $TestConnection = Connect-UniFi `
        -Host $HostName `
        -Port $Port `
        -Site $Site `
        -Username $Username `
        -Password $Password

    if (-not (Test-Path $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }

    @{
        Host     = $HostName
        Port     = $Port
        Site     = $Site
        Username = $Username
        Password = $Password
    } | ConvertTo-Json | Set-Content -Path $Path

    Write-Host ""
    Write-Host "UniFi connected and configuration saved." -ForegroundColor Green
    Write-Host ""

    $TestConnection
}

function Invoke-HALSUniFiInventory {

    param([Parameter(Mandatory)]$Knowledge)

    $Connection = Connect-HALSConfiguredUniFi
    if (-not $Connection) { return [PSCustomObject]@{ Devices = @() } }

    $Infrastructure = @(Get-UniFiInfrastructure -Session $Connection.Session -Host $Connection.Host)
    $Clients = @(Get-UniFiClients -Session $Connection.Session -Host $Connection.Host)
    $Devices = @($Clients | ForEach-Object {
        ConvertTo-HALSDevice -Device $_ -Source UniFi -Knowledge $Knowledge
    })

    [PSCustomObject]@{
        Devices        = $Devices
        Infrastructure = $Infrastructure
        Clients        = $Clients
        Connection     = $Connection
        Data           = $Clients
    }
}

function Get-HALSUniFiPermissions {

    param([Parameter(Mandatory)]$Inventory)

    @(
        New-HALSPermission -Provider UniFi -Name "Read Clients" -Granted $true
        New-HALSPermission -Provider UniFi -Name "Read Infrastructure" -Granted $true
        New-HALSPermission -Provider UniFi -Name "Reconnect Clients" -Granted $false
        New-HALSPermission -Provider UniFi -Name "Restart Devices" -Granted $false
        New-HALSPermission -Provider UniFi -Name "Firmware Management" -Granted $false
    )
}

Export-ModuleMember -Function `
    Test-HALSUniFiConfigured,
    Initialize-UniFi,
    Invoke-HALSUniFiInventory,
    Get-HALSUniFiPermissions

if (Get-Command Register-HALSDeviceProvider -ErrorAction SilentlyContinue) {
    Register-HALSDeviceProvider `
        -Key "UniFi" `
        -Name "UniFi" `
        -TestConfiguredCommand "Test-HALSUniFiConfigured" `
        -InventoryCommand "Invoke-HALSUniFiInventory" `
        -PermissionCatalogCommand "Get-HALSUniFiPermissions" `
        -SetupCommands @(
            @{ Name = "Initialize-UniFi"; Description = "Set up a UniFi controller" }
        ) `
        -Order 10
}
