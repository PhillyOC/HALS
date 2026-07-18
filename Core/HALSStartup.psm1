#==========================================================
# HALS - Startup Display
# Version : 3.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Get-HALSAIProviderRegistry -ErrorAction SilentlyContinue)) {
    Import-Module "$(Get-HALSRoot)\AI\HALSAIProviderRegistry.psm1" -Global
}

function Get-Divider {
    "  " + ("-" * 46)
}

function Get-HALSDeviceProviderSetupCommandName {

    param([Parameter(Mandatory)]$Provider)

    $Setup = @($Provider.SetupCommands) | Select-Object -First 1
    if ($Setup -and $Setup.Name) {
        return [string]$Setup.Name
    }

    return "Initialize-HALSDeviceProvider"
}

#----------------------------------------------------------
# Unified providers panel
# Status on the left, setup command on the right.
#----------------------------------------------------------

function Write-HALSProvidersPanel {

    param(
        $ProviderHealth = $null,
        $AIConfiguration = $null
    )

    if ($null -eq $ProviderHealth -and (Get-Command Get-HALSProviderHealth -ErrorAction SilentlyContinue)) {
        $ProviderHealth = Get-HALSProviderHealth
    }

    if ($null -eq $AIConfiguration -and (Get-Command Get-HALSAIConfiguration -ErrorAction SilentlyContinue)) {
        $AIConfiguration = Get-HALSAIConfiguration -Optional
    }

    $CommandWidth = 28

    Write-Host ""
    Write-Host "  DEVICE PROVIDERS" -ForegroundColor Cyan
    Write-Host (Get-Divider) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("    " + "Initialize-HALSDeviceProvider".PadRight($CommandWidth)) -NoNewline -ForegroundColor White
    Write-Host "Choose a platform to connect" -ForegroundColor DarkGray
    Write-Host ""

    foreach ($Integration in @(Get-HALSDeviceProviders)) {

        $SetupCommand = Get-HALSDeviceProviderSetupCommandName -Provider $Integration
        $Entry = $null
        if ($ProviderHealth -is [hashtable] -or $ProviderHealth -is [System.Collections.IDictionary]) {
            if ($ProviderHealth.ContainsKey($Integration.Key)) {
                $Entry = $ProviderHealth[$Integration.Key]
            }
        }

        $Status = if ($Entry -and $Entry.PSObject.Properties["Status"]) {
            [string]$Entry.Status
        }
        elseif ($Entry -and ($Entry -is [hashtable] -or $Entry -is [System.Collections.IDictionary]) -and $Entry.ContainsKey("Status")) {
            [string]$Entry.Status
        }
        else {
            "NotConfigured"
        }

        if ($Status -eq "Healthy") {
            Write-Host ("    [+] " + $Integration.Name.PadRight(20)) -NoNewline -ForegroundColor Green
            Write-Host ($SetupCommand.PadRight($CommandWidth)) -NoNewline -ForegroundColor DarkGray
            Write-Host "Connected" -ForegroundColor Green
        }
        elseif ($Status -eq "NotConfigured" -or [string]::IsNullOrWhiteSpace($Status)) {
            Write-Host ("    [ ] " + $Integration.Name.PadRight(20)) -NoNewline -ForegroundColor DarkGray
            Write-Host ($SetupCommand.PadRight($CommandWidth)) -NoNewline -ForegroundColor DarkGray
            Write-Host "Not configured" -ForegroundColor DarkGray
        }
        else {
            Write-Host ("    [!] " + $Integration.Name.PadRight(20)) -NoNewline -ForegroundColor Yellow
            Write-Host ($SetupCommand.PadRight($CommandWidth)) -NoNewline -ForegroundColor DarkGray
            Write-Host $Status -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "  AI PROVIDERS" -ForegroundColor Cyan
    Write-Host (Get-Divider) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("    " + "Initialize-HALSAI".PadRight($CommandWidth)) -NoNewline -ForegroundColor White
    Write-Host "Choose an AI provider" -ForegroundColor DarkGray
    Write-Host ("    " + "Switch-HALSAIProvider".PadRight($CommandWidth)) -NoNewline -ForegroundColor DarkGray
    Write-Host "Switch active AI (-Provider <name>)" -ForegroundColor DarkGray
    Write-Host ""

    $ActiveProvider = if ($AIConfiguration -and $AIConfiguration.PSObject.Properties["Provider"]) {
        $AIConfiguration.Provider
    }
    else {
        $null
    }

    foreach ($Provider in @(Get-HALSAIProviderRegistry)) {

        $Config = if ($AIConfiguration -and $AIConfiguration.PSObject.Properties[$Provider.Key]) {
            $AIConfiguration.($Provider.Key)
        }
        else {
            $null
        }

        $Configured = $Config -and
            (Test-HALSAIProviderConfigured -Provider $Provider.Key -Configuration $Config)

        $SetupCommand = $Provider.SetupCommand

        if ($Configured) {
            $HasModel = $Config.PSObject.Properties["Model"] -and
                -not [string]::IsNullOrWhiteSpace([string]$Config.Model)
            $Model = if ($HasModel) { " [$($Config.Model)]" } else { "" }
            $Tag = if ($ActiveProvider -eq $Provider.Key) { " active" } else { "" }

            Write-Host ("    [+] " + $Provider.Name.PadRight(20)) -NoNewline -ForegroundColor Green
            Write-Host ($SetupCommand.PadRight($CommandWidth)) -NoNewline -ForegroundColor DarkGray
            Write-Host ("Ready$Model$Tag") -ForegroundColor $(if ($ActiveProvider -eq $Provider.Key) { "Cyan" } else { "Green" })
        }
        else {
            Write-Host ("    [ ] " + $Provider.Name.PadRight(20)) -NoNewline -ForegroundColor DarkGray
            Write-Host ($SetupCommand.PadRight($CommandWidth)) -NoNewline -ForegroundColor DarkGray
            Write-Host "Not configured" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

# Keep older names as thin wrappers for any callers.
function Write-HALSIntegrationsPanel {

    param([Parameter(Mandatory)]$ProviderHealth)

    Write-HALSProvidersPanel -ProviderHealth $ProviderHealth
}

function Write-HALSAIPanel {

    param([Parameter(Mandatory)]$AIConfiguration)

    # AI block is included in Write-HALSProvidersPanel.
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
            $_.Category -eq "Mobile Phone" -or
            $_.Category -eq "Network Client" -or
            $_.Category -eq "Wireless Client" -or
            $_.Category -eq "Network Access Point" -or
            $_.Category -eq "Network Switch" -or
            $_.Category -eq "Network Infrastructure"
        }
    ).Count

    $Updates = @(
        $Devices | Where-Object { (Get-Domain $_) -eq "update" }
    ).Count

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
    -Function Write-HALSProvidersPanel,
              Write-HALSIntegrationsPanel,
              Write-HALSAIPanel,
              Write-HALSInventorySummary
