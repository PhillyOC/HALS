#==========================================================
# HALS Web API
# Version : 1.0.0
#
# REST backend for the portable HALS web frontend.
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script:WebVersion = $(
    $VersionFile = if ($PSCommandPath) {
        Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) "VERSION"
    }
    else {
        Join-Path (Split-Path -Parent $PSScriptRoot) "VERSION"
    }
    if (Test-Path -LiteralPath $VersionFile) {
        (Get-Content -LiteralPath $VersionFile -Raw).Trim()
    }
    else {
        "1.0.0"
    }
)
$Script:WebStarted = Get-Date
$Script:WebModulesLoaded = $false

function Test-HALSWebInventoryLoaded {
    return (Test-Path variable:global:HALSInventory)
}

function Get-HALSWebInventory {
    if (Test-HALSWebInventoryLoaded) { return $Global:HALSInventory }
    return $null
}

#----------------------------------------------------------
# Module bootstrap
#----------------------------------------------------------

function Initialize-HALSWebModules {

    if ($Script:WebModulesLoaded) { return }

    $Root = Get-HALSRoot

    $CoreModules = @(
        "HALSProviderRegistry.psm1", "HALSDevice.psm1", "HALSColor.psm1",
        "HALSKnowledgeBase.psm1", "HALSJsonStore.psm1", "HALSExperiment.psm1",
        "HALSObservation.psm1", "HALSProviderHealth.psm1", "HALSEvidence.psm1",
        "HALSLab.psm1", "HALSOAuth.psm1", "HALSOAuthToken.psm1",
        "HALS.psm1", "Inventory.psm1", "Knowledge.psm1",
        "HALSEntity.psm1", "HALSAsset.psm1", "HALSAssetMerge.psm1",
        "IdentityResolver.psm1", "EntityClassification.psm1", "EntityQuery.psm1",
        "HALSCapability.psm1", "Status.psm1", "CapabilityDiscovery.psm1",
        "CapabilityQuery.psm1", "HALSPermission.psm1", "PermissionDiscovery.psm1",
        "HALSAction.psm1", "HALSPlanner.psm1", "HALSPolicy.psm1",
        "HALSExecutor.psm1", "HALSCommand.psm1", "CommandDiscovery.psm1",
        "HALSStartup.psm1"
    )

    foreach ($Module in $CoreModules) {
        Import-Module "$Root\Core\$Module" -Force -Global -WarningAction SilentlyContinue
    }

    $AIModules = @(
        "HALSAIProviderRegistry.psm1", "AIConfiguration.psm1", "InventorySerializer.psm1", "ContextBuilder.psm1",
        "HALSAIPrompt.psm1",         "HALSAIPrompt.psm1", "PromptBuilder.psm1", "Initialize-HALSAI.psm1",
        "PlanParser.psm1", "PlanRepair.psm1", "ExecutionDetector.psm1", "HALSAI.psm1", "HALSAIProvider.psm1"
    )

    foreach ($Module in $AIModules) {
        Import-Module "$Root\AI\$Module" -Force -Global -DisableNameChecking -WarningAction SilentlyContinue
    }

    $Providers = @(
        Get-ChildItem (Join-Path $Root "Providers") -Filter "*.psm1" |
            Sort-Object Name |
            Select-Object -ExpandProperty Name
    )

    foreach ($Module in $Providers) {
        Import-Module "$Root\Providers\$Module" -Force -Global -WarningAction SilentlyContinue
    }

    $Script:WebModulesLoaded = $true

    Ensure-HALSWebCommands @(
        "Get-HALSKnowledge",
        "Get-HALSInventory",
        "Merge-HALSAssets",
        "Get-HALSAIConfiguration",
        "Switch-HALSAIProvider"
    )
}

function Ensure-HALSWebCommands {

    param([string[]]$Commands)

    $Root = Get-HALSRoot

    $ModuleMap = @{
        "Get-HALSKnowledge"       = "Core\Knowledge.psm1"
        "Get-HALSKnownDevices"    = "Core\Knowledge.psm1"
        "Get-HALSInventory"       = "Core\Inventory.psm1"
        "Save-HALSSnapshot"       = "Core\HALS.psm1"
        "Get-HALSSnapshots"       = "Core\HALS.psm1"
        "New-HALSAsset"           = "Core\HALSAsset.psm1"
        "Merge-HALSAssets"        = "Core\HALSAssetMerge.psm1"
        "Get-HALSCapabilities"    = "Core\HALSCapability.psm1"
        "Get-HALSAIConfiguration" = "AI\AIConfiguration.psm1"
        "ConvertTo-HALSAIInventory" = "AI\InventorySerializer.psm1"
        "Get-HALSAIContext"       = "AI\ContextBuilder.psm1"
        "Switch-HALSAIProvider"   = "AI\HALSAIProvider.psm1"
        "Get-HALSRegisteredAIProviders" = "AI\HALSAIProviderRegistry.psm1"
    }

    foreach ($Command in $Commands) {

        if (Get-Command $Command -ErrorAction SilentlyContinue) { continue }

        if ($ModuleMap.ContainsKey($Command)) {
            Import-Module "$Root\$($ModuleMap[$Command])" -Force -Global
        }

        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "HALS Web could not load required command '$Command'. Restart the web server."
        }
    }
}

function Get-HALSWebKnowledgeSafe {

    Ensure-HALSWebCommands @("Get-HALSKnowledge")

    try { return Get-HALSKnowledge }
    catch { return @{} }
}

#----------------------------------------------------------
# Session
#----------------------------------------------------------

function Initialize-HALSWebSession {

    Initialize-HALSWebModules

    if (-not (Test-HALSWebInventoryLoaded)) {
        Import-HALSWebSnapshot
    }
    else {
        Ensure-HALSWebInventoryComplete
    }

    Ensure-HALSWebConnections
}

function Import-HALSWebSnapshot {

    $Snapshots = @(Get-HALSSnapshots)

    if ($Snapshots.Count -eq 0) {
        $Global:HALSInventory = [PSCustomObject]@{
            Devices        = @()
            Infrastructure = @()
            Clients        = @()
        }
        return
    }

    $Devices = Get-Content $Snapshots[0].FullName -Raw | ConvertFrom-Json

    $Global:HALSInventory = [PSCustomObject]@{
        Devices        = @($Devices)
        Infrastructure = @()
        Clients        = @()
        LoadedFrom     = $Snapshots[0].Name
    }

    Ensure-HALSWebInventoryComplete
}

function Ensure-HALSWebInventoryComplete {

    $Inventory = Get-HALSWebInventory
    if (-not $Inventory) { return }

    $Devices = @($Inventory.Devices)

    if ($Devices.Count -gt 0) {

        $HasAssets = $Inventory.PSObject.Properties["Assets"] -and @($Inventory.Assets).Count -gt 0

        if (-not $HasAssets) {
            Ensure-HALSWebCommands @("Merge-HALSAssets")
            $Assets = Merge-HALSAssets -Devices $Devices

            if ($Inventory.PSObject.Properties["Assets"]) {
                $Inventory.Assets = $Assets
            }
            else {
                $Inventory | Add-Member -NotePropertyName Assets -NotePropertyValue $Assets
            }
        }
    }

    $Global:HALSInventory = $Inventory

    if (-not $Inventory.PSObject.Properties["Knowledge"]) {
        $Inventory | Add-Member -NotePropertyName Knowledge -NotePropertyValue (Get-HALSWebKnowledgeSafe) -Force
        $Global:HALSInventory = $Inventory
    }
}

function Ensure-HALSWebConnections {
    # Provider action handlers establish connections on demand.
}

#----------------------------------------------------------
# Device helpers
#----------------------------------------------------------

function Get-HALSWebDeviceStatus {

    param($Device)

    if (-not $Device.Entities) { return "" }

    foreach ($Entity in $Device.Entities) {
        switch -Wildcard ($Entity.Name) {
            "switch.switch" { return [string]$Entity.Value }
            "contactSensor.contact" { return [string]$Entity.Value }
            "motionSensor.motion" { return [string]$Entity.Value }
            "lock.lock" { return [string]$Entity.Value }
            "thermostatMode.thermostatMode" { return [string]$Entity.Value }
        }
    }

    return ""
}

function ConvertTo-HALSWebDevice {

    param($Device)

    $Domain = ""
    if ($Device.PSObject.Properties["Domain"]) { $Domain = $Device.Domain }

    $DeviceId = ""
    if ($Device.PSObject.Properties["DeviceId"]) { $DeviceId = $Device.DeviceId }

    @{
        Name     = $Device.Name
        Category = $Device.Category
        Source   = $Device.Source
        IP       = if ($Device.IP) { $Device.IP } else { "" }
        MAC      = $Device.MAC
        Known    = [bool]$Device.Known
        Domain   = $Domain
        DeviceId = $DeviceId
        Status   = Get-HALSWebDeviceStatus -Device $Device
    }
}

#----------------------------------------------------------
# Overview
#----------------------------------------------------------

function Get-HALSWebOverview {

    Initialize-HALSWebSession

    $Inventory = Get-HALSWebInventory
    if (-not $Inventory) {
        return @{
            TotalDevices = 0
            Lights = 0; Sensors = 0; Switches = 0
            MediaPlayers = 0; Locks = 0; Cameras = 0
            BySource = @(); LoadedFrom = "none"
        }
    }

    $Devices = @($Inventory.Devices)

    function Get-Domain ($Device) {
        if ($Device.PSObject.Properties["Domain"]) { return $Device.Domain }
        return ""
    }

    $BySource = $Devices | Group-Object Source | ForEach-Object {
        @{ Source = $_.Name; Count = $_.Count }
    }

    @{
        TotalDevices = $Devices.Count
        Lights       = @($Devices | Where-Object { $_.Category -eq "Light Bulb" -or (Get-Domain $_) -eq "light" }).Count
        Sensors      = @($Devices | Where-Object { $_.Category -eq "Sensor" -or (Get-Domain $_) -in @("sensor","binary_sensor") }).Count
        Switches     = @($Devices | Where-Object { (Get-Domain $_) -eq "switch" }).Count
        MediaPlayers = @($Devices | Where-Object { $_.Category -in @("Television","Streaming Device","Smart Assistant") -or (Get-Domain $_) -eq "media_player" }).Count
        Locks        = @($Devices | Where-Object { (Get-Domain $_) -eq "lock" }).Count
        Cameras      = @($Devices | Where-Object { (Get-Domain $_) -eq "camera" }).Count
        BySource     = $BySource
        LoadedFrom   = if ($Inventory.PSObject.Properties["LoadedFrom"]) { $Inventory.LoadedFrom } else { "live" }
    }
}

#----------------------------------------------------------
# Status
#----------------------------------------------------------

function Get-HALSWebStatus {

    Initialize-HALSWebSession

    $ProviderHealth = Get-HALSProviderHealth

    $Integrations = @(Get-HALSDeviceProviders) | ForEach-Object {
        $Entry = $ProviderHealth[$_.Key]
        @{
            Name    = $_.Name
            Key     = $_.Key
            Status  = if ($Entry) { $Entry.Status } else { "NotConfigured" }
            Message = if ($Entry -and $Entry.Message) { $Entry.Message } else { "" }
        }
    }

    $AI = $null
    $AIProviders = @()

    try {
        $AIConfig = Get-HALSAIConfiguration -Optional

        if ($AIConfig) {
            $ActiveConfig = $AIConfig.($AIConfig.Provider)
            $AI = @{
                Active = $AIConfig.Provider
                Model  = if ($ActiveConfig.PSObject.Properties["Model"]) { $ActiveConfig.Model } else { "" }
            }
        }
        else {
            $AI = @{ Active = $null; Model = $null }
        }

        foreach ($Provider in @(Get-HALSAIProviderRegistry)) {
            $Cfg = if ($AIConfig -and $AIConfig.PSObject.Properties[$Provider.Key]) {
                $AIConfig.($Provider.Key)
            }
            else { $null }
            $Configured = $Cfg -and (
                Test-HALSAIProviderConfigured -Provider $Provider.Key -Configuration $Cfg
            )
            $AIProviders += @{
                Name     = $Provider.Name
                Key      = $Provider.Key
                Active   = $AIConfig -and $AIConfig.Provider -eq $Provider.Key
                Configured = $Configured
                Model    = if ($Cfg -and $Cfg.PSObject.Properties["Model"]) { $Cfg.Model } else { "" }
            }
        }
    }
    catch {
        $AI = @{ Active = $null; Model = $null }
    }

    @{
        Version      = $Script:WebVersion
        HALSVersion  = $(if (Get-Command Get-HALSVersion -ErrorAction SilentlyContinue) { Get-HALSVersion } else { $Script:WebVersion })
        Started      = $Script:WebStarted.ToString("o")
        Integrations = $Integrations
        AI           = $AI
        AIProviders  = $AIProviders
        Overview     = Get-HALSWebOverview
    }
}

#----------------------------------------------------------
# Devices
#----------------------------------------------------------

function Get-HALSWebDevices {

    param(
        [string]$Source = "",
        [string]$Category = "",
        [string]$Search = ""
    )

    Initialize-HALSWebSession

    $Inventory = Get-HALSWebInventory
    if (-not $Inventory) { return @() }

    $Devices = @($Inventory.Devices)

    if (-not [string]::IsNullOrWhiteSpace($Source)) {
        $Devices = @($Devices | Where-Object { $_.Source -eq $Source })
    }

    if (-not [string]::IsNullOrWhiteSpace($Category)) {
        $Devices = @($Devices | Where-Object { $_.Category -eq $Category })
    }

    if (-not [string]::IsNullOrWhiteSpace($Search)) {
        $Devices = @($Devices | Where-Object {
            $_.Name -like "*$Search*" -or
            $_.MAC -like "*$Search*" -or
            $_.IP -like "*$Search*"
        })
    }

    @($Devices | ForEach-Object { ConvertTo-HALSWebDevice -Device $_ })
}

function Get-HALSWebDevice {

    param([string]$Mac)

    Initialize-HALSWebSession

    $Inventory = Get-HALSWebInventory
    $Device = $Inventory.Devices |
        Where-Object { $_.MAC -eq $Mac } |
        Select-Object -First 1

    if (-not $Device) { return $null }

    $Summary = ConvertTo-HALSWebDevice -Device $Device
    $Summary.Entities = @($Device.Entities | ForEach-Object {
        @{
            Name  = $_.Name
            Value = [string]$_.Value
            Type  = $_.Type
        }
    })

    $Summary
}

#----------------------------------------------------------
# Scan
#----------------------------------------------------------

function Invoke-HALSWebScan {

    Initialize-HALSWebModules
    Ensure-HALSWebCommands @("Get-HALSKnowledge", "Get-HALSInventory", "Save-HALSSnapshot")

    $Inventory = Get-HALSInventory

    $Global:HALSInventory = $Inventory
    Ensure-HALSWebInventoryComplete

    $Snapshot = Save-HALSSnapshot -Devices $Inventory.Devices

    Ensure-HALSWebConnections

    @{
        DeviceCount = @($Inventory.Devices).Count
        Snapshot    = Split-Path $Snapshot -Leaf
        Overview    = Get-HALSWebOverview
    }
}

#----------------------------------------------------------
# Snapshots
#----------------------------------------------------------

function Get-HALSWebSnapshots {

    @(Get-HALSSnapshots | ForEach-Object {
        @{
            Name      = $_.Name
            Timestamp = $_.LastWriteTime.ToString("o")
            SizeKB    = [Math]::Round($_.Length / 1KB, 1)
        }
    })
}

function Compare-HALSWebSnapshots {

    $Snapshots = @(Get-HALSSnapshots)

    if ($Snapshots.Count -lt 2) {
        return @{ HasComparison = $false; Message = "Need at least two snapshots." }
    }

    $Current  = Get-Content $Snapshots[0].FullName -Raw | ConvertFrom-Json
    $Previous = Get-Content $Snapshots[1].FullName -Raw | ConvertFrom-Json

    $PreviousByMAC = @{}
    foreach ($Device in $Previous) { $PreviousByMAC[$Device.MAC] = $Device }

    $WizardDomains = @("light","switch","lock","fan","climate","cover","media_player","vacuum","camera","alarm_control_panel","humidifier","water_heater")

    $New     = @()
    $Missing = @()
    $Changed = @()

    foreach ($Device in $Current) {

        if (-not $PreviousByMAC.ContainsKey($Device.MAC)) {

            if ($Device.PSObject.Properties["Domain"] -and
                (-not $Device.PSObject.Properties["IP"] -or
                 [string]::IsNullOrWhiteSpace($Device.IP)) -and
                $Device.Domain -notin $WizardDomains) {
                $PreviousByMAC.Remove($Device.MAC)
                continue
            }

            $New += @{ Name = $Device.Name; MAC = $Device.MAC; Source = $Device.Source }
            continue
        }

        $Old = $PreviousByMAC[$Device.MAC]

        if ($Old.IP -ne $Device.IP -and -not [string]::IsNullOrWhiteSpace($Device.IP)) {
            $Changed += @{
                Name   = $Device.Name
                MAC    = $Device.MAC
                OldIP  = $Old.IP
                NewIP  = $Device.IP
                Change = "IP"
            }
        }

        $PreviousByMAC.Remove($Device.MAC)
    }

    foreach ($Device in $PreviousByMAC.Values) {

        if ($Device.PSObject.Properties["Domain"] -and
            (-not $Device.PSObject.Properties["IP"] -or
             [string]::IsNullOrWhiteSpace($Device.IP)) -and
            $Device.Domain -notin $WizardDomains) {
            continue
        }

        $Missing += @{ Name = $Device.Name; MAC = $Device.MAC; Source = $Device.Source }
    }

    @{
        HasComparison = $true
        Current       = $Snapshots[0].Name
        Previous      = $Snapshots[1].Name
        New           = $New
        Missing       = $Missing
        Changed       = $Changed
    }
}

#----------------------------------------------------------
# Actions
#----------------------------------------------------------

function Invoke-HALSWebAction {

    param(
        [string]$Provider,
        [string]$Device,
        [string]$Command,
        [hashtable]$Parameters = @{}
    )

    Initialize-HALSWebSession

    $Action = New-HALSAction `
        -Provider $Provider `
        -Device $Device `
        -Command $Command `
        -Parameters $Parameters

    $Plan = New-HALSPlan -Actions @($Action)
    Invoke-HALSPlan -Plan $Plan

    @{ Executed = $true; Command = $Command; Device = $Device; Provider = $Provider }
}

function Invoke-HALSWebPlan {

    param($PlanBody)

    Initialize-HALSWebSession

    $Actions = @()

    foreach ($Action in @($PlanBody.Actions)) {

        $Params = @{}
        if ($Action.Parameters) {
            foreach ($Prop in $Action.Parameters.PSObject.Properties) {
                $Params[$Prop.Name] = $Prop.Value
            }
        }

        $Actions += New-HALSAction `
            -Provider $Action.Provider `
            -Device $Action.Device `
            -Command $Action.Command `
            -Parameters $Params `
            -Risk $(if ($Action.Risk) { $Action.Risk } else { "Low" })
    }

    $Plan = New-HALSPlan -Actions $Actions
    Invoke-HALSPlan -Plan $Plan

    @{ Executed = $true; ActionCount = $Actions.Count }
}

#----------------------------------------------------------
# AI
#----------------------------------------------------------

function Invoke-HALSWebAI {

    param([string]$Question)

    Initialize-HALSWebSession
    Ensure-HALSWebInventoryComplete

    $Inventory = Get-HALSWebInventory
    if (-not $Inventory -or @($Inventory.Devices).Count -eq 0) {
        throw "HALS inventory is empty. Run a scan first."
    }

    if (-not ($Inventory.PSObject.Properties["Assets"] -and @($Inventory.Assets).Count -gt 0)) {
        throw "HALS inventory is missing Assets. Run a scan to rebuild inventory."
    }

    $Configuration = Get-HALSAIConfiguration -Optional
    if (-not $Configuration) {
        return @{
            Type = "unconfigured"
            Message = "AI is not configured. Run Initialize-HALSAI to choose a provider."
            Provider = $null
        }
    }

    $Global:HALSAIInventory = ConvertTo-HALSAIInventory -Inventory $Inventory
    $Context = Get-HALSAIContext
    $Prompt  = New-HALSAIPrompt -Context $Context -Question $Question

    $Response = Invoke-HALSAIProvider `
        -Provider $Configuration.Provider `
        -Configuration $Configuration `
        -Prompt $Prompt

    $Response = $Response.Trim()

    $Preamble = ""
    $Json     = ""

    if ($Response -match '(?s)^```(?:json)?\s*(\{.*\})\s*```$') {
        $Json = $Matches[1].Trim()
    }
    elseif ($Response -match '(?s)(\{.*\})') {
        $JsonStart = $Response.IndexOf('{')
        if ($JsonStart -gt 0) { $Preamble = $Response.Substring(0, $JsonStart).Trim() }
        $Json = $Response.Substring($JsonStart).Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($Json)) {

        $Plan = ConvertFrom-HALSAIPlan -Json $Json

        if (Test-HALSExecutionPlan $Plan -and $Plan.Actions.Count -gt 0) {

            $Actions = @($Plan.Actions | ForEach-Object {
                @{
                    Provider   = $_.Provider
                    Device     = $_.Device
                    Command    = $_.Command
                    Parameters = $_.Parameters
                    Risk       = $_.Risk
                }
            })

            return @{
                Type     = "plan"
                Preamble = $Preamble
                Plan     = @{ Type = "ExecutionPlan"; Actions = $Actions }
                Provider = $Configuration.Provider
            }
        }
    }

    @{
        Type     = "information"
        Message  = if ($Preamble) { "$Preamble`n$Response" } else { $Response }
        Provider = $Configuration.Provider
    }
}

function Get-HALSWebAIProviders {

    Initialize-HALSWebModules
    Ensure-HALSWebCommands @("Get-HALSAIConfiguration", "Get-HALSRegisteredAIProviders")

    $AIConfig = Get-HALSAIConfiguration -Optional

    @(Get-HALSAIProviderRegistry | ForEach-Object {
        $Cfg = if ($AIConfig -and $AIConfig.PSObject.Properties[$_.Key]) {
            $AIConfig.($_.Key)
        }
        else { $null }
        $Configured = $Cfg -and (
            Test-HALSAIProviderConfigured -Provider $_.Key -Configuration $Cfg
        )
        @{
            Name       = $_.Name
            Key        = $_.Key
            Active     = $AIConfig -and $AIConfig.Provider -eq $_.Key
            Configured = $Configured
            Model      = if ($Cfg -and $Cfg.PSObject.Properties["Model"]) { $Cfg.Model } else { "" }
        }
    })
}

function Switch-HALSWebAIProvider {

    param([string]$Provider)

    Initialize-HALSWebModules
    Ensure-HALSWebCommands @("Switch-HALSAIProvider", "Get-HALSAIConfiguration")

    Switch-HALSAIProvider -Provider $Provider

    $AIConfig = Get-HALSAIConfiguration

    @{
        Active = $AIConfig.Provider
        Model  = $AIConfig.($AIConfig.Provider).Model
    }
}

#----------------------------------------------------------
# Route dispatcher
#----------------------------------------------------------

function Invoke-HALSWebRoute {

    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = "",
        [hashtable]$Query = @{}
    )

    Initialize-HALSWebModules

    $Segments = $Path.Trim("/").Split("/", [System.StringSplitOptions]::RemoveEmptyEntries)

    try {

        if ($Segments.Count -eq 0 -or $Segments[0] -ne "api") {
            return @{ Status = 404; Body = @{ ok = $false; error = "Not found" } }
        }

        $Resource = if ($Segments.Count -gt 1) { $Segments[1] } else { "" }
        $Sub      = if ($Segments.Count -gt 2) { $Segments[2] } else { "" }
        $Id       = if ($Segments.Count -gt 3) { $Segments[3] } else { "" }

        $Payload = $null
        if ($Body) { $Payload = $Body | ConvertFrom-Json }

        switch ($Resource) {

            "status" {
                if ($Method -ne "GET") { throw "Method not allowed" }
                @{ Status = 200; Body = @{ ok = $true; data = (Get-HALSWebStatus) } }
            }

            "overview" {
                if ($Method -ne "GET") { throw "Method not allowed" }
                @{ Status = 200; Body = @{ ok = $true; data = (Get-HALSWebOverview) } }
            }

            "devices" {

                if ($Method -ne "GET") { throw "Method not allowed" }

                $MacQuery = if ($Query["mac"]) { [string]$Query["mac"] } else { "" }

                if ($MacQuery) {
                    $Device = Get-HALSWebDevice -Mac $MacQuery
                    if (-not $Device) { throw "Device not found: $MacQuery" }
                    return @{ Status = 200; Body = @{ ok = $true; data = $Device } }
                }

                if ($Sub) {
                    $DeviceMac = [System.Uri]::UnescapeDataString($Sub)
                    $Device = Get-HALSWebDevice -Mac $DeviceMac
                    if (-not $Device) { throw "Device not found: $DeviceMac" }
                    return @{ Status = 200; Body = @{ ok = $true; data = $Device } }
                }

                $Search   = if ($Query["search"])   { [string]$Query["search"] }   else { "" }
                $Source   = if ($Query["source"])   { [string]$Query["source"] }   else { "" }
                $Category = if ($Query["category"]) { [string]$Query["category"] } else { "" }

                @{ Status = 200; Body = @{ ok = $true; data = (Get-HALSWebDevices -Search $Search -Source $Source -Category $Category) } }
            }

            "scan" {
                if ($Method -ne "POST") { throw "Method not allowed" }
                @{ Status = 200; Body = @{ ok = $true; data = (Invoke-HALSWebScan) } }
            }

            "snapshots" {

                if ($Method -ne "GET") { throw "Method not allowed" }

                if ($Sub -eq "compare") {
                    return @{ Status = 200; Body = @{ ok = $true; data = (Compare-HALSWebSnapshots) } }
                }

                @{ Status = 200; Body = @{ ok = $true; data = (Get-HALSWebSnapshots) } }
            }

            "knowledge" {
                if ($Method -ne "GET") { throw "Method not allowed" }
                $Devices = @(Get-HALSKnownDevices | ForEach-Object {
                    @{
                        MAC          = $_.MAC
                        FriendlyName = $_.FriendlyName
                        Category     = $_.Category
                        Tags         = $_.Tags
                    }
                })
                @{ Status = 200; Body = @{ ok = $true; data = $Devices } }
            }

            "actions" {
                if ($Method -ne "POST") { throw "Method not allowed" }
                if (-not $Payload) { throw "Request body required" }

                $Params = @{}
                if ($Payload.parameters) {
                    foreach ($Prop in $Payload.parameters.PSObject.Properties) {
                        $Params[$Prop.Name] = $Prop.Value
                    }
                }

                $Result = Invoke-HALSWebAction `
                    -Provider ([string]$Payload.provider) `
                    -Device ([string]$Payload.device) `
                    -Command ([string]$Payload.command) `
                    -Parameters $Params

                @{ Status = 200; Body = @{ ok = $true; data = $Result } }
            }

            "ai" {

                if ($Sub -eq "providers" -and $Method -eq "GET") {
                    return @{ Status = 200; Body = @{ ok = $true; data = (Get-HALSWebAIProviders) } }
                }

                if ($Sub -eq "switch" -and $Method -eq "POST") {
                    if (-not $Payload -or -not $Payload.provider) { throw "provider is required" }
                    $Result = Switch-HALSWebAIProvider -Provider ([string]$Payload.provider)
                    return @{ Status = 200; Body = @{ ok = $true; data = $Result } }
                }

                if ($Sub -eq "ask" -and $Method -eq "POST") {
                    if (-not $Payload -or -not $Payload.question) { throw "question is required" }
                    $Result = Invoke-HALSWebAI -Question ([string]$Payload.question)
                    return @{ Status = 200; Body = @{ ok = $true; data = $Result } }
                }

                if ($Sub -eq "execute" -and $Method -eq "POST") {
                    if (-not $Payload -or -not $Payload.plan) { throw "plan is required" }
                    $Result = Invoke-HALSWebPlan -PlanBody $Payload.plan
                    return @{ Status = 200; Body = @{ ok = $true; data = $Result } }
                }

                throw "Not found"
            }

            default {
                @{ Status = 404; Body = @{ ok = $false; error = "Unknown API route: $Resource" } }
            }
        }
    }
    catch {
        @{ Status = 400; Body = @{ ok = $false; error = $_.Exception.Message } }
    }
}

Export-ModuleMember -Function `
    Initialize-HALSWebModules,
    Initialize-HALSWebSession,
    Invoke-HALSWebRoute
