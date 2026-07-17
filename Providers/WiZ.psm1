#==========================================================
# HALS - WiZ Pro Provider
# Version : 1.0.0
#
# Official API:
#   OAuth 2.0 with PKCE
#   https://api.pro.wizconnected.com/api/oauth/token
#   https://api.pro.wizconnected.com/api/graphql
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script:WiZTokenEndpoint = "https://api.pro.wizconnected.com/api/oauth/token"
$Script:WiZGraphQLEndpoint = "https://api.pro.wizconnected.com/api/graphql"

function ConvertTo-WiZBase64Url {

    param([Parameter(Mandatory)][byte[]]$Bytes)

    [Convert]::ToBase64String($Bytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

function New-WiZCodeVerifier {
    $Bytes = [byte[]]::new(64)
    [Security.Cryptography.RandomNumberGenerator]::Fill($Bytes)
    ConvertTo-WiZBase64Url -Bytes $Bytes
}

function Get-WiZCodeChallenge {

    param([Parameter(Mandatory)][string]$Verifier)

    $Bytes = [Text.Encoding]::ASCII.GetBytes($Verifier)
    $Hash = [Security.Cryptography.SHA256]::HashData($Bytes)
    ConvertTo-WiZBase64Url -Bytes $Hash
}

function Get-WiZConfigurationPath {
    Join-Path (Get-HALSRoot) "Secrets\OAuth\WiZ.json"
}

function Get-WiZConfiguration {

    $Path = Get-WiZConfigurationPath
    if (-not (Test-Path $Path)) {
        throw "WiZ is not configured. Run Initialize-WiZ."
    }

    Get-Content $Path -Raw | ConvertFrom-Json
}

function Save-WiZConfiguration {

    param([Parameter(Mandatory)]$Configuration)

    $Path = Get-WiZConfigurationPath
    $Folder = Split-Path -Parent $Path
    if (-not (Test-Path $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }

    $Configuration | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
}

function Update-WiZTokens {

    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)]$TokenResponse
    )

    $Configuration.AccessToken = $TokenResponse.accessToken
    $Configuration.RefreshToken = $TokenResponse.refreshToken
    $Configuration.AccessTokenExpires = $TokenResponse.expiresAt
    $Configuration.Authorized = $true
    Save-WiZConfiguration -Configuration $Configuration
    $Configuration
}

function Request-WiZToken {

    param(
        [Parameter(Mandatory)][ValidateSet("authorizationCode", "refreshToken")]
        [string]$GrantType,
        [Parameter(Mandatory)]$Configuration,
        [string]$AuthorizationCode = "",
        [string]$CodeVerifier = ""
    )

    $Body = if ($GrantType -eq "authorizationCode") {
        @{
            grantType = "authorizationCode"
            authorizationCode = $AuthorizationCode
            clientId = $Configuration.ClientId
            codeVerifier = $CodeVerifier
        }
    }
    else {
        @{
            grantType = "refreshToken"
            refreshToken = $Configuration.RefreshToken
        }
    }

    Invoke-RestMethod `
        -Uri $Script:WiZTokenEndpoint `
        -Method Post `
        -ContentType "application/json" `
        -Body ($Body | ConvertTo-Json)
}

function Connect-WiZ {

    $Configuration = Get-WiZConfiguration
    $Expired = $true

    if ($Configuration.PSObject.Properties["AccessTokenExpires"] -and
        $Configuration.AccessTokenExpires) {
        $Expired = ([datetime]$Configuration.AccessTokenExpires) -le (Get-Date).AddMinutes(2)
    }

    if ($Expired -and
        $Configuration.PSObject.Properties["RefreshToken"] -and
        -not [string]::IsNullOrWhiteSpace($Configuration.RefreshToken)) {
        $Tokens = Request-WiZToken -GrantType refreshToken -Configuration $Configuration
        $Configuration = Update-WiZTokens -Configuration $Configuration -TokenResponse $Tokens
    }

    if (-not $Configuration.PSObject.Properties["AccessToken"] -or
        [string]::IsNullOrWhiteSpace($Configuration.AccessToken)) {
        throw "WiZ access token is unavailable. Run Initialize-WiZ."
    }

    @{
        Headers = @{
            Authorization = "Bearer $($Configuration.AccessToken)"
            "Content-Type" = "application/json"
        }
    }
}

function Invoke-WiZGraphQL {

    param(
        [Parameter(Mandatory)]$Connection,
        [Parameter(Mandatory)][string]$Query,
        [hashtable]$Variables = @{}
    )

    $Response = Invoke-RestMethod `
        -Uri $Script:WiZGraphQLEndpoint `
        -Method Post `
        -Headers $Connection.Headers `
        -Body (@{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 20)

    if ($Response.PSObject.Properties["errors"] -and @($Response.errors).Count -gt 0) {
        $Messages = @($Response.errors | ForEach-Object { $_.message }) -join "; "
        throw "WiZ GraphQL error: $Messages"
    }

    $Response.data
}

function Get-WiZBuildings {

    param([Parameter(Mandatory)]$Connection)

    $Data = Invoke-WiZGraphQL `
        -Connection $Connection `
        -Query "query { buildings { id name } }"

    @($Data.buildings)
}

function Get-WiZBuildingTopology {

    param(
        [Parameter(Mandatory)]$Connection,
        [Parameter(Mandatory)][string]$BuildingId
    )

    $Query = @'
query BuildingTopology($buildingId: String!) {
  buildingTopology(buildingId: $buildingId) {
    id
    name
    floors {
      id
      name
      rooms {
        id
        name
        roomScenes { id name }
        lights {
          id
          name
          mac
          model {
            id
            brand
            name
            temperatureMin
            temperatureMax
          }
          currentState {
            r
            g
            b
            cw
            ww
            dimming
            sceneId
            speed
            ratio
            state
            temperature
          }
        }
      }
    }
  }
}
'@

    $Data = Invoke-WiZGraphQL `
        -Connection $Connection `
        -Query $Query `
        -Variables @{ buildingId = $BuildingId }

    $Data.buildingTopology
}

function Get-WiZInventory {

    param([Parameter(Mandatory)]$Connection)

    foreach ($Building in @(Get-WiZBuildings -Connection $Connection)) {
        $Topology = Get-WiZBuildingTopology -Connection $Connection -BuildingId $Building.id

        foreach ($Floor in @($Topology.floors)) {
            foreach ($Room in @($Floor.rooms)) {
                foreach ($Light in @($Room.lights)) {
                    [PSCustomObject]@{
                        BuildingId = $Topology.id
                        BuildingName = $Topology.name
                        FloorId = $Floor.id
                        FloorName = $Floor.name
                        RoomId = $Room.id
                        RoomName = $Room.name
                        RoomScenes = @($Room.roomScenes)
                        LightId = $Light.id
                        Name = $Light.name
                        MAC = $Light.mac
                        Model = $Light.model
                        State = $Light.currentState
                        Raw = $Light
                    }
                }
            }
        }
    }
}

function ConvertTo-HALSWiZDevice {

    param(
        [Parameter(Mandatory)]$Device,
        [Parameter(Mandatory)][hashtable]$Knowledge
    )

    $Name = $Device.Name
    $Known = $false

    if ($Device.MAC -and $Knowledge.ContainsKey($Device.MAC)) {
        $Known = $true
        $Entry = $Knowledge[$Device.MAC]
        if ($Entry.FriendlyName) { $Name = $Entry.FriendlyName }
    }

    $State = $Device.State
    $Entities = @(
        New-HALSEntity -Name "switch.switch" -Type "State" -Provider "WiZ" `
            -Value $(if ($State.state) { "on" } else { "off" }) -Writable $true -Raw $State.state
        New-HALSEntity -Name "switchLevel.level" -Type "State" -Provider "WiZ" `
            -Value $State.dimming -Writable $true -Raw $State.dimming
        New-HALSEntity -Name "colorTemperature.colorTemperature" -Type "State" -Provider "WiZ" `
            -Value $State.temperature -Writable $true -Raw $State.temperature
        New-HALSEntity -Name "colorControl.red" -Type "State" -Provider "WiZ" `
            -Value $State.r -Writable $true -Raw $State.r
        New-HALSEntity -Name "colorControl.green" -Type "State" -Provider "WiZ" `
            -Value $State.g -Writable $true -Raw $State.g
        New-HALSEntity -Name "colorControl.blue" -Type "State" -Provider "WiZ" `
            -Value $State.b -Writable $true -Raw $State.b
        New-HALSEntity -Name "scene.sceneId" -Type "State" -Provider "WiZ" `
            -Value $State.sceneId -Writable $true -Raw $State.sceneId
    )

    [PSCustomObject]@{
        Name = $Name
        Category = "Light Bulb"
        Known = $Known
        Hostname = ""
        IP = ""
        MAC = $Device.MAC
        Manufacturer = $(if ($Device.Model.brand) { $Device.Model.brand } else { "WiZ" })
        Source = "WiZ"
        Room = $Device.RoomName
        BuildingId = $Device.BuildingId
        BuildingName = $Device.BuildingName
        FloorId = $Device.FloorId
        FloorName = $Device.FloorName
        RoomId = $Device.RoomId
        LightId = $Device.LightId
        TemperatureMin = $Device.Model.temperatureMin
        TemperatureMax = $Device.Model.temperatureMax
        RoomScenes = $Device.RoomScenes
        Critical = $false
        Infrastructure = $false
        Mobile = $false
        SleepCapable = $false
        ExpectedAvailability = "Always"
        Entities = $Entities
        RawProviderData = $Device.Raw
    }
}

function Set-WiZLightState {

    param(
        [Parameter(Mandatory)]$Connection,
        [Parameter(Mandatory)]$Device,
        [Parameter(Mandatory)][hashtable]$State
    )

    $Query = @'
mutation ChangeLightState(
  $floorId: String!
  $lightId: String!
  $provider: String!
  $mac: String
  $state: PilotingLightStateInput!
) {
  changeLightState(
    floorId: $floorId
    lightId: $lightId
    provider: $provider
    mac: $mac
    state: $state
  )
}
'@

    $Data = Invoke-WiZGraphQL `
        -Connection $Connection `
        -Query $Query `
        -Variables @{
            floorId = $Device.FloorId
            lightId = $Device.LightId
            provider = "WiZ"
            mac = $Device.MAC
            state = $State
        }

    [bool]$Data.changeLightState
}

function Get-WiZRequiredParameter {

    param(
        [Parameter(Mandatory)]$Parameters,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Parameters -is [System.Collections.IDictionary]) {
        if ($Parameters.Contains($Name)) {
            return $Parameters[$Name]
        }
    }
    elseif ($Parameters.PSObject.Properties[$Name]) {
        return $Parameters.$Name
    }

    throw "WiZ command requires parameter '$Name'."
}

function Invoke-WiZAction {

    param([Parameter(Mandatory)]$Action)

    $Device = $Global:HALSInventory.Devices |
        Where-Object { $_.Source -eq "WiZ" -and $_.Name -eq $Action.Device } |
        Select-Object -First 1

    if (-not $Device) {
        throw "WiZ light '$($Action.Device)' was not found."
    }

    $State = @{}

    switch ($Action.Command) {
        "TurnOnLight" { $State.state = $true }
        "TurnOffLight" { $State.state = $false }
        "ToggleLight" {
            $Switch = @($Device.Entities | Where-Object { $_.Name -eq "switch.switch" }) |
                Select-Object -First 1
            if (-not $Switch) {
                throw "WiZ light '$($Device.Name)' does not expose a switch state."
            }
            $State.state = [string]$Switch.Value -ne "on"
        }
        "SetBrightness" {
            $Value = [int](Get-WiZRequiredParameter -Parameters $Action.Parameters -Name "Brightness")
            if ($Value -lt 10 -or $Value -gt 100) {
                throw "WiZ brightness must be between 10 and 100."
            }
            $State.dimming = $Value
            $State.state = $true
        }
        "SetColor" {
            $ColorName = [string](Get-WiZRequiredParameter -Parameters $Action.Parameters -Name "Color")
            $Color = Get-HALSColor -Name $ColorName
            $State.r = [int]$Color.RGB[0]
            $State.g = [int]$Color.RGB[1]
            $State.b = [int]$Color.RGB[2]
            $State.cw = 0
            $State.ww = 0
            $State.state = $true
        }
        "SetColorTemperature" {
            $Value = [int](Get-WiZRequiredParameter -Parameters $Action.Parameters -Name "ColorTemperature")
            if ($Device.TemperatureMin -and $Value -lt $Device.TemperatureMin) {
                throw "WiZ color temperature must be at least $($Device.TemperatureMin)K for this light."
            }
            if ($Device.TemperatureMax -and $Value -gt $Device.TemperatureMax) {
                throw "WiZ color temperature must be at most $($Device.TemperatureMax)K for this light."
            }
            $State.temperature = $Value
            $State.state = $true
        }
        "SetScene" {
            $Value = [int](Get-WiZRequiredParameter -Parameters $Action.Parameters -Name "SceneId")
            if ($Value -lt 1 -or $Value -gt 33) {
                throw "WiZ SceneId must be between 1 and 33."
            }
            $State.sceneId = $Value
            $State.state = $true
        }
        default { throw "Unsupported WiZ command: $($Action.Command)" }
    }

    $Connection = Connect-WiZ
    if (-not (Set-WiZLightState -Connection $Connection -Device $Device -State $State)) {
        throw "WiZ rejected the state change for '$($Device.Name)'."
    }

    @{ Executed = $true; Provider = "WiZ"; Device = $Device.Name; Command = $Action.Command }
}

function Get-HALSWiZCommands {
    $Commands = @(
        New-HALSCommand -Name TurnOnLight -Provider WiZ -Description "Turn on a WiZ light."
        New-HALSCommand -Name TurnOffLight -Provider WiZ -Description "Turn off a WiZ light."
        New-HALSCommand -Name ToggleLight -Provider WiZ -Description "Toggle a WiZ light using its current state."
        New-HALSCommand -Name SetBrightness -Provider WiZ -Description "Set WiZ brightness. Required parameter: Brightness (integer 10-100)."
        New-HALSCommand -Name SetColor -Provider WiZ -Description "Set an RGB WiZ light color. Required parameter: Color (CSS color name)."
        New-HALSCommand -Name SetColorTemperature -Provider WiZ -Description "Set WiZ white color temperature. Required parameter: ColorTemperature (Kelvin within the device model range)."
        New-HALSCommand -Name SetScene -Provider WiZ -Description "Apply a WiZ light mode. Required parameter: SceneId (1-33: Ocean, Romance, Sunset, Party, Fireplace, Cozy, Forest, Pastel, Wake up, Bedtime, Warm white, Daylight, Cool white, Night light, Focus, Relax, True colors, TV Time, Plant growth, Spring, Summer, Fall, Deep dive, Jungle, Mojito, Club, Christmas, Halloween, Candlelight, Golden white, Pulse, Steampunk, Diwali)."
    )

    foreach ($Command in $Commands) {
        $Schema = switch ($Command.Name) {
            "SetBrightness" {
                @{ Brightness = @{ Type = "integer"; Minimum = 10; Maximum = 100; Required = $true } }
            }
            "SetColor" {
                @{ Color = @{ Type = "CSS color name"; Required = $true } }
            }
            "SetColorTemperature" {
                @{ ColorTemperature = @{ Type = "integer"; Unit = "Kelvin"; Required = $true; DeviceRange = $true } }
            }
            "SetScene" {
                @{ SceneId = @{ Type = "integer"; Minimum = 1; Maximum = 33; Required = $true } }
            }
            default { @{} }
        }

        $Command | Add-Member -NotePropertyName ApiOperation -NotePropertyValue "changeLightState"
        $Command | Add-Member -NotePropertyName Parameters -NotePropertyValue $Schema
    }

    @($Commands)
}

function Get-HALSWiZPermissions {

    param([Parameter(Mandatory)]$Inventory)

    @(
        New-HALSPermission -Provider WiZ -Name "Read Building Topology" -Granted $true
        New-HALSPermission -Provider WiZ -Name "Read Light State" -Granted $true
        New-HALSPermission -Provider WiZ -Name "Control Lights" -Granted $true
    )
}

function Test-HALSWiZConfigured {

    $Path = Get-WiZConfigurationPath
    if (-not (Test-Path $Path)) { return $false }

    try {
        $Configuration = Get-Content $Path -Raw | ConvertFrom-Json
        return (
            -not [string]::IsNullOrWhiteSpace($Configuration.ClientId) -and
            (
                -not [string]::IsNullOrWhiteSpace($Configuration.AccessToken) -or
                -not [string]::IsNullOrWhiteSpace($Configuration.RefreshToken)
            )
        )
    }
    catch {
        return $false
    }
}

function Initialize-WiZ {

    Write-Host ""
    Write-Host "HALS WiZ Pro setup" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "A WiZ Pro client ID and registered redirect URI are required." -ForegroundColor DarkGray
    Write-Host ""

    $ClientId = (Read-Host "WiZ Pro client ID").Trim()
    $RedirectUri = (Read-Host "Registered redirect URI").Trim()

    if ([string]::IsNullOrWhiteSpace($ClientId) -or
        [string]::IsNullOrWhiteSpace($RedirectUri)) {
        throw "Client ID and redirect URI are required."
    }

    $Verifier = New-WiZCodeVerifier
    $Challenge = Get-WiZCodeChallenge -Verifier $Verifier
    $AuthorizeUrl =
        "https://pro.wizconnected.com/dashboard/#/oauth/authorize" +
        "?client_id=$([Uri]::EscapeDataString($ClientId))" +
        "&code_challenge=$([Uri]::EscapeDataString($Challenge))" +
        "&code_challenge_method=S256" +
        "&redirect_uri=$([Uri]::EscapeDataString($RedirectUri))"

    $Configuration = [PSCustomObject]@{
        Provider = "WiZ"
        ClientId = $ClientId
        RedirectUri = $RedirectUri
        AccessToken = ""
        RefreshToken = ""
        AccessTokenExpires = $null
        Authorized = $false
    }
    Save-WiZConfiguration -Configuration $Configuration

    Write-Host "Opening WiZ authorization page..." -ForegroundColor Green
    Start-Process $AuthorizeUrl
    Write-Host ""
    Write-Host "After WiZ redirects your browser, copy the authorization code." -ForegroundColor DarkGray
    $Code = (Read-Host "Authorization code").Trim()
    if ([string]::IsNullOrWhiteSpace($Code)) {
        throw "Authorization code cannot be empty."
    }

    $Tokens = Request-WiZToken `
        -GrantType authorizationCode `
        -Configuration $Configuration `
        -AuthorizationCode $Code `
        -CodeVerifier $Verifier

    $null = Update-WiZTokens -Configuration $Configuration -TokenResponse $Tokens
    $Connection = Connect-WiZ
    $Buildings = @(Get-WiZBuildings -Connection $Connection)

    Write-Host ""
    Write-Host "WiZ connected. Found $($Buildings.Count) building(s)." -ForegroundColor Green
    Write-Host "Run HALS to inventory WiZ lights." -ForegroundColor DarkGray
    Write-Host ""
}

function Invoke-HALSWiZInventory {

    param([Parameter(Mandatory)]$Knowledge)

    $Connection = Connect-WiZ
    $Raw = @(Get-WiZInventory -Connection $Connection)
    $Devices = @($Raw | ForEach-Object {
        ConvertTo-HALSWiZDevice -Device $_ -Knowledge $Knowledge
    })

    [PSCustomObject]@{
        Devices = $Devices
        Connection = $Connection
        Data = $Raw
    }
}

Export-ModuleMember -Function `
    Connect-WiZ,
    Invoke-WiZGraphQL,
    Get-WiZBuildings,
    Get-WiZBuildingTopology,
    Get-WiZInventory,
    Set-WiZLightState,
    Invoke-WiZAction,
    Get-HALSWiZCommands,
    Get-HALSWiZPermissions,
    Test-HALSWiZConfigured,
    Initialize-WiZ,
    Invoke-HALSWiZInventory

if (Get-Command Register-HALSDeviceProvider -ErrorAction SilentlyContinue) {
    Register-HALSDeviceProvider `
        -Key "WiZ" `
        -Name "WiZ Pro" `
        -TestConfiguredCommand "Test-HALSWiZConfigured" `
        -InventoryCommand "Invoke-HALSWiZInventory" `
        -CommandCatalogCommand "Get-HALSWiZCommands" `
        -PermissionCatalogCommand "Get-HALSWiZPermissions" `
        -ActionHandlerCommand "Invoke-WiZAction" `
        -SetupCommands @(
            @{ Name = "Initialize-WiZ"; Description = "Set up WiZ Pro lighting" }
        ) `
        -Order 55
}
