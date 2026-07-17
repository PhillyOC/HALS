#==========================================================
# HALS - Inventory Module
# Version : 0.7.1
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSInventory {

    param(
        [AllowNull()]
        $Connection = $null
    )

    #------------------------------------------------------
    # Knowledge
    #------------------------------------------------------

    $Knowledge = Get-HALSKnowledge

    $Infrastructure = @()
    $Clients = @()
    $Devices = @()

    $SmartThings = @()
    $STDevices = @()

    $HomeAssistant = @()
    $HADevices = @()

    #------------------------------------------------------
    # UniFi
    #------------------------------------------------------

    if ($null -eq $Connection) {

        Set-HALSProviderHealth `
            -Provider "UniFi" `
            -Status "NotConfigured" `
            -Message "UniFi is not configured."

        Write-Host "  [ ] UniFi not configured; skipping." -ForegroundColor DarkGray

    }
    else {

        Write-Host "  [+] Connecting to UniFi..." -ForegroundColor DarkGray

        try {

            $Infrastructure = Get-UniFiInfrastructure `
                -Session $Connection.Session `
                -Host $Connection.Host

            $Clients = Get-UniFiClients `
                -Session $Connection.Session `
                -Host $Connection.Host

            $Devices = foreach ($Client in $Clients) {

                ConvertTo-HALSDevice `
                    -Device $Client `
                    -Source UniFi `
                    -Knowledge $Knowledge

            }

            Record-HALSProviderHealth `
                -Provider "UniFi" `
                -Status "Healthy"

            Write-Host "      UniFi OK" -ForegroundColor Green

        }

        catch {

            Record-HALSProviderHealth `
                -Provider "UniFi" `
                -Status "Offline" `
                -Message $_.Exception.Message

            Write-Warning "UniFi failed."

            Write-Host $_.Exception.Message -ForegroundColor Yellow

        }

    }

    #------------------------------------------------------
    # SmartThings
    #------------------------------------------------------

    $SmartThingsConfigured =
        (Test-Path "$(Get-HALSRoot)\Secrets\SmartThings.json") -or
        (Test-Path "$(Get-HALSRoot)\Secrets\OAuth\SmartThings.json")

    if (-not $SmartThingsConfigured) {

        Set-HALSProviderHealth `
            -Provider "SmartThings" `
            -Status "NotConfigured" `
            -Message "SmartThings is not configured."

        Write-Host "  [ ] SmartThings not configured; skipping." -ForegroundColor DarkGray

    }
    else {

        Write-Host "  [+] Connecting to SmartThings..." -ForegroundColor DarkGray

        try {

            $Global:HALSSmartThingsConnection = Connect-SmartThings

            $SmartThings = Get-SmartThingsInventory `
                -Connection $Global:HALSSmartThingsConnection

            $STDevices = foreach ($Device in $SmartThings) {

                ConvertTo-HALSSmartThingsDevice `
                    -Device $Device `
                    -Knowledge $Knowledge

            }

            Record-HALSProviderHealth `
                -Provider "SmartThings" `
                -Status "Healthy"

            Write-Host "      SmartThings OK" -ForegroundColor Green

        }

        catch {

            Record-HALSProviderHealth `
                -Provider "SmartThings" `
                -Status "Offline" `
                -Message $_.Exception.Message

            Write-Warning "SmartThings failed."

            Write-Host $_.Exception.Message -ForegroundColor Yellow

        }

    }

    #------------------------------------------------------
    # Home Assistant
    #------------------------------------------------------

    if (-not (Test-Path "$(Get-HALSRoot)\Secrets\HomeAssistant.json")) {

        Set-HALSProviderHealth `
            -Provider "HomeAssistant" `
            -Status "NotConfigured" `
            -Message "Home Assistant is not configured."

        Write-Host "  [ ] Home Assistant not configured; skipping." -ForegroundColor DarkGray

    }
    else {

        Write-Host "  [+] Connecting to Home Assistant..." -ForegroundColor DarkGray

        try {

            $Global:HALSHomeAssistantConnection = Connect-HomeAssistant

            $HomeAssistant = Get-HomeAssistantInventory `
                -Connection $Global:HALSHomeAssistantConnection

            $HADevices = foreach ($Device in $HomeAssistant) {

                ConvertTo-HALSHomeAssistantDevice `
                    -Device $Device `
                    -Knowledge $Knowledge

            }

            Record-HALSProviderHealth `
                -Provider "HomeAssistant" `
                -Status "Healthy"

            Write-Host "      Home Assistant OK" -ForegroundColor Green

        }

        catch {

            Record-HALSProviderHealth `
                -Provider "HomeAssistant" `
                -Status "Offline" `
                -Message $_.Exception.Message

            Write-Warning "Home Assistant failed."

            Write-Host $_.Exception.Message -ForegroundColor Yellow

        }

    }


    #------------------------------------------------------
    # Google Nest
    #------------------------------------------------------

    $NestDevices = @()

    if (Test-Path "$(Get-HALSRoot)\Secrets\OAuth\GoogleNest.json") {

        $NestConfig = Get-Content "$(Get-HALSRoot)\Secrets\OAuth\GoogleNest.json" -Raw | ConvertFrom-Json

        if ($NestConfig.Authorized -eq $true -and
            -not [string]::IsNullOrWhiteSpace($NestConfig.ProjectId)) {

            Write-Host "  [+] Connecting to Google Nest..." -ForegroundColor DarkGray

            try {

                $NestConnection = Connect-GoogleNest
                $NestInventory  = Get-GoogleNestInventory `
                    -Connection $NestConnection `
                    -ProjectId  $NestConfig.ProjectId

                $NestDevices = foreach ($Device in $NestInventory) {
                    ConvertTo-HALSGoogleNestDevice -Device $Device -Knowledge $Knowledge
                }

                Record-HALSProviderHealth -Provider "GoogleNest" -Status "Healthy"
                Write-Host "      Google Nest OK" -ForegroundColor Green

            }
            catch {

                Record-HALSProviderHealth `
                    -Provider "GoogleNest" `
                    -Status "Offline" `
                    -Message $_.Exception.Message

                Write-Warning "Google Nest failed."
                Write-Host $_.Exception.Message -ForegroundColor Yellow

            }

        }

    }

    #------------------------------------------------------
    # Philips Hue
    #------------------------------------------------------

    $HueDevices = @()

    if (Test-Path "$(Get-HALSRoot)\Secrets\PhilipsHue.json") {

        $HueSecrets = Get-Content "$(Get-HALSRoot)\Secrets\PhilipsHue.json" -Raw | ConvertFrom-Json

        if (-not [string]::IsNullOrWhiteSpace($HueSecrets.BridgeIp) -and
            -not [string]::IsNullOrWhiteSpace($HueSecrets.Username)) {

            Write-Host "  [+] Connecting to Philips Hue..." -ForegroundColor DarkGray

            try {

                $HueConnection = Connect-PhilipsHue
                $HueInventory  = Get-PhilipsHueInventory -Connection $HueConnection

                $HueDevices = foreach ($Device in $HueInventory) {
                    ConvertTo-HALSPhilipsHueDevice -Device $Device -Knowledge $Knowledge
                }

                Record-HALSProviderHealth -Provider "PhilipsHue" -Status "Healthy"
                Write-Host "      Philips Hue OK" -ForegroundColor Green

            }
            catch {

                Record-HALSProviderHealth `
                    -Provider "PhilipsHue" `
                    -Status "Offline" `
                    -Message $_.Exception.Message

                Write-Warning "Philips Hue failed."
                Write-Host $_.Exception.Message -ForegroundColor Yellow

            }

        }

    }

    #------------------------------------------------------
    # Ecobee
    #------------------------------------------------------

    $EcobeeDevices = @()

    if (Test-Path "$(Get-HALSRoot)\Secrets\OAuth\Ecobee.json") {

        $EcobeeConfig = Get-Content "$(Get-HALSRoot)\Secrets\OAuth\Ecobee.json" -Raw | ConvertFrom-Json

        if ($EcobeeConfig.Authorized -eq $true) {

            Write-Host "  [+] Connecting to Ecobee..." -ForegroundColor DarkGray

            try {

                $EcobeeConnection = Connect-Ecobee
                $EcobeeInventory  = Get-EcobeeInventory -Connection $EcobeeConnection

                $EcobeeDevices = foreach ($Device in $EcobeeInventory) {
                    ConvertTo-HALSEcobeeDevice -Device $Device -Knowledge $Knowledge
                }

                # Flatten - ConvertTo-HALSEcobeeDevice returns thermostat + sensors array
                $EcobeeDevices = @($EcobeeDevices | ForEach-Object { $_ })

                Record-HALSProviderHealth -Provider "Ecobee" -Status "Healthy"
                Write-Host "      Ecobee OK" -ForegroundColor Green

            }
            catch {

                Record-HALSProviderHealth `
                    -Provider "Ecobee" `
                    -Status "Offline" `
                    -Message $_.Exception.Message

                Write-Warning "Ecobee failed."
                Write-Host $_.Exception.Message -ForegroundColor Yellow

            }

        }

    }
    #------------------------------------------------------
    # Merge Devices
    #------------------------------------------------------

    $Devices = @(
        $Devices
        $STDevices
        $HADevices
    )

    #------------------------------------------------------
    # Build Assets
    #------------------------------------------------------

    $Assets = Merge-HALSAssets `
        -Devices $Devices

    #------------------------------------------------------
    # Return Inventory
    #------------------------------------------------------

    [PSCustomObject]@{

        Connection      = $Connection

        Knowledge       = $Knowledge

        Infrastructure  = $Infrastructure

        Clients         = $Clients

        Devices         = $Devices

        Assets          = $Assets

        SmartThings     = $SmartThings

        HomeAssistant   = $HomeAssistant

    }

}

Export-ModuleMember -Function Get-HALSInventory