#==========================================================
# HALS - Knowledge Base
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$KnowledgeRoot = "$(Get-HALSRoot)\Knowledge"

#----------------------------------------------------------
# Ensure Knowledge Store Exists
#----------------------------------------------------------

function Initialize-HALSKnowledgeBase {

    if (!(Test-Path $KnowledgeRoot)) {

        New-Item `
            -ItemType Directory `
            -Path $KnowledgeRoot `
            -Force | Out-Null

    }

}

#----------------------------------------------------------
# Read
#----------------------------------------------------------

function Get-HALSKnowledgeFile {

    param(

        [Parameter(Mandatory)]
        [string]$Name

    )

    $Path = Join-Path `
        $KnowledgeRoot `
        "$Name.json"

    if (!(Test-Path $Path)) {

        return $null

    }

    $Json = Get-Content $Path -Raw

    if ([string]::IsNullOrWhiteSpace($Json)) {

        return $null

    }

    return $Json | ConvertFrom-Json

}

#----------------------------------------------------------
# Write
#----------------------------------------------------------

function Save-HALSKnowledgeFile {

    param(

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Object

    )

    $Path = Join-Path `
        $KnowledgeRoot `
        "$Name.json"

    $Object |
        ConvertTo-Json -Depth 100 |
        Set-Content $Path

}

#----------------------------------------------------------
# Exists
#----------------------------------------------------------

function Test-HALSKnowledgeFile {

    param(

        [Parameter(Mandatory)]
        [string]$Name

    )

    Test-Path (
        Join-Path `
            $KnowledgeRoot `
            "$Name.json"
    )

}

#----------------------------------------------------------
# List
#----------------------------------------------------------

function Get-HALSKnowledgeFiles {

    Get-ChildItem `
        $KnowledgeRoot `
        -Filter *.json |
        Sort-Object Name |
        Select-Object -ExpandProperty BaseName

}

Initialize-HALSKnowledgeBase

Export-ModuleMember `
    -Function Initialize-HALSKnowledgeBase,
              Get-HALSKnowledgeFile,
              Save-HALSKnowledgeFile,
              Test-HALSKnowledgeFile,
              Get-HALSKnowledgeFiles