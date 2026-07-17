#==========================================================
# HALS - Lab
# Version : 2.2.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Initialize
#----------------------------------------------------------

function Initialize-HALSLab {

    Initialize-HALSKnowledgeBase
    Initialize-HALSExperiments
    Initialize-HALSObservations
    Initialize-HALSProviderHealth
    Initialize-HALSEvidence

}

#----------------------------------------------------------
# Start Experiment
#----------------------------------------------------------

function Start-HALSExperiment {

    param(

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Objective,

        [string]$Provider = ""

    )

    $null = Add-HALSExperiment `
        -Title $Title `
        -Objective $Objective `
        -Provider $Provider `
        -Status "Running"

}

#----------------------------------------------------------
# Record Observation
#----------------------------------------------------------

function Record-HALSObservation {

    param(

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Summary,

        [string]$Provider = "",

        [string]$Severity = "Information"

    )

    $null = Add-HALSObservation `
        -Category $Category `
        -Summary $Summary `
        -Provider $Provider `
        -Severity $Severity

}

#----------------------------------------------------------
# Record Evidence
#----------------------------------------------------------

function Record-HALSEvidence {

    param(

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Finding,

        [string]$Category = "General",

        [string]$Severity = "Information",

        [int]$Confidence = 100

    )

    $null = Add-HALSEvidence `
        -Source $Source `
        -Finding $Finding `
        -Category $Category `
        -Severity $Severity `
        -Confidence $Confidence

}

#----------------------------------------------------------
# Record Provider Health
#----------------------------------------------------------

function Record-HALSProviderHealth {

    param(

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Status,

        [string]$Message = ""

    )

    $null = Set-HALSProviderHealth `
        -Provider $Provider `
        -Status $Status `
        -Message $Message

    if ($Status -eq "Healthy") {

        $null = Record-HALSObservation `
            -Category "Provider" `
            -Provider $Provider `
            -Summary "$Provider provider is healthy."

    }
    else {

        $null = Record-HALSObservation `
            -Category "Provider" `
            -Provider $Provider `
            -Severity "Critical" `
            -Summary "$Provider provider status: $Status. $Message"

        $null = Record-HALSEvidence `
            -Source $Provider `
            -Category "Provider" `
            -Severity "Critical" `
            -Finding $Message `
            -Confidence 100

    }

}

Export-ModuleMember `
    -Function Initialize-HALSLab,
              Start-HALSExperiment,
              Record-HALSObservation,
              Record-HALSEvidence,
              Record-HALSProviderHealth