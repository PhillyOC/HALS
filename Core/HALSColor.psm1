#==========================================================
# HALS - CSS Color Engine
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Load CSS Color Database
#----------------------------------------------------------

$Global:HALSColors = Import-Csv "$(Get-HALSRoot)\Data\CSSColors.csv" |
    ForEach-Object {

        [PSCustomObject]@{

            Name = $_.name
            Hex  = $_.Hex
            RGB  = @(
                $_.RGB.Split(' ') |
                    ForEach-Object { [int]$_ }
            )

        }

    }

#----------------------------------------------------------
# Build Indexes
#----------------------------------------------------------

$Global:HALSColorByName = @{}
$Global:HALSColorByHex  = @{}
$Global:HALSColorByRGB  = @{}

foreach ($Color in $Global:HALSColors) {

    $Global:HALSColorByName[$Color.Name.ToLower().Replace(" ","")] = $Color
    $Global:HALSColorByHex[$Color.Hex.ToUpper()]                   = $Color
    $Global:HALSColorByRGB[($Color.RGB -join ",")]                 = $Color

}

#----------------------------------------------------------
# Get Color
#----------------------------------------------------------

function Get-HALSColor {

    param(

        [Parameter(Mandatory)]
        [string]$Name

    )

    $Key = $Name.ToLower().Replace(" ","")

    if ($Global:HALSColorByName.ContainsKey($Key)) {

        return $Global:HALSColorByName[$Key]

    }

    throw "Unknown color '$Name'."

}

#----------------------------------------------------------
# Find Color
#----------------------------------------------------------

function Find-HALSColor {

    param(

        [Parameter(Mandatory)]
        [string]$Search

    )

    $Search = $Search.ToLower()

    $Global:HALSColors |
        Where-Object {

            $_.Name.ToLower() -like "*$Search*"

        } |
        Sort-Object Name

}

#----------------------------------------------------------
# Convert Color
#----------------------------------------------------------

function Convert-HALSColor {

    param(

        [string]$Name,
        [string]$Hex,
        [int[]]$RGB

    )

    if ($Name) {

        return Get-HALSColor $Name

    }

    if ($Hex) {

        $Hex = $Hex.ToUpper()

        if ($Global:HALSColorByHex.ContainsKey($Hex)) {

            return $Global:HALSColorByHex[$Hex]

        }

    }

    if ($RGB) {

        $Key = $RGB -join ","

        if ($Global:HALSColorByRGB.ContainsKey($Key)) {

            return $Global:HALSColorByRGB[$Key]

        }

    }

    throw "Color not found."

}

#----------------------------------------------------------
# Convert RGB to SmartThings Hue/Saturation
#
# SmartThings uses a 0-100 scale for both hue and saturation
# (hue as a percentage of 360 degrees).
# Input: R, G, B each 0-255.
# Output: hashtable with Hue (0-100) and Saturation (0-100).
#----------------------------------------------------------

function ConvertTo-HALSSmartThingsColor {

    param(

        [Parameter(Mandatory)]
        [int]$R,

        [Parameter(Mandatory)]
        [int]$G,

        [Parameter(Mandatory)]
        [int]$B

    )

    $Rf = $R / 255.0
    $Gf = $G / 255.0
    $Bf = $B / 255.0

    $Max = [Math]::Max($Rf, [Math]::Max($Gf, $Bf))
    $Min = [Math]::Min($Rf, [Math]::Min($Gf, $Bf))
    $Delta = $Max - $Min

    #
    # Saturation
    #

    if ($Max -eq 0) {
        $Saturation = 0
    } else {
        $Saturation = [Math]::Round(($Delta / $Max) * 100)
    }

    #
    # Hue (degrees 0-360, then scaled to 0-100)
    #

    if ($Delta -eq 0) {

        $HueDegrees = 0

    } elseif ($Max -eq $Rf) {

        $HueDegrees = 60 * ((($Gf - $Bf) / $Delta) % 6)

    } elseif ($Max -eq $Gf) {

        $HueDegrees = 60 * ((($Bf - $Rf) / $Delta) + 2)

    } else {

        $HueDegrees = 60 * ((($Rf - $Gf) / $Delta) + 4)

    }

    if ($HueDegrees -lt 0) {
        $HueDegrees += 360
    }

    $Hue = [Math]::Round(($HueDegrees / 360.0) * 100)

    return @{
        Hue        = $Hue
        Saturation = $Saturation
    }

}

Export-ModuleMember `
    -Function Get-HALSColor,
              Find-HALSColor,
              Convert-HALSColor,
              ConvertTo-HALSSmartThingsColor
