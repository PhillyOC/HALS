#==========================================================
# HALS - Entity Module
# Version : 0.4.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Create a Single HALS Entity
#----------------------------------------------------------

function New-HALSEntity {

    param(

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Provider,

        [string]$Category,

        $Value,

        [bool]$Writable = $false,

        $LastUpdated = $null,

        $Raw = $null

    )

    #
    # Automatically classify if not supplied
    #

    if ([string]::IsNullOrWhiteSpace($Category)) {

        $Category = Get-HALSEntityCategory `
            -Name $Name

    }

    [PSCustomObject]@{

        Name         = $Name
        Type         = $Type
        Provider     = $Provider

        Category     = $Category

        Value        = $Value
        Writable     = $Writable

        LastUpdated  = $LastUpdated

        Raw          = $Raw

    }

}

#----------------------------------------------------------
# Convert Any Flat Object into HALS Entities
#----------------------------------------------------------

function ConvertTo-HALSEntities {

    param(

        [Parameter(Mandatory)]
        $Object,

        [Parameter(Mandatory)]
        [string]$Provider,

        [string]$Type = "Telemetry"

    )

    $Entities = @()

    foreach ($Property in $Object.PSObject.Properties) {

        if ($Property.MemberType -notin @("NoteProperty","Property")) {
            continue
        }

        $Value = $Property.Value

        #
        # Skip complex objects and arrays.
        #

        if ($Value -is [System.Collections.IEnumerable] -and
            $Value -isnot [string]) {

            continue

        }

        if ($Value -is [psobject]) {

            continue

        }

        $Entities += New-HALSEntity `
            -Name $Property.Name `
            -Type $Type `
            -Provider $Provider `
            -Value $Value `
            -Raw $Value

    }

    return $Entities

}

Export-ModuleMember `
    -Function New-HALSEntity,
              ConvertTo-HALSEntities