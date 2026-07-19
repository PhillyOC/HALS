#==========================================================
# HALS - SmartThings OAuth Completion
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Confirm-HALSOAuthAuthorization -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path (Get-HALSRoot) "Core\HALSOAuth.psm1") -Force -WarningAction SilentlyContinue
}

function Complete-HALSSmartThingsOAuth {

    param(
        [string]$RedirectUrl,
        [string]$AuthorizationCode
    )

    if ([string]::IsNullOrWhiteSpace($RedirectUrl) -and
        [string]::IsNullOrWhiteSpace($AuthorizationCode)) {
        throw "Provide either -RedirectUrl or -AuthorizationCode."
    }

    Write-Host ""
    Write-Host "Completing SmartThings OAuth..." -ForegroundColor Cyan

    $Code = $AuthorizationCode

    if ([string]::IsNullOrWhiteSpace($Code)) {

        $Uri = [System.Uri]$RedirectUrl
        $Parameters = @{}

        foreach ($Item in $Uri.Query.TrimStart('?').Split('&')) {

            if (-not $Item) { continue }

            $Pair = $Item.Split('=', 2)
            if ($Pair.Count -eq 2) {
                $Parameters[$Pair[0]] = [System.Uri]::UnescapeDataString($Pair[1])
            }

        }

        if ($Parameters.ContainsKey("error")) {
            throw "SmartThings authorization failed: $($Parameters.error)"
        }

        if (-not $Parameters.ContainsKey("code")) {
            throw "Authorization code not found in redirect URL."
        }

        $Code = [string]$Parameters.code

    }

    $Code = $Code.Trim()
    if ([string]::IsNullOrWhiteSpace($Code)) {
        throw "Authorization code is empty."
    }

    Write-Host "Authorization code received." -ForegroundColor Green

    Confirm-HALSOAuthAuthorization `
        -Provider "SmartThings" `
        -AuthorizationCode $Code

    $PatPath = Join-Path (Get-HALSRoot) "Secrets\SmartThings.json"
    if (Test-Path -LiteralPath $PatPath) {
        Remove-Item -LiteralPath $PatPath -Force
        Write-Host "Removed legacy SmartThings PAT file (OAuth is now active)." -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "SmartThings OAuth authorization completed." -ForegroundColor Green
    Write-Host "HALS will use OAuth on the next connection." -ForegroundColor DarkGreen
    Write-Host ""

}

Export-ModuleMember -Function Complete-HALSSmartThingsOAuth
