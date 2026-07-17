#==========================================================
# HALS - Command Discovery
# Version : 1.1.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSCommands {

    Get-HALSRegisteredProviderCommands

}

#----------------------------------------------------------
# Update Knowledge Base
#----------------------------------------------------------

function Update-HALSKnowledgeCommands {

    $Commands = Get-HALSCommands

    $CommandObjects = foreach ($Command in $Commands) {

        [PSCustomObject]@{

            Name        = $Command.Name
            Provider    = $Command.Provider
            Description = $Command.Description
            Risk        = $Command.Risk

        }

    }

    Save-HALSKnowledgeFile `
        -Name "Commands" `
        -Object $CommandObjects

}

Export-ModuleMember `
    -Function Get-HALSCommands,
              Update-HALSKnowledgeCommands