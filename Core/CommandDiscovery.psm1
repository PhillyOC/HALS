#==========================================================
# HALS - Command Discovery
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSCommands {

    $Commands = @()

    #
    # SmartThings
    #

    $Commands += New-HALSCommand `
        -Name TurnOnLight `
        -Provider SmartThings `
        -Description "Turn on a light."

    $Commands += New-HALSCommand `
        -Name TurnOffLight `
        -Provider SmartThings `
        -Description "Turn off a light."

    $Commands += New-HALSCommand `
        -Name ToggleLight `
        -Provider SmartThings `
        -Description "Toggle a light."

    $Commands += New-HALSCommand `
        -Name SetBrightness `
        -Provider SmartThings `
        -Description "Set light brightness 0-100. Required parameter: Brightness (integer). Example: {\"Brightness\":100}. Always use Brightness - never use Level."

    $Commands += New-HALSCommand `
        -Name SetColor `
        -Provider SmartThings `
        -Description "Set light color. Required parameter: Color (string). Accepts any CSS color name: red, orange, yellow, green, cyan, blue, purple, magenta, pink, white, coral, salmon, crimson, gold, indigo, violet, turquoise, lavender, and 140+ more. Example: {\"Color\":\"coral\"}. Always use a named Color - never use Hue or Saturation parameters."

    $Commands += New-HALSCommand `
        -Name SetColorTemperature `
        -Provider SmartThings `
        -Description "Set color temperature in Kelvin. Required parameter: ColorTemperature (integer). Example: {\"ColorTemperature\":2700}. Always use ColorTemperature - never use Temperature or Kelvin."

    $Commands += New-HALSCommand `
        -Name ActivateSiren `
        -Provider SmartThings `
        -Description "Activate siren." `
        -Risk Medium

    $Commands += New-HALSCommand `
        -Name DeactivateSiren `
        -Provider SmartThings `
        -Description "Deactivate siren."

    return $Commands

}

#----------------------------------------------------------
# Update Knowledge Base
#----------------------------------------------------------

function Update-HALSKnowledgeCommands {

    $Commands = Get-HALSCommands

    $CommandObjects = foreach ($Command in $Commands) {

        [PSCustomObject]@{

            Name        = $Command.Name
            Provider    = $Command.Provider
            Description = $Command.Description
            Risk        = $Command.Risk

        }

    }

    Save-HALSKnowledgeFile `
        -Name "Commands" `
        -Object $CommandObjects

}

Export-ModuleMember `
    -Function Get-HALSCommands,
              Update-HALSKnowledgeCommands