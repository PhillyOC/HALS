# =====================================================================
# Start-HALSEnvironment.ps1
#
# Launches optional background gateways, then starts the main
# HALS interactive session. Called by Start-HALS.cmd.
#
# All gateway entries are optional - missing paths are silently
# skipped with a [NOT FOUND] note and never block startup.
# =====================================================================

$Host.UI.RawUI.WindowTitle = "HALS"

# Bind to this tree so a moved/copied HALS folder stays portable.
$HALSRoot = Split-Path -Parent $PSScriptRoot
$env:HALS_ROOT = $HALSRoot
Set-Location $HALSRoot

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " HALS Gateway Environment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

#----------------------------------------------------------------------
# Gateway definitions
# Set Optional = $true for gateways that may not exist yet.
# Set Optional = $false for gateways that MUST exist to continue.
#----------------------------------------------------------------------

$Gateways = @(

    @{
        Name     = "HALS OAuth Gateway"
        Path     = "$HALSRoot\Gateway\HALSGateway.ps1"
        Optional = $true
    }

    # ------------------------------------------------------------------
    # Future gateways - uncomment and set paths when ready
    # ------------------------------------------------------------------

    # @{
    #     Name     = "VirtualBox Gateway"
    #     Path     = "$env:HALS_ROOT\Gateways\VirtualBoxGateway\VirtualBoxGateway.ps1"
    #     Optional = $true
    # }

    # @{
    #     Name     = "Home Assistant Gateway"
    #     Path     = "$env:HALS_ROOT\Gateways\HomeAssistantGateway\HomeAssistantGateway.ps1"
    #     Optional = $true
    # }

    # @{
    #     Name     = "Cloudflare Gateway"
    #     Path     = "$env:HALS_ROOT\Gateways\CloudflareGateway\CloudflareGateway.ps1"
    #     Optional = $true
    # }

    # @{
    #     Name     = "Ollama Gateway"
    #     Path     = "$env:HALS_ROOT\Gateways\OllamaGateway\OllamaGateway.ps1"
    #     Optional = $true
    # }

)

#----------------------------------------------------------------------
# Launch gateways
#----------------------------------------------------------------------

$AnyLaunched = $false

foreach ($Gateway in $Gateways) {

    Write-Host ("  {0,-30}" -f $Gateway.Name) -NoNewline

    if (Test-Path $Gateway.Path) {

        Start-Process pwsh `
            -WindowStyle Normal `
            -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$($Gateway.Path)`""

        Write-Host "[OK]" -ForegroundColor Green
        $AnyLaunched = $true

    }
    elseif ($Gateway.Optional) {

        Write-Host "[not configured]" -ForegroundColor DarkGray

    }
    else {

        Write-Host "[NOT FOUND - required]" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Required gateway missing: $($Gateway.Path)" -ForegroundColor Red
        Write-Host "  HALS startup aborted." -ForegroundColor Red
        Write-Host ""
        exit 1

    }

}

Write-Host ""

if ($AnyLaunched) {
    Write-Host "  Gateways launched. Starting HALS..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 800
}

#----------------------------------------------------------------------
# Hand off to the main HALS session
#----------------------------------------------------------------------

& "$HALSRoot\Start-HALS.ps1"
