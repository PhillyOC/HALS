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

    Get-HALSRegisteredProviderPermissions -Inventory $Inventory

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