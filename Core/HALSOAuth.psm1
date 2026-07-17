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

function New-HALSOAuthAuthorizationUrl {

    param(

        [Parameter(Mandatory)]
        $Configuration,

        [string]$State = ""

    )

    $Scopes = $Configuration.Scopes -join " "

    $Url = "$($Configuration.AuthorizationEndpoint)" +
           "?client_id=$($Configuration.ClientId)" +
           "&response_type=code" +
           "&redirect_uri=$([Uri]::EscapeDataString($Configuration.RedirectUri))" +
           "&scope=$([Uri]::EscapeDataString($Scopes))"

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

    $Configuration = Get-HALSOAuthConfiguration `
        -Provider $Provider

    if ([string]::IsNullOrWhiteSpace($State)) {
        $State = $Provider
    }

    $Url = New-HALSOAuthAuthorizationUrl `
        -Configuration $Configuration `
        -State $State

    Write-Host ""
    Write-Host "Opening browser..." -ForegroundColor Cyan
    Write-Host ""

    Start-Process $Url

}

#----------------------------------------------------------
# Complete Authorization
# Used for providers that follow standard Basic Auth +
# form-encoded token exchange (SmartThings, GoogleNest).
# Pushbullet uses its own Complete-HALSPushbulletOAuth
# because it requires a JSON body instead.
#----------------------------------------------------------

function Complete-HALSOAuthAuthorization {

    param(

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$AuthorizationCode

    )

    $Configuration = Get-HALSOAuthConfiguration `
        -Provider $Provider

    $BasicAuth = [Convert]::ToBase64String(
        [Text.Encoding]::ASCII.GetBytes(
            "$($Configuration.ClientId):$($Configuration.ClientSecret)"
        )
    )

    $Body = @{
        grant_type   = "authorization_code"
        redirect_uri = $Configuration.RedirectUri
        code         = $AuthorizationCode
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
        $_ | Format-List * -Force
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
              Save-HALSOAuthConfiguration,
              Test-HALSOAuthExpired,
              Get-HALSOAuthAccessToken,
              New-HALSOAuthAuthorizationUrl,
              Start-HALSOAuthAuthorization,
              Complete-HALSOAuthAuthorization
