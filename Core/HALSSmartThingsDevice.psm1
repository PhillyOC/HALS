#==========================================================
# HALS - SmartThings Device Converter
# Version : 0.4.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-HALSSmartThingsDevice {

    param(

        [Parameter(Mandatory)]
        $Device,

        [Parameter(Mandatory)]
        [hashtable]$Knowledge

    )

    $MAC = "ST:$($Device.DeviceId)"
    $Name = $Device.Label
    $Category = "SmartThings"
    $Known = $false

    foreach ($Entry in $Knowledge.GetEnumerator()) {

        if ($Entry.Value.FriendlyName -ieq $Device.Label) {

            $MAC = $Entry.Key
            $Known = $true

            if ($Entry.Value.Category) {
                $Category = $Entry.Value.Category
            }

            if ($Entry.Value.FriendlyName) {
                $Name = $Entry.Value.FriendlyName
            }

            break

        }

    }

    if (-not $Known -and $Knowledge.ContainsKey($MAC)) {

        $Known = $true

        if ($Knowledge[$MAC].Category) {
            $Category = $Knowledge[$MAC].Category
        }

        if ($Knowledge[$MAC].FriendlyName) {
            $Name = $Knowledge[$MAC].FriendlyName
        }

    }

    $Entities = @()

    $Entities += ConvertTo-HALSEntities `
        -Object $Device `
        -Provider "SmartThings"

    if ($Device.Status) {

        foreach ($Component in $Device.Status.components.PSObject.Properties) {

            foreach ($Capability in $Component.Value.PSObject.Properties) {

                foreach ($Attribute in $Capability.Value.PSObject.Properties) {

                    if ($Attribute.Value.value -ne $null) {

                        $Entities += New-HALSEntity `
                            -Name "$($Capability.Name).$($Attribute.Name)" `
                            -Type "Capability" `
                            -Provider "SmartThings" `
                            -Value $Attribute.Value.value `
                            -LastUpdated $Attribute.Value.timestamp `
                            -Raw $Attribute.Value

                    }

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

        #--------------------------------------------------
        # SmartThings Identity
        #--------------------------------------------------

        DeviceId        = $Device.DeviceId

        Manufacturer    = $Device.Manufacturer
        Source          = "SmartThings"

        Entities        = $Entities

        NativeDevice    = $Device
        RawProviderData = $Device

    }

}

Export-ModuleMember -Function ConvertTo-HALSSmartThingsDevice