#==========================================================
# HALS - SmartThings Action Provider
# Version : 3.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-SmartThingsAction {

    param(

        [Parameter(Mandatory)]
        $Action

    )

    #------------------------------------------------------
    # Translate HALS Command
    #------------------------------------------------------

    $ProviderCommand = ConvertTo-HALSProviderCommand `
        -Action $Action

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

Export-ModuleMember -Function Invoke-SmartThingsAction