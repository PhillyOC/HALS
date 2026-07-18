#==========================================================
# HALS - OAuth Gateway Manager
# Version : 1.0.0
#
# Starts and monitors the local OAuth callback gateway on
# port 8000. Used at HALS launch and before OAuth flows.
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSGatewayPath {

    Join-Path (Get-HALSRoot) "Gateway\HALSGateway.ps1"

}

function Test-HALSGatewayRunning {

    param(
        [int]$Port = 8000,
        [string]$HostName = "127.0.0.1"
    )

    $Client = $null

    try {
        $Client = [System.Net.Sockets.TcpClient]::new()
        $Connect = $Client.BeginConnect($HostName, $Port, $null, $null)
        $Ready = $Connect.AsyncWaitHandle.WaitOne(500)

        if ($Ready -and $Client.Connected) {
            return $true
        }
    }
    catch {
        return $false
    }
    finally {
        if ($Client) {
            $Client.Close()
        }
    }

    return $false

}

function Start-HALSGateway {

    param(
        [switch]$WaitForReady,
        [int]$TimeoutSeconds = 15
    )

    if (Test-HALSGatewayRunning) {
        return $true
    }

    $GatewayPath = Get-HALSGatewayPath

    if (-not (Test-Path -LiteralPath $GatewayPath)) {
        throw "HALS OAuth Gateway not found: $GatewayPath"
    }

    Start-Process pwsh `
        -WindowStyle Normal `
        -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $GatewayPath
        )

    if (-not $WaitForReady) {
        return $true
    }

    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $Deadline) {
        Start-Sleep -Milliseconds 400

        if (Test-HALSGatewayRunning) {
            return $true
        }
    }

    throw "HALS OAuth Gateway did not start on http://127.0.0.1:8000/ within $TimeoutSeconds seconds."

}

function Initialize-HALSGateway {

    param(
        [switch]$Quiet
    )

    if (Test-HALSGatewayRunning) {
        if (-not $Quiet) {
            Write-Host "  HALS OAuth Gateway is ready on http://127.0.0.1:8000/" -ForegroundColor DarkGray
        }
        return $true
    }

    if (-not $Quiet) {
        Write-Host "  Starting HALS OAuth Gateway..." -ForegroundColor Yellow
    }

    Start-HALSGateway -WaitForReady | Out-Null

    if (-not $Quiet) {
        Write-Host "  HALS OAuth Gateway started on http://127.0.0.1:8000/" -ForegroundColor Green
        Write-Host "  Complete OAuth consent in your browser when prompted." -ForegroundColor DarkGray
    }

    return $true

}

Set-Alias -Name Ensure-HALSGateway -Value Initialize-HALSGateway -Scope Local

Export-ModuleMember -Function `
    Get-HALSGatewayPath,
    Test-HALSGatewayRunning,
    Start-HALSGateway,
    Initialize-HALSGateway
