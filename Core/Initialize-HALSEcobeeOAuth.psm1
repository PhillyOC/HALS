#==========================================================
# HALS - Ecobee OAuth Wizard
# Version : 1.0.0
#
# Ecobee uses a PIN-based OAuth 2.0 flow.
# No redirect URI or Gateway needed - the user visits
# ecobee.com and enters a 4-character PIN to authorize.
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-HALSEcobeeOAuth {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS ECOBEE SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    #----------------------------------------------------------
    # Step 1: API key
    #----------------------------------------------------------

    Write-Host "Step 1 : Get your Ecobee API key." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "         Log in to the Ecobee developer portal:" -ForegroundColor Gray
    Write-Host "           https://www.ecobee.com/home/developer/api/introduction/auth-overview.shtml" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "         In the Ecobee web portal go to:" -ForegroundColor Gray
    Write-Host "           My Apps > Add application" -ForegroundColor Gray
    Write-Host "         Copy the API key shown for your app." -ForegroundColor Gray
    Write-Host ""

    do {
        $ClientId = (Read-Host "Ecobee API Key (Client ID)").Trim()
        if ([string]::IsNullOrWhiteSpace($ClientId)) {
            Write-Host "API key cannot be empty." -ForegroundColor Red
        }
    } while ([string]::IsNullOrWhiteSpace($ClientId))

    #----------------------------------------------------------
    # Step 2: Request a PIN from Ecobee
    #----------------------------------------------------------

    Write-Host ""
    Write-Host "Step 2 : Requesting authorization PIN from Ecobee..." -ForegroundColor Yellow

    try {

        $PinResponse = Invoke-RestMethod `
            -Uri "https://api.ecobee.com/authorize?response_type=ecobeePin&client_id=$ClientId&scope=smartRead,smartWrite" `
            -Method Get

    }
    catch {
        Write-Host "         Failed to get PIN: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }

    $PIN      = $PinResponse.ecobeePin
    $AuthCode = $PinResponse.code
    $Expires  = $PinResponse.expires_in   # minutes

    Write-Host ""
    Write-Host "         +-----------------------------+" -ForegroundColor Cyan
    Write-Host "         |   Authorization PIN: $PIN   |" -ForegroundColor Cyan
    Write-Host "         +-----------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Step 3 : Enter this PIN at:" -ForegroundColor Yellow
    Write-Host "           https://www.ecobee.com/consumerportal/index.html" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "         Go to  My Apps > Add Application  and enter the PIN above." -ForegroundColor Gray
    Write-Host "         You have $Expires minutes before it expires." -ForegroundColor Gray
    Write-Host ""

    Read-Host "Press Enter after authorizing in the Ecobee portal"

    #----------------------------------------------------------
    # Step 4: Exchange auth code for tokens
    #----------------------------------------------------------

    Write-Host ""
    Write-Host "Step 4 : Exchanging authorization code for tokens..." -ForegroundColor Yellow

    try {

        $TokenResponse = Invoke-RestMethod `
            -Uri "https://api.ecobee.com/token" `
            -Method Post `
            -ContentType "application/x-www-form-urlencoded" `
            -Body "grant_type=ecobeePin&code=$AuthCode&client_id=$ClientId"

    }
    catch {
        Write-Host "         Token exchange failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "         Make sure you entered the PIN in the Ecobee portal before pressing Enter." -ForegroundColor Yellow
        throw
    }

    #----------------------------------------------------------
    # Step 5: Save to OAuth config
    #----------------------------------------------------------

    $Config = Initialize-HALSOAuthConfiguration -Provider "Ecobee"

    $Config.ClientId     = $ClientId
    $Config.AccessToken  = $TokenResponse.access_token
    $Config.RefreshToken = $TokenResponse.refresh_token
    $Config.Authorized   = $true

    if ($TokenResponse.PSObject.Properties["expires_in"]) {
        $Config.AccessTokenExpires = (Get-Date).AddSeconds($TokenResponse.expires_in)
    }

    Save-HALSOAuthConfiguration -Provider "Ecobee" -Configuration $Config

    Write-Host "         Tokens saved." -ForegroundColor Green

    #----------------------------------------------------------
    # Step 6: Test connection
    #----------------------------------------------------------

    Write-Host ""
    Write-Host "Step 5 : Testing connection..." -ForegroundColor Yellow

    try {

        $Connection   = Connect-Ecobee
        $Thermostats  = Get-EcobeeThermostats -Connection $Connection

        Write-Host "         Connected. Found $($Thermostats.Count) thermostat(s)." -ForegroundColor Green

    }
    catch {

        Write-Host "         Connection test failed: $($_.Exception.Message)" -ForegroundColor Red
        throw

    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Ecobee setup complete." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Run HALS to include your Ecobee thermostat in the inventory." -ForegroundColor Green
    Write-Host ""

}

Export-ModuleMember -Function Initialize-HALSEcobeeOAuth
