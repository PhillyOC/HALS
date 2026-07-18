#==========================================================
# HALS - OAuth Token Manager
# Version : 1.2.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Get-HALSOAuthSetupCommand -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force
}

function Update-HALSOAuthAccessToken {

    param(

        [Parameter(Mandatory)]
        [string]$Provider

    )

    $Configuration = Get-HALSOAuthConfiguration `
        -Provider $Provider

    $SetupCommand = Get-HALSOAuthSetupCommand -Provider $Provider

    if ([string]::IsNullOrWhiteSpace($Configuration.RefreshToken)) {

        throw "$Provider does not have a refresh token. Re-run $SetupCommand to reauthorize."

    }

    Write-Host ""
    Write-Host "Refreshing $Provider OAuth token..." -ForegroundColor Cyan

    try {

        if ($Provider -eq "Ecobee") {

            $Body = @{
                grant_type    = "refresh_token"
                refresh_token = $Configuration.RefreshToken
                client_id     = $Configuration.ClientId
            }

            $Response = Invoke-RestMethod `
                -Uri $Configuration.TokenEndpoint `
                -Method Post `
                -ContentType "application/x-www-form-urlencoded" `
                -Body $Body

        }
        else {

            $BasicAuth = [Convert]::ToBase64String(
                [Text.Encoding]::ASCII.GetBytes(
                    "$($Configuration.ClientId):$($Configuration.ClientSecret)"
                )
            )

            $Body = @{
                grant_type    = "refresh_token"
                refresh_token = $Configuration.RefreshToken
            }

            if ($Provider -in @("SmartThings", "GoogleNest")) {
                $Body.client_id = [string]$Configuration.ClientId
            }

            $Response = Invoke-RestMethod `
                -Uri $Configuration.TokenEndpoint `
                -Method Post `
                -Headers @{
                    Authorization = "Basic $BasicAuth"
                } `
                -ContentType "application/x-www-form-urlencoded" `
                -Body $Body

        }

    }
    catch {

        $Configuration.Authorized = $false

        Save-HALSOAuthConfiguration `
            -Provider $Provider `
            -Configuration $Configuration

        throw "Unable to refresh the OAuth token for $Provider. Re-run $SetupCommand to reauthorize."

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
