#==========================================================
# HALS - Home Assistant Provider
# Version : 0.3.1
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Connect
#----------------------------------------------------------

function Connect-HomeAssistant {

    $Secrets = Get-Content "$(Get-HALSRoot)\Secrets\HomeAssistant.json" -Raw |
        ConvertFrom-Json

    if (-not $Secrets.Host) {
        throw "Home Assistant Host is missing from HomeAssistant.json."
    }

    if (-not $Secrets.Port) {
        throw "Home Assistant Port is missing from HomeAssistant.json."
    }

    if ($null -eq $Secrets.SSL) {
        throw "Home Assistant SSL setting is missing from HomeAssistant.json."
    }

    if (-not $Secrets.Token) {
        throw "Home Assistant Token is missing from HomeAssistant.json."
    }

    return @{

        Host = $Secrets.Host

        Port = $Secrets.Port

        SSL = $Secrets.SSL

        Headers = @{

            Authorization = "Bearer $($Secrets.Token)"
            Accept        = "application/json"

        }

    }

}

#----------------------------------------------------------
# Build URI
#----------------------------------------------------------

function Get-HAUri {

    param(

        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$Endpoint

    )

    $Protocol = if ($Connection.SSL) {

        "https"

    }
    else {

        "http"

    }

    "{0}://{1}:{2}/api/{3}" -f `
        $Protocol,
        $Connection.Host,
        $Connection.Port,
        $Endpoint.TrimStart('/')

}

#----------------------------------------------------------
# Configuration
#----------------------------------------------------------

function Get-HAConfig {

    param(

        [Parameter(Mandatory)]
        $Connection

    )

    Invoke-RestMethod `
        -Uri (Get-HAUri -Connection $Connection -Endpoint "config") `
        -Headers $Connection.Headers `
        -Method Get

}

#----------------------------------------------------------
# States
#----------------------------------------------------------

function Get-HAStates {

    param(

        [Parameter(Mandatory)]
        $Connection

    )

    Invoke-RestMethod `
        -Uri (Get-HAUri -Connection $Connection -Endpoint "states") `
        -Headers $Connection.Headers `
        -Method Get

}

#----------------------------------------------------------
# Services
#----------------------------------------------------------

function Get-HAServices {

    param(

        [Parameter(Mandatory)]
        $Connection

    )

    Invoke-RestMethod `
        -Uri (Get-HAUri -Connection $Connection -Endpoint "services") `
        -Headers $Connection.Headers `
        -Method Get

}

#----------------------------------------------------------
# Inventory
#----------------------------------------------------------

function Get-HomeAssistantInventory {

    param(

        [Parameter(Mandatory)]
        $Connection

    )

    $States = Get-HAStates `
        -Connection $Connection

    foreach ($Entity in $States) {

        $Domain = ""

        if ($Entity.entity_id -match "^([^\.]+)\.") {

            $Domain = $Matches[1]

        }

        #
        # friendly_name is optional in Home Assistant.
        # Fall back to the entity_id when it doesn't exist.
        #

        $FriendlyName = $Entity.entity_id

        if (
            $Entity.PSObject.Properties.Name -contains "attributes" -and
            $null -ne $Entity.attributes -and
            $Entity.attributes.PSObject.Properties.Name -contains "friendly_name"
        ) {

            $FriendlyName = $Entity.attributes.friendly_name

        }

        [PSCustomObject]@{

            EntityId     = $Entity.entity_id
            FriendlyName = $FriendlyName
            Domain       = $Domain
            State        = $Entity.state
            Attributes   = $Entity.attributes
            Raw          = $Entity

        }

    }

}

#----------------------------------------------------------
# Execute Service
#----------------------------------------------------------

function Invoke-HAService {

    param(

        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$Domain,

        [Parameter(Mandatory)]
        [string]$Service,

        [hashtable]$Data = @{}

    )

    Invoke-RestMethod `
        -Uri (Get-HAUri -Connection $Connection -Endpoint "services/$Domain/$Service") `
        -Headers $Connection.Headers `
        -Method Post `
        -ContentType "application/json" `
        -Body ($Data | ConvertTo-Json -Depth 10)

}

Export-ModuleMember `
    -Function Connect-HomeAssistant,
              Get-HAConfig,
              Get-HAStates,
              Get-HAServices,
              Get-HomeAssistantInventory,
              Invoke-HAService