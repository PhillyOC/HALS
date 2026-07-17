#==========================================================
# HALS - Permission Discovery
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSPermissions {

    param(

        [Parameter(Mandatory)]
        $Inventory

    )

    $Permissions = @()

    #
    # SmartThings
    #

    if ($Inventory.SmartThings) {

        $Permissions += New-HALSPermission `
            -Provider SmartThings `
            -Name "Read Devices" `
            -Granted $true `
            -Description "Read SmartThings devices."

        $Permissions += New-HALSPermission `
            -Provider SmartThings `
            -Name "Read Rooms" `
            -Granted $true

        $Permissions += New-HALSPermission `
            -Provider SmartThings `
            -Name "Execute Commands" `
            -Granted $true

        $Permissions += New-HALSPermission `
            -Provider SmartThings `
            -Name "Firmware Management" `
            -Granted $false

        $Permissions += New-HALSPermission `
            -Provider SmartThings `
            -Name "Driver Management" `
            -Granted $false

    }

    #
    # UniFi
    #

    if ($Inventory.Clients) {

        $Permissions += New-HALSPermission `
            -Provider UniFi `
            -Name "Read Clients" `
            -Granted $true

        $Permissions += New-HALSPermission `
            -Provider UniFi `
            -Name "Read Infrastructure" `
            -Granted $true

        $Permissions += New-HALSPermission `
            -Provider UniFi `
            -Name "Reconnect Clients" `
            -Granted $false

        $Permissions += New-HALSPermission `
            -Provider UniFi `
            -Name "Restart Devices" `
            -Granted $false

        $Permissions += New-HALSPermission `
            -Provider UniFi `
            -Name "Firmware Management" `
            -Granted $false

    }

    return $Permissions

}

#----------------------------------------------------------
# Update Knowledge Base
#----------------------------------------------------------

function Update-HALSKnowledgePermissions {

    param(

        [Parameter(Mandatory)]
        $Inventory

    )

    $PermissionObjects = foreach ($Permission in (Get-HALSPermissions -Inventory $Inventory)) {

        [PSCustomObject]@{

            Provider    = $Permission.Provider
            Name        = $Permission.Name
            Granted     = $Permission.Granted
            Description = $Permission.Description

        }

    }

    Save-HALSKnowledgeFile `
        -Name "Permissions" `
        -Object $PermissionObjects

}

Export-ModuleMember `
    -Function Get-HALSPermissions,
              Update-HALSKnowledgePermissions