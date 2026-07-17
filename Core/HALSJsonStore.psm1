#==========================================================
# HALS - JSON Store
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Read Collection
#----------------------------------------------------------

function Read-HALSCollection {

    param(

        [Parameter(Mandatory)]
        [string]$Path

    )

    if (!(Test-Path $Path)) {

        return @()

    }

    $Json = Get-Content $Path -Raw

    if ([string]::IsNullOrWhiteSpace($Json)) {

        return @()

    }

    try {

        $Data = $Json | ConvertFrom-Json

    }

    catch {

        return @()

    }

    if ($null -eq $Data) {

        return @()

    }

    $Collection = @()

    foreach ($Item in @($Data)) {

        $Collection += $Item

    }

    return $Collection

}

#----------------------------------------------------------
# Write Collection
#----------------------------------------------------------

function Write-HALSCollection {

    param(

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Collection

    )

    $Json = ConvertTo-Json -InputObject @($Collection) -Depth 20
    Set-Content -Path $Path -Value $Json

}

#----------------------------------------------------------
# Add Item
#----------------------------------------------------------

function Add-HALSCollectionItem {

    param(

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $Item

    )

    $Collection = @(Read-HALSCollection -Path $Path)

    $Collection += $Item

    Write-HALSCollection `
        -Path $Path `
        -Collection $Collection

}

Export-ModuleMember `
    -Function Read-HALSCollection,
              Write-HALSCollection,
              Add-HALSCollectionItem