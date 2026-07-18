#==========================================================
# HALS - Provider Health
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSProviderHealthFile {
    Join-Path (Get-HALSRoot) "Knowledge\ProviderHealth.json"
}

#----------------------------------------------------------
# Initialize
#----------------------------------------------------------

function Initialize-HALSProviderHealth {

    $ProviderHealthFile = Get-HALSProviderHealthFile

    if (!(Test-Path $ProviderHealthFile)) {

        @{} |
            ConvertTo-Json |
            Set-Content $ProviderHealthFile

    }

}

#----------------------------------------------------------
# Get
#----------------------------------------------------------

function Get-HALSProviderHealth {

    Initialize-HALSProviderHealth

    $Json = Get-Content (Get-HALSProviderHealthFile) -Raw

    if ([string]::IsNullOrWhiteSpace($Json)) {

        return @{}

    }

    return $Json | ConvertFrom-Json -AsHashtable

}

#----------------------------------------------------------
# Set
#----------------------------------------------------------

function Set-HALSProviderHealth {

    param(

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Status,

        [string]$Message = "",

        [int]$Confidence = 100

    )

    $Health = Get-HALSProviderHealth

    $Health[$Provider] = @{

        Provider   = $Provider
        Status     = $Status
        Message    = $Message
        Confidence = $Confidence
        Timestamp  = (Get-Date)

    }

    $Health |
        ConvertTo-Json -Depth 10 |
        Set-Content (Get-HALSProviderHealthFile)

}

#----------------------------------------------------------
# Test
#----------------------------------------------------------

function Test-HALSProviderHealthy {

    param(

        [Parameter(Mandatory)]
        [string]$Provider

    )

    $Health = Get-HALSProviderHealth

    if (-not $Health.ContainsKey($Provider)) {

        return $false

    }

    return ($Health[$Provider].Status -eq "Healthy")

}

#----------------------------------------------------------
# Clear
#----------------------------------------------------------

function Clear-HALSProviderHealth {

    @{} |
        ConvertTo-Json |
        Set-Content (Get-HALSProviderHealthFile)

}

Initialize-HALSProviderHealth

Export-ModuleMember `
    -Function Initialize-HALSProviderHealth,
              Get-HALSProviderHealth,
              Set-HALSProviderHealth,
              Test-HALSProviderHealthy,
              Clear-HALSProviderHealth
