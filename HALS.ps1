#==========================================================
# HALS - Main Program
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Helper : separator line (ASCII-safe)
#----------------------------------------------------------

function Get-Sep { "  " + ("-" * 46) }

#----------------------------------------------------------
# Root path bootstrap
#----------------------------------------------------------

# Bind to this script's folder so a moved/copied tree stays self-contained.
$HALSRootPath = Split-Path -Parent $PSCommandPath
$env:HALS_ROOT = $HALSRootPath
Import-Module "$HALSRootPath\Core\HALSRoot.psm1" -Force -WarningAction SilentlyContinue

# Core Modules
#----------------------------------------------------------

Import-Module "$(Get-HALSRoot)\Core\HALSVersion.psm1"              -Force
Import-Module "$(Get-HALSRoot)\Core\HALSDevice.psm1"               -Force
Import-Module "$(Get-HALSRoot)\Core\HALSProviderRegistry.psm1"     -Force -Global
Import-Module "$(Get-HALSRoot)\Core\HALSColor.psm1"                -Force
Import-Module "$(Get-HALSRoot)\Core\HALSKnowledgeBase.psm1"        -Force
Import-Module "$(Get-HALSRoot)\Core\HALSJsonStore.psm1"            -Force
Import-Module "$(Get-HALSRoot)\Core\HALSExperiment.psm1"           -Force
Import-Module "$(Get-HALSRoot)\Core\HALSObservation.psm1"          -Force
Import-Module "$(Get-HALSRoot)\Core\HALSProviderHealth.psm1"       -Force
Import-Module "$(Get-HALSRoot)\Core\HALSEvidence.psm1"             -Force
Import-Module "$(Get-HALSRoot)\Core\HALSLab.psm1"                  -Force -WarningAction SilentlyContinue
Import-Module "$(Get-HALSRoot)\Core\HALSOAuth.psm1"                -Force
Import-Module "$(Get-HALSRoot)\Core\HALSOAuthToken.psm1"           -Force

Import-Module "$(Get-HALSRoot)\Core\HALS.psm1"                -Force
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
Import-Module "$(Get-HALSRoot)\Core\HALSStartup.psm1"         -Force

#----------------------------------------------------------
# AI Modules
#----------------------------------------------------------

Import-Module "$(Get-HALSRoot)\AI\HALSAIProviderRegistry.psm1" -Force -Global
Import-Module "$(Get-HALSRoot)\AI\AIConfiguration.psm1"       -Force
Import-Module "$(Get-HALSRoot)\AI\InventorySerializer.psm1"   -Force
Import-Module "$(Get-HALSRoot)\AI\ContextBuilder.psm1"        -Force
Import-Module "$(Get-HALSRoot)\AI\PromptBuilder.psm1"         -Force
Import-Module "$(Get-HALSRoot)\AI\Initialize-HALSAI.psm1"     -Force -Global
Import-Module "$(Get-HALSRoot)\AI\PlanParser.psm1"            -Force
Import-Module "$(Get-HALSRoot)\AI\ExecutionDetector.psm1"     -Force

Import-Module "$(Get-HALSRoot)\AI\HALSAI.psm1" `
    -Force `
    -DisableNameChecking `
    -WarningAction SilentlyContinue

Import-Module "$(Get-HALSRoot)\AI\HALSAIProvider.psm1"        -Force

# Load every AI provider module and setup wizard so Initialize-*
# commands (and their Invoke-/Get- helpers) work at the prompt.
foreach ($AIProvider in @(Get-HALSAIProviderRegistry)) {
    foreach ($RelativePath in @($AIProvider.ModulePath, $AIProvider.SetupModule) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique) {

        $ModuleFile = Join-Path (Get-HALSRoot) $RelativePath
        if (Test-Path -LiteralPath $ModuleFile) {
            Import-Module $ModuleFile -Force -Global
        }
    }
}

#----------------------------------------------------------
# Provider Modules
#----------------------------------------------------------

Get-ChildItem "$(Get-HALSRoot)\Providers" -Filter "*.psm1" |
    Sort-Object Name |
    ForEach-Object {
        Import-Module $_.FullName -Force -Global
    }

#----------------------------------------------------------
# Build Inventory
#----------------------------------------------------------

$Inventory = Get-HALSInventory

$Global:HALSInventory = $Inventory

#----------------------------------------------------------
# HALSLab
#----------------------------------------------------------

Initialize-HALSLab

#----------------------------------------------------------
# Providers (status + setup command on one line each)
#----------------------------------------------------------

$ProviderHealth = Get-HALSProviderHealth
$AIConfig = Get-HALSAIConfiguration -Optional
$AIConfigured = $null -ne $AIConfig

Write-HALSProvidersPanel `
    -ProviderHealth $ProviderHealth `
    -AIConfiguration $AIConfig

#----------------------------------------------------------
# Inventory Summary
#----------------------------------------------------------

Write-HALSInventorySummary -Inventory $Inventory

#----------------------------------------------------------
# Discovery
#----------------------------------------------------------

Invoke-HALSDiscovery -Devices @($Inventory.Devices)

$Global:HALSInventory = $Inventory

#----------------------------------------------------------
# Snapshot
#----------------------------------------------------------

$Snapshot = Save-HALSSnapshot -Devices @($Inventory.Devices)

Write-Host "  Snapshot : " -NoNewline -ForegroundColor DarkGray
Write-Host $Snapshot -ForegroundColor DarkGray
Write-Host ""

#----------------------------------------------------------
# Core commands (provider setup lives in the panels above)
#----------------------------------------------------------

Write-Host "  COMMANDS" -ForegroundColor Cyan
Write-Host (Get-Sep) -ForegroundColor DarkGray
Write-Host ""

$CW = 34

if ($AIConfigured) {
    Write-Host ("    " + "Ask-HALSAI".PadRight($CW)) -NoNewline
    Write-Host "Natural language control" -ForegroundColor DarkGray
}
Write-Host ("    " + "HALS".PadRight($CW))        -NoNewline; Write-Host "Run inventory scan" -ForegroundColor DarkGray
Write-Host ("    " + "CompareHALS".PadRight($CW)) -NoNewline; Write-Host "Compare latest snapshots" -ForegroundColor DarkGray
Write-Host ("    " + "Knowledge".PadRight($CW))   -NoNewline; Write-Host "Show known devices" -ForegroundColor DarkGray
Write-Host ("    " + "Snapshots".PadRight($CW))   -NoNewline; Write-Host "List snapshots" -ForegroundColor DarkGray
Write-Host ("    " + "Help".PadRight($CW))        -NoNewline; Write-Host "Show help" -ForegroundColor DarkGray
Write-Host ("    " + "Version".PadRight($CW))     -NoNewline; Write-Host "Show version" -ForegroundColor DarkGray
Write-Host ""
