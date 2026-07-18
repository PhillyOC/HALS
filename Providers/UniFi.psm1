Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

    # Accept host, host:port, or full https://host:port URLs.
    $NormalizedHost = $Host.Trim()
    $NormalizedPort = $Port

    if ($NormalizedHost -match '^(?i)https?://') {
        $Uri = [Uri]$NormalizedHost
        $NormalizedHost = $Uri.Host
        if (-not $Uri.IsDefaultPort -and $Uri.Port -gt 0) {
            $NormalizedPort = $Uri.Port
        }
    }
    elseif ($NormalizedHost -match '^(?<name>[^:/]+):(?<port>\d+)$') {
        $NormalizedHost = $Matches.name
        $NormalizedPort = [int]$Matches.port
    }

    $NormalizedHost = $NormalizedHost.TrimEnd('/')

    $Body = @{
        username = $Username
        password = $Password
        remember = $true
    } | ConvertTo-Json

    Invoke-RestMethod `
        -Method Post `
        -Uri "https://${NormalizedHost}:${NormalizedPort}/api/login" `
        -SkipCertificateCheck `
        -ContentType "application/json" `
        -Body $Body `
        -SessionVariable Session |
        Out-Null

    if (-not $Session) {
        throw "UniFi login failed for ${NormalizedHost}:${NormalizedPort}."
    }

    [PSCustomObject]@{
        Host      = $NormalizedHost
        Port      = $NormalizedPort
        Site      = $Site
        Session   = $Session
        Username  = $Username
        Password  = $Password
        Connected = Get-Date
    }
}


Export-ModuleMember -Function Connect-UniFi

function Resolve-UniFiSiteName {

    param(
        [Parameter(Mandatory)]
        [string]$Site,

        [Parameter(Mandatory)]
        [string]$HostName
    )

    $Resolved = $Site.Trim()
    if ([string]::IsNullOrWhiteSpace($Resolved)) {
        $Resolved = "default"
    }

    if ($Resolved -eq $HostName) {
        return "default"
    }

    return $Resolved

}

function Get-UniFiSites {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $HostName = [string]$Connection.Host
    $Port = if ($Connection.PSObject.Properties["Port"] -and $Connection.Port) {
        [int]$Connection.Port
    }
    else {
        8443
    }

    $Response = Invoke-RestMethod `
        -Method Get `
        -Uri "https://${HostName}:${Port}/api/self/sites" `
        -WebSession $Connection.Session `
        -SkipCertificateCheck

    if ($Response.PSObject.Properties["data"]) {
        return @($Response.data)
    }

    if ($Response -is [System.Collections.IEnumerable] -and -not ($Response -is [string])) {
        return @($Response)
    }

    return @()

}

function Test-UniFiControllerAccess {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    try {
        $null = Get-UniFiClients -Connection $Connection
        return $true
    }
    catch {
        $Message = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $Message = $_.ErrorDetails.Message
        }

        $Site = if ($Connection.PSObject.Properties["Site"]) { $Connection.Site } else { "default" }
        throw "UniFi site '$Site' is not accessible after login. Choose the site slug from your controller URL (for example /manage/default/dashboard means site 'default'). $Message"
    }

}

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
        Site     = Resolve-UniFiSiteName `
            -Site (if ($Config.PSObject.Properties["Site"] -and $Config.Site) { [string]$Config.Site } else { "default" }) `
            -HostName [string]$Config.Host
    }

    Connect-UniFi @Parameters
}

Export-ModuleMember -Function Connect-HALSConfiguredUniFi

function Get-UniFiApiBase {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $HostName = [string]$Connection.Host
    $Port = if ($Connection.PSObject.Properties["Port"] -and $Connection.Port) {
        [int]$Connection.Port
    }
    else {
        8443
    }

    $Site = if ($Connection.PSObject.Properties["Site"] -and $Connection.Site) {
        Resolve-UniFiSiteName -Site [string]$Connection.Site -HostName [string]$Connection.Host
    }
    else {
        "default"
    }

    return "https://${HostName}:${Port}/api/s/$Site"
}

function Get-UniFiInfrastructure {
    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $BaseUri = Get-UniFiApiBase -Connection $Connection

    return (Invoke-RestMethod `
        -Method Get `
        -Uri "$BaseUri/stat/device" `
        -WebSession $Connection.Session `
        -SkipCertificateCheck).data
}

Export-ModuleMember -Function Get-UniFiApiBase, Get-UniFiInfrastructure
function Get-UniFiClients {
    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $BaseUri = Get-UniFiApiBase -Connection $Connection

    return (Invoke-RestMethod `
        -Method Get `
        -Uri "$BaseUri/stat/sta" `
        -WebSession $Connection.Session `
        -SkipCertificateCheck).data
}

Export-ModuleMember -Function Get-UniFiClients
function ConvertFrom-UniFiClient {
    param(
        [Parameter(Mandatory)]
        $Client
    )

    $Name = if ($Client.name) { $Client.name } elseif ($Client.hostname) { $Client.hostname } else { "UniFi Client" }

    $Category = "Network Client"
    if ($Client.PSObject.Properties["is_wired"] -and -not $Client.is_wired) {
        $Category = "Wireless Client"
    }

    [PSCustomObject]@{
        Name         = $Name
        Hostname     = $Client.hostname
        IP           = $Client.ip
        MAC          = $Client.mac
        Manufacturer = $Client.oui
        Category     = $Category
        Source       = "UniFi"
    }
}

function ConvertFrom-UniFiInfrastructureDevice {

    param(
        [Parameter(Mandatory)]
        $Device
    )

    $Category = switch ([string]$Device.type) {
        "ugw" { "Firewall" }
        "uap" { "Network Access Point" }
        "usw" { "Network Switch" }
        default { "Network Infrastructure" }
    }

    $Name = if ($Device.name) { $Device.name } else { "$Category" }

    [PSCustomObject]@{
        Name         = $Name
        Hostname     = $Device.name
        IP           = $Device.ip
        MAC          = $Device.mac
        Manufacturer = "Ubiquiti"
        Category     = $Category
        Source       = "UniFi"
    }
}

Export-ModuleMember -Function ConvertFrom-UniFiClient, ConvertFrom-UniFiInfrastructureDevice

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
    Write-Host "Enter the controller hostname or IP only (not the full dashboard URL)." -ForegroundColor DarkGray
    Write-Host "Example host: unifi-cloudkey" -ForegroundColor DarkGray
    Write-Host ""

    do {
        $HostName = (Read-Host "Controller host").Trim().Trim('"').Trim("'")
        if (-not (Test-HALSNetworkHostInput -HostName $HostName)) {
            Write-Host "Enter a hostname or IP only (for example unifi-cloudkey)." -ForegroundColor Yellow
            Write-Host "Do not paste a file path, JSON file, or full URL." -ForegroundColor Gray
        }
    } while (-not (Test-HALSNetworkHostInput -HostName $HostName))
    $PortText = (Read-Host "Controller port [8443]").Trim()
    $Username = (Read-Host "Username").Trim()
    $Password = Read-Host "Password" -MaskInput

    if ([string]::IsNullOrWhiteSpace($HostName) -or
        [string]::IsNullOrWhiteSpace($Username) -or
        [string]::IsNullOrWhiteSpace($Password)) {
        throw "Host, username, and password are required."
    }

    $Port = if ($PortText) { [int]$PortText } else { 8443 }

    try {
        $Login = Connect-UniFi `
            -Host $HostName `
            -Port $Port `
            -Site "default" `
            -Username $Username `
            -Password $Password
    }
    catch {
        Write-Host ""
        Write-Host "UniFi login failed. Configuration was not saved." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor DarkGray
        Write-Host "Tip: enter just the hostname or IP (for example unifi-cloudkey), not a full URL." -ForegroundColor DarkGray
        Write-Host ""
        throw
    }

    $Sites = @(Get-UniFiSites -Connection $Login)
    $Site = "default"

    if ($Sites.Count -gt 0) {

        Write-Host ""
        Write-Host "Available UniFi sites:" -ForegroundColor Yellow

        for ($Index = 0; $Index -lt $Sites.Count; $Index++) {
            $Entry = $Sites[$Index]
            $Slug = if ($Entry.PSObject.Properties["name"]) { [string]$Entry.name } else { [string]$Entry }
            $Desc = if ($Entry.PSObject.Properties["desc"] -and $Entry.desc) { " ($($Entry.desc))" } else { "" }
            Write-Host ("  [{0}] {1}{2}" -f ($Index + 1), $Slug, $Desc) -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "Site is the slug from your controller URL." -ForegroundColor DarkGray
        Write-Host "Example: https://unifi-cloudkey:8443/manage/default/dashboard -> site 'default'" -ForegroundColor DarkGray
        Write-Host ""

        $DefaultIndex = 1
        for ($Index = 0; $Index -lt $Sites.Count; $Index++) {
            if ($Sites[$Index].PSObject.Properties["name"] -and
                [string]$Sites[$Index].name -eq "default") {
                $DefaultIndex = $Index + 1
                break
            }
        }

        $SiteChoice = (Read-Host "Choose site [1-$($Sites.Count)] (default $DefaultIndex)").Trim()
        if ([string]::IsNullOrWhiteSpace($SiteChoice)) {
            $SiteChoice = [string]$DefaultIndex
        }

        if ($SiteChoice -match '^\d+$') {
            $Idx = [int]$SiteChoice
            if ($Idx -ge 1 -and $Idx -le $Sites.Count) {
                $Site = [string]$Sites[$Idx - 1].name
            }
        }
        else {
            $Site = Resolve-UniFiSiteName -Site $SiteChoice -HostName $Login.Host
        }

    }
    else {

        Write-Host ""
        Write-Host "Could not list sites automatically." -ForegroundColor DarkYellow
        Write-Host "Enter the site slug from your controller URL (usually 'default')." -ForegroundColor DarkGray
        Write-Host ""

        $SiteInput = (Read-Host "Site [default]").Trim()
        $Site = Resolve-UniFiSiteName `
            -Site $(if ([string]::IsNullOrWhiteSpace($SiteInput)) { "default" } else { $SiteInput }) `
            -HostName $Login.Host

    }

    $Login.Site = $Site

    try {
        $null = Test-UniFiControllerAccess -Connection $Login
    }
    catch {
        Write-Host ""
        Write-Host "UniFi login succeeded, but inventory access failed." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor DarkGray
        Write-Host ""
        throw
    }

    if (-not (Test-Path $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }

    @{
        Host     = $Login.Host
        Port     = $Login.Port
        Site     = $Site
        Username = $Username
        Password = $Password
    } | ConvertTo-Json | Set-Content -Path $Path

    Write-Host ""
    Write-Host "UniFi connected and configuration saved." -ForegroundColor Green
    Write-Host "  Site: $Site" -ForegroundColor DarkGray
    Write-Host ""

    $Login
}

function Invoke-HALSUniFiInventory {

    param([Parameter(Mandatory)]$Knowledge)

    $Connection = Connect-HALSConfiguredUniFi
    if (-not $Connection) { return [PSCustomObject]@{ Devices = @() } }

    $Infrastructure = @(Get-UniFiInfrastructure -Connection $Connection)
    $Clients = @(Get-UniFiClients -Connection $Connection)
    $Devices = @()

    $Devices += @($Clients | ForEach-Object {
        ConvertTo-HALSDevice -Device (ConvertFrom-UniFiClient -Client $_) -Source UniFi -Knowledge $Knowledge
    })

    $Devices += @($Infrastructure | ForEach-Object {
        ConvertTo-HALSDevice -Device (ConvertFrom-UniFiInfrastructureDevice -Device $_) -Source UniFi -Knowledge $Knowledge
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
    Get-HALSUniFiPermissions,
    Resolve-UniFiSiteName

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
