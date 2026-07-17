#==========================================================
# HALS - Status Engine
# Version : 0.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSStatusSummary {

    param($Device)

    if (-not $Device.Entities) {
        return ""
    }

    foreach ($Entity in $Device.Entities) {

        switch -Wildcard ($Entity.Name) {

            "switch.switch" {
                return $Entity.Value
            }

            "contactSensor.contact" {
                return $Entity.Value
            }

            "motionSensor.motion" {
                return $Entity.Value
            }

            "presenceSensor.presence" {
                return $Entity.Value
            }

            "smokeDetector.smoke" {
                return $Entity.Value
            }

            "carbonMonoxideDetector.carbonMonoxide" {
                return $Entity.Value
            }

        }

    }

    return ""

}

Export-ModuleMember -Function Get-HALSStatusSummary