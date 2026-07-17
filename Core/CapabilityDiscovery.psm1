#==========================================================
# HALS - Capability Discovery
# Version : 0.2.1
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSCapabilities {

    param(

        [Parameter(Mandatory)]
        $Device

    )

    $Capabilities = @()

    foreach ($Entity in $Device.Entities) {

        $Capability = New-HALSCapability `
            -Name $Entity.Name `
            -Provider $Entity.Provider `
            -Category $Entity.Category

        switch -Wildcard ($Entity.Name) {

            "switch.switch" {

                $Capability.Writable = $true
                $Capability.Command = "switch"
                $Capability.AllowedValues = @("on","off")

            }

            "switchLevel.level" {

                $Capability.Writable = $true
                $Capability.Command = "setLevel"
                $Capability.Minimum = 0
                $Capability.Maximum = 100
                $Capability.Step = 1

            }

            "colorTemperature*" {

                $Capability.Writable = $true
                $Capability.Command = "setColorTemperature"
                $Capability.Minimum = 2700
                $Capability.Maximum = 6500

            }

            "colorControl.hue" {

                $Capability.Writable = $true
                $Capability.Command = "setHue"
                $Capability.Minimum = 0
                $Capability.Maximum = 100

            }

            "colorControl.saturation" {

                $Capability.Writable = $true
                $Capability.Command = "setSaturation"
                $Capability.Minimum = 0
                $Capability.Maximum = 100

            }

        }

        $Capabilities += $Capability

    }

    return $Capabilities

}

#----------------------------------------------------------
# Build Knowledge Base
#----------------------------------------------------------

function Update-HALSKnowledgeCapabilities {

    param(

        [Parameter(Mandatory)]
        [array]$Devices

    )

    $Capabilities = @()
    $Commands = @()
    $Providers = @()

    foreach ($Device in $Devices) {

        if (-not $Device.Entities) {
            continue
        }

        $DeviceCapabilities = Get-HALSCapabilities -Device $Device

        foreach ($Capability in $DeviceCapabilities) {

            $Capabilities += [PSCustomObject]@{
                Device      = $Device.Name
                Provider    = $Capability.Provider
                Name        = $Capability.Name
                Category    = $Capability.Category
                Writable    = $Capability.Writable
                Command     = $Capability.Command
            }

            if ($Capability.Command) {

                $Commands += [PSCustomObject]@{
                    Provider = $Capability.Provider
                    Command  = $Capability.Command
                }

            }

            if ($Capability.Provider) {

                $Providers += [PSCustomObject]@{
                    Name = $Capability.Provider
                }

            }

        }

    }

    $Capabilities = $Capabilities |
        Sort-Object Provider,Device,Name -Unique

    $Commands = $Commands |
        Sort-Object Provider,Command -Unique

    $Providers = $Providers |
        Sort-Object Name -Unique

    Save-HALSKnowledgeFile `
        -Name "Capabilities" `
        -Object $Capabilities

    Save-HALSKnowledgeFile `
        -Name "Commands" `
        -Object $Commands

    Save-HALSKnowledgeFile `
        -Name "Providers" `
        -Object $Providers

}

Export-ModuleMember `
    -Function Get-HALSCapabilities,
              Update-HALSKnowledgeCapabilities