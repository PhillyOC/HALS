#==========================================================
# HALS - Philips Hue Setup Wizard
# Version : 1.0.0
#
# Hue uses a local bridge API. Auth is a one-time button
# press on the bridge to generate a username token.
# No cloud account or OAuth required.
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-HALSPhilipsHue {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS PHILIPS HUE SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    #----------------------------------------------------------
    # Step 1: Bridge IP
    #----------------------------------------------------------

    Write-Host "Step 1 : Locate your Hue Bridge IP address." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Options:" -ForegroundColor Gray
    Write-Host "           - Check your router's DHCP table" -ForegroundColor Gray
    Write-Host "           - Visit https://discovery.meethue.com/ from your local network" -ForegroundColor Cyan
    Write-Host "           - Check the Hue app under Settings > My Hue System" -ForegroundColor Gray
    Write-Host ""

    do {
        $BridgeIp = (Read-Host "Bridge IP address").Trim()
        if ([string]::IsNullOrWhiteSpace($BridgeIp)) {
            Write-Host "IP address cannot be empty." -ForegroundColor Red
        }
    } while ([string]::IsNullOrWhiteSpace($BridgeIp))

    #----------------------------------------------------------
    # Step 2: Verify bridge is reachable
    #----------------------------------------------------------

    Write-Host ""
    Write-Host "Step 2 : Verifying bridge at $BridgeIp ..." -ForegroundColor Yellow

    try {

        $BridgeInfo = Invoke-RestMethod `
            -Uri "https://$BridgeIp/api/0/config" `
            -Method Get `
            -SkipCertificateCheck `
            -ErrorAction Stop

        $BridgeName = if ($BridgeInfo.PSObject.Properties["name"]) { $BridgeInfo.name } else { "Hue Bridge" }
        $BridgeId   = if ($BridgeInfo.PSObject.Properties["bridgeid"]) { $BridgeInfo.bridgeid } else { "" }

        Write-Host "         Found: $BridgeName" -ForegroundColor Green
        if ($BridgeId) {
            Write-Host "         Bridge ID: $BridgeId" -ForegroundColor DarkGray
        }

    }
    catch {

        Write-Host "         Could not reach bridge: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "         Check the IP and ensure HALS is on the same network." -ForegroundColor Yellow
        throw

    }

    #----------------------------------------------------------
    # Step 3: Button press to get username token
    #----------------------------------------------------------

    Write-Host ""
    Write-Host "Step 3 : Press the button on top of your Hue Bridge NOW," -ForegroundColor Yellow
    Write-Host "         then press Enter within 30 seconds." -ForegroundColor Yellow
    Write-Host ""

    Read-Host "Press Enter after pushing the bridge button"

    Write-Host ""
    Write-Host "         Requesting access token..." -ForegroundColor Cyan

    try {

        $Body = (@{
            devicetype       = "HALS#$($env:COMPUTERNAME)"
            generateclientkey = $true
        } | ConvertTo-Json -Compress)

        $Response = Invoke-RestMethod `
            -Uri "https://$BridgeIp/api" `
            -Method Post `
            -Body $Body `
            -ContentType "application/json" `
            -SkipCertificateCheck `
            -ErrorAction Stop

        $Result = $Response[0]

        if ($Result.PSObject.Properties["error"]) {
            $ErrDesc = $Result.error.description
            throw "Bridge returned error: $ErrDesc"
        }

        if (-not $Result.PSObject.Properties["success"]) {
            throw "Unexpected bridge response."
        }

        $Username = $Result.success.username

    }
    catch {

        Write-Host ""
        Write-Host "         Failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "         Make sure you pressed the bridge button within 30 seconds." -ForegroundColor Yellow
        throw

    }

    #----------------------------------------------------------
    # Step 4: Save secrets
    #----------------------------------------------------------

    $Secrets = [PSCustomObject]@{
        BridgeIp = $BridgeIp
        Username = $Username
        BridgeId = $BridgeId
    }

    $Secrets |
        ConvertTo-Json -Depth 5 |
        Set-Content "$(Get-HALSRoot)\Secrets\PhilipsHue.json"

    Write-Host "         Token saved." -ForegroundColor Green

    #----------------------------------------------------------
    # Step 5: Test full connection
    #----------------------------------------------------------

    Write-Host ""
    Write-Host "Step 4 : Testing full connection..." -ForegroundColor Yellow

    try {

        if (-not (Get-Command Connect-PhilipsHue -ErrorAction SilentlyContinue)) {
            Import-Module (Join-Path (Get-HALSRoot) "Providers\PhilipsHue.psm1") -Force
        }

        $Connection = Connect-PhilipsHue
        $Lights     = @(Get-PhilipsHueLights -Connection $Connection)

        Write-Host "         Connected. Found $($Lights.Count) light(s)." -ForegroundColor Green

    }
    catch {

        Write-Host "         Connection test failed: $($_.Exception.Message)" -ForegroundColor Red
        throw

    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Philips Hue setup complete." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Run HALS to include Hue lights in your inventory." -ForegroundColor Green
    Write-Host ""

}

Export-ModuleMember -Function Initialize-HALSPhilipsHue
