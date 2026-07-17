#==========================================================
# HALS - Knowledge Module
# Version : 0.2.1
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$KnowledgePath = "$(Get-HALSRoot)\Knowledge\Devices.json"

function Get-HALSKnowledge {

    if (!(Test-Path $KnowledgePath)) {
        return @{}
    }

    $Json = Get-Content $KnowledgePath -Raw

    if ([string]::IsNullOrWhiteSpace($Json)) {
        return @{}
    }

    return $Json | ConvertFrom-Json -AsHashtable
}

function Save-HALSKnowledge {

    param(
        [Parameter(Mandatory)]
        [hashtable]$Knowledge
    )

    $Knowledge |
        ConvertTo-Json -Depth 10 |
        Set-Content $KnowledgePath
}

function Add-HALSKnownDevice {

    param(
        [Parameter(Mandatory)][string]$MAC,
        [Parameter(Mandatory)][string]$FriendlyName,
        [Parameter(Mandatory)][string]$Category,

        [string[]]$Tags = @()
    )

    $Knowledge = Get-HALSKnowledge

    $Knowledge[$MAC] = @{
        FriendlyName = $FriendlyName
        Category     = $Category
        Tags         = $Tags
    }

    Save-HALSKnowledge $Knowledge
}

function Get-HALSKnownDevices {

    $Knowledge = Get-HALSKnowledge

    foreach ($MAC in $Knowledge.Keys | Sort-Object) {

        [PSCustomObject]@{
            FriendlyName = $Knowledge[$MAC].FriendlyName
            Category     = $Knowledge[$MAC].Category
            Tags         = ($Knowledge[$MAC].Tags -join ", ")
            MAC          = $MAC
        }

    }

}

Export-ModuleMember `
    -Function Get-HALSKnowledge,
              Save-HALSKnowledge,
              Add-HALSKnownDevice,
              Get-HALSKnownDevices