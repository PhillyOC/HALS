#==========================================================
# HALS - SmartThings OAuth Helpers
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script:HALSSmartThingsHttpbinRedirectUri = "https://httpbin.org/get"

function Test-HALSPublicHttpsRedirectUri {

    param(
        [Parameter(Mandatory)]
        [string]$RedirectUri
    )

    if ($RedirectUri -notmatch '^https://') {
        return $false
    }

    try {
        $Parsed = [Uri]$RedirectUri
    }
    catch {
        return $false
    }

    $HostName = $Parsed.Host.ToLower()

    if ($HostName -in @('localhost', '127.0.0.1', '::1', '0.0.0.0')) {
        return $false
    }

    if ($HostName -match '^\d+\.\d+\.\d+\.\d+$') {
        return $false
    }

    if ($HostName -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)') {
        return $false
    }

    return $true

}

function Test-HALSSmartThingsRedirectUri {

    param(
        [Parameter(Mandatory)]
        [string]$RedirectUri,

        [switch]$AllowHttpbinManual
    )

    if ($AllowHttpbinManual -and $RedirectUri -eq $Script:HALSSmartThingsHttpbinRedirectUri) {
        return $true
    }

    return (Test-HALSPublicHttpsRedirectUri -RedirectUri $RedirectUri)

}

function Get-HALSSmartThingsRedirectUriError {

    param(
        [Parameter(Mandatory)]
        [string]$RedirectUri
    )

    if ($RedirectUri -notmatch '^https://') {
        return "Use https:// — HTTP redirect URIs return 403 Forbidden from SmartThings."
    }

    if ($RedirectUri -match '127\.0\.0\.1|localhost') {
        return "https://127.0.0.1 and localhost are still local addresses. SmartThings rejects them with 403.`nUse https://httpbin.org/get (desktop flow) or a public ngrok URL."
    }

    if ($RedirectUri -match '^\https://\d+\.\d+\.\d+\.\d+') {
        return "SmartThings requires a public hostname (for example an ngrok URL), not a raw IP address."
    }

    return "Redirect URI must be a public HTTPS URL registered in your SmartThings OAuth-In app."

}

function Update-HALSSmartThingsOAuthConfiguration {

    param(
        [Parameter(Mandatory)]
        $Configuration
    )

    $Configuration.AuthorizationEndpoint = "https://api.smartthings.com/oauth/authorize"
    $Configuration.TokenEndpoint = "https://api.smartthings.com/oauth/token"
    $Configuration | Add-Member -NotePropertyName Provider -NotePropertyValue "SmartThings" -Force

    if (-not $Configuration.PSObject.Properties["Scopes"] -or
        @($Configuration.Scopes).Count -eq 0) {
        $Configuration.Scopes = @(
            "r:devices:*",
            "w:devices:*",
            "x:devices:*"
        )
    }

    return $Configuration

}

function Show-HALSSmartThingsCliInstructions {

    Write-Host "  CREATE THE APP WITH SMARTTHINGS CLI (required)" -ForegroundColor Yellow
    Write-Host "  " + ("-" * 46) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  OAuth-In apps cannot be created in Developer Workspace." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    npm install -g @smartthings/cli" -ForegroundColor Cyan
    Write-Host "    smartthings login" -ForegroundColor Cyan
    Write-Host "    smartthings apps:create" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  When prompted, use:" -ForegroundColor Gray
    Write-Host "    Type         : OAuth-In App" -ForegroundColor DarkGray
    Write-Host "    Redirect URI : https://httpbin.org/get" -ForegroundColor White
    Write-Host "    Scopes       : r:devices:* w:devices:* x:devices:*" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    smartthings apps:oauth <appId>" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Do NOT run smartthings apps:oauth:generate." -ForegroundColor DarkYellow
    Write-Host ""

}

function Resolve-HALSSmartThingsOAuthCallback {

    param(
        [AllowEmptyString()]
        [string]$InputText
    )

    if ([string]::IsNullOrWhiteSpace($InputText)) {
        return $null
    }

    $Text = $InputText.Trim()

    if ($Text.StartsWith("{")) {
        try {
            $Json = $Text | ConvertFrom-Json
            if ($Json.args -and $Json.args.code) {
                return @{
                    RedirectUrl = "https://httpbin.org/get?code=$([Uri]::EscapeDataString([string]$Json.args.code))"
                }
            }
        }
        catch {
            # Fall through to regex parsing.
        }
    }

    if ($Text -match '(https?://httpbin\.org/get\?[^\s"'']+)') {
        return @{
            RedirectUrl = $Matches[1]
        }
    }

    if ($Text -match '[?&]code=([^&\s"'']+)') {
        return @{
            AuthorizationCode = [System.Uri]::UnescapeDataString($Matches[1])
        }
    }

    if ($Text -match '"code"\s*:\s*"([^"]+)"') {
        return @{
            AuthorizationCode = $Matches[1]
        }
    }

    if ($Text -match '^[A-Za-z0-9_-]{6,128}$') {
        return @{
            AuthorizationCode = $Text
        }
    }

    return $null

}

function Wait-HALSSmartThingsOAuthCallback {

    param(
        [int]$TimeoutSeconds = 180
    )

    Write-Host ""
    Write-Host "  Complete login in your browser." -ForegroundColor Green
    Write-Host "  After login, copy the FULL address bar URL (Ctrl+L, Ctrl+C)." -ForegroundColor DarkGray
    Write-Host "  HALS ignores whatever was already on the clipboard before login." -ForegroundColor DarkGray
    Write-Host "  HALS watches for a new clipboard entry and completes OAuth automatically." -ForegroundColor DarkGray
    Write-Host ""

    $BaselineClip = (Get-Clipboard -Raw -ErrorAction SilentlyContinue)
    if (-not [string]::IsNullOrWhiteSpace($BaselineClip)) {
        $BaselineClip = $BaselineClip.Trim()
    }

    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $SeenClipboard = @{}

    while ((Get-Date) -lt $Deadline) {

        $Clip = Get-Clipboard -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($Clip)) {
            Start-Sleep -Milliseconds 500
            continue
        }

        $Clip = $Clip.Trim()

        if (-not [string]::IsNullOrWhiteSpace($BaselineClip) -and $Clip -eq $BaselineClip) {
            Start-Sleep -Milliseconds 500
            continue
        }

        if (-not $SeenClipboard.ContainsKey($Clip)) {
            $SeenClipboard[$Clip] = $true
            $Resolved = Resolve-HALSSmartThingsOAuthCallback -InputText $Clip
            if ($Resolved) {
                Write-Host "  Callback detected from clipboard." -ForegroundColor Green
                return $Resolved
            }
        }

        Start-Sleep -Milliseconds 500
    }

    Write-Host "  Paste callback URL/code, or press Enter to check clipboard again." -ForegroundColor Yellow
    $Manual = (Read-Host "  ").Trim()

    if (-not [string]::IsNullOrWhiteSpace($Manual)) {
        $Resolved = Resolve-HALSSmartThingsOAuthCallback -InputText $Manual
        if ($Resolved) {
            return $Resolved
        }

        throw "Could not find a SmartThings authorization code in that input."
    }

    $Clip = Get-Clipboard -Raw -ErrorAction SilentlyContinue
    $Resolved = Resolve-HALSSmartThingsOAuthCallback -InputText $Clip
    if ($Resolved) {
        Write-Host "  Callback detected from clipboard." -ForegroundColor Green
        return $Resolved
    }

    throw "No SmartThings callback detected. Copy the browser URL after login and run Initialize-SmartThings again."

}

function Start-HALSSmartThingsOAuthLogin {

    param(
        [Parameter(Mandatory)]
        $Configuration,

        [switch]$Quiet
    )

    if (-not (Get-Command New-HALSOAuthAuthorizationUrl -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force
    }

    if (-not (Get-Command Complete-HALSSmartThingsOAuth -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\Complete-HALSSmartThingsOAuth.psm1") -Force
    }

    $Configuration = Update-HALSSmartThingsOAuthConfiguration -Configuration $Configuration
    $Configuration.RedirectUri = $Script:HALSSmartThingsHttpbinRedirectUri

    $AuthUrl = New-HALSOAuthAuthorizationUrl `
        -Configuration $Configuration `
        -State "SmartThings"

    if (-not $Quiet) {
        Write-Host ""
        Write-Host "  Opening SmartThings login..." -ForegroundColor Green
    }

    Start-Process $AuthUrl

    $Callback = Wait-HALSSmartThingsOAuthCallback

    if ($Callback.ContainsKey("AuthorizationCode") -and
        -not [string]::IsNullOrWhiteSpace([string]$Callback["AuthorizationCode"])) {
        Complete-HALSSmartThingsOAuth -AuthorizationCode $Callback["AuthorizationCode"]
    }
    elseif ($Callback.ContainsKey("RedirectUrl") -and
        -not [string]::IsNullOrWhiteSpace([string]$Callback["RedirectUrl"])) {
        Complete-HALSSmartThingsOAuth -RedirectUrl $Callback["RedirectUrl"]
    }
    else {
        throw "SmartThings callback did not contain an authorization code."
    }

}

function Start-HALSSmartThingsOAuthTunnelLogin {

    param(
        [Parameter(Mandatory)]
        $Configuration
    )

    if (-not (Get-Command Initialize-HALSGateway -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSGatewayManager.psm1") -Force
    }

    if (-not (Get-Command Start-HALSOAuthAuthorization -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force
    }

    Initialize-HALSGateway | Out-Null
    Start-HALSOAuthAuthorization -Provider "SmartThings" -State "SmartThings"

    Write-Host ""
    Write-Host "  Waiting for the gateway to complete OAuth..." -ForegroundColor DarkGray
    Write-Host ""

}

Export-ModuleMember -Function `
    Test-HALSPublicHttpsRedirectUri,
    Test-HALSSmartThingsRedirectUri,
    Get-HALSSmartThingsRedirectUriError,
    Update-HALSSmartThingsOAuthConfiguration,
    Show-HALSSmartThingsCliInstructions,
    Resolve-HALSSmartThingsOAuthCallback,
    Wait-HALSSmartThingsOAuthCallback,
    Start-HALSSmartThingsOAuthLogin,
    Start-HALSSmartThingsOAuthTunnelLogin
