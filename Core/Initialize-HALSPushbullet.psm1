#==========================================================
# HALS - Pushbullet OAuth Setup Wizard
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-HALSPushbullet {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS PUSHBULLET SETUP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    #----------------------------------------------------------
    # Registration instructions
    #----------------------------------------------------------

    $Config = $null
    try { $Config = Get-HALSOAuthConfiguration -Provider "Pushbullet" } catch {}
    $RedirectUri = if ($Config) { $Config.RedirectUri } else { "(configure RedirectUri in Secrets\OAuth\Pushbullet.json)" }

    Write-Host "  PUSHBULLET APP REGISTRATION" -ForegroundColor White
    Write-Host "  " + ("-" * 46) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Register HALS as an OAuth client at:" -ForegroundColor Gray
    Write-Host "    https://www.pushbullet.com/create-client" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Required settings:" -ForegroundColor Gray
    Write-Host "    Name         : HALS (or any name you prefer)" -ForegroundColor Gray
    Write-Host ("    redirect_uri : " + $RedirectUri) -ForegroundColor White
    Write-Host "    website_url  : (optional)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  After creating, copy the Client ID and Client Secret" -ForegroundColor Gray
    Write-Host "  shown on the client page." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  NOTE: The redirect_uri above must match exactly" -ForegroundColor DarkYellow
    Write-Host "  what you enter on the Pushbullet create-client page." -ForegroundColor DarkYellow
    Write-Host ""

    $Ready = (Read-Host "  Do you have a Client ID and Secret? (Y/N)").Trim().ToUpper()
    if ($Ready -ne "Y") {
        Write-Host ""
        Write-Host "  Register your app first, then re-run Initialize-HALSPushbullet." -ForegroundColor Yellow
        return
    }

    Write-Host ""

    #----------------------------------------------------------
    # Collect credentials
    #----------------------------------------------------------

    do {
        $ClientId = (Read-Host "  Pushbullet Client ID").Trim()
        if ([string]::IsNullOrWhiteSpace($ClientId)) { Write-Host "  Cannot be empty." -ForegroundColor Red }
    } while ([string]::IsNullOrWhiteSpace($ClientId))

    do {
        $ClientSecret = (Read-Host "  Pushbullet Client Secret").Trim()
        if ([string]::IsNullOrWhiteSpace($ClientSecret)) { Write-Host "  Cannot be empty." -ForegroundColor Red }
    } while ([string]::IsNullOrWhiteSpace($ClientSecret))

    #----------------------------------------------------------
    # Save credentials
    #----------------------------------------------------------

    $Config               = Get-HALSOAuthConfiguration -Provider "Pushbullet"
    $Config.ClientId      = $ClientId
    $Config.ClientSecret  = $ClientSecret
    $Config.Authorized    = $false
    $Config.AccessToken   = ""
    Save-HALSOAuthConfiguration -Provider "Pushbullet" -Configuration $Config

    #----------------------------------------------------------
    # Gateway reminder
    #----------------------------------------------------------

    Write-Host ""
    Write-Host "  BEFORE CONTINUING" -ForegroundColor White
    Write-Host "  " + ("-" * 46) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Make sure the HALS Gateway is running." -ForegroundColor Yellow
    Write-Host "  Open a second terminal and run:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host ("    & '" + (Get-HALSRoot) + "\Gateway\HALSGateway.ps1'") -ForegroundColor Cyan
    Write-Host ""

    $GwReady = (Read-Host "  Gateway running? (Y/N)").Trim().ToUpper()
    if ($GwReady -ne "Y") {
        Write-Host ""
        Write-Host "  Start the Gateway first, then re-run Initialize-HALSPushbullet." -ForegroundColor Yellow
        return
    }

    #----------------------------------------------------------
    # Launch flow
    #----------------------------------------------------------

    Write-Host ""
    Write-Host "  Opening Pushbullet consent page..." -ForegroundColor Green
    Write-Host ""
    Write-Host "  After clicking Allow:" -ForegroundColor Gray
    Write-Host ("    Pushbullet redirects to : " + $Config.RedirectUri) -ForegroundColor DarkGray
    Write-Host "    Gateway captures the code and completes the exchange." -ForegroundColor DarkGray
    Write-Host ""

    Start-HALSOAuthAuthorization -Provider "Pushbullet" -State "Pushbullet"

}

#----------------------------------------------------------
# Pushbullet token exchange
# Called by HALSGateway when it receives the callback.
# Pushbullet token endpoint requires a JSON body (not
# form-encoded) and no Basic Auth header.
#----------------------------------------------------------

function Complete-HALSPushbulletOAuth {

    param(
        [Parameter(Mandatory)]
        [string]$RedirectUrl
    )

    Write-Host "  Exchanging Pushbullet authorization code..." -ForegroundColor Cyan

    $Uri        = [System.Uri]$RedirectUrl
    $Parameters = @{}

    foreach ($Item in $Uri.Query.TrimStart('?').Split('&')) {
        if ($Item) {
            $Pair = $Item.Split('=')
            if ($Pair.Count -eq 2) {
                $Parameters[$Pair[0]] = [System.Uri]::UnescapeDataString($Pair[1])
            }
        }
    }

    if ($Parameters.ContainsKey("error")) {
        throw "Pushbullet authorization failed: $($Parameters.error)"
    }

    if (-not $Parameters.ContainsKey("code")) {
        throw "Authorization code not found in redirect URL."
    }

    $Config = Get-HALSOAuthConfiguration -Provider "Pushbullet"

    $Body = @{
        grant_type    = "authorization_code"
        client_id     = $Config.ClientId
        client_secret = $Config.ClientSecret
        code          = $Parameters.code
    } | ConvertTo-Json -Depth 5

    try {

        $Response = Invoke-RestMethod `
            -Uri $Config.TokenEndpoint `
            -Method Post `
            -ContentType "application/json" `
            -Body $Body

    }
    catch {

        throw "Pushbullet token exchange failed: $($_.Exception.Message)"

    }

    $Config.AccessToken        = $Response.access_token
    $Config.Authorized         = $true
    $Config.AccessTokenExpires = (Get-Date).AddYears(10)   # Pushbullet tokens don't expire

    Save-HALSOAuthConfiguration -Provider "Pushbullet" -Configuration $Config

}

Export-ModuleMember `
    -Function Initialize-HALSPushbullet,
              Complete-HALSPushbulletOAuth
