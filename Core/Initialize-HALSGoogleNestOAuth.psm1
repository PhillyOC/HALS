#==========================================================
# HALS - Google Nest OAuth Wizard
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Ensure-HALSOAuthConfiguration -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force
}

if (-not (Get-Command Ensure-HALSGateway -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path (Get-HALSRoot) "Core\HALSGatewayManager.psm1") -Force
}

function Initialize-HALSGoogleNestOAuth {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS GOOGLE NEST SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    #----------------------------------------------------------
    # Registration instructions
    #----------------------------------------------------------

    Write-Host "  PREREQUISITES" -ForegroundColor White
    Write-Host "  " + ("-" * 46) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  1. Google Cloud project with SDM API enabled:" -ForegroundColor Gray
    Write-Host "       https://console.cloud.google.com/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Google Device Access project (one-time dollar 5 fee):" -ForegroundColor Gray
    Write-Host "       https://console.nest.google.com/device-access" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. OAuth 2.0 Client in Google Cloud Console:" -ForegroundColor Gray
    Write-Host "       https://console.cloud.google.com/apis/credentials" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Get-Command Ensure-HALSOAuthConfiguration -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force
    }

    $Config = $null
    try { $Config = Ensure-HALSOAuthConfiguration -Provider "GoogleNest" } catch { $Config = $null }
    $RedirectUri = if ($Config) { $Config.RedirectUri } else { "http://127.0.0.1:8000/" }

    Write-Host "  Required OAuth client settings:" -ForegroundColor Gray
    Write-Host "    Application type   : Web application" -ForegroundColor Gray
    Write-Host ("    Authorized redirect URI : " + $RedirectUri) -ForegroundColor White
    Write-Host ""
    Write-Host "  NOTE: The redirect URI above must match exactly" -ForegroundColor DarkYellow
    Write-Host "  what is registered in Google Cloud Console." -ForegroundColor DarkYellow
    Write-Host ""

    $Ready = (Read-Host "  Do you have your Client ID, Client Secret, and Project ID? (Y/N)").Trim().ToUpper()
    if ($Ready -ne "Y") {
        Write-Host ""
        Write-Host "  Complete the prerequisites then re-run Initialize-HALSGoogleNestOAuth." -ForegroundColor Yellow
        return
    }

    Write-Host ""

    #----------------------------------------------------------
    # Collect credentials
    #----------------------------------------------------------

    $ClientId     = (Read-Host "  Google OAuth Client ID").Trim()
    $ClientSecret = (Read-Host "  Google OAuth Client Secret").Trim()
    $ProjectId    = (Read-Host "  Device Access Project ID").Trim()

    #----------------------------------------------------------
    # Save config
    #----------------------------------------------------------

    $Config = Ensure-HALSOAuthConfiguration -Provider "GoogleNest"
    $Config.ClientId     = $ClientId
    $Config.ClientSecret = $ClientSecret
    $Config.ProjectId    = $ProjectId
    $Config.AuthorizationEndpoint = "https://nestservices.google.com/partnerconnections/$ProjectId/auth"
    Save-HALSOAuthConfiguration -Provider "GoogleNest" -Configuration $Config

    Write-Host ""
    Initialize-HALSGateway | Out-Null

    Write-Host ""
    Write-Host "  Opening Google consent page..." -ForegroundColor Green
    Write-Host ""
    Write-Host "  After approving:" -ForegroundColor Gray
    Write-Host ("    Google redirects to : " + $Config.RedirectUri) -ForegroundColor DarkGray
    Write-Host "    Gateway captures the code and completes the exchange." -ForegroundColor DarkGray
    Write-Host ""

    Start-HALSOAuthAuthorization -Provider "GoogleNest" -State "GoogleNest"

}

Export-ModuleMember -Function Initialize-HALSGoogleNestOAuth
