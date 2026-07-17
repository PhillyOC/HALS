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
