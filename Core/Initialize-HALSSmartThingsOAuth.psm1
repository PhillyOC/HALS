#==========================================================
# HALS - SmartThings OAuth Initialization
# Version : 1.2.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-HALSSmartThingsOAuth {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS SMARTTHINGS OAUTH" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $Configuration = Get-HALSOAuthConfiguration -Provider "SmartThings"

    #----------------------------------------------------------
    # Registration instructions
    #----------------------------------------------------------

    Write-Host "  SMARTTHINGS APP REGISTRATION" -ForegroundColor White
    Write-Host "  " + ("-" * 46) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  If you have not yet registered HALS as a SmartThings" -ForegroundColor Gray
    Write-Host "  app, do so at:" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    https://developer.smartthings.com/workspace" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Required settings:" -ForegroundColor Gray
    Write-Host ("    App Type        : API_ONLY") -ForegroundColor Gray
    Write-Host ("    Redirect URI    : " + $Configuration.RedirectUri) -ForegroundColor White
    Write-Host ("    OAuth Client ID : (copy from app settings)") -ForegroundColor Gray
    Write-Host ""
    Write-Host "  NOTE: The redirect URI above must match exactly" -ForegroundColor DarkYellow
    Write-Host "  what is registered in your SmartThings app." -ForegroundColor DarkYellow
    Write-Host ""

    #----------------------------------------------------------
    # Gateway reminder
    #----------------------------------------------------------

    Write-Host "  BEFORE CONTINUING" -ForegroundColor White
    Write-Host "  " + ("-" * 46) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Make sure the HALS Gateway is running." -ForegroundColor Yellow
    Write-Host "  Open a second terminal and run:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host ("    & '" + (Get-HALSRoot) + "\Gateway\HALSGateway.ps1'") -ForegroundColor Cyan
    Write-Host ""

    $Ready = (Read-Host "  Gateway running? (Y/N)").Trim().ToUpper()
    if ($Ready -ne "Y") {
        Write-Host ""
        Write-Host "  Start the Gateway first, then re-run Initialize-HALSSmartThingsOAuth." -ForegroundColor Yellow
        return
    }

    #----------------------------------------------------------
    # Launch flow
    #----------------------------------------------------------

    Write-Host ""
    Write-Host "  Opening SmartThings consent page..." -ForegroundColor Green
    Write-Host ""
    Write-Host "  After approving:" -ForegroundColor Gray
    Write-Host ("    SmartThings redirects to : " + $Configuration.RedirectUri) -ForegroundColor DarkGray
    Write-Host "    Gateway captures the code and completes the exchange." -ForegroundColor DarkGray
    Write-Host ""

    Start-HALSOAuthAuthorization -Provider "SmartThings" -State "SmartThings"

}

Export-ModuleMember -Function Initialize-HALSSmartThingsOAuth
