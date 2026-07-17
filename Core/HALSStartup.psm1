#==========================================================
# HALS - Startup Display
# Version : 2.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Get-HALSAIProviderRegistry -ErrorAction SilentlyContinue)) {
    Import-Module "$(Get-HALSRoot)\AI\HALSAIProviderRegistry.psm1" -Global
}

#----------------------------------------------------------
# Helper
#----------------------------------------------------------

function Get-Divider {
    "  " + ("-" * 46)
}

#----------------------------------------------------------
# Integrations Panel
#----------------------------------------------------------

function Write-HALSIntegrationsPanel {

    param(
        [Parameter(Mandatory)]
        $ProviderHealth
    )

    Write-Host ""
    Write-Host "  INTEGRATIONS" -ForegroundColor Cyan
    Write-Host (Get-Divider) -ForegroundColor DarkGray
    Write-Host ""

    foreach ($Integration in @(Get-HALSDeviceProviders)) {

        $Entry  = $ProviderHealth[$Integration.Key]

        if ($null -eq $Entry) {
            # Not configured -- show as not configured placeholder
            Write-Host ("    [ ] " + $Integration.Name.PadRight(22)) -NoNewline -ForegroundColor DarkGray
            Write-Host "Not configured" -ForegroundColor DarkGray
            continue
        }

        $Status = $Entry.Status

        if ($Status -eq "NotConfigured") {
            Write-Host ("    [ ] " + $Integration.Name.PadRight(22)) -NoNewline -ForegroundColor DarkGray
            Write-Host "Not configured" -ForegroundColor DarkGray
        }
        elseif ($Status -eq "Healthy") {
            Write-Host ("    [+] " + $Integration.Name.PadRight(22)) -NoNewline -ForegroundColor Green
            Write-Host "Connected" -ForegroundColor Green
        }
        else {
            Write-Host ("    [!] " + $Integration.Name.PadRight(22)) -NoNewline -ForegroundColor Yellow
            Write-Host $Status -ForegroundColor Yellow
        }

    }

    Write-Host ""

}

#----------------------------------------------------------
# AI Providers Panel
#
# Iterates the providers exposed by the AI registry.
#----------------------------------------------------------

function Write-HALSAIPanel {

    param(
        [Parameter(Mandatory)]
        $AIConfiguration
    )

    Write-Host "  AI PROVIDERS" -ForegroundColor Cyan
    Write-Host (Get-Divider) -ForegroundColor DarkGray
    Write-Host ""

    $ActiveProvider = $AIConfiguration.Provider

    foreach ($Provider in @(Get-HALSAIProviderRegistry)) {

        $Config = if ($AIConfiguration.PSObject.Properties[$Provider.Key]) {
            $AIConfiguration.($Provider.Key)
        }
        else {
            $null
        }

        $HasModel = $Config -and
            $Config.PSObject.Properties["Model"] -and
            -not [string]::IsNullOrWhiteSpace($Config.Model)

        $Configured = $Config -and
            (Test-HALSAIProviderConfigured -Provider $Provider.Key -Configuration $Config)

        if ($Configured) {

            $IsActive = $ActiveProvider -eq $Provider.Key
            $Model    = if ($HasModel) { "  [$($Config.Model)]" } else { "" }
            $Tag      = if ($IsActive) { "  active" } else { "" }

            Write-Host ("    [+] " + $Provider.Name.PadRight(22)) -NoNewline -ForegroundColor Green
            Write-Host ("Ready" + $Model + $Tag) -ForegroundColor $(if ($IsActive) { "Cyan" } else { "Green" })

        }
        else {

            Write-Host ("    [ ] " + $Provider.Name.PadRight(22)) -NoNewline -ForegroundColor DarkGray
            Write-Host "Not configured" -ForegroundColor DarkGray

        }

    }

    Write-Host ""

}

#----------------------------------------------------------
# Inventory Summary Panel
#----------------------------------------------------------

function Write-HALSInventorySummary {

    param(
        [Parameter(Mandatory)]
        $Inventory
    )

    Write-Host "  HOME OVERVIEW" -ForegroundColor Cyan
    Write-Host (Get-Divider) -ForegroundColor DarkGray
    Write-Host ""

    $Devices = @($Inventory.Devices)

    #
    # Domain is optional provider metadata. Guard access so
    # providers without it remain compatible under StrictMode.
    #

    function Get-Domain ($Device) {
        if ($Device.PSObject.Properties["Domain"]) { return $Device.Domain }
        return ""
    }

    $Lights = @(
        $Devices | Where-Object {
            $_.Category -eq "Light Bulb" -or (Get-Domain $_) -eq "light"
        }
    ).Count

    $Sensors = @(
        $Devices | Where-Object {
            $_.Category -eq "Sensor" -or
            (Get-Domain $_) -eq "sensor" -or
            (Get-Domain $_) -eq "binary_sensor"
        }
    ).Count

    $Switches = @(
        $Devices | Where-Object { (Get-Domain $_) -eq "switch" }
    ).Count

    $Scenes = @(
        $Devices | Where-Object { (Get-Domain $_) -eq "scene" }
    ).Count

    $MediaPlayers = @(
        $Devices | Where-Object {
            $_.Category -eq "Television" -or
            $_.Category -eq "Streaming Device" -or
            $_.Category -eq "Smart Assistant" -or
            (Get-Domain $_) -eq "media_player"
        }
    ).Count

    $Locks = @(
        $Devices | Where-Object { (Get-Domain $_) -eq "lock" }
    ).Count

    $Cameras = @(
        $Devices | Where-Object { (Get-Domain $_) -eq "camera" }
    ).Count

    $Hubs = @(
        $Devices | Where-Object { $_.Category -eq "Home Automation" }
    ).Count

    $NetworkDevices = @(
        $Devices | Where-Object {
            $_.Category -eq "Firewall" -or
            $_.Category -eq "Workstation" -or
            $_.Category -eq "Mobile Phone"
        }
    ).Count

    $Updates = @(
        $Devices | Where-Object { (Get-Domain $_) -eq "update" }
    ).Count

    #
    # Two-column display - only rows with count > 0
    #

    $Rows = @(
        @{ Label = "Lights";          Count = $Lights        }
        @{ Label = "Sensors";         Count = $Sensors       }
        @{ Label = "Switches";        Count = $Switches      }
        @{ Label = "Scenes";          Count = $Scenes        }
        @{ Label = "Media Players";   Count = $MediaPlayers  }
        @{ Label = "Cameras";         Count = $Cameras       }
        @{ Label = "Locks";           Count = $Locks         }
        @{ Label = "Hubs";            Count = $Hubs          }
        @{ Label = "Network Devices"; Count = $NetworkDevices}
        @{ Label = "Pending Updates"; Count = $Updates       }
    ) | Where-Object { $_.Count -gt 0 }

    $ColWidth = 30
    $i = 0

    foreach ($Row in $Rows) {

        $Cell = ("    " + ([string]$Row.Count).PadLeft(3) + "  " + $Row.Label).PadRight($ColWidth)

        if ($i % 2 -eq 0) {
            Write-Host $Cell -NoNewline -ForegroundColor White
        }
        else {
            Write-Host $Cell -ForegroundColor White
        }

        $i++

    }

    if ($i % 2 -ne 0) { Write-Host "" }

    #
    # Network infrastructure summary line
    #

    Write-Host ""

    $GW  = @($Inventory.Infrastructure | Where-Object Type -eq "ugw").Count
    $APs = @($Inventory.Infrastructure | Where-Object Type -eq "uap").Count
    $SW  = @($Inventory.Infrastructure | Where-Object Type -eq "usw").Count
    $CL  = @($Inventory.Clients).Count

    $NetLine = "    Network  $GW gateway  *  $APs access point$(if($APs -ne 1){'s'})  *  $SW switch$(if($SW -ne 1){'es'})  *  $CL client$(if($CL -ne 1){'s'})"
    Write-Host $NetLine -ForegroundColor DarkCyan

    Write-Host ""

}

Export-ModuleMember `
    -Function Write-HALSIntegrationsPanel,
              Write-HALSAIPanel,
              Write-HALSInventorySummary
