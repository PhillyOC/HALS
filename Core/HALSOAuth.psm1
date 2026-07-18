#==========================================================
# HALS - OAuth Engine
# Version : 1.3.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Load OAuth Provider Configuration
#----------------------------------------------------------

function Get-HALSOAuthConfiguration {

    param(

        [Parameter(Mandatory)]
        [string]$Provider

    )

    $Path = "$(Get-HALSRoot)\Secrets\OAuth\$Provider.json"

    if (!(Test-Path $Path)) {

        throw "OAuth configuration not found: $Path"

    }

    Get-Content $Path -Raw |
        ConvertFrom-Json

}

function Initialize-HALSOAuthConfiguration {

    param(
        [Parameter(Mandatory)]
        [string]$Provider
    )

    $Path = Join-Path (Get-HALSRoot) "Secrets\OAuth\$Provider.json"

    if (Test-Path -LiteralPath $Path) {
        return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
    }

    $ExamplePath = Join-Path (Get-HALSRoot) "Secrets\OAuth\$Provider.example.json"

    if (-not (Test-Path -LiteralPath $ExamplePath)) {
        throw "OAuth template not found: $ExamplePath"
    }

    $Configuration = Get-Content -LiteralPath $ExamplePath -Raw | ConvertFrom-Json

    if ($Configuration.PSObject.Properties["RedirectUri"] -and
        ($Configuration.RedirectUri -match 'example\.com' -or
         [string]::IsNullOrWhiteSpace([string]$Configuration.RedirectUri))) {

        if ($Provider -eq "SmartThings") {
            $Configuration.RedirectUri = ""
        }
        else {
            $Configuration.RedirectUri = "http://127.0.0.1:8000/"
        }

    }

    Save-HALSOAuthConfiguration -Provider $Provider -Configuration $Configuration

    return $Configuration

}

#----------------------------------------------------------
# Save OAuth Provider Configuration
#----------------------------------------------------------

function Save-HALSOAuthConfiguration {

    param(

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        $Configuration

    )

    $Folder = "$(Get-HALSRoot)\Secrets\OAuth"

    if (!(Test-Path $Folder)) {

        New-Item `
            -ItemType Directory `
            -Path $Folder | Out-Null

    }

    $Configuration |
        ConvertTo-Json -Depth 20 |
        Set-Content "$Folder\$Provider.json"

}

#----------------------------------------------------------
# Test Expiration
#----------------------------------------------------------

function Test-HALSOAuthExpired {

    param(

        [Parameter(Mandatory)]
        $Configuration

    )

    if (-not $Configuration.AccessTokenExpires) {

        return $true

    }

    ([datetime]$Configuration.AccessTokenExpires) -le (Get-Date)

}

#----------------------------------------------------------
# Get Access Token
#----------------------------------------------------------

function Get-HALSOAuthAccessToken {

    param(

        [Parameter(Mandatory)]
        [string]$Provider

    )

    $Configuration = Get-HALSOAuthConfiguration `
        -Provider $Provider

    if ($Provider -eq "SmartThings") {
        if (-not (Get-Command Update-HALSSmartThingsOAuthConfiguration -ErrorAction SilentlyContinue)) {
            Import-Module (Join-Path (Get-HALSRoot) "Core\HALSSmartThingsOAuth.psm1") -Force -WarningAction SilentlyContinue
        }

        $Repaired = Update-HALSSmartThingsOAuthConfiguration -Configuration $Configuration
        if ($Repaired.TokenEndpoint -ne $Configuration.TokenEndpoint) {
            Save-HALSOAuthConfiguration -Provider $Provider -Configuration $Repaired
            $Configuration = $Repaired
        }
    }

    if ([string]::IsNullOrWhiteSpace($Configuration.AccessToken)) {

        throw "$Provider has not been authorized."

    }

    if (Test-HALSOAuthExpired $Configuration) {

        return Update-HALSOAuthAccessToken `
            -Provider $Provider

    }

    return $Configuration.AccessToken

}

#----------------------------------------------------------
# Authorization URL
# State parameter is the provider name so the Gateway can
# route callbacks without ambiguity, regardless of which
# redirect URI or domain the user has configured.
#----------------------------------------------------------

function Get-HALSOAuthSetupCommand {

    param(
        [Parameter(Mandatory)]
        [string]$Provider
    )

    switch ($Provider) {
        "SmartThings" { return "Initialize-SmartThings" }
        "GoogleNest"  { return "Initialize-GoogleNest" }
        "Pushbullet"  { return "Initialize-Pushbullet" }
        "Ecobee"      { return "Initialize-Ecobee" }
        default       { return "Initialize-HALSDeviceProvider" }
    }

}

function Test-HALSOAuthCredentialsConfigured {

    param(
        [Parameter(Mandatory)]
        $Configuration
    )

    if (-not $Configuration.PSObject.Properties["ClientId"] -or
        [string]::IsNullOrWhiteSpace([string]$Configuration.ClientId) -or
        [string]$Configuration.ClientId -eq "REPLACE_ME") {
        return $false
    }

    if ($Configuration.PSObject.Properties["ClientSecret"]) {
        $Secret = [string]$Configuration.ClientSecret
        if ([string]::IsNullOrWhiteSpace($Secret) -or $Secret -eq "REPLACE_ME") {
            return $false
        }
    }

    return $true

}

function Test-HALSOAuthRedirectUriForProvider {

    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$RedirectUri
    )

    if ([string]::IsNullOrWhiteSpace($RedirectUri)) {
        return $false
    }

    if ($Provider -eq "SmartThings") {
        if (-not (Get-Command Test-HALSSmartThingsRedirectUri -ErrorAction SilentlyContinue)) {
            Import-Module (Join-Path (Get-HALSRoot) "Core\HALSSmartThingsOAuth.psm1") -Force
        }

        return (Test-HALSSmartThingsRedirectUri -RedirectUri $RedirectUri -AllowHttpbinManual)
    }

    return $true

}

function Get-HALSOAuthRedirectUriGuidance {

    param(
        [Parameter(Mandatory)]
        [string]$Provider
    )

    switch ($Provider) {
        "SmartThings" {
            return @(
                "SmartThings OAuth-In apps must be created with: smartthings apps:create",
                "Developer Workspace credentials return 403 Forbidden.",
                "Redirect URI must be a public HTTPS hostname (ngrok, Cloudflare, your domain).",
                "https://127.0.0.1:8000/ is NOT valid — adding https:// does not help.",
                "Manual fallback: register https://httpbin.org/get and paste the callback URL.",
                "Point tunnels at http://127.0.0.1:8000/ where the HALS gateway listens."
            ) -join "`n"
        }
        default {
            return "Register redirect URI http://127.0.0.1:8000/ unless your provider requires HTTPS."
        }
    }

}

function New-HALSOAuthAuthorizationUrl {

    param(

        [Parameter(Mandatory)]
        $Configuration,

        [string]$State = ""

    )

    $ScopeParam = if ($Configuration.PSObject.Properties["Provider"] -and
        [string]$Configuration.Provider -eq "SmartThings") {
        (@($Configuration.Scopes | ForEach-Object { [Uri]::EscapeDataString($_) })) -join "+"
    }
    elseif ($Configuration.PSObject.Properties["AuthorizationEndpoint"] -and
        [string]$Configuration.AuthorizationEndpoint -match 'smartthings\.com/oauth/authorize') {
        (@($Configuration.Scopes | ForEach-Object { [Uri]::EscapeDataString($_) })) -join "+"
    }
    else {
        [Uri]::EscapeDataString(($Configuration.Scopes -join " "))
    }

    $Url = "$($Configuration.AuthorizationEndpoint)" +
           "?client_id=$([Uri]::EscapeDataString([string]$Configuration.ClientId))" +
           "&response_type=code" +
           "&redirect_uri=$([Uri]::EscapeDataString($Configuration.RedirectUri))" +
           "&scope=$ScopeParam"

    if (-not [string]::IsNullOrWhiteSpace($State)) {
        $Url += "&state=$([Uri]::EscapeDataString($State))"
    }

    return $Url

}

#----------------------------------------------------------
# Launch Browser
#----------------------------------------------------------

function Start-HALSOAuthAuthorization {

    param(

        [Parameter(Mandatory)]
        [string]$Provider,

        #
        # State is passed through the OAuth flow and echoed
        # back in the callback so the Gateway knows which
        # provider completed authorization. Defaults to the
        # provider name if not explicitly set.
        #

        [string]$State = ""

    )

    if (-not (Get-Command Initialize-HALSGateway -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSGatewayManager.psm1") -Force
    }

    $Configuration = Get-HALSOAuthConfiguration `
        -Provider $Provider

    if (-not (Test-HALSOAuthCredentialsConfigured -Configuration $Configuration)) {
        throw "$Provider OAuth client credentials are missing. Run $(Get-HALSOAuthSetupCommand -Provider $Provider) first."
    }

    if (-not (Test-HALSOAuthRedirectUriForProvider -Provider $Provider -RedirectUri $Configuration.RedirectUri)) {
        throw (Get-HALSOAuthRedirectUriGuidance -Provider $Provider)
    }

    if ([string]::IsNullOrWhiteSpace($State)) {
        $State = $Provider
    }

    Initialize-HALSGateway | Out-Null

    $Url = New-HALSOAuthAuthorizationUrl `
        -Configuration $Configuration `
        -State $State

    Write-Host ""
    Write-Host "Opening browser..." -ForegroundColor Cyan
    Write-Host ""

    Start-Process $Url

}

#----------------------------------------------------------
# Confirm Authorization
# Used for providers that follow standard Basic Auth +
# form-encoded token exchange (SmartThings, GoogleNest).
# Pushbullet uses its own Complete-HALSPushbulletOAuth
# because it requires a JSON body instead.
#----------------------------------------------------------

function Confirm-HALSOAuthAuthorization {

    param(

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$AuthorizationCode

    )

    $Configuration = Get-HALSOAuthConfiguration `
        -Provider $Provider

    if ($Provider -eq "SmartThings") {
        if (-not (Get-Command Update-HALSSmartThingsOAuthConfiguration -ErrorAction SilentlyContinue)) {
            Import-Module (Join-Path (Get-HALSRoot) "Core\HALSSmartThingsOAuth.psm1") -Force -WarningAction SilentlyContinue
        }
        $Configuration = Update-HALSSmartThingsOAuthConfiguration -Configuration $Configuration
    }

    $Code = $AuthorizationCode.Trim()
    if ([string]::IsNullOrWhiteSpace($Code)) {
        throw "Authorization code is empty."
    }

    $BasicAuth = [Convert]::ToBase64String(
        [Text.Encoding]::ASCII.GetBytes(
            "$($Configuration.ClientId):$($Configuration.ClientSecret)"
        )
    )

    $Body = @{
        grant_type   = "authorization_code"
        client_id    = [string]$Configuration.ClientId
        redirect_uri = [string]$Configuration.RedirectUri
        code         = $Code
    }

    try {

        $Response = Invoke-RestMethod `
            -Uri $Configuration.TokenEndpoint `
            -Method Post `
            -Headers @{
                Authorization = "Basic $BasicAuth"
            } `
            -ContentType "application/x-www-form-urlencoded" `
            -Body $Body

    }
    catch {

        Write-Host ""
        Write-Host "===== TOKEN REQUEST FAILED =====" -ForegroundColor Red
        Write-Host ""

        $Detail = $_.ErrorDetails.Message
        if (-not [string]::IsNullOrWhiteSpace($Detail)) {
            Write-Host $Detail -ForegroundColor Red
        }

        if ($Detail -match 'invalid_grant') {
            Write-Host ""
            Write-Host "Common causes:" -ForegroundColor Yellow
            Write-Host "  - The authorization code was already used or expired." -ForegroundColor DarkGray
            Write-Host "  - Clipboard still held an old httpbin URL from a previous attempt." -ForegroundColor DarkGray
            Write-Host "  - redirect_uri mismatch (expected: $($Configuration.RedirectUri))." -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "Run Reconnect-SmartThingsOAuth and copy a fresh browser URL after login." -ForegroundColor Cyan
        }

        throw

    }

    $Configuration.AccessToken    = $Response.access_token
    $Configuration.RefreshToken   = $Response.refresh_token
    $Configuration.Authorized     = $true

    if ($Response.expires_in) {

        $Configuration.AccessTokenExpires =
            (Get-Date).AddSeconds($Response.expires_in)

    }

    Save-HALSOAuthConfiguration `
        -Provider $Provider `
        -Configuration $Configuration

}

Export-ModuleMember `
    -Function Get-HALSOAuthConfiguration,
              Initialize-HALSOAuthConfiguration,
              Save-HALSOAuthConfiguration,
              Test-HALSOAuthExpired,
              Get-HALSOAuthAccessToken,
              Get-HALSOAuthSetupCommand,
              Test-HALSOAuthCredentialsConfigured,
              Test-HALSOAuthRedirectUriForProvider,
              Get-HALSOAuthRedirectUriGuidance,
              New-HALSOAuthAuthorizationUrl,
              Start-HALSOAuthAuthorization,
              Confirm-HALSOAuthAuthorization
