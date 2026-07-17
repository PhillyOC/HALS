#==========================================================
# HALS - Device Module
# Version : 0.5.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-HALSDevice {

    param(

        [Parameter(Mandatory)]
        $Device,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [hashtable]$Knowledge

    )

    #------------------------------------------------------
    # Safe Property Reader
    #------------------------------------------------------

    function Get-Prop {

        param($Object,[string]$Name)

        if ($Object.PSObject.Properties[$Name]) {
            return $Object.$Name
        }

        return $null

    }

    #------------------------------------------------------
    # Read Common Properties
    #------------------------------------------------------

    $Hostname     = Get-Prop $Device "hostname"
    $Name         = Get-Prop $Device "name"
    $IP           = Get-Prop $Device "ip"
    $MAC          = Get-Prop $Device "mac"
    $Manufacturer = Get-Prop $Device "oui"

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = $Hostname
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = "Unknown Device"
    }

    #------------------------------------------------------
    # Defaults
    #------------------------------------------------------

    $Category = "Unknown"
    $Known = $false

    $Critical = $false
    $Infrastructure = $false
    $Mobile = $false
    $SleepCapable = $false
    $ExpectedAvailability = "Always"

    #------------------------------------------------------
    # Knowledge Lookup
    #------------------------------------------------------

    if ($MAC -and $Knowledge.ContainsKey($MAC)) {

        $Known = $true

        $Entry = $Knowledge[$MAC]

        if ($Entry.FriendlyName) {
            $Name = $Entry.FriendlyName
        }

        if ($Entry.Category) {
            $Category = $Entry.Category
        }

        if ($Entry.PSObject.Properties["Critical"]) {
            $Critical = [bool]$Entry.Critical
        }

        if ($Entry.PSObject.Properties["Infrastructure"]) {
            $Infrastructure = [bool]$Entry.Infrastructure
        }

        if ($Entry.PSObject.Properties["Mobile"]) {
            $Mobile = [bool]$Entry.Mobile
        }

        if ($Entry.PSObject.Properties["SleepCapable"]) {
            $SleepCapable = [bool]$Entry.SleepCapable
        }

        if ($Entry.PSObject.Properties["ExpectedAvailability"]) {
            $ExpectedAvailability = $Entry.ExpectedAvailability
        }

    }

    #------------------------------------------------------
    # Build Entities Automatically
    #------------------------------------------------------

    $Entities = ConvertTo-HALSEntities `
        -Object $Device `
        -Provider $Source `
        -Type "Telemetry"

    #------------------------------------------------------
    # Return HALS Device
    #------------------------------------------------------

    [PSCustomObject]@{

        Name                 = $Name
        Category             = $Category
        Known                = $Known

        Hostname             = $Hostname
        IP                   = $IP
        MAC                  = $MAC

        Manufacturer         = $Manufacturer
        Source               = $Source

        Critical             = $Critical
        Infrastructure       = $Infrastructure
        Mobile               = $Mobile
        SleepCapable         = $SleepCapable
        ExpectedAvailability = $ExpectedAvailability

        Entities             = $Entities

        RawProviderData      = $Device

    }

}

Export-ModuleMember -Function ConvertTo-HALSDevice