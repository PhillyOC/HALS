#==========================================================
# HALS - SmartThings OAuth Completion
# Version : 1.0.1
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Complete-HALSSmartThingsOAuth {

    param(

        [Parameter(Mandatory)]
        [string]$RedirectUrl

    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " SMARTTHINGS OAUTH COMPLETION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $Uri = [System.Uri]$RedirectUrl

    $Parameters = @{}

    foreach ($Item in $Uri.Query.TrimStart('?').Split('&')) {

        if ($Item) {

            $Pair = $Item.Split('=')

            if ($Pair.Count -eq 2) {

                $Parameters[$Pair[0]] = `
                    [System.Uri]::UnescapeDataString($Pair[1])

            }

        }

    }

    #
    # Check for error before checking for code.
    # SmartThings returns ?error=access_denied etc.
    #

    if ($Parameters.ContainsKey("error")) {

        throw "SmartThings authorization failed: $($Parameters.error)"

    }

    if (-not $Parameters.ContainsKey("code")) {

        throw "Authorization code not found in redirect URL."

    }

    Write-Host "Authorization code received." -ForegroundColor Green

    Complete-HALSOAuthAuthorization `
        -Provider "SmartThings" `
        -AuthorizationCode $Parameters.code

    Write-Host ""
    Write-Host "SmartThings OAuth authorization completed." -ForegroundColor Green
    Write-Host "HALS will use OAuth on the next connection." -ForegroundColor DarkGreen

}

Export-ModuleMember `
    -Function Complete-HALSSmartThingsOAuth
