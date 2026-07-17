#==========================================================
# HALS Startup Console
# Version : 1.4.0
#==========================================================

Clear-Host

$HALSVersion = "0.8.0"

#----------------------------------------------------------
# HALS Root
#----------------------------------------------------------

$HALSRoot = Split-Path -Parent $PSCommandPath
Set-Location $HALSRoot

#
# Publish the root path as an environment variable so every
# module loaded by HALS.ps1 can call Get-HALSRoot() without
# needing to know where the folder is installed.
#
$env:HALS_ROOT = $HALSRoot

#
# Load the root resolver first so all subsequent modules
# can call Get-HALSRoot().
#
Import-Module "$HALSRoot\Core\HALSRoot.psm1" -Force -WarningAction SilentlyContinue

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

    Write-Host "  -- General --" -ForegroundColor DarkGray
    Write-Host ("    " + "Ask-HALSAI".PadRight($CW))             -NoNewline; Write-Host "Natural language control" -ForegroundColor DarkGray
    Write-Host ("    " + "HALS".PadRight($CW))                   -NoNewline; Write-Host "Run inventory scan" -ForegroundColor DarkGray
    Write-Host ("    " + "CompareHALS".PadRight($CW))            -NoNewline; Write-Host "Compare latest snapshots" -ForegroundColor DarkGray
    Write-Host ("    " + "Knowledge".PadRight($CW))              -NoNewline; Write-Host "Show known devices" -ForegroundColor DarkGray
    Write-Host ("    " + "Snapshots".PadRight($CW))              -NoNewline; Write-Host "List snapshots" -ForegroundColor DarkGray
    Write-Host ("    " + "Help".PadRight($CW))                   -NoNewline; Write-Host "Show this help" -ForegroundColor DarkGray
    Write-Host ("    " + "Version".PadRight($CW))                -NoNewline; Write-Host "Show version" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  -- AI Providers --" -ForegroundColor DarkGray
    Write-Host ("    " + "Initialize-HALSAI".PadRight($CW))             -NoNewline; Write-Host "Choose and set up an AI provider" -ForegroundColor DarkGray
    foreach ($Provider in @(Get-HALSAIProviderRegistry)) {
        Write-Host ("    " + $Provider.SetupCommand.PadRight($CW)) -NoNewline
        Write-Host "Set up $($Provider.Name)" -ForegroundColor DarkGray
    }
    Write-Host ("    " + "Switch-HALSAIProvider".PadRight($CW))           -NoNewline; Write-Host "Switch active provider (-Provider <name>)" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  -- Device Integrations --" -ForegroundColor DarkGray
    Write-Host ("    " + "Initialize-HALSDeviceProvider".PadRight($CW))    -NoNewline; Write-Host "Choose and set up a device provider" -ForegroundColor DarkGray
    foreach ($Setup in @(Get-HALSDeviceProviderSetupCommands)) {
        Write-Host ("    " + $Setup.Name.PadRight($CW)) -NoNewline
        Write-Host $Setup.Description -ForegroundColor DarkGray
    }
    Write-Host ""

    Write-Host "  -- HALSLab --" -ForegroundColor DarkGray
    Write-Host ("    " + "Start-HALSExperiment".PadRight($CW))   -NoNewline; Write-Host "New experiment" -ForegroundColor DarkGray
    Write-Host ("    " + "Get-HALSExperiments".PadRight($CW))    -NoNewline; Write-Host "View experiment history" -ForegroundColor DarkGray
    Write-Host ("    " + "Get-HALSObservations".PadRight($CW))   -NoNewline; Write-Host "View observations" -ForegroundColor DarkGray
    Write-Host ("    " + "Get-HALSEvidence".PadRight($CW))       -NoNewline; Write-Host "View evidence" -ForegroundColor DarkGray
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

#----------------------------------------------------------
# Snapshot Comparison
#----------------------------------------------------------

Write-Host "  CHANGES SINCE LAST SCAN" -ForegroundColor Cyan
Write-Host (Get-Sep) -ForegroundColor DarkGray

CompareHALS

#----------------------------------------------------------
# Ready
#----------------------------------------------------------

Write-Host "  HALS Ready. " -NoNewline -ForegroundColor Cyan
Write-Host "Type " -NoNewline -ForegroundColor DarkGray
Write-Host "Help" -NoNewline -ForegroundColor White
Write-Host " to view available commands." -ForegroundColor DarkGray
Write-Host ""
