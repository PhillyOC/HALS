#==========================================================
# HALS - AI Execution Plan Repair
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSQuestionColorName {

    param(
        [Parameter(Mandatory)]
        [string]$Question
    )

    if (-not (Get-Command Get-HALSColor -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Get-HALSRoot) "Core\HALSColor.psm1") -Force
    }

    $Normalized = $Question.ToLower()

    foreach ($Color in @($Global:HALSColors | Sort-Object { $_.Name.Length } -Descending)) {

        $Pattern = "\b$([regex]::Escape($Color.Name.ToLower()))\b"
        if ($Normalized -match $Pattern) {
            return $Color.Name
        }

    }

    return $null

}

function Test-HALSQuestionRequestsColor {

    param(
        [Parameter(Mandatory)]
        [string]$Question
    )

    if (Get-HALSQuestionColorName -Question $Question) {
        return $true
    }

    return [bool]($Question -match '(?i)\b(color|colour)\b')

}

function Get-HALSAIColorCapableAssets {

    if (-not $Global:HALSAIInventory) {
        return @()
    }

    $Assets = @($Global:HALSAIInventory.Assets)
    $Commands = @(Get-HALSCommands)

    return @(
        $Assets | Where-Object {
            $Asset = $_
            $HasColorCapability = @($Asset.Capabilities | Where-Object {
                $_ -like "colorControl*" -or $_ -like "colorTemperature*"
            }).Count -gt 0

            if (-not $HasColorCapability) {
                return $false
            }

            $ControllableProviders = @(
                $Commands |
                    Where-Object { $_.Name -eq "SetColor" } |
                    Select-Object -ExpandProperty Provider -Unique
            )

            @($Asset.Providers | Where-Object { $ControllableProviders -contains $_ }).Count -gt 0
        }
    )

}

function Repair-HALSAIExecutionPlan {

    param(
        [Parameter(Mandatory)]
        $Plan,

        [Parameter(Mandatory)]
        [string]$Question
    )

    if (-not (Test-HALSExecutionPlan $Plan)) {
        return $Plan
    }

    $Actions = @($Plan.Actions)
    if ($Actions.Count -eq 0) {
        return $Plan
    }

    if (-not (Test-HALSQuestionRequestsColor -Question $Question)) {
        return $Plan
    }

    $ColorName = Get-HALSQuestionColorName -Question $Question
    if ([string]::IsNullOrWhiteSpace($ColorName)) {
        $ColorName = "white"
    }

    $UsesWrongCommand = @(
        $Actions | Where-Object {
            $_.Command -in @("SetColorTemperature", "TurnOnLight", "TurnOffLight", "ToggleLight")
        }
    ).Count -gt 0

    $SetColorActions = @($Actions | Where-Object { $_.Command -eq "SetColor" })
    $MissingSetColor = $SetColorActions.Count -eq 0

    $TargetAssets = @(Get-HALSAIColorCapableAssets)
    if ($TargetAssets.Count -eq 0) {
        return $Plan
    }

    $WantsAllLights = $Question -match '(?i)\blights\b|\bevery\b|\ball\b'

    if (-not $MissingSetColor -and -not $UsesWrongCommand) {
        if (-not $WantsAllLights -or $SetColorActions.Count -ge $TargetAssets.Count) {
            return $Plan
        }
    }

    if (-not $MissingSetColor -and $SetColorActions.Count -gt 0) {
        $ExistingColor = $SetColorActions[0].Parameters.Color
        if (-not [string]::IsNullOrWhiteSpace([string]$ExistingColor)) {
            $ColorName = [string]$ExistingColor
        }
    }

    if (-not $WantsAllLights) {
        $NamedDevices = @($Actions | Select-Object -ExpandProperty Device -Unique)
        $TargetAssets = @(
            $TargetAssets | Where-Object { $NamedDevices -contains $_.Name }
        )

        if ($TargetAssets.Count -eq 0) {
            $TargetAssets = @(Get-HALSAIColorCapableAssets)
        }
    }

    $Repaired = @()

    foreach ($Asset in $TargetAssets) {

        $Provider = @(
            Get-HALSCommands |
                Where-Object { $_.Name -eq "SetColor" -and $Asset.Providers -contains $_.Provider } |
                Select-Object -ExpandProperty Provider -First 1
        )

        if ([string]::IsNullOrWhiteSpace($Provider)) {
            continue
        }

        $Repaired += New-HALSAction `
            -Provider $Provider `
            -Device $Asset.Name `
            -Command "SetColor" `
            -Parameters @{ Color = $ColorName }

    }

    if ($Repaired.Count -eq 0) {
        return $Plan
    }

    return (New-HALSPlan -Actions $Repaired)

}

Export-ModuleMember -Function Repair-HALSAIExecutionPlan
