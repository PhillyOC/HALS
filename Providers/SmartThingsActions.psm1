#==========================================================
# HALS - SmartThings Action Provider
# Version : 3.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command ConvertTo-HALSProviderCommand -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path (Get-HALSRoot) "Core\HALSCommandTranslator.psm1") -Force
}

function Invoke-SmartThingsAction {

    param(

        [Parameter(Mandatory)]
        $Action

    )

    #------------------------------------------------------
    # Find Device
    #------------------------------------------------------

    $Device = $Global:HALSInventory.Devices |
        Where-Object {

            $_.Source -eq "SmartThings" -and
            $_.Name -eq $Action.Device

        } |
        Select-Object -First 1

    if (-not $Device) {
        throw "SmartThings device '$($Action.Device)' was not found."
    }

    if (-not $Device.DeviceId) {
        throw "Device '$($Action.Device)' does not contain a SmartThings DeviceId."
    }

    #------------------------------------------------------
    # Translate HALS Command
    #------------------------------------------------------

    if ($Action.Command -eq "ToggleLight") {
        $SwitchEntity = @($Device.Entities | Where-Object { $_.Name -eq "switch.switch" }) |
            Select-Object -First 1

        if (-not $SwitchEntity) {
            throw "Device '$($Action.Device)' does not expose a switch state."
        }

        $ProviderCommand = [PSCustomObject]@{
            Provider   = "SmartThings"
            Capability = "switch"
            Command    = if ([string]$SwitchEntity.Value -eq "on") { "off" } else { "on" }
            Arguments  = @()
        }
    }
    else {
        $ProviderCommand = ConvertTo-HALSProviderCommand -Action $Action
    }

    #------------------------------------------------------
    # Display
    #------------------------------------------------------

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " SMARTTHINGS ACTION EXECUTOR" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host ("Device".PadRight(15) + ": " + $Device.Name)
    Write-Host ("DeviceId".PadRight(15) + ": " + $Device.DeviceId)
    Write-Host ("HALS".PadRight(15) + ": " + $Action.Command)
    Write-Host ("Capability".PadRight(15) + ": " + $ProviderCommand.Capability)
    Write-Host ("Command".PadRight(15) + ": " + $ProviderCommand.Command)

    Write-Host ""
    Write-Host "Executing SmartThings command..." -ForegroundColor Yellow

    #------------------------------------------------------
    # Execute
    #------------------------------------------------------

    try {

        if (-not (Test-Path variable:global:HALSSmartThingsConnection) -or
            -not $Global:HALSSmartThingsConnection) {
            $Global:HALSSmartThingsConnection = Connect-SmartThings
        }

        $Result = Invoke-SmartThingsCommand `
            -Connection $Global:HALSSmartThingsConnection `
            -DeviceId $Device.DeviceId `
            -Capability $ProviderCommand.Capability `
            -Command $ProviderCommand.Command `
            -Arguments $ProviderCommand.Arguments

        Write-Host ""
        Write-Host "SUCCESS" -ForegroundColor Green

        return $Result

    }

    catch {

        Write-Host ""
        Write-Host "FAILED" -ForegroundColor Red
        Write-Host ""

        Write-Host $_.Exception.Message -ForegroundColor Yellow

        throw

    }

}

function Get-HALSSmartThingsCommands {
    @(
        New-HALSCommand -Name TurnOnLight -Provider SmartThings -Description "Turn on a light."
        New-HALSCommand -Name TurnOffLight -Provider SmartThings -Description "Turn off a light."
        New-HALSCommand -Name ToggleLight -Provider SmartThings -Description "Toggle a light."
        New-HALSCommand -Name SetBrightness -Provider SmartThings -Description "Set light brightness 0-100. Required parameter: Brightness (integer)."
        New-HALSCommand -Name SetColor -Provider SmartThings -Description "Set light color. Required parameter: Color (CSS color name)."
        New-HALSCommand -Name SetColorTemperature -Provider SmartThings -Description "Set color temperature in Kelvin. Required parameter: ColorTemperature (integer)."
        New-HALSCommand -Name ActivateSiren -Provider SmartThings -Description "Activate siren." -Risk Medium
        New-HALSCommand -Name DeactivateSiren -Provider SmartThings -Description "Deactivate siren."
    )
}

Export-ModuleMember -Function Invoke-SmartThingsAction, Get-HALSSmartThingsCommands