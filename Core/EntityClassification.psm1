#==========================================================
# HALS - Entity Classification
# Version : 0.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:EntityClassification = @{

    #------------------------------------------------------
    # Network
    #------------------------------------------------------

    "ip*"           = "Network"
    "mac*"          = "Network"
    "hostname*"     = "Network"
    "signal*"       = "Network"
    "rssi*"         = "Network"
    "noise*"        = "Network"
    "tx_*"          = "Network"
    "rx_*"          = "Network"
    "channel*"      = "Network"
    "radio*"        = "Network"
    "vlan*"         = "Network"

    #------------------------------------------------------
    # Security
    #------------------------------------------------------

    "contactSensor*" = "Security"
    "lock*"          = "Security"
    "tamper*"        = "Security"

    #------------------------------------------------------
    # Safety
    #------------------------------------------------------

    "smokeDetector*"            = "Safety"
    "carbonMonoxideDetector*"   = "Safety"

    #------------------------------------------------------
    # Battery
    #------------------------------------------------------

    "battery*" = "Battery"

    #------------------------------------------------------
    # Lighting
    #------------------------------------------------------

    "switch*"              = "Lighting"
    "switchLevel*"         = "Lighting"
    "color*"               = "Lighting"
    "colorTemperature*"    = "Lighting"

    #------------------------------------------------------
    # Presence
    #------------------------------------------------------

    "presence*"        = "Presence"
    "presenceSensor*"  = "Presence"

    #------------------------------------------------------
    # Firmware
    #------------------------------------------------------

    "firmware*"        = "Firmware"
    "firmwareUpdate*"  = "Firmware"

}

function Get-HALSEntityCategory {

    param(

        [Parameter(Mandatory)]
        [string]$Name

    )

    foreach ($Pattern in $script:EntityClassification.Keys) {

        if ($Name -like $Pattern) {
            return $script:EntityClassification[$Pattern]
        }

    }

    return "General"

}

Export-ModuleMember -Function Get-HALSEntityCategory