#==========================================================
# HALS Gateway
# Version : 1.0.0
#
# Handles OAuth callbacks for all HALS providers.
# Route all OAuth redirect URIs to this machine on port 8000
# via your reverse proxy / Cloudflare tunnel.
#
# Provider routing uses the OAuth "state" parameter which
# is set to the provider name by Start-HALSOAuthAuthorization.
# This is portable - works with any redirect URI or domain.
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$_HALSRoot = if ($env:HALS_ROOT) { $env:HALS_ROOT } else { Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
Import-Module "$_HALSRoot\Core\HALSRoot.psm1"                         -Force
Import-Module "$(Get-HALSRoot)\Core\HALSOAuth.psm1"                   -Force
Import-Module "$(Get-HALSRoot)\Core\HALSOAuthToken.psm1"              -Force
Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSPushbullet.psm1"   -Force -WarningAction SilentlyContinue

#----------------------------------------------------------
# Provider registry
# Maps state parameter value -> display name + completion
# function. Add a new entry here when adding a new provider.
#----------------------------------------------------------

$ProviderRegistry = @{

    "SmartThings" = @{
        DisplayName    = "SmartThings"
        TokenStyle     = "BasicAuth"       # form-encoded + Basic Auth header
    }

    "GoogleNest"  = @{
        DisplayName    = "Google Nest"
        TokenStyle     = "BasicAuth"
    }

    "Pushbullet"  = @{
        DisplayName    = "Pushbullet"
        TokenStyle     = "JsonBody"        # JSON body, no Basic Auth
    }

}

[Console]::Title = "HALS Gateway"

$Listener = [System.Net.HttpListener]::new()
$Listener.Prefixes.Add("http://+:8000/")
$Listener.Start()

Write-Host ""
Write-Host "  +================================================+" -ForegroundColor Cyan
Write-Host "  |             HALS OAuth Gateway                 |" -ForegroundColor Cyan
Write-Host "  +================================================+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Listening on   http://+:8000/" -ForegroundColor Green
Write-Host ""
Write-Host "  Route your OAuth redirect URI(s) to this machine on port 8000." -ForegroundColor DarkGray
Write-Host "  All providers share one redirect URI - routing uses state param." -ForegroundColor DarkGray
Write-Host ""

#
# Show the configured redirect URI for each registered provider
# so the user knows exactly what to register at each service.
#

Write-Host "  REGISTERED PROVIDERS" -ForegroundColor Cyan
Write-Host "  " + ("-" * 52) -ForegroundColor DarkGray
Write-Host ""

$ProviderInfo = @(
    @{
        Key          = "SmartThings"
        Name         = "SmartThings"
        RegistrarUrl = "https://developer.smartthings.com/workspace"
        Note         = "Apps > Your App > OAuth > Redirect URIs"
    }
    @{
        Key          = "GoogleNest"
        Name         = "Google Nest"
        RegistrarUrl = "https://console.cloud.google.com/apis/credentials"
        Note         = "OAuth 2.0 Client > Authorized redirect URIs"
    }
    @{
        Key          = "Pushbullet"
        Name         = "Pushbullet"
        RegistrarUrl = "https://www.pushbullet.com/create-client"
        Note         = "redirect_uri field on your OAuth client"
    }
)

foreach ($Info in $ProviderInfo) {

    $RedirectUri = ""

    try {
        $Cfg = Get-HALSOAuthConfiguration -Provider $Info.Key
        $RedirectUri = $Cfg.RedirectUri
    }
    catch {
        $RedirectUri = "(not configured)"
    }

    Write-Host ("  " + $Info.Name.PadRight(16)) -ForegroundColor White -NoNewline
    Write-Host $RedirectUri -ForegroundColor Cyan
    Write-Host ("  " + "".PadRight(16)) -NoNewline -ForegroundColor DarkGray
    Write-Host $Info.Note -ForegroundColor DarkGray
    Write-Host ("  " + "".PadRight(16)) -NoNewline -ForegroundColor DarkGray
    Write-Host $Info.RegistrarUrl -ForegroundColor DarkGray
    Write-Host ""

}

Write-Host "  Waiting for callbacks..." -ForegroundColor DarkGray
Write-Host ""

#----------------------------------------------------------
# Request loop
#----------------------------------------------------------

try {

    while ($Listener.IsListening) {

        $Context  = $Listener.GetContext()
        $Request  = $Context.Request
        $Response = $Context.Response

        #------------------------------------------------------
        # OAuth Callback - must have ?code= parameter
        #------------------------------------------------------

        if ($Request.QueryString["code"]) {

            $Code     = $Request.QueryString["code"]
            $State    = $Request.QueryString["state"]
            $FullUrl  = $Request.Url.ToString()

            Write-Host ""
            Write-Host "  *** OAuth Callback ***" -ForegroundColor Green
            Write-Host ("  Provider : " + $(if ($State) { $State } else { "(unknown)" })) -ForegroundColor White
            Write-Host ("  Code     : " + $Code.Substring(0, [Math]::Min(12,$Code.Length)) + "...") -ForegroundColor DarkGray
            Write-Host ""

            #
            # Determine which provider this callback belongs to.
            # The state parameter is set to the provider name by
            # Start-HALSOAuthAuthorization -- this is the portable,
            # single-redirect-URI solution.
            #

            $TargetProvider = $null
            $ProviderEntry  = $null

            if (-not [string]::IsNullOrWhiteSpace($State) -and
                $ProviderRegistry.ContainsKey($State)) {

                $TargetProvider = $State
                $ProviderEntry  = $ProviderRegistry[$State]

            }
            else {

                #
                # No state or unrecognised state -- log a warning.
                # This should not happen when all wizards pass state correctly.
                #

                Write-Host "  WARNING: No valid state parameter in callback." -ForegroundColor Yellow
                Write-Host "  Received state: '$State'" -ForegroundColor DarkYellow
                Write-Host "  Cannot determine provider. Callback ignored." -ForegroundColor Yellow
                Write-Host ""

                $Html  = "<html><body style='font-family:Segoe UI'>"
                $Html += "<h2>OAuth callback received but provider could not be determined.</h2>"
                $Html += "<p>State parameter was: <code>$State</code></p>"
                $Html += "<p>Please re-run the HALS setup wizard for your provider.</p>"
                $Html += "</body></html>"

                $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Html)
                $Response.StatusCode      = 400
                $Response.ContentType     = "text/html"
                $Response.ContentLength64 = $Bytes.Length
                $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
                $Response.OutputStream.Close()
                $Response.Close()
                continue

            }

            try {

                Write-Host "  Completing $($ProviderEntry.DisplayName) authorization..." -ForegroundColor Cyan

                switch ($ProviderEntry.TokenStyle) {

                    "JsonBody" {
                        # Pushbullet: JSON body, no Basic Auth
                        Complete-HALSPushbulletOAuth -RedirectUrl $FullUrl
                    }

                    default {
                        # Standard: form-encoded + Basic Auth (SmartThings, GoogleNest)
                        Complete-HALSOAuthAuthorization `
                            -Provider    $TargetProvider `
                            -AuthorizationCode $Code
                    }

                }

                Write-Host "  $($ProviderEntry.DisplayName) connected." -ForegroundColor Green
                Write-Host ""

                $Html  = "<html><head><title>HALS</title></head>"
                $Html += "<body style='font-family:Segoe UI;max-width:480px;margin:60px auto;text-align:center'>"
                $Html += "<h2 style='color:#2d7d46'>HALS connected to $($ProviderEntry.DisplayName)</h2>"
                $Html += "<p>The OAuth token has been saved successfully.</p>"
                $Html += "<p style='color:#888'>You may close this window and return to HALS.</p>"
                $Html += "</body></html>"

            }
            catch {

                Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host ""

                $ErrMsg = $_.Exception.Message

                $Html  = "<html><head><title>HALS OAuth Error</title></head>"
                $Html += "<body style='font-family:Segoe UI;max-width:480px;margin:60px auto'>"
                $Html += "<h2 style='color:#c0392b'>OAuth failed for $($ProviderEntry.DisplayName)</h2>"
                $Html += "<pre style='background:#f8f8f8;padding:12px;border-radius:4px;font-size:13px'>$ErrMsg</pre>"
                $Html += "<p>Re-run the HALS setup wizard for this provider and try again.</p>"
                $Html += "</body></html>"

            }

            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Html)
            $Response.StatusCode      = 200
            $Response.ContentType     = "text/html; charset=utf-8"
            $Response.ContentLength64 = $Bytes.Length
            $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
            $Response.OutputStream.Close()
            $Response.Close()
            continue

        }

        #------------------------------------------------------
        # SmartThings Confirmation (LIFECYCLE event)
        #------------------------------------------------------

        $Reader = [System.IO.StreamReader]::new($Request.InputStream)
        $Body   = $Reader.ReadToEnd()
        $Reader.Close()

        if (-not [string]::IsNullOrWhiteSpace($Body)) {

            try {

                $Json = $Body | ConvertFrom-Json

                if ($Json.messageType -eq "CONFIRMATION") {

                    Write-Host "  *** SmartThings Confirmation ***" -ForegroundColor Green

                    $ConfirmationUrl = $Json.confirmationData.confirmationUrl
                    Invoke-RestMethod -Uri $ConfirmationUrl -Method Get | Out-Null

                    Write-Host "  Registration confirmed." -ForegroundColor Green
                    Write-Host ""

                }

            }
            catch { }

        }

        #------------------------------------------------------
        # Other requests - return 200 OK
        #------------------------------------------------------

        $Bytes = [System.Text.Encoding]::UTF8.GetBytes("OK")
        $Response.StatusCode      = 200
        $Response.ContentType     = "text/plain"
        $Response.ContentLength64 = $Bytes.Length
        $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
        $Response.OutputStream.Close()
        $Response.Close()

    }

}
finally {

    Write-Host ""
    Write-Host "  Stopping HALS Gateway..." -ForegroundColor Yellow

    if ($Listener.IsListening) { $Listener.Stop() }
    $Listener.Close()

}
