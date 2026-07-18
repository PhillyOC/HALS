#==========================================================
# HALS - Observation Module
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSObservationFile {
    Join-Path (Get-HALSRoot) "Knowledge\Observations.json"
}

#----------------------------------------------------------
# Initialize
#----------------------------------------------------------

function Initialize-HALSObservations {

    $ObservationFile = Get-HALSObservationFile

    if (!(Test-Path $ObservationFile)) {

        Set-Content -Path $ObservationFile -Value "[]"

    }

}

#----------------------------------------------------------
# Get
#----------------------------------------------------------

function Get-HALSObservations {

    Initialize-HALSObservations

    $Json = Get-Content (Get-HALSObservationFile) -Raw

    if ([string]::IsNullOrWhiteSpace($Json)) {

        return @()

    }

    $Data = $Json | ConvertFrom-Json

    if ($null -eq $Data) {

        return @()

    }

    $Results = @()

    foreach ($Item in @($Data)) {

        $Results += $Item

    }

    return $Results

}

#----------------------------------------------------------
# Add
#----------------------------------------------------------

function Add-HALSObservation {

    param(

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Summary,

        [string]$Provider = "",

        [string]$Severity = "Information",

        [string]$RelatedExperiment = ""

    )

    $Observations = @(Get-HALSObservations)

    $Observation = [PSCustomObject]@{

        Id                = ([guid]::NewGuid()).Guid
        Timestamp         = Get-Date
        Category          = $Category
        Summary           = $Summary
        Provider          = $Provider
        Severity          = $Severity
        RelatedExperiment = $RelatedExperiment

    }

    $Observations = @($Observations + $Observation)

    $Observations |
        ConvertTo-Json -Depth 20 |
        Set-Content (Get-HALSObservationFile)

    return $Observation

}

#----------------------------------------------------------
# Find
#----------------------------------------------------------

function Find-HALSObservation {

    param(

        [Parameter(Mandatory)]
        [string]$Text

    )

    Get-HALSObservations |

        Where-Object {

            $_.Summary -like "*$Text*" -or
            $_.Category -like "*$Text*"

        }

}

#----------------------------------------------------------
# Clear
#----------------------------------------------------------

function Clear-HALSObservations {

    Set-Content -Path (Get-HALSObservationFile) -Value "[]"

}

Initialize-HALSObservations

Export-ModuleMember `
    -Function Initialize-HALSObservations,
              Get-HALSObservations,
              Add-HALSObservation,
              Find-HALSObservation,
              Clear-HALSObservations