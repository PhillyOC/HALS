#==========================================================
# HALS - Google Nest Device Converter
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-HALSGoogleNestDevice {

    param(

        [Parameter(Mandatory)]
        $Device,

        [Parameter(Mandatory)]
        [hashtable]$Knowledge

    )

    #
    # Category from device type
    #

    $Category = switch ($Device.Type) {
        "thermostat"      { "Thermostat"    }
        "camera"          { "Camera"        }
        "doorbell"        { "Doorbell"      }
        "display"         { "Smart Display" }
        "hub"             { "Home Automation" }
        default           { "Google Nest Device" }
    }

    $Name  = $Device.DisplayName
    $MAC   = "NEST:$($Device.DeviceId)"
    $Known = $false

    #
    # Knowledge lookup by MAC key
    #

    if ($Knowledge.ContainsKey($MAC)) {

        $Known = $true
        $Entry = $Knowledge[$MAC]

        if ($Entry.FriendlyName) { $Name     = $Entry.FriendlyName }
        if ($Entry.Category)     { $Category = $Entry.Category     }

    }

    #
    # Pull readable state from traits
    #

    $Status = $Device.Online

    $Entities = @()

    if ($Device.Traits) {

        foreach ($Trait in $Device.Traits.PSObject.Properties) {

            $TraitName  = $Trait.Name.Split(".")[-1]   # e.g. "ThermostatMode"
            $TraitValue = $Trait.Value

            foreach ($Prop in $TraitValue.PSObject.Properties) {

                $Entities += [PSCustomObject]@{
                    Name        = "$TraitName.$($Prop.Name)"
                    Type        = "Trait"
                    Provider    = "GoogleNest"
                    Category    = $TraitName
                    Value       = $Prop.Value
                    Writable    = $false
                    LastUpdated = $null
                    Raw         = $Prop.Value
                }

            }

        }

    }

    [PSCustomObject]@{

        Name            = $Name
        Category        = $Category
        Known           = $Known

        Hostname        = $null
        IP              = $null
        MAC             = $MAC

        Manufacturer    = "Google"
        Source          = "GoogleNest"

        Status          = $Status
        DeviceId        = $Device.DeviceId
        Type            = $Device.Type

        Entities        = $Entities
        RawProviderData = $Device

    }

}

Export-ModuleMember -Function ConvertTo-HALSGoogleNestDevice
