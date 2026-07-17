#==========================================================
# HALS - Command Translator
# Version : 2.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-HALSProviderCommand {

    param(

        [Parameter(Mandatory)]
        $Action

    )

    switch ($Action.Command) {

        "TurnOnLight" {

            return [PSCustomObject]@{
                Provider   = "SmartThings"
                Capability = "switch"
                Command    = "on"
                Arguments  = @()
            }

        }

        "TurnOffLight" {

            return [PSCustomObject]@{
                Provider   = "SmartThings"
                Capability = "switch"
                Command    = "off"
                Arguments  = @()
            }

        }

        "SetBrightness" {

            # HALS plan parameter is Brightness; Level is accepted as a
            # defensive fallback when the AI mirrors switchLevel.level naming.
            if ($Action.Parameters.ContainsKey("Brightness")) {
                $Level = [int]$Action.Parameters.Brightness
            }
            elseif ($Action.Parameters.ContainsKey("Level")) {
                $Level = [int]$Action.Parameters.Level
            }
            else {
                throw "SetBrightness requires a 'Brightness' parameter (0-100). Received: $($Action.Parameters.Keys -join ', ')."
            }

            return [PSCustomObject]@{
                Provider   = "SmartThings"
                Capability = "switchLevel"
                Command    = "setLevel"
                Arguments  = @($Level)
            }

        }

        "SetColorTemperature" {

            if ($Action.Parameters.ContainsKey("ColorTemperature")) {
                $Temp = [int]$Action.Parameters.ColorTemperature
            }
            elseif ($Action.Parameters.ContainsKey("Temperature")) {
                $Temp = [int]$Action.Parameters.Temperature
            }
            elseif ($Action.Parameters.ContainsKey("Kelvin")) {
                $Temp = [int]$Action.Parameters.Kelvin
            }
            else {
                throw "SetColorTemperature requires a 'ColorTemperature' parameter (Kelvin). Received: $($Action.Parameters.Keys -join ', ')."
            }

            return [PSCustomObject]@{
                Provider   = "SmartThings"
                Capability = "colorTemperature"
                Command    = "setColorTemperature"
                Arguments  = @($Temp)
            }

        }

        "SetColor" {

            #
            # Color resolution order:
            #   1. Named color string via CSS color engine (148 colors)
            #   2. Raw Hue/Saturation values (defensive fallback)
            #

            $Hue        = $null
            $Saturation = $null

            if ($Action.Parameters.ContainsKey("Color")) {

                $ColorName = $Action.Parameters.Color.ToString().ToLower()

                try {
                    $CSSColor = Get-HALSColor -Name $ColorName
                    $HSB = ConvertTo-HALSSmartThingsColor `
                        -R $CSSColor.RGB[0] `
                        -G $CSSColor.RGB[1] `
                        -B $CSSColor.RGB[2]
                    $Hue        = $HSB.Hue
                    $Saturation = $HSB.Saturation
                }
                catch {
                    throw "Unknown color '$ColorName'. Use any CSS color name (red, coral, salmon, lavender...) or run Find-HALSColor to search."
                }

            }
            elseif (
                $Action.Parameters.ContainsKey("Hue") -and
                $Action.Parameters.ContainsKey("Saturation")
            ) {

                # Raw Hue/Saturation fallback.
                $Hue        = [int]$Action.Parameters.Hue
                $Saturation = [int]$Action.Parameters.Saturation

            }
            else {

                throw "SetColor requires a 'Color' parameter (e.g. 'red', 'coral'). Received: $($Action.Parameters.Keys -join ', ')."

            }

            return [PSCustomObject]@{
                Provider   = "SmartThings"
                Capability = "colorControl"
                Command    = "setColor"
                Arguments  = @(
                    @{
                        hue        = $Hue
                        saturation = $Saturation
                    }
                )
            }

        }

        "ActivateSiren" {

            return [PSCustomObject]@{
                Provider   = "SmartThings"
                Capability = "alarm"
                Command    = "siren"
                Arguments  = @()
            }

        }

        "DeactivateSiren" {

            return [PSCustomObject]@{
                Provider   = "SmartThings"
                Capability = "alarm"
                Command    = "off"
                Arguments  = @()
            }

        }

        default {

            throw "Unknown HALS command: $($Action.Command)"

        }

    }

}

Export-ModuleMember -Function ConvertTo-HALSProviderCommand