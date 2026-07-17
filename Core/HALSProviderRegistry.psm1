#==========================================================
# HALS - Device Provider Registry
# Version : 1.0.0
#
# Device providers register their own metadata and hooks.
# Core HALS consumes this registry without knowing provider
# names, configuration files, commands, or action handlers.
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script:HALSDeviceProviders = [ordered]@{}

function Register-HALSDeviceProvider {

    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Name,
        [string]$TestConfiguredCommand = "",
        [string]$InventoryCommand = "",
        [string]$CommandCatalogCommand = "",
        [string]$PermissionCatalogCommand = "",
        [string]$ActionHandlerCommand = "",
        [array]$SetupCommands = @(),
        [int]$Order = 100
    )

    $Script:HALSDeviceProviders[$Key] = [PSCustomObject]@{
        Key                      = $Key
        Name                     = $Name
        TestConfiguredCommand    = $TestConfiguredCommand
        InventoryCommand         = $InventoryCommand
        CommandCatalogCommand    = $CommandCatalogCommand
        PermissionCatalogCommand = $PermissionCatalogCommand
        ActionHandlerCommand     = $ActionHandlerCommand
        SetupCommands            = @($SetupCommands)
        Order                    = $Order
    }
}

function Get-HALSDeviceProviders {
    @($Script:HALSDeviceProviders.Values | Sort-Object Order, Name)
}

function Get-HALSDeviceProvider {

    param([Parameter(Mandatory)][string]$Key)

    if ($Script:HALSDeviceProviders.Contains($Key)) {
        return $Script:HALSDeviceProviders[$Key]
    }

    return $null
}

function Test-HALSDeviceProviderConfigured {

    param([Parameter(Mandatory)]$Provider)

    if ([string]::IsNullOrWhiteSpace($Provider.TestConfiguredCommand)) {
        return $false
    }

    $Command = Get-Command $Provider.TestConfiguredCommand -ErrorAction SilentlyContinue
    if (-not $Command) { return $false }

    return [bool](& $Command)
}

function Invoke-HALSDeviceProviderInventory {

    param(
        [Parameter(Mandatory)]$Provider,
        [Parameter(Mandatory)]$Knowledge
    )

    if ([string]::IsNullOrWhiteSpace($Provider.InventoryCommand)) {
        return [PSCustomObject]@{ Devices = @() }
    }

    $Command = Get-Command $Provider.InventoryCommand -ErrorAction SilentlyContinue
    if (-not $Command) {
        throw "Inventory command is unavailable for $($Provider.Name): $($Provider.InventoryCommand)"
    }

    & $Command -Knowledge $Knowledge
}

function Get-HALSRegisteredProviderCommands {

    $Commands = @()

    foreach ($Provider in @(Get-HALSDeviceProviders)) {
        if (-not (Test-HALSDeviceProviderConfigured -Provider $Provider)) { continue }
        if ([string]::IsNullOrWhiteSpace($Provider.CommandCatalogCommand)) { continue }

        $Command = Get-Command $Provider.CommandCatalogCommand -ErrorAction SilentlyContinue
        if ($Command) { $Commands += @(& $Command) }
    }

    @($Commands)
}

function Get-HALSRegisteredProviderPermissions {

    param([Parameter(Mandatory)]$Inventory)

    $Permissions = @()

    foreach ($Provider in @(Get-HALSDeviceProviders)) {
        if (-not (Test-HALSDeviceProviderConfigured -Provider $Provider)) { continue }
        if ([string]::IsNullOrWhiteSpace($Provider.PermissionCatalogCommand)) { continue }

        $Command = Get-Command $Provider.PermissionCatalogCommand -ErrorAction SilentlyContinue
        if ($Command) { $Permissions += @(& $Command -Inventory $Inventory) }
    }

    @($Permissions)
}

function Invoke-HALSRegisteredProviderAction {

    param([Parameter(Mandatory)]$Action)

    $Provider = Get-HALSDeviceProvider -Key $Action.Provider
    if (-not $Provider) {
        throw "Unknown device provider: $($Action.Provider)"
    }

    if ([string]::IsNullOrWhiteSpace($Provider.ActionHandlerCommand)) {
        throw "Provider '$($Provider.Name)' does not support actions."
    }

    $Command = Get-Command $Provider.ActionHandlerCommand -ErrorAction SilentlyContinue
    if (-not $Command) {
        throw "Action handler is unavailable for $($Provider.Name): $($Provider.ActionHandlerCommand)"
    }

    & $Command -Action $Action
}

function Get-HALSDeviceProviderSetupCommands {

    $Commands = @()

    foreach ($Provider in @(Get-HALSDeviceProviders)) {
        foreach ($Setup in @($Provider.SetupCommands)) {
            $Commands += [PSCustomObject]@{
                Provider    = $Provider.Key
                ProviderName = $Provider.Name
                Name        = [string]$Setup.Name
                Description = [string]$Setup.Description
            }
        }
    }

    @($Commands)
}

function Initialize-HALSDeviceProvider {

    $Providers = @(Get-HALSDeviceProviders | Where-Object { @($_.SetupCommands).Count -gt 0 })

    if ($Providers.Count -eq 0) {
        Write-Host "No device providers are installed." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "HALS device provider setup" -ForegroundColor Cyan
    Write-Host ""

    for ($Index = 0; $Index -lt $Providers.Count; $Index++) {
        Write-Host ("  [{0}] {1}" -f ($Index + 1), $Providers[$Index].Name)
    }

    Write-Host ""
    $ChoiceText = (Read-Host "Choose a provider [1-$($Providers.Count)]").Trim()
    $Choice = 0

    if (-not [int]::TryParse($ChoiceText, [ref]$Choice) -or
        $Choice -lt 1 -or $Choice -gt $Providers.Count) {
        Write-Host "Invalid provider selection." -ForegroundColor Yellow
        return
    }

    $Provider = $Providers[$Choice - 1]
    $Setup = @($Provider.SetupCommands)[0]
    $Command = Get-Command $Setup.Name -ErrorAction SilentlyContinue

    if (-not $Command) {
        throw "Provider setup command is unavailable: $($Setup.Name)"
    }

    & $Command
}

Export-ModuleMember -Function `
    Register-HALSDeviceProvider,
    Get-HALSDeviceProviders,
    Get-HALSDeviceProvider,
    Test-HALSDeviceProviderConfigured,
    Invoke-HALSDeviceProviderInventory,
    Get-HALSRegisteredProviderCommands,
    Get-HALSRegisteredProviderPermissions,
    Invoke-HALSRegisteredProviderAction,
    Get-HALSDeviceProviderSetupCommands,
    Initialize-HALSDeviceProvider
