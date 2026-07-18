#==========================================================
# HALS - Inventory Module
# Version : 0.8.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSInventory {

    $Knowledge = Get-HALSKnowledge

    $Infrastructure = @()
    $Clients = @()
    $Devices = @()
    $ProviderData = @{}

    foreach ($Provider in @(Get-HALSDeviceProviders)) {

        try {
            if (-not (Test-HALSDeviceProviderConfigured -Provider $Provider)) {
                $PendingMessage = "$($Provider.Name) is not configured."
                if ($Provider.Key -eq "SmartThings" -and
                    (Get-Command Test-HALSSmartThingsOAuthPending -ErrorAction SilentlyContinue) -and
                    (Test-HALSSmartThingsOAuthPending)) {
                    $PendingMessage = "$($Provider.Name) OAuth is not finished. Run Reconnect-SmartThingsOAuth."
                }

                Set-HALSProviderHealth `
                    -Provider $Provider.Key `
                    -Status "NotConfigured" `
                    -Message $PendingMessage

                if ($Provider.Key -eq "SmartThings" -and $PendingMessage -match "Reconnect-SmartThingsOAuth") {
                    Write-Host "  [ ] $PendingMessage" -ForegroundColor Yellow
                }
                else {
                    Write-Host "  [ ] $($Provider.Name) not configured; skipping." -ForegroundColor DarkGray
                }
                continue
            }

            Write-Host "  [+] Connecting to $($Provider.Name)..." -ForegroundColor DarkGray

            $ProviderInventory = Invoke-HALSDeviceProviderInventory `
                -Provider $Provider `
                -Knowledge $Knowledge

            if ($null -ne $ProviderInventory) {
                if ($ProviderInventory.PSObject.Properties["Devices"]) {
                    $Devices += @($ProviderInventory.Devices)
                }

                if ($ProviderInventory.PSObject.Properties["Infrastructure"]) {
                    $Infrastructure += @($ProviderInventory.Infrastructure)
                }

                if ($ProviderInventory.PSObject.Properties["Clients"]) {
                    $Clients += @($ProviderInventory.Clients)
                }

                if ($ProviderInventory.PSObject.Properties["Data"]) {
                    $ProviderData[$Provider.Key] = $ProviderInventory.Data
                }
            }

            Record-HALSProviderHealth `
                -Provider $Provider.Key `
                -Status "Healthy"

            Write-Host "      $($Provider.Name) OK" -ForegroundColor Green
        }
        catch {
            Record-HALSProviderHealth `
                -Provider $Provider.Key `
                -Status "Offline" `
                -Message $_.Exception.Message

            Write-Warning "$($Provider.Name) failed."
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }
    }

    $Assets = @(Merge-HALSAssets -Devices @($Devices))

    [PSCustomObject]@{
        Devices        = @($Devices)
        Assets         = $Assets
        Infrastructure = @($Infrastructure)
        Clients        = @($Clients)
        ProviderData   = $ProviderData
    }
}

Export-ModuleMember -Function Get-HALSInventory
