#==========================================================
# HALS - Evidence Module
# Version : 2.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSEvidenceFile {
    Join-Path (Get-HALSRoot) "Knowledge\Evidence.json"
}

#----------------------------------------------------------
# Initialize
#----------------------------------------------------------

function Initialize-HALSEvidence {

    $EvidenceFile = Get-HALSEvidenceFile

    if (!(Test-Path $EvidenceFile)) {

        Write-HALSCollection `
            -Path $EvidenceFile `
            -Collection @()

    }

}

#----------------------------------------------------------
# Get
#----------------------------------------------------------

function Get-HALSEvidence {

    Initialize-HALSEvidence

    Read-HALSCollection `
        -Path (Get-HALSEvidenceFile)

}

#----------------------------------------------------------
# Add
#----------------------------------------------------------

function Add-HALSEvidence {

    param(

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Finding,

        [string]$Category = "General",

        [string]$Severity = "Information",

        [int]$Confidence = 100

    )

    $Item = [PSCustomObject]@{

        Id         = ([guid]::NewGuid()).Guid
        Timestamp  = Get-Date
        Source     = $Source
        Category   = $Category
        Finding    = $Finding
        Severity   = $Severity
        Confidence = $Confidence

    }

    Add-HALSCollectionItem `
        -Path (Get-HALSEvidenceFile) `
        -Item $Item

}

#----------------------------------------------------------
# Find
#----------------------------------------------------------

function Find-HALSEvidence {

    param(

        [Parameter(Mandatory)]
        [string]$Text

    )

    Get-HALSEvidence |

        Where-Object {

            $_.Finding -like "*$Text*" -or
            $_.Category -like "*$Text*" -or
            $_.Source -like "*$Text*"

        }

}

#----------------------------------------------------------
# Clear
#----------------------------------------------------------

function Clear-HALSEvidence {

    Write-HALSCollection `
        -Path (Get-HALSEvidenceFile) `
        -Collection @()

}

Initialize-HALSEvidence

Export-ModuleMember `
    -Function Initialize-HALSEvidence,
              Get-HALSEvidence,
              Add-HALSEvidence,
              Find-HALSEvidence,
              Clear-HALSEvidence
