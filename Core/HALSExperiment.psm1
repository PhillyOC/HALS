#==========================================================
# HALS - Experiment Module
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExperimentFile = "$(Get-HALSRoot)\Knowledge\Experiments.json"

#----------------------------------------------------------
# Initialize
#----------------------------------------------------------

function Initialize-HALSExperiments {

    if (!(Test-Path $ExperimentFile)) {

        Set-Content -Path $ExperimentFile -Value "[]"

    }

}

#----------------------------------------------------------
# Get
#----------------------------------------------------------

function Get-HALSExperiments {

    Initialize-HALSExperiments

    $Json = Get-Content $ExperimentFile -Raw

    if ([string]::IsNullOrWhiteSpace($Json)) {

        return @()

    }

    $Experiments = $Json | ConvertFrom-Json

    if ($null -eq $Experiments) {

        return @()

    }

    return @($Experiments)

}

#----------------------------------------------------------
# Add
#----------------------------------------------------------

function Add-HALSExperiment {

    param(

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Objective,

        [string]$Provider = "",

        [string]$Status = "Planned",

        [string]$Result = "",

        [string]$Conclusion = "",

        [int]$Confidence = 0

    )

    $Experiments = Get-HALSExperiments

    $Experiment = [PSCustomObject]@{

        Id          = ([guid]::NewGuid()).Guid
        Timestamp   = Get-Date
        Title       = $Title
        Objective   = $Objective
        Provider    = $Provider
        Status      = $Status
        Result      = $Result
        Conclusion  = $Conclusion
        Confidence  = $Confidence

    }

    $Experiments += $Experiment

    $Experiments |
        ConvertTo-Json -Depth 20 |
        Set-Content $ExperimentFile

    return $Experiment

}

#----------------------------------------------------------
# Find
#----------------------------------------------------------

function Find-HALSExperiment {

    param(

        [Parameter(Mandatory)]
        [string]$Title

    )

    Get-HALSExperiments |

        Where-Object {

            $_.Title -like "*$Title*"

        }

}

#----------------------------------------------------------
# Clear
#----------------------------------------------------------

function Clear-HALSExperiments {

    Set-Content -Path $ExperimentFile -Value "[]"

}

Initialize-HALSExperiments

Export-ModuleMember `
    -Function Initialize-HALSExperiments,
              Get-HALSExperiments,
              Add-HALSExperiment,
              Find-HALSExperiment,
              Clear-HALSExperiments