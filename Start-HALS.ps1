#==========================================================
# HALS Startup Console
# Version : 1.4.0
#==========================================================

Clear-Host

$HALSVersionFile = Join-Path (Split-Path -Parent $PSCommandPath) "VERSION"
$HALSVersion = if (Test-Path -LiteralPath $HALSVersionFile) {
    (Get-Content -LiteralPath $HALSVersionFile -Raw).Trim()
}
else {
    "0.0.0-dev"
}

#----------------------------------------------------------
# HALS Root
#----------------------------------------------------------

$HALSRoot = Split-Path -Parent $PSCommandPath
Set-Location $HALSRoot

#
# Always bind this session to the folder that was launched.
# This keeps HALS portable across drives and ignores any stale
# machine/user HALS_ROOT left behind from an older location.
#
$env:HALS_ROOT = $HALSRoot

#
# Load the root resolver first so all subsequent modules
# can call Get-HALSRoot().
#
Import-Module "$HALSRoot\Core\HALSRoot.psm1" -Force -WarningAction SilentlyContinue

try {
    Import-Module "$HALSRoot\Core\HALSGatewayManager.psm1" -Force -ErrorAction SilentlyContinue
    if (Get-Command Initialize-HALSGateway -ErrorAction SilentlyContinue) {
        Initialize-HALSGateway -Quiet | Out-Null
    }
    elseif (Get-Command Ensure-HALSGateway -ErrorAction SilentlyContinue) {
        Ensure-HALSGateway -Quiet | Out-Null
    }
}
catch {
    # Gateway is optional at startup; OAuth setup will retry if needed.
}

#----------------------------------------------------------
# Load Bootstrap Modules
#----------------------------------------------------------

Import-Module "$HALSRoot\Core\HALS.psm1"       -Force -WarningAction SilentlyContinue
Import-Module "$HALSRoot\Core\HALSDevice.psm1" -Force -WarningAction SilentlyContinue
Import-Module "$HALSRoot\Core\HALSProviderRegistry.psm1" -Force -Global -WarningAction SilentlyContinue
Import-Module "$HALSRoot\Core\Knowledge.psm1"  -Force -WarningAction SilentlyContinue
Import-Module "$HALSRoot\Core\Inventory.psm1"  -Force -WarningAction SilentlyContinue

#----------------------------------------------------------
# Helper
#----------------------------------------------------------

function Get-Sep { "  " + ("-" * 48) }

#----------------------------------------------------------
# Session Commands
#----------------------------------------------------------

function HALS        { & "$HALSRoot\HALS.ps1" }
function CompareHALS { Compare-HALSSnapshots }
function Knowledge   { Get-HALSKnownDevices | Format-Table -AutoSize }
function Snapshots   { Get-HALSSnapshots }

function global:Initiate-HALSDeviceProvider {
    Initialize-HALSDeviceProvider @args
}

function global:Initiazize-HALSDeviceProvider {
    Initialize-HALSDeviceProvider @args
}

function Version {
    Write-Host ""
    Write-Host "  HALS v$HALSVersion" -ForegroundColor Cyan
    Write-Host ""
}

function Help {

    Write-Host ""
    Write-Host "  HALS COMMANDS" -ForegroundColor Cyan
    Write-Host (Get-Sep) -ForegroundColor DarkGray
    Write-Host ""

    $CW = 34

    Write-Host "  -- Get started --" -ForegroundColor DarkGray
    Write-Host ("    " + "Initialize-HALSDeviceProvider".PadRight($CW)) -NoNewline
    Write-Host "Wizard: connect a device platform" -ForegroundColor DarkGray
    Write-Host ("    " + "Reconnect-SmartThingsOAuth".PadRight($CW)) -NoNewline
    Write-Host "Finish SmartThings OAuth after browser login" -ForegroundColor DarkGray
    Write-Host ("    " + "Initialize-HALSAI".PadRight($CW)) -NoNewline
    Write-Host "Wizard: choose and set up an AI provider" -ForegroundColor DarkGray
    Write-Host ("    " + "Switch-HALSAIProvider".PadRight($CW)) -NoNewline
    Write-Host "Switch active AI (-Provider <name>)" -ForegroundColor DarkGray
    Write-Host ("    " + "Remove-HALSDeviceProvider".PadRight($CW)) -NoNewline
    Write-Host "Remove a device integration (-Provider <name>)" -ForegroundColor DarkGray
    Write-Host ("    " + "Remove-HALSAIProvider".PadRight($CW)) -NoNewline
    Write-Host "Remove an AI provider (-Provider <name>)" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  -- Everyday --" -ForegroundColor DarkGray
    Write-Host ("    " + "Ask-HALSAI".PadRight($CW))  -NoNewline; Write-Host "Natural language control (-Verbose previews plan)" -ForegroundColor DarkGray
    Write-Host ("    " + "HALS".PadRight($CW))        -NoNewline; Write-Host "Run inventory scan" -ForegroundColor DarkGray
    Write-Host ("    " + "CompareHALS".PadRight($CW)) -NoNewline; Write-Host "Compare latest snapshots" -ForegroundColor DarkGray
    Write-Host ("    " + "Knowledge".PadRight($CW))   -NoNewline; Write-Host "Show known devices" -ForegroundColor DarkGray
    Write-Host ("    " + "Snapshots".PadRight($CW))   -NoNewline; Write-Host "List snapshots" -ForegroundColor DarkGray
    Write-Host ("    " + "Version".PadRight($CW))     -NoNewline; Write-Host "Show version" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  -- HALSLab --" -ForegroundColor DarkGray
    Write-Host ("    " + "Start-HALSExperiment".PadRight($CW))  -NoNewline; Write-Host "New experiment" -ForegroundColor DarkGray
    Write-Host ("    " + "Get-HALSExperiments".PadRight($CW))   -NoNewline; Write-Host "View experiment history" -ForegroundColor DarkGray
    Write-Host ("    " + "Get-HALSObservations".PadRight($CW))  -NoNewline; Write-Host "View observations" -ForegroundColor DarkGray
    Write-Host ("    " + "Get-HALSEvidence".PadRight($CW))      -NoNewline; Write-Host "View evidence" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  Provider setup commands are listed next to each platform" -ForegroundColor DarkGray
    Write-Host "  on startup. Prefer the wizards above when you are just getting started." -ForegroundColor DarkGray
    Write-Host ""

}

#----------------------------------------------------------
# Banner
#----------------------------------------------------------

Write-Host ""
Write-Host "  +================================================+" -ForegroundColor Cyan
Write-Host "  |   HALS  -  Home Automation & Logging System   |" -ForegroundColor Cyan
Write-Host "  +================================================+" -ForegroundColor Cyan
Write-Host ""
Write-Host ("  " + "Version".PadRight(12) + $HALSVersion) -ForegroundColor DarkGray
Write-Host ("  " + "User".PadRight(12)    + $env:USERNAME) -ForegroundColor DarkGray
Write-Host ("  " + "Computer".PadRight(12)+ $env:COMPUTERNAME) -ForegroundColor DarkGray
Write-Host ("  " + "Started".PadRight(12) + (Get-Date -Format "yyyy-MM-dd  HH:mm:ss")) -ForegroundColor DarkGray
Write-Host ""

#----------------------------------------------------------
# Run HALS Scan
#----------------------------------------------------------

HALS

# Make sure AI setup wizards are available at the interactive prompt.
# (Initialize-HALSAI loads them on demand; these make direct commands work too.)
if (Get-Command Get-HALSAIProviderRegistry -ErrorAction SilentlyContinue) {
    foreach ($AIProvider in @(Get-HALSAIProviderRegistry)) {
        if (-not (Get-Command $AIProvider.SetupCommand -ErrorAction SilentlyContinue)) {
            Import-HALSAIProvider -Provider $AIProvider.Key -Setup
        }
    }
}

# Expose SmartThings OAuth reconnect at the prompt when credentials exist but tokens do not.
if (-not (Get-Command Test-HALSSmartThingsOAuthPending -ErrorAction SilentlyContinue)) {
    $SmartThingsModule = Join-Path $HALSRoot "Providers\SmartThings.psm1"
    if (Test-Path -LiteralPath $SmartThingsModule) {
        Import-Module $SmartThingsModule -Force -Global -WarningAction SilentlyContinue
    }
}

if ((Get-Command Test-HALSSmartThingsOAuthPending -ErrorAction SilentlyContinue) -and
    (Test-HALSSmartThingsOAuthPending)) {
    Write-Host "  SmartThings OAuth is not finished. Run Reconnect-SmartThingsOAuth." -ForegroundColor Yellow
    Write-Host ""
}

#----------------------------------------------------------
# Snapshot Comparison
#----------------------------------------------------------

Write-Host "  CHANGES SINCE LAST SCAN" -ForegroundColor Cyan
Write-Host (Get-Sep) -ForegroundColor DarkGray

CompareHALS

#----------------------------------------------------------
# Ready
#----------------------------------------------------------

Write-Host "  HALS Ready." -ForegroundColor Cyan
Write-Host "  Enter " -NoNewline -ForegroundColor DarkGray
Write-Host "Initialize-HALSDeviceProvider" -NoNewline -ForegroundColor White
Write-Host " (or " -NoNewline -ForegroundColor DarkGray
Write-Host "Initiate-HALSDeviceProvider" -NoNewline -ForegroundColor DarkGray
Write-Host ") or " -NoNewline -ForegroundColor DarkGray
Write-Host "Initialize-HALSAI" -NoNewline -ForegroundColor White
Write-Host " to get started adding your platforms and AI." -ForegroundColor DarkGray
Write-Host ""
