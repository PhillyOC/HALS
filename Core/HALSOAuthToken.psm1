#==========================================================
# HALS - OAuth Token Manager
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Refresh Access Token
#----------------------------------------------------------

function Update-HALSOAuthAccessToken {

    param(

        [Parameter(Mandatory)]
        [string]$Provider

    )

    $Configuration = Get-HALSOAuthConfiguration `
        -Provider $Provider

    if ([string]::IsNullOrWhiteSpace($Configuration.RefreshToken)) {

        throw "$Provider does not have a refresh token. Re-run Initialize-HALSSmartThingsOAuth to reauthorize."

    }

    Write-Host ""
    Write-Host "Refreshing $Provider OAuth token..." -ForegroundColor Cyan

    #
    # SmartThings token endpoint requires Basic Auth.
    # client_id / client_secret must NOT be in the body.
    #

    $BasicAuth = [Convert]::ToBase64String(
        [Text.Encoding]::ASCII.GetBytes(
            "$($Configuration.ClientId):$($Configuration.ClientSecret)"
        )
    )

    $Body = @{
        grant_type    = "refresh_token"
        refresh_token = $Configuration.RefreshToken
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

        $Configuration.Authorized = $false

        Save-HALSOAuthConfiguration `
            -Provider $Provider `
            -Configuration $Configuration

        throw "Unable to refresh the OAuth token for $Provider. Re-run Initialize-HALSSmartThingsOAuth to reauthorize."

    }

    $Configuration.AccessToken = $Response.access_token

    if (-not [string]::IsNullOrWhiteSpace($Response.refresh_token)) {

        $Configuration.RefreshToken = $Response.refresh_token

    }

    $Configuration.Authorized = $true

    if ($Response.expires_in) {

        $Configuration.AccessTokenExpires =
            (Get-Date).AddSeconds($Response.expires_in)

    }

    Save-HALSOAuthConfiguration `
        -Provider $Provider `
        -Configuration $Configuration

    Write-Host "$Provider token refreshed." -ForegroundColor Green

    return $Configuration.AccessToken

}

Export-ModuleMember `
    -Function Update-HALSOAuthAccessToken
