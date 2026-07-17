#==========================================================
# HALS - Core Module
# Version : 0.6.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SnapshotFolder = "$(Get-HALSRoot)\Snapshots"

#
# HA domains that represent physical or controllable devices.
# All other domains (automation, sensor, binary_sensor, sun,
# update, backup, person, script, scene, etc.) are silently
# skipped in the New Device wizard - they are not things a
# user would want to name or categorize manually.
#
$WizardDomains = @(
    "light"
    "switch"
    "lock"
    "fan"
    "climate"
    "cover"
    "media_player"
    "vacuum"
    "camera"
    "alarm_control_panel"
    "humidifier"
    "water_heater"
)

#----------------------------------------------------------
# Status
#----------------------------------------------------------

function Get-HALSStatus {

    param(
        [Parameter(Mandatory)]$Infrastructure,
        [Parameter(Mandatory)]$Clients
    )

    $Gateways = @($Infrastructure | Where-Object Type -eq "ugw")
    $APs      = @($Infrastructure | Where-Object Type -eq "uap")
    $Switches = @($Infrastructure | Where-Object Type -eq "usw")
    $Clients  = @($Clients)

    [PSCustomObject]@{
        Gateway      = $Gateways.Count
        AccessPoints = $APs.Count
        Switches     = $Switches.Count
        Clients      = $Clients.Count
        Generated    = Get-Date
    }

}

#----------------------------------------------------------
# Snapshot - Save
#----------------------------------------------------------

function Save-HALSSnapshot {

    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Devices
    )

    if (!(Test-Path $SnapshotFolder)) {
        New-Item -ItemType Directory -Force -Path $SnapshotFolder | Out-Null
    }

    $File = Join-Path $SnapshotFolder (
        (Get-Date).ToString("yyyy-MM-dd_HHmmss") + ".json"
    )

    $Json = ConvertTo-Json -InputObject @($Devices) -Depth 10
    Set-Content -Path $File -Value $Json

    return $File

}

#----------------------------------------------------------
# Snapshot - List
#----------------------------------------------------------

function Get-HALSSnapshots {

    if (!(Test-Path $SnapshotFolder)) {
        return @()
    }

    @(Get-ChildItem $SnapshotFolder -Filter *.json |
        Sort-Object LastWriteTime -Descending)

}

#----------------------------------------------------------
# Snapshot - Compare
#----------------------------------------------------------

function Compare-HALSSnapshots {

    $Snapshots = @(Get-HALSSnapshots)

    if ($Snapshots.Count -lt 2) {
        Write-Host ""
        Write-Host "Need at least two snapshots." -ForegroundColor Yellow
        return
    }

    $Current  = Get-Content $Snapshots[0].FullName -Raw | ConvertFrom-Json
    $Previous = Get-Content $Snapshots[1].FullName -Raw | ConvertFrom-Json

    $PreviousByMAC = @{}

    foreach ($Device in $Previous) {
        $PreviousByMAC[$Device.MAC] = $Device
    }

    Write-Host ""
    Write-Host "Changes Since Previous Snapshot" -ForegroundColor Cyan
    Write-Host "==============================="

    foreach ($Device in $Current) {

        if (-not $PreviousByMAC.ContainsKey($Device.MAC)) {

            #
            # Skip provider entities that expose a non-controllable domain
            # but no network identity.
            #
            if (
                $Device.PSObject.Properties["Domain"] -and
                (-not $Device.PSObject.Properties["IP"] -or
                 [string]::IsNullOrWhiteSpace($Device.IP)) -and
                $Device.Domain -notin $WizardDomains
            ) {
                $PreviousByMAC.Remove($Device.MAC)
                continue
            }

            Write-Host ""
            Write-Host "+ NEW DEVICE" -ForegroundColor Green
            Write-Host "  $($Device.Name)"

            continue

        }

        $Old = $PreviousByMAC[$Device.MAC]

        if ($Old.IP -ne $Device.IP -and
            -not [string]::IsNullOrWhiteSpace($Device.IP)) {

            Write-Host ""
            Write-Host "~ IP CHANGED" -ForegroundColor Yellow
            Write-Host "  $($Device.Name)"
            Write-Host "  $($Old.IP) -> $($Device.IP)"

        }

        $PreviousByMAC.Remove($Device.MAC)

    }

    foreach ($Device in $PreviousByMAC.Values) {

        #
        # Same generic filter for non-physical provider entities.
        #
        if (
            $Device.PSObject.Properties["Domain"] -and
            (-not $Device.PSObject.Properties["IP"] -or
             [string]::IsNullOrWhiteSpace($Device.IP)) -and
            $Device.Domain -notin $WizardDomains
        ) {
            continue
        }

        Write-Host ""
        Write-Host "- DEVICE MISSING" -ForegroundColor Red
        Write-Host "  $($Device.Name)"

    }

    Write-Host ""
    Write-Host "Comparison complete." -ForegroundColor Green

}

#----------------------------------------------------------
# Discovery Wizard
#----------------------------------------------------------

function Invoke-HALSDiscovery {

    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Devices
    )

    $Unknown = @(
        $Devices | Where-Object {
            -not $_.Known -and (
                -not $_.PSObject.Properties["Domain"] -or
                $WizardDomains -contains $_.Domain
            )
        }
    )

    if ($Unknown.Count -eq 0) {
        return
    }

    foreach ($Device in $Unknown) {

        Write-Host ""
        Write-Host "===================================" -ForegroundColor Cyan
        Write-Host "New Device Found"                   -ForegroundColor Yellow
        Write-Host "===================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Current Name : $($Device.Name)"
        Write-Host "Category     : $($Device.Category)"
        Write-Host "IP           : $($Device.IP)"
        Write-Host "MAC          : $($Device.MAC)"
        Write-Host ""

        do {

            $Choice = (Read-Host "[U] Use current name   [R] Rename   [S] Skip").Trim().ToUpper()

        } until ($Choice -in @("U","R","S"))

        if ($Choice -eq "S") {

            Write-Host "Skipped." -ForegroundColor Yellow
            continue

        }

        $FriendlyName = $Device.Name

        if ($Choice -eq "R") {

            $FriendlyName = Read-Host "New Friendly Name"

            if ([string]::IsNullOrWhiteSpace($FriendlyName)) {

                $FriendlyName = $Device.Name

            }

        }

        $Device.Name  = $FriendlyName
        $Device.Known = $true

        #
        # Save immediately so progress is never lost if a later
        # device fails or the script is interrupted.
        #
        Add-HALSKnownDevice `
            -MAC          $Device.MAC `
            -FriendlyName $FriendlyName `
            -Category     $Device.Category

        Write-Host "Accepted." -ForegroundColor Green

    }

}

Export-ModuleMember `
    -Function Get-HALSStatus,
              Save-HALSSnapshot,
              Get-HALSSnapshots,
              Compare-HALSSnapshots,
              Invoke-HALSDiscovery
