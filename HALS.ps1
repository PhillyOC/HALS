#==========================================================
# HALS - Main Program
# Version : 0.8.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Helper : separator line (ASCII-safe)
#----------------------------------------------------------

function Get-Sep { "  " + ("-" * 46) }

#----------------------------------------------------------
#----------------------------------------------------------
# Root path bootstrap
#----------------------------------------------------------

$HALSRootPath = if ($env:HALS_ROOT) { $env:HALS_ROOT } else { Split-Path -Parent $PSCommandPath }
Import-Module "$HALSRootPath\Core\HALSRoot.psm1" -Force -WarningAction SilentlyContinue

# Core Modules
#----------------------------------------------------------

Import-Module "$(Get-HALSRoot)\Core\HALSDevice.psm1"               -Force
Import-Module "$(Get-HALSRoot)\Core\HALSColor.psm1"                -Force
Import-Module "$(Get-HALSRoot)\Core\HALSSmartThingsDevice.psm1"    -Force
Import-Module "$(Get-HALSRoot)\Core\HALSHomeAssistantDevice.psm1"  -Force
Import-Module "$(Get-HALSRoot)\Core\HALSGoogleNestDevice.psm1"     -Force
Import-Module "$(Get-HALSRoot)\Core\HALSPhilipsHueDevice.psm1"     -Force
Import-Module "$(Get-HALSRoot)\Core\HALSEcobeeDevice.psm1"         -Force
Import-Module "$(Get-HALSRoot)\Core\HALSKnowledgeBase.psm1"        -Force
Import-Module "$(Get-HALSRoot)\Core\HALSJsonStore.psm1"            -Force
Import-Module "$(Get-HALSRoot)\Core\HALSExperiment.psm1"           -Force
Import-Module "$(Get-HALSRoot)\Core\HALSObservation.psm1"          -Force
Import-Module "$(Get-HALSRoot)\Core\HALSProviderHealth.psm1"       -Force
Import-Module "$(Get-HALSRoot)\Core\HALSEvidence.psm1"             -Force
Import-Module "$(Get-HALSRoot)\Core\HALSLab.psm1"                  -Force -WarningAction SilentlyContinue
Import-Module "$(Get-HALSRoot)\Core\HALSOAuth.psm1"                -Force
Import-Module "$(Get-HALSRoot)\Core\HALSOAuthToken.psm1"           -Force
Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSSmartThingsOAuth.psm1"  -Force
Import-Module "$(Get-HALSRoot)\Core\Complete-HALSSmartThingsOAuth.psm1"    -Force
Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSGoogleNestOAuth.psm1"   -Force
Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSPhilipsHue.psm1"        -Force
Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSEcobeeOAuth.psm1"       -Force
Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSPushbullet.psm1"      -Force

Import-Module "$(Get-HALSRoot)\Core\HALS.psm1"                -Force
Import-Module "$(Get-HALSRoot)\Core\Merge.psm1"               -Force
Import-Module "$(Get-HALSRoot)\Core\Inventory.psm1"           -Force
Import-Module "$(Get-HALSRoot)\Core\Knowledge.psm1"           -Force
Import-Module "$(Get-HALSRoot)\Core\HALSEntity.psm1"          -Force
Import-Module "$(Get-HALSRoot)\Core\HALSAsset.psm1"           -Force
Import-Module "$(Get-HALSRoot)\Core\HALSAssetMerge.psm1"      -Force
Import-Module "$(Get-HALSRoot)\Core\IdentityResolver.psm1"    -Force
Import-Module "$(Get-HALSRoot)\Core\EntityClassification.psm1" -Force
Import-Module "$(Get-HALSRoot)\Core\EntityQuery.psm1"         -Force
Import-Module "$(Get-HALSRoot)\Core\HALSCapability.psm1"      -Force
Import-Module "$(Get-HALSRoot)\Core\Status.psm1"              -Force
Import-Module "$(Get-HALSRoot)\Core\CapabilityDiscovery.psm1" -Force
Import-Module "$(Get-HALSRoot)\Core\CapabilityQuery.psm1"     -Force
Import-Module "$(Get-HALSRoot)\Core\HALSPermission.psm1"      -Force
Import-Module "$(Get-HALSRoot)\Core\PermissionDiscovery.psm1" -Force
Import-Module "$(Get-HALSRoot)\Core\HALSAction.psm1"          -Force
Import-Module "$(Get-HALSRoot)\Core\HALSPlanner.psm1"         -Force
Import-Module "$(Get-HALSRoot)\Core\HALSPolicy.psm1"          -Force
Import-Module "$(Get-HALSRoot)\Core\HALSExecutor.psm1"        -Force
Import-Module "$(Get-HALSRoot)\Core\HALSCommand.psm1"         -Force
Import-Module "$(Get-HALSRoot)\Core\CommandDiscovery.psm1"    -Force
Import-Module "$(Get-HALSRoot)\Core\HALSCommandTranslator.psm1" -Force
Import-Module "$(Get-HALSRoot)\Core\HALSStartup.psm1"         -Force

#----------------------------------------------------------
# AI Modules
#----------------------------------------------------------

Import-Module "$(Get-HALSRoot)\AI\AIConfiguration.psm1"       -Force
Import-Module "$(Get-HALSRoot)\AI\InventorySerializer.psm1"   -Force
Import-Module "$(Get-HALSRoot)\AI\ContextBuilder.psm1"        -Force
Import-Module "$(Get-HALSRoot)\AI\PromptBuilder.psm1"         -Force
Import-Module "$(Get-HALSRoot)\AI\Initialize-HALSAI.psm1"     -Force
Import-Module "$(Get-HALSRoot)\AI\Providers\OpenAI.psm1"      -Force
Import-Module "$(Get-HALSRoot)\AI\Providers\Claude.psm1"      -Force
Import-Module "$(Get-HALSRoot)\AI\Providers\Gemini.psm1"      -Force
Import-Module "$(Get-HALSRoot)\AI\Providers\TogetherAI.psm1"  -Force
Import-Module "$(Get-HALSRoot)\AI\Providers\Mistral.psm1"      -Force
Import-Module "$(Get-HALSRoot)\AI\Providers\Ollama.psm1"       -Force
Import-Module "$(Get-HALSRoot)\AI\PlanParser.psm1"            -Force
Import-Module "$(Get-HALSRoot)\AI\ExecutionDetector.psm1"     -Force

Import-Module "$(Get-HALSRoot)\AI\HALSAI.psm1" `
    -Force `
    -DisableNameChecking `
    -WarningAction SilentlyContinue

Import-Module "$(Get-HALSRoot)\AI\HALSAIProvider.psm1"        -Force

#----------------------------------------------------------
# AI Setup Wizards
#----------------------------------------------------------

Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSClaude.psm1"      -Force
Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSGemini.psm1"      -Force
Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSTogetherAI.psm1"  -Force
Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSMistral.psm1"       -Force
Import-Module "$(Get-HALSRoot)\Core\Initialize-HALSOllama.psm1"        -Force

#----------------------------------------------------------
# Provider Modules
#----------------------------------------------------------

Import-Module "$(Get-HALSRoot)\Providers\UniFi.psm1"            -Force
Import-Module "$(Get-HALSRoot)\Providers\SmartThings.psm1"      -Force
Import-Module "$(Get-HALSRoot)\Providers\HomeAssistant.psm1"    -Force
Import-Module "$(Get-HALSRoot)\Providers\SmartThingsActions.psm1" -Force
Import-Module "$(Get-HALSRoot)\Providers\GoogleNest.psm1"       -Force
Import-Module "$(Get-HALSRoot)\Providers\PhilipsHue.psm1"       -Force
Import-Module "$(Get-HALSRoot)\Providers\Ecobee.psm1"           -Force
Import-Module "$(Get-HALSRoot)\Providers\Pushbullet.psm1"      -Force

#----------------------------------------------------------
# Connect UniFi
#----------------------------------------------------------

$Connection = Connect-HALSConfiguredUniFi

#----------------------------------------------------------
# Build Inventory
#----------------------------------------------------------

$Inventory = Get-HALSInventory -Connection $Connection

$Global:HALSInventory = $Inventory

#----------------------------------------------------------
# HALSLab
#----------------------------------------------------------

Initialize-HALSLab

#----------------------------------------------------------
# Integrations Panel
#----------------------------------------------------------

$ProviderHealth = Get-HALSProviderHealth

Write-HALSIntegrationsPanel -ProviderHealth $ProviderHealth

#----------------------------------------------------------
# AI Panel
#----------------------------------------------------------

try {

    $AIConfig = Get-HALSAIConfiguration
    Write-HALSAIPanel -AIConfiguration $AIConfig

}
catch {

    Write-Host "  AI PROVIDERS" -ForegroundColor Cyan
    Write-Host (Get-Sep) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    [!] AI not configured." -ForegroundColor Yellow
    Write-Host "        Run Initialize-HALSAI to choose a provider." -ForegroundColor DarkGray
    Write-Host ""

}

#----------------------------------------------------------
# Inventory Summary
#----------------------------------------------------------

Write-HALSInventorySummary -Inventory $Inventory

#----------------------------------------------------------
# Discovery
#----------------------------------------------------------

Invoke-HALSDiscovery -Devices $Inventory.Devices

$Global:HALSInventory = $Inventory

#----------------------------------------------------------
# Snapshot
#----------------------------------------------------------

$Snapshot = Save-HALSSnapshot -Devices $Inventory.Devices

Write-Host "  Snapshot : " -NoNewline -ForegroundColor DarkGray
Write-Host $Snapshot -ForegroundColor DarkGray
Write-Host ""

#----------------------------------------------------------
# Available Commands
#----------------------------------------------------------

Write-Host "  COMMANDS" -ForegroundColor Cyan
Write-Host (Get-Sep) -ForegroundColor DarkGray
Write-Host ""

$CW = 34

Write-Host "  -- General --" -ForegroundColor DarkGray
Write-Host ("    " + "Ask-HALSAI".PadRight($CW))             -NoNewline; Write-Host "Natural language control" -ForegroundColor DarkGray
Write-Host ("    " + "HALS".PadRight($CW))                   -NoNewline; Write-Host "Run inventory scan" -ForegroundColor DarkGray
Write-Host ("    " + "CompareHALS".PadRight($CW))            -NoNewline; Write-Host "Compare latest snapshots" -ForegroundColor DarkGray
Write-Host ("    " + "Knowledge".PadRight($CW))              -NoNewline; Write-Host "Show known devices" -ForegroundColor DarkGray
Write-Host ("    " + "Snapshots".PadRight($CW))              -NoNewline; Write-Host "List snapshots" -ForegroundColor DarkGray
Write-Host ("    " + "Help".PadRight($CW))                   -NoNewline; Write-Host "Show help" -ForegroundColor DarkGray
Write-Host ("    " + "Version".PadRight($CW))                -NoNewline; Write-Host "Show version" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  -- AI Providers --" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSAI".PadRight($CW))             -NoNewline; Write-Host "Choose and set up an AI provider" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-OpenAI".PadRight($CW))             -NoNewline; Write-Host "Set up OpenAI" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSClaude".PadRight($CW))         -NoNewline; Write-Host "Set up Anthropic Claude" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSGemini".PadRight($CW))         -NoNewline; Write-Host "Set up Google Gemini" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSTogetherAI".PadRight($CW))     -NoNewline; Write-Host "Set up Together AI" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSMistral".PadRight($CW))        -NoNewline; Write-Host "Set up Mistral AI" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSOllama".PadRight($CW))         -NoNewline; Write-Host "Set up local Ollama" -ForegroundColor DarkGray
Write-Host ("    " + "Switch-HALSAIProvider".PadRight($CW))           -NoNewline; Write-Host "Switch active provider (-Provider <name>)" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  -- Device Integrations --" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSSmartThingsOAuth".PadRight($CW))  -NoNewline; Write-Host "Set up SmartThings OAuth" -ForegroundColor DarkGray
Write-Host ("    " + "Complete-HALSSmartThingsOAuth".PadRight($CW))    -NoNewline; Write-Host "Complete SmartThings OAuth manually" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSGoogleNestOAuth".PadRight($CW))   -NoNewline; Write-Host "Set up Google Nest" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSPhilipsHue".PadRight($CW))        -NoNewline; Write-Host "Set up Philips Hue bridge" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSEcobeeOAuth".PadRight($CW))       -NoNewline; Write-Host "Set up Ecobee thermostat" -ForegroundColor DarkGray
Write-Host ("    " + "Initialize-HALSPushbullet".PadRight($CW))        -NoNewline; Write-Host "Set up Pushbullet notifications" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  -- HALSLab --" -ForegroundColor DarkGray
Write-Host ("    " + "Start-HALSExperiment".PadRight($CW))  -NoNewline; Write-Host "New experiment" -ForegroundColor DarkGray
Write-Host ("    " + "Get-HALSExperiments".PadRight($CW))   -NoNewline; Write-Host "View experiment history" -ForegroundColor DarkGray
Write-Host ("    " + "Get-HALSObservations".PadRight($CW))  -NoNewline; Write-Host "View observations" -ForegroundColor DarkGray
Write-Host ("    " + "Get-HALSEvidence".PadRight($CW))      -NoNewline; Write-Host "View evidence" -ForegroundColor DarkGray
Write-Host ""