#==========================================================
# HALS - SmartThings OAuth Initialization
# Version : 1.6.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force -WarningAction SilentlyContinue
Import-Module (Join-Path (Get-HALSRoot) "Core\HALSSmartThingsOAuth.psm1") -Force -WarningAction SilentlyContinue

function Initialize-HALSSmartThingsOAuth {

    param(
        [switch]$UseTunnel
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " HALS SMARTTHINGS OAUTH" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $Configuration = Initialize-HALSOAuthConfiguration -Provider "SmartThings"
    $Configuration = Update-HALSSmartThingsOAuthConfiguration -Configuration $Configuration

    Show-HALSSmartThingsCliInstructions

    if (-not $UseTunnel) {

        Write-Host "  DESKTOP OAUTH (default)" -ForegroundColor White
        Write-Host "  " + ("-" * 46) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  HALS uses https://httpbin.org/get as the redirect URI." -ForegroundColor Gray
        Write-Host "  After browser login, copy the address bar — HALS detects it automatically." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Advanced tunnel setup: Initialize-SmartThings -UseTunnel" -ForegroundColor DarkGray
        Write-Host ""

        $Configuration.RedirectUri = "https://httpbin.org/get"
        $Configuration | Add-Member -NotePropertyName CallbackMode -NotePropertyValue "Httpbin" -Force

    }
    else {

        Write-Host "  TUNNEL OAUTH (advanced)" -ForegroundColor White
        Write-Host "  " + ("-" * 46) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Start ngrok http 8000 and enter the public HTTPS URL below." -ForegroundColor Gray
        Write-Host ""

        do {
            $RedirectUri = (Read-Host "  Public HTTPS redirect URI from ngrok/tunnel").Trim()

            if ([string]::IsNullOrWhiteSpace($RedirectUri)) {
                Write-Host "  Redirect URI cannot be empty." -ForegroundColor Red
                continue
            }

            if (-not (Test-HALSSmartThingsRedirectUri -RedirectUri $RedirectUri)) {
                Write-Host ("  " + (Get-HALSSmartThingsRedirectUriError -RedirectUri $RedirectUri)) -ForegroundColor Red
                $RedirectUri = $null
            }

        } while ([string]::IsNullOrWhiteSpace($RedirectUri))

        $Configuration.RedirectUri = $RedirectUri.Trim()
        $Configuration | Add-Member -NotePropertyName CallbackMode -NotePropertyValue "Tunnel" -Force

    }

    Save-HALSOAuthConfiguration -Provider "SmartThings" -Configuration $Configuration

    Write-Host ("  Redirect URI: " + $Configuration.RedirectUri) -ForegroundColor Green
    Write-Host ""

    Write-Host "  OAuth scopes must match your SmartThings app exactly." -ForegroundColor Gray
    $ScopeText = (Read-Host "  Scopes [r:devices:* w:devices:* x:devices:*]").Trim()
    if ([string]::IsNullOrWhiteSpace($ScopeText)) {
        $Configuration.Scopes = @("r:devices:*", "w:devices:*", "x:devices:*")
    }
    else {
        $Configuration.Scopes = @(
            $ScopeText -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    $HasCredentials = (Test-HALSOAuthCredentialsConfigured -Configuration $Configuration)

    if (-not $HasCredentials) {

        $Ready = (Read-Host "  Do you have OAuth Client ID and Secret from smartthings apps:oauth? (Y/N)").Trim().ToUpper()
        if ($Ready -ne "Y") {
            Write-Host ""
            Write-Host "  Run smartthings apps:create first, then re-run Initialize-SmartThings." -ForegroundColor Yellow
            return
        }

        Write-Host ""

        do {
            $ClientId = (Read-Host "  SmartThings OAuth Client ID").Trim()
            if ([string]::IsNullOrWhiteSpace($ClientId)) {
                Write-Host "  Client ID cannot be empty." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($ClientId))

        do {
            $ClientSecret = (Read-Host "  SmartThings OAuth Client Secret").Trim()
            if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
                Write-Host "  Client Secret cannot be empty." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($ClientSecret))

        $Configuration.ClientId = $ClientId
        $Configuration.ClientSecret = $ClientSecret

    }
    else {

        Write-Host "  Using saved SmartThings OAuth client credentials." -ForegroundColor DarkGray
        Write-Host ""

    }

    $Configuration.Authorized = $false
    $Configuration.AccessToken = ""
    $Configuration.RefreshToken = ""
    $Configuration.AccessTokenExpires = $null

    Save-HALSOAuthConfiguration -Provider "SmartThings" -Configuration $Configuration

    if ($UseTunnel) {
        Start-HALSSmartThingsOAuthTunnelLogin -Configuration $Configuration
        return
    }

    Start-HALSSmartThingsOAuthLogin -Configuration $Configuration

}

Export-ModuleMember -Function Initialize-HALSSmartThingsOAuth
