Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-UniFiSiteName {

    param(
        [Parameter(Mandatory)]
        [string]$Site,

        [Parameter(Mandatory)]
        [string]$HostName
    )

    $Resolved = $Site.Trim()
    if ([string]::IsNullOrWhiteSpace($Resolved)) {
        $Resolved = "default"
    }

    if ($Resolved -match '^(?i)https?://' -or $Resolved -match '[/\\]' -or $Resolved -match '^\d{1,3}(\.\d{1,3}){3}$') {
        return "default"
    }

    if ($Resolved -eq $HostName) {
        return "default"
    }

    return $Resolved

}

function Set-UniFiConnectionProperty {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [string]$Name,

        $Value
    )

    $Connection | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force

}

function Get-UniFiControllerProfile {

    param(
        [Parameter(Mandatory)]
        [ValidateSet("Legacy", "UniFiOS")]
        [string]$ControllerType,

        [Parameter(Mandatory)]
        [string]$HostName,

        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter(Mandatory)]
        [string]$Site
    )

    $ResolvedSite = Resolve-UniFiSiteName -Site $Site -HostName $HostName

    if ($ControllerType -eq "UniFiOS") {
        $NetworkBase = "https://${HostName}:${Port}/proxy/network"
        return [PSCustomObject]@{
            ControllerType    = "UniFiOS"
            ApiMode           = "Classic"
            LoginUri          = "$NetworkBase/api/auth/login"
            SitesUri          = "$NetworkBase/api/self/sites"
            StatSitesUri      = "$NetworkBase/api/stat/sites"
            IntegrationBase   = "$NetworkBase/integration/v1"
            IntegrationSitesUri = "$NetworkBase/integration/v1/sites"
            ApiBase           = "$NetworkBase/api/s/$ResolvedSite"
        }
    }

    return [PSCustomObject]@{
        ControllerType = "Legacy"
        ApiMode        = "Classic"
        LoginUri       = "https://${HostName}:${Port}/api/login"
        SitesUri       = "https://${HostName}:${Port}/api/self/sites"
        StatSitesUri   = "https://${HostName}:${Port}/api/stat/sites"
        ApiBase        = "https://${HostName}:${Port}/api/s/$ResolvedSite"
    }

}

function Resolve-UniFiControllerHostInput {

    param(
        [Parameter(Mandatory)]
        [string]$ControllerHost,

        [int]$Port = 8443
    )

    $NormalizedHost = $ControllerHost.Trim()
    $NormalizedPort = $Port

    if ($NormalizedHost -match '^(?i)https?://') {
        $Uri = [Uri]$NormalizedHost
        $NormalizedHost = $Uri.Host
        if (-not $Uri.IsDefaultPort -and $Uri.Port -gt 0) {
            $NormalizedPort = $Uri.Port
        }
    }
    elseif ($NormalizedHost -match '^(?<name>[^:/]+):(?<port>\d+)$') {
        $NormalizedHost = $Matches.name
        $NormalizedPort = [int]$Matches.port
    }

    @{
        HostName = $NormalizedHost.TrimEnd('/')
        Port     = $NormalizedPort
    }

}

function Get-UniFiApiErrorMessageFromBody {

    param([string]$Body)

    if ([string]::IsNullOrWhiteSpace($Body)) {
        return $null
    }

    if ($Body -match '\{[\s\S]*\}') {
        try {
            $JsonText = ($Body | Select-String -Pattern '\{[\s\S]*\}' -AllMatches).Matches[-1].Value
            $Parsed = $JsonText | ConvertFrom-Json
            if ($Parsed.PSObject.Properties["meta"] -and
                $Parsed.meta.PSObject.Properties["msg"] -and
                -not [string]::IsNullOrWhiteSpace([string]$Parsed.meta.msg)) {
                return [string]$Parsed.meta.msg
            }
            if ($Parsed.PSObject.Properties["message"] -and
                -not [string]::IsNullOrWhiteSpace([string]$Parsed.message)) {
                return [string]$Parsed.message
            }
            if ($Parsed.PSObject.Properties["code"] -and
                -not [string]::IsNullOrWhiteSpace([string]$Parsed.code)) {
                return [string]$Parsed.code
            }
        }
        catch {
            # Ignore malformed JSON fragments in HTML error pages.
        }
    }

    if ($Body -match '(?i)HTTP Status 500') {
        return "HTTP 500 from controller login endpoint"
    }

    return $null

}

function Get-UniFiErrorRecordMessage {

    param($ErrorRecord)

    if (-not $ErrorRecord) {
        return "Unknown error"
    }

    $Detail = $null
    if ($ErrorRecord.PSObject.Properties["ErrorDetails"] -and $ErrorRecord.ErrorDetails) {
        if ($ErrorRecord.ErrorDetails.PSObject.Properties["Message"]) {
            $Detail = [string]$ErrorRecord.ErrorDetails.Message
            $ParsedMessage = Get-UniFiApiErrorMessageFromBody -Body $Detail
            if ($ParsedMessage) {
                return $ParsedMessage
            }
        }
    }

    if ($ErrorRecord.PSObject.Properties["Exception"] -and $ErrorRecord.Exception) {
        if ($ErrorRecord.Exception.PSObject.Properties["Response"] -and $ErrorRecord.Exception.Response) {
            $StatusCode = [int]$ErrorRecord.Exception.Response.StatusCode
            if ($StatusCode -eq 500) {
                return "HTTP 500 from controller login endpoint"
            }
        }

        if ($ErrorRecord.Exception.PSObject.Properties["Message"]) {
            $ExMessage = [string]$ErrorRecord.Exception.Message
            if ($Detail -and $Detail.Length -lt 600 -and $Detail -notmatch '(?i)<html|<body') {
                return $Detail
            }
            return $ExMessage
        }
    }

    return [string]$ErrorRecord

}

function Get-UniFiLoginErrorHint {

    param(
        [string]$ControllerType,
        [int]$Port,
        [string]$ApiMessage
    )

    if ($ApiMessage -match '(?i)HTTP 500') {
        if ($Port -eq 8443) {
            return "Port 8443 /api/login returned HTTP 500 on this Cloud Key (Tomcat error). HALS also tries port 443 — or enter port 443 when prompted."
        }
        return "Controller login endpoint returned HTTP 500 on port $Port."
    }

    switch ($ApiMessage) {
        "api.err.Invalid" {
            if ($ControllerType -eq "Legacy") {
                return "Invalid login request or credentials rejected on port $Port. Confirm the local admin password from Settings > System > Admins (not your ui.com password)."
            }
            return "The legacy /api/login endpoint is not valid on this controller (common on UniFi OS). Try API key auth or port 443."
        }
        "api.err.LoginRequired" {
            if ($ControllerType -eq "UniFiOS") {
                return @"
Local admin login was rejected on port $Port.
Use a local Super Admin account (Settings > Admins > Add Admin > Local Access).
Ubiquiti/ui.com-only accounts cannot use the local API.
Recommended: create an API key at https://unifi.ui.com/settings/api-keys or on the local console (Settings > Control Plane > Integrations > API Keys), then choose API key auth in HALS.
"@
            }
            return "Login required or credentials rejected on port $Port. Use the local Cloud Key admin password (Settings > System > Admins), not your ui.com SSO password."
        }
        default {
            return $ApiMessage
        }
    }

}

function Test-UniFiLoginResponseSuccess {

    param($Parsed)

    if (-not $Parsed) {
        return $true
    }

    if ($Parsed.PSObject.Properties["meta"] -and $Parsed.meta.PSObject.Properties["rc"]) {
        return ([string]$Parsed.meta.rc -ne "error")
    }

    if ($Parsed.PSObject.Properties["unique_id"] -or $Parsed.PSObject.Properties["name"]) {
        return $true
    }

    if ($Parsed.PSObject.Properties["data"] -and @($Parsed.data).Count -gt 0) {
        return $true
    }

    return $true

}

function Get-UniFiCsrfToken {

    param(
        $Connection,

        [Parameter(Mandatory)]
        [string]$Uri
    )

    if ($Connection.PSObject.Properties["CsrfToken"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.CsrfToken)) {
        return [string]$Connection.CsrfToken
    }

    if (-not $Connection.Session) {
        return $null
    }

    $RequestUri = [Uri]$Uri
    $Cookies = $Connection.Session.Cookies.GetCookies($RequestUri)

    foreach ($Cookie in $Cookies) {
        if ($Cookie.Name -match '(?i)csrf') {
            return [string]$Cookie.Value
        }
    }

    return $null

}

function Get-UniFiSessionRequestHeaders {

    param(
        $Connection,

        [Parameter(Mandatory)]
        [string]$Uri
    )

    $Headers = @{
        Accept = "application/json"
    }

    $CsrfToken = Get-UniFiCsrfToken -Connection $Connection -Uri $Uri
    if ($CsrfToken) {
        $Headers["X-CSRF-Token"] = $CsrfToken
    }

    return $Headers

}

function Invoke-UniFiControllerLogin {

    param(
        [Parameter(Mandatory)]
        $Profile,

        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$Password,

        [Parameter(Mandatory)]
        [ValidateSet("Legacy", "UniFiOS")]
        [string]$ControllerType,

        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter(Mandatory)]
        [string]$HostName
    )

    $Body = if ($ControllerType -eq "UniFiOS") {
        @{
            username = $Username
            password = $Password
        }
    }
    else {
        @{
            username = $Username
            password = $Password
            remember = $true
        }
    }

    $Json = $Body | ConvertTo-Json -Compress
    $Session = $null

    try {
        $Response = Invoke-WebRequest `
            -Method Post `
            -Uri $Profile.LoginUri `
            -Body $Json `
            -ContentType "application/json" `
            -SkipCertificateCheck `
            -UseBasicParsing `
            -SessionVariable Session
    }
    catch {
        $ApiMessage = Get-UniFiErrorRecordMessage -ErrorRecord $_
        $Hint = Get-UniFiLoginErrorHint -ControllerType $ControllerType -Port $Port -ApiMessage $ApiMessage
        throw ('{0}@{1}: {2}' -f $ControllerType, $Port, $Hint)
    }

    $Parsed = $null
    if (-not [string]::IsNullOrWhiteSpace($Response.Content)) {
        $Parsed = $Response.Content | ConvertFrom-Json
    }

    if (-not (Test-UniFiLoginResponseSuccess -Parsed $Parsed)) {
        $ApiMessage = if ($Parsed.PSObject.Properties["meta"] -and
            $Parsed.meta.PSObject.Properties["msg"]) {
            [string]$Parsed.meta.msg
        }
        else {
            "Login failed"
        }
        $Hint = Get-UniFiLoginErrorHint -ControllerType $ControllerType -Port $Port -ApiMessage $ApiMessage
        throw ('{0}@{1}: {2}' -f $ControllerType, $Port, $Hint)
    }

    if (-not $Session) {
        throw ('{0}@{1}: Login did not return a session.' -f $ControllerType, $Port)
    }

    $CsrfToken = $null
    if ($Response.Headers -and $Response.Headers["X-CSRF-Token"]) {
        $CsrfToken = [string]$Response.Headers["X-CSRF-Token"][0]
    }
    if (-not $CsrfToken) {
        $CsrfToken = Get-UniFiCsrfToken -Connection ([PSCustomObject]@{ Session = $Session }) -Uri $Profile.LoginUri
    }

    return [PSCustomObject]@{
        Session   = $Session
        CsrfToken = $CsrfToken
    }

}

function Invoke-UniFiApiRequest {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [ValidateSet("Get", "Post")]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri
    )

    $Params = @{
        Method               = $Method
        Uri                  = $Uri
        SkipCertificateCheck = $true
    }

    if ($Connection.PSObject.Properties["ApiKey"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.ApiKey)) {
        $Params.Headers = @{
            "X-API-KEY" = [string]$Connection.ApiKey
            "Accept"    = "application/json"
        }
        return Invoke-RestMethod @Params
    }

    $Params.WebSession = $Connection.Session
    $Headers = @{
        Accept = "application/json"
    }
    $CsrfToken = Get-UniFiCsrfToken -Connection $Connection -Uri $Uri
    if ($CsrfToken) {
        $Headers["X-CSRF-Token"] = $CsrfToken
    }
    $Params.Headers = $Headers

    return Invoke-RestMethod @Params

}

function ConvertFrom-UniFiApiResponse {

    param(
        $Response,

        [ValidateSet("Classic", "Integration")]
        [string]$ApiMode = "Classic"
    )

    if ($null -eq $Response) {
        return @()
    }

    if ($ApiMode -eq "Integration") {
        if ($Response.PSObject.Properties["code"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Response.code)) {
            $Message = if ($Response.PSObject.Properties["message"]) {
                [string]$Response.message
            }
            else {
                [string]$Response.code
            }
            throw $Message
        }

        if ($Response.PSObject.Properties["meta"] -and
            $Response.meta.PSObject.Properties["rc"] -and
            [string]$Response.meta.rc -eq "error") {
            $Message = if ($Response.meta.PSObject.Properties["msg"]) {
                [string]$Response.meta.msg
            }
            else {
                "UniFi Integration API error"
            }
            throw $Message
        }

        foreach ($PropertyName in @("data", "dataExpand", "items", "results")) {
            if ($Response.PSObject.Properties[$PropertyName]) {
                return @($Response.$PropertyName)
            }
        }

        if ($Response -is [System.Array]) {
            return @($Response)
        }

        if ($Response.PSObject.Properties["id"] -or $Response.PSObject.Properties["name"]) {
            return @($Response)
        }

        return @()
    }

    if ($Response.PSObject.Properties["meta"] -and
        $Response.meta.PSObject.Properties["rc"] -and
        [string]$Response.meta.rc -eq "error") {
        $Message = if ($Response.meta.PSObject.Properties["msg"]) {
            [string]$Response.meta.msg
        }
        else {
            "UniFi API error"
        }
        throw $Message
    }

    if ($Response.PSObject.Properties["data"]) {
        return @($Response.data)
    }

    if ($Response -is [System.Array]) {
        return @($Response)
    }

    if ($Response.PSObject.Properties["name"] -or $Response.PSObject.Properties["_id"]) {
        return @($Response)
    }

    return @()

}

function Get-UniFiSiteRecordName {

    param($SiteRecord)

    if ($SiteRecord.PSObject.Properties["meta"] -and
        $SiteRecord.meta.PSObject.Properties["name"] -and
        -not [string]::IsNullOrWhiteSpace([string]$SiteRecord.meta.name)) {
        return [string]$SiteRecord.meta.name
    }

    if ($SiteRecord.PSObject.Properties["meta"] -and
        $SiteRecord.meta.PSObject.Properties["desc"] -and
        -not [string]::IsNullOrWhiteSpace([string]$SiteRecord.meta.desc)) {
        return [string]$SiteRecord.meta.desc
    }

    foreach ($PropertyName in @("name", "internalReference", "slug", "desc", "description")) {
        if ($SiteRecord.PSObject.Properties[$PropertyName] -and
            -not [string]::IsNullOrWhiteSpace([string]$SiteRecord.$PropertyName)) {
            return [string]$SiteRecord.$PropertyName
        }
    }

    return $null

}

function Get-UniFiSiteRecordId {

    param($SiteRecord)

    foreach ($PropertyName in @("id", "_id", "site_id", "siteId")) {
        if ($SiteRecord.PSObject.Properties[$PropertyName] -and
            -not [string]::IsNullOrWhiteSpace([string]$SiteRecord.$PropertyName)) {
            return [string]$SiteRecord.$PropertyName
        }
    }

    if ($SiteRecord.PSObject.Properties["meta"] -and $SiteRecord.meta) {
        foreach ($PropertyName in @("id", "_id", "site_id", "siteId")) {
            if ($SiteRecord.meta.PSObject.Properties[$PropertyName] -and
                -not [string]::IsNullOrWhiteSpace([string]$SiteRecord.meta.$PropertyName)) {
                return [string]$SiteRecord.meta.$PropertyName
            }
        }
    }

    return $null

}

function Get-UniFiSiteApiSlugCandidates {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $Candidates = [System.Collections.Generic.List[string]]::new()

    if ($Connection.PSObject.Properties["SiteApiSlug"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.SiteApiSlug)) {
        [void]$Candidates.Add([string]$Connection.SiteApiSlug)
    }

    $TargetName = if ($Connection.PSObject.Properties["Site"] -and $Connection.Site) {
        [string]$Connection.Site
    }
    else {
        "default"
    }

    if (-not [string]::IsNullOrWhiteSpace($TargetName)) {
        [void]$Candidates.Add($TargetName)
    }

    $Sites = @()
    if ($Connection.PSObject.Properties["Sites"] -and @($Connection.Sites).Count -gt 0) {
        $Sites = @($Connection.Sites)
    }
    else {
        $Sites = @(Get-UniFiSites -Connection $Connection)
    }

    foreach ($SiteRecord in $Sites) {
        $RecordName = Get-UniFiSiteRecordName -SiteRecord $SiteRecord
        if ($RecordName -ne $TargetName -and $TargetName -ne "default") {
            continue
        }

        foreach ($PropertyName in @("_id", "name", "internalReference", "slug")) {
            if ($SiteRecord.PSObject.Properties[$PropertyName] -and
                -not [string]::IsNullOrWhiteSpace([string]$SiteRecord.$PropertyName)) {
                [void]$Candidates.Add([string]$SiteRecord.$PropertyName)
            }
        }
    }

    if ($Candidates.Count -eq 0) {
        [void]$Candidates.Add("default")
    }

    return @($Candidates | Select-Object -Unique)

}

function Test-UniFiPasswordInventoryAccess {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [ValidateSet("Legacy", "UniFiOS")]
        [string]$ControllerType,

        [Parameter(Mandatory)]
        [string]$SiteApiSlug
    )

    $TestConnection = [PSCustomObject]@{
        Host           = [string]$Connection.Host
        Port           = [int]$Connection.Port
        Site           = if ($Connection.PSObject.Properties["Site"]) { [string]$Connection.Site } else { "default" }
        SiteApiSlug    = $SiteApiSlug
        ControllerType = $ControllerType
        Session        = $Connection.Session
        CsrfToken      = if ($Connection.PSObject.Properties["CsrfToken"]) { [string]$Connection.CsrfToken } else { $null }
        AuthMethod     = if ($Connection.PSObject.Properties["AuthMethod"]) { [string]$Connection.AuthMethod } else { "Password" }
    }

    $InventoryPaths = @("stat/sta", "stat/device", "stat/sysinfo")

    foreach ($InventoryPath in $InventoryPaths) {
        try {
            $BaseUri = Get-UniFiApiBase -Connection $TestConnection
            $Response = Invoke-UniFiApiRequest `
                -Connection $TestConnection `
                -Method Get `
                -Uri "$BaseUri/$InventoryPath"

            $null = ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Classic
            return $true
        }
        catch {
            continue
        }
    }

    return $false
}

function Confirm-UniFiPasswordConnection {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $CurrentType = if ($Connection.PSObject.Properties["ControllerType"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.ControllerType)) {
        [string]$Connection.ControllerType
    }
    else {
        "Legacy"
    }

    $TypeOrder = @($CurrentType)
    $AlternateType = if ($CurrentType -eq "Legacy") { "UniFiOS" } else { "Legacy" }
    $TypeOrder += $AlternateType

    $SlugCandidates = @(Get-UniFiSiteApiSlugCandidates -Connection $Connection)

    foreach ($ControllerType in $TypeOrder) {
        foreach ($SiteApiSlug in $SlugCandidates) {
            if (Test-UniFiPasswordInventoryAccess `
                -Connection $Connection `
                -ControllerType $ControllerType `
                -SiteApiSlug $SiteApiSlug) {

                $Connection | Add-Member -NotePropertyName ControllerType -NotePropertyValue $ControllerType -Force
                $Connection | Add-Member -NotePropertyName SiteApiSlug -NotePropertyValue $SiteApiSlug -Force
                return $Connection
            }
        }
    }

    throw @"
Login succeeded, but inventory endpoints failed on port $($Connection.Port).
Tried Legacy and UniFi OS API paths with site slug(s): $($SlugCandidates -join ', ').

Cloud Key Gen1 / legacy controllers use port 8443 with Legacy login only (no /proxy/network paths).
Cloud Key Gen2+ / UniFi OS usually use port 443 or API key auth.
"@

}

function Resolve-UniFiSiteId {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    if ($Connection.PSObject.Properties["SiteId"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.SiteId)) {
        return [string]$Connection.SiteId
    }

    $Sites = @(Get-UniFiSites -Connection $Connection)
    $TargetName = if ($Connection.PSObject.Properties["Site"] -and $Connection.Site) {
        [string]$Connection.Site
    }
    else {
        "default"
    }

    foreach ($SiteRecord in $Sites) {
        $Name = Get-UniFiSiteRecordName -SiteRecord $SiteRecord
        $Id = Get-UniFiSiteRecordId -SiteRecord $SiteRecord
        if ($Name -eq $TargetName -and $Id) {
            return $Id
        }
    }

    if ($Sites.Count -eq 1) {
        $OnlyId = Get-UniFiSiteRecordId -SiteRecord $Sites[0]
        if ($OnlyId) {
            return $OnlyId
        }
    }

    throw "Could not resolve UniFi site id for '$TargetName'. Re-run Initialize-UniFi and pick the site from the list."

}

function Get-UniFiConnectionApiMode {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    if ($Connection.PSObject.Properties["ApiMode"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.ApiMode)) {
        return [string]$Connection.ApiMode
    }

    $UsesApiKey = $Connection.PSObject.Properties["ApiKey"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.ApiKey)

    $ControllerType = if ($Connection.PSObject.Properties["ControllerType"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.ControllerType)) {
        [string]$Connection.ControllerType
    }
    else {
        "Legacy"
    }

    if ($UsesApiKey -and $ControllerType -eq "UniFiOS") {
        return "Integration"
    }

    return "Classic"

}

function New-UniFiConnectionFromConfig {

    param(
        [Parameter(Mandatory)]
        $Config,

        [Parameter(Mandatory)]
        [string]$Site
    )

    $Port = if ($Config.PSObject.Properties["Port"] -and $Config.Port) { [int]$Config.Port } else { 443 }

    [PSCustomObject]@{
        Host           = [string]$Config.Host
        Port           = $Port
        Site           = $Site
        SiteId         = if ($Config.PSObject.Properties["SiteId"]) { [string]$Config.SiteId } else { $null }
        ControllerType = if ($Config.PSObject.Properties["ControllerType"]) { [string]$Config.ControllerType } else { "UniFiOS" }
        ApiMode        = if ($Config.PSObject.Properties["ApiMode"]) { [string]$Config.ApiMode } else { "Integration" }
        AuthMethod     = "ApiKey"
        ApiKey         = [string]$Config.ApiKey
        Session        = $null
        Connected      = Get-Date
    }

}

function Test-UniFiApiKeyConnection {

    param(
        [Parameter(Mandatory)]
        [string]$HostName,

        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter(Mandatory)]
        [string]$ApiKey,

        [Parameter(Mandatory)]
        [ValidateSet("Legacy", "UniFiOS")]
        [string]$ControllerType
    )

    $Profile = Get-UniFiControllerProfile `
        -ControllerType $ControllerType `
        -HostName $HostName `
        -Port $Port `
        -Site "default"

    $Headers = @{
        "X-API-KEY" = $ApiKey
        "Accept"    = "application/json"
    }

    if ($ControllerType -eq "UniFiOS" -and
        $Profile.PSObject.Properties["IntegrationSitesUri"]) {
        try {
            $Response = Invoke-RestMethod `
                -Method Get `
                -Uri $Profile.IntegrationSitesUri `
                -Headers $Headers `
                -SkipCertificateCheck

            $Sites = @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Integration)
            if ($Sites.Count -gt 0) {
                return [PSCustomObject]@{
                    ApiMode = "Integration"
                    Sites   = $Sites
                }
            }
        }
        catch {
            # Fall back to classic network API paths below.
        }
    }

    foreach ($SitesUri in @($Profile.StatSitesUri, $Profile.SitesUri)) {
        if ([string]::IsNullOrWhiteSpace($SitesUri)) {
            continue
        }

        try {
            $Response = Invoke-RestMethod `
                -Method Get `
                -Uri $SitesUri `
                -Headers $Headers `
                -SkipCertificateCheck

            $Sites = @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Classic)
            if ($Sites.Count -gt 0) {
                return [PSCustomObject]@{
                    ApiMode = "Classic"
                    Sites   = $Sites
                }
            }
        }
        catch {
            continue
        }
    }

    return $null

}

function Connect-UniFi {
    param(
        [Parameter(Mandatory)]
        [string]$ControllerHost,

        [Parameter()]
        [int]$Port = 8443,

        [Parameter()]
        [string]$Site = "default",

        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$Password,

        [Parameter()]
        [ValidateSet("Legacy", "UniFiOS")]
        [string]$ControllerType = "Legacy"
    )

    $Resolved = Resolve-UniFiControllerHostInput -ControllerHost $ControllerHost -Port $Port
    $NormalizedHost = $Resolved.HostName
    $NormalizedPort = $Resolved.Port
    $ResolvedSite = Resolve-UniFiSiteName -Site $Site -HostName $NormalizedHost
    $Profile = Get-UniFiControllerProfile `
        -ControllerType $ControllerType `
        -HostName $NormalizedHost `
        -Port $NormalizedPort `
        -Site $ResolvedSite

    $Session = Invoke-UniFiControllerLogin `
        -Profile $Profile `
        -Username $Username `
        -Password $Password `
        -ControllerType $ControllerType `
        -Port $NormalizedPort `
        -HostName $NormalizedHost

    [PSCustomObject]@{
        Host           = $NormalizedHost
        Port           = $NormalizedPort
        Site           = $ResolvedSite
        ControllerType = $ControllerType
        AuthMethod     = "Password"
        Session        = $Session.Session
        CsrfToken      = $Session.CsrfToken
        Username       = $Username
        Password       = $Password
        Connected      = Get-Date
    }
}


Export-ModuleMember -Function Connect-UniFi

function Connect-UniFiWithApiKey {

    param(
        [Parameter(Mandatory)]
        [string]$ControllerHost,

        [Parameter(Mandatory)]
        [string]$ApiKey,

        [int]$PreferredPort = 0,

        [string]$Site = "default"
    )

    $Resolved = Resolve-UniFiControllerHostInput `
        -ControllerHost $ControllerHost `
        -Port $(if ($PreferredPort -gt 0) { $PreferredPort } else { 443 })

    $HostName = $Resolved.HostName
    $Ports = @(
        if ($PreferredPort -gt 0) {
            @($PreferredPort, 443, 8443)
        }
        else {
            @(443, 8443)
        }
    ) | Select-Object -Unique

    $ResolvedSite = Resolve-UniFiSiteName -Site $Site -HostName $HostName
    $Attempts = @()

    foreach ($Port in $Ports) {
        foreach ($ControllerType in @("UniFiOS", "Legacy")) {
            try {
                $Validation = Test-UniFiApiKeyConnection `
                    -HostName $HostName `
                    -Port $Port `
                    -ApiKey $ApiKey `
                    -ControllerType $ControllerType

                if (-not $Validation) {
                    throw "No accessible sites returned."
                }

                $DefaultSiteId = $null
                foreach ($SiteRecord in @($Validation.Sites)) {
                    $Name = Get-UniFiSiteRecordName -SiteRecord $SiteRecord
                    $InternalRef = if ($SiteRecord.PSObject.Properties["internalReference"]) {
                        [string]$SiteRecord.internalReference
                    }
                    else {
                        $null
                    }

                    if ($Name -eq $ResolvedSite -or $InternalRef -eq $ResolvedSite) {
                        $DefaultSiteId = Get-UniFiSiteRecordId -SiteRecord $SiteRecord
                        break
                    }
                }

                if (-not $DefaultSiteId -and @($Validation.Sites).Count -eq 1) {
                    $DefaultSiteId = Get-UniFiSiteRecordId -SiteRecord $Validation.Sites[0]
                }

                Write-Host ("  API key accepted using {0} on port {1} ({2} API)." -f `
                    $ControllerType, $Port, $Validation.ApiMode) -ForegroundColor DarkGray

                return [PSCustomObject]@{
                    Host           = $HostName
                    Port           = $Port
                    Site           = $ResolvedSite
                    SiteId         = $DefaultSiteId
                    ControllerType = $ControllerType
                    ApiMode        = [string]$Validation.ApiMode
                    AuthMethod     = "ApiKey"
                    ApiKey         = $ApiKey
                    Sites          = @($Validation.Sites)
                    Session        = $null
                    Connected      = Get-Date
                }
            }
            catch {
                $Message = Get-UniFiErrorRecordMessage -ErrorRecord $_
                $Attempts += ('{0}@{1}: {2}' -f $ControllerType, $Port, $Message)
            }
        }
    }

    $Detail = ($Attempts | Select-Object -First 4) -join "`n  "
    throw @"
UniFi API key authentication failed.

Create an API key at https://unifi.ui.com/settings/api-keys
(or on the local UniFi OS console: Settings > Control Plane > Integrations > API Keys)
Then re-run Initialize-UniFi and choose API key authentication.

Attempts:
  $Detail
"@

}

function Invoke-UniFiSiteManagerRequest {

    param(
        [Parameter(Mandatory)]
        $Connection,

        [Parameter(Mandatory)]
        [ValidateSet("Get", "Post")]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri
    )

    Invoke-RestMethod `
        -Method $Method `
        -Uri $Uri `
        -Headers @{
            "X-API-KEY" = [string]$Connection.ApiKey
            Accept      = "application/json"
        }

}

function Connect-UniFiWithSiteManagerApiKey {

    param(
        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    $TrimmedKey = $ApiKey.Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($TrimmedKey)) {
        throw "API key is required."
    }

    if ($TrimmedKey -match '\*') {
        throw @"
The API key appears masked (contains *).
ui.com only shows the full key once at creation. Create a new key at https://unifi.ui.com/settings/api-keys
and paste the entire key immediately (no spaces before/after).
"@
    }

    if ($TrimmedKey.Length -lt 20) {
        throw "The API key looks too short ($($TrimmedKey.Length) characters). Paste the full key from ui.com — it is usually much longer."
    }

    try {
        $Response = Invoke-RestMethod `
            -Method Get `
            -Uri "https://api.ui.com/v1/sites" `
            -Headers @{
                "X-API-KEY" = $TrimmedKey
                Accept      = "application/json"
            }

        $Sites = @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Integration)
        if ($Sites.Count -eq 0) {
            throw "Site Manager returned no sites."
        }

        Write-Host "  Site Manager API key accepted (ui.com cloud)." -ForegroundColor DarkGray

        return [PSCustomObject]@{
            Host           = "api.ui.com"
            Port           = 443
            Site           = "default"
            ControllerType = "SiteManager"
            ApiMode        = "SiteManager"
            AuthMethod     = "ApiKey"
            ApiKey         = $TrimmedKey
            Sites          = $Sites
            Session        = $null
            Connected      = Get-Date
        }
    }
    catch {
        $StatusCode = $null
        if ($_.Exception.PSObject.Properties["Response"] -and $_.Exception.Response) {
            $StatusCode = [int]$_.Exception.Response.StatusCode
        }

        $ApiDetail = Get-UniFiErrorRecordMessage -ErrorRecord $_
        $Hint = switch ($StatusCode) {
            401 { "The API key was rejected (401 unauthorized). Create a fresh key at https://unifi.ui.com/settings/api-keys with Site Manager + Network scope." }
            400 { "The API key request was malformed (400). Paste the full key with no spaces, quotes, or masked asterisks. ui.com shows the key only once at creation." }
            default { $ApiDetail }
        }

        throw @"
Site Manager API key authentication failed.

Use a key from https://unifi.ui.com/settings/api-keys with Site Manager + Network scope.
Cloud Key Gen1 controllers do not expose local API keys — ui.com keys talk to api.ui.com, not 192.168.1.10:8443.

$Hint
"@
    }

}

function Connect-UniFiAuto {

    param(
        [Parameter(Mandatory)]
        [string]$ControllerHost,

        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$Password,

        [int]$PreferredPort = 0
    )

    $Ports = @(443, 8443)
    if ($PreferredPort -gt 0) {
        $Ports = @($PreferredPort) + $Ports | Select-Object -Unique
    }

    $Attempts = @()

    foreach ($Port in $Ports) {
        foreach ($ControllerType in @("Legacy", "UniFiOS")) {
            try {
                $Connection = Connect-UniFi `
                    -ControllerHost $ControllerHost `
                    -Port $Port `
                    -Site "default" `
                    -Username $Username `
                    -Password $Password `
                    -ControllerType $ControllerType

                Write-Host ("  Logged in using {0} on port {1}." -f $ControllerType, $Connection.Port) -ForegroundColor DarkGray
                return $Connection
            }
            catch {
                $Attempts += Get-UniFiErrorRecordMessage -ErrorRecord $_
            }
        }
    }

    $Detail = ($Attempts | Select-Object -First 6) -join "`n  "
    $CloudKeyHint = ""
    if (($Attempts | Where-Object { $_ -match '(?i)HTTP 500' }).Count -gt 0) {
        $CloudKeyHint = @"

Cloud Key note:
  Some Gen1 Cloud Keys return HTTP 500 on port 8443 /api/login even though the web UI works.
  Re-run setup and enter port 443 when asked, or confirm the local admin password under Settings > System > Admins.
"@
    }

    throw @"
UniFi controller login failed after trying Legacy and UniFi OS API paths on ports $($Ports -join ' and ').

UniFi does not use OAuth — use a local controller admin or a ui.com API key (option 1).

Common fixes:
  - Cloud Key Gen1: local admin on port 443 (8443 login API may return HTTP 500)
  - Cloud Key Gen2+ / UniFi OS: port 443 with API key or local Super Admin login
  - ui.com-only passwords cannot authenticate to the local API
$CloudKeyHint
Attempts:
  $Detail
"@
}

function Get-UniFiSites {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    if ($Connection.PSObject.Properties["Sites"] -and @($Connection.Sites).Count -gt 0) {
        return @($Connection.Sites)
    }

    $HostName = [string]$Connection.Host
    $Port = if ($Connection.PSObject.Properties["Port"] -and $Connection.Port) {
        [int]$Connection.Port
    }
    else {
        8443
    }

    $ControllerType = if ($Connection.PSObject.Properties["ControllerType"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.ControllerType)) {
        [string]$Connection.ControllerType
    }
    else {
        "Legacy"
    }

    $ApiMode = Get-UniFiConnectionApiMode -Connection $Connection

    if ($ApiMode -eq "SiteManager") {
        $Response = Invoke-UniFiSiteManagerRequest `
            -Connection $Connection `
            -Method Get `
            -Uri "https://api.ui.com/v1/sites"

        return @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Integration)
    }

    $Site = if ($Connection.PSObject.Properties["Site"] -and $Connection.Site) {
        [string]$Connection.Site
    }
    else {
        "default"
    }

    $Profile = Get-UniFiControllerProfile `
        -ControllerType $ControllerType `
        -HostName $HostName `
        -Port $Port `
        -Site $Site

    if ($ApiMode -eq "Integration" -and $Profile.PSObject.Properties["IntegrationSitesUri"]) {
        $Response = Invoke-UniFiApiRequest `
            -Connection $Connection `
            -Method Get `
            -Uri $Profile.IntegrationSitesUri

        return @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Integration)
    }

    foreach ($SitesUri in @($Profile.StatSitesUri, $Profile.SitesUri)) {
        if ([string]::IsNullOrWhiteSpace($SitesUri)) {
            continue
        }

        try {
            $Response = Invoke-UniFiApiRequest `
                -Connection $Connection `
                -Method Get `
                -Uri $SitesUri

            $Sites = @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Classic)
            if ($Sites.Count -gt 0) {
                return $Sites
            }
        }
        catch {
            continue
        }
    }

    return @()

}

function Test-UniFiControllerAccess {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $WorkingConnection = $Connection

    $UsesApiKey = $Connection.PSObject.Properties["ApiKey"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.ApiKey)

    if (-not $UsesApiKey -and -not ($Connection.PSObject.Properties["ApiMode"] -and
        [string]$Connection.ApiMode -eq "SiteManager")) {
        $WorkingConnection = Confirm-UniFiPasswordConnection -Connection $Connection
        $Connection | Add-Member -NotePropertyName ControllerType -NotePropertyValue $WorkingConnection.ControllerType -Force
        if ($WorkingConnection.PSObject.Properties["SiteApiSlug"]) {
            $Connection | Add-Member -NotePropertyName SiteApiSlug -NotePropertyValue $WorkingConnection.SiteApiSlug -Force
        }
    }

    try {
        $null = Get-UniFiClients -Connection $Connection
        return $true
    }
    catch {
        $Message = Get-UniFiErrorRecordMessage -ErrorRecord $_

        $Site = if ($Connection.PSObject.Properties["Site"]) { $Connection.Site } else { "default" }
        throw "UniFi site '$Site' is not accessible after login. Choose the site slug from your controller URL (for example /manage/default/dashboard means site 'default'). $Message"
    }

}

function Connect-HALSConfiguredUniFi {

    $Config = $null
    $ConfigPath = Join-Path (Get-HALSRoot) "Secrets\UniFi.json"

    if (Test-Path $ConfigPath) {
        $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    }
    elseif ($env:HALS_UNIFI_HOST -and $env:HALS_UNIFI_API_KEY) {
        $Config = [PSCustomObject]@{
            Host       = $env:HALS_UNIFI_HOST
            Port       = if ($env:HALS_UNIFI_PORT) { [int]$env:HALS_UNIFI_PORT } else { 443 }
            Site       = if ($env:HALS_UNIFI_SITE) { $env:HALS_UNIFI_SITE } else { "default" }
            AuthMethod = "ApiKey"
            ApiKey     = $env:HALS_UNIFI_API_KEY
        }
    }
    elseif ($env:HALS_UNIFI_HOST -and $env:HALS_UNIFI_USERNAME -and $env:HALS_UNIFI_PASSWORD) {
        $Config = [PSCustomObject]@{
            Host       = $env:HALS_UNIFI_HOST
            Port       = if ($env:HALS_UNIFI_PORT) { [int]$env:HALS_UNIFI_PORT } else { 8443 }
            Site       = if ($env:HALS_UNIFI_SITE) { $env:HALS_UNIFI_SITE } else { "default" }
            AuthMethod = "Password"
            Username   = $env:HALS_UNIFI_USERNAME
            Password   = $env:HALS_UNIFI_PASSWORD
        }
    }
    else {
        return $null
    }

    $ConfiguredSite = if ($Config.PSObject.Properties["Site"] -and $Config.Site) {
        [string]$Config.Site
    }
    else {
        "default"
    }

    $Site = Resolve-UniFiSiteName -Site $ConfiguredSite -HostName [string]$Config.Host

    $Port = if ($Config.PSObject.Properties["Port"] -and $Config.Port) { [int]$Config.Port } else { 443 }

    $UsesApiKey = ($Config.PSObject.Properties["AuthMethod"] -and
        [string]$Config.AuthMethod -eq "ApiKey") -or
        ($Config.PSObject.Properties["ApiKey"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Config.ApiKey))

    if ($UsesApiKey) {
        $SavedApiMode = if ($Config.PSObject.Properties["ApiMode"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Config.ApiMode)) {
            [string]$Config.ApiMode
        }
        else {
            "SiteManager"
        }

        if ($SavedApiMode -eq "SiteManager") {
            $Connection = [PSCustomObject]@{
                Host           = "api.ui.com"
                Port           = 443
                Site           = $Site
                SiteId         = if ($Config.PSObject.Properties["SiteId"]) { [string]$Config.SiteId } else { $null }
                ControllerType = "SiteManager"
                ApiMode        = "SiteManager"
                AuthMethod     = "ApiKey"
                ApiKey         = [string]$Config.ApiKey
                Session        = $null
            }

            try {
                $null = Get-UniFiClients -Connection $Connection
                return $Connection
            }
            catch {
                $Connection = Connect-UniFiWithSiteManagerApiKey -ApiKey [string]$Config.ApiKey
                Set-UniFiConnectionProperty -Connection $Connection -Name Site -Value $Site
                if ($Config.PSObject.Properties["SiteId"] -and $Config.SiteId) {
                    $Connection | Add-Member -NotePropertyName SiteId -NotePropertyValue ([string]$Config.SiteId) -Force
                }
                return $Connection
            }
        }

        $HasSavedSession = $Config.PSObject.Properties["ApiMode"] -and
            $Config.PSObject.Properties["SiteId"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Config.ApiMode) -and
            -not [string]::IsNullOrWhiteSpace([string]$Config.SiteId)

        if ($HasSavedSession) {
            $SavedConnection = New-UniFiConnectionFromConfig -Config $Config -Site $Site
            try {
                $null = Get-UniFiClients -Connection $SavedConnection
                return $SavedConnection
            }
            catch {
                # Saved Integration/Classic mode may be stale; rediscover below.
            }
        }

        $Connection = Connect-UniFiWithApiKey `
            -ControllerHost [string]$Config.Host `
            -ApiKey [string]$Config.ApiKey `
            -PreferredPort $Port `
            -Site $Site

        Set-UniFiConnectionProperty -Connection $Connection -Name Site -Value $Site

        if ($Config.PSObject.Properties["ApiMode"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Config.ApiMode)) {
            $Connection | Add-Member -NotePropertyName ApiMode -NotePropertyValue ([string]$Config.ApiMode) -Force
        }

        if ($Config.PSObject.Properties["SiteId"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Config.SiteId)) {
            $Connection | Add-Member -NotePropertyName SiteId -NotePropertyValue ([string]$Config.SiteId) -Force
        }

        return $Connection
    }

    $Parameters = @{
        ControllerHost = [string]$Config.Host
        Username       = [string]$Config.Username
        Password       = [string]$Config.Password
        Port           = $Port
        Site           = $Site
    }

    if ($Config.PSObject.Properties["ControllerType"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Config.ControllerType)) {
        $Parameters.ControllerType = [string]$Config.ControllerType
    }

    try {
        $Connection = Connect-UniFi @Parameters
        if ($Config.PSObject.Properties["SiteApiSlug"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Config.SiteApiSlug)) {
            $Connection | Add-Member -NotePropertyName SiteApiSlug -NotePropertyValue ([string]$Config.SiteApiSlug) -Force
        }
        return (Confirm-UniFiPasswordConnection -Connection $Connection)
    }
    catch {
        $Connection = Connect-UniFiAuto `
            -ControllerHost $Parameters.ControllerHost `
            -Username $Parameters.Username `
            -Password $Parameters.Password `
            -PreferredPort $Parameters.Port

        Set-UniFiConnectionProperty -Connection $Connection -Name Site -Value $Parameters.Site

        if ($Config.PSObject.Properties["SiteApiSlug"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Config.SiteApiSlug)) {
            $Connection | Add-Member -NotePropertyName SiteApiSlug -NotePropertyValue ([string]$Config.SiteApiSlug) -Force
        }

        if (Test-Path -LiteralPath $ConfigPath) {
            $Saved = @{
                Host           = $Connection.Host
                Port           = $Connection.Port
                Site           = $Parameters.Site
                ControllerType = $Connection.ControllerType
                AuthMethod     = "Password"
                ApiMode        = "Classic"
                Username       = $Parameters.Username
                Password       = $Parameters.Password
            }
            if ($Connection.PSObject.Properties["SiteApiSlug"]) {
                $Saved.SiteApiSlug = [string]$Connection.SiteApiSlug
            }
            $Saved | ConvertTo-Json | Set-Content -LiteralPath $ConfigPath
        }

        return $Connection
    }
}

Export-ModuleMember -Function Connect-HALSConfiguredUniFi

function Get-UniFiApiBase {

    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $HostName = [string]$Connection.Host
    $Port = if ($Connection.PSObject.Properties["Port"] -and $Connection.Port) {
        [int]$Connection.Port
    }
    else {
        8443
    }

    $ControllerType = if ($Connection.PSObject.Properties["ControllerType"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.ControllerType)) {
        [string]$Connection.ControllerType
    }
    else {
        "Legacy"
    }

    $Site = if ($Connection.PSObject.Properties["Site"] -and $Connection.Site) {
        Resolve-UniFiSiteName -Site [string]$Connection.Site -HostName [string]$Connection.Host
    }
    else {
        "default"
    }

    $SiteSlug = if ($Connection.PSObject.Properties["SiteApiSlug"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Connection.SiteApiSlug)) {
        [string]$Connection.SiteApiSlug
    }
    else {
        $Site
    }

    $Profile = Get-UniFiControllerProfile `
        -ControllerType $ControllerType `
        -HostName $HostName `
        -Port $Port `
        -Site $SiteSlug

    return $Profile.ApiBase
}

function Get-UniFiInfrastructure {
    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $ApiMode = Get-UniFiConnectionApiMode -Connection $Connection

    if ($ApiMode -eq "SiteManager") {
        $SiteId = Resolve-UniFiSiteId -Connection $Connection
        $Response = Invoke-UniFiSiteManagerRequest `
            -Connection $Connection `
            -Method Get `
            -Uri "https://api.ui.com/v1/sites/$SiteId/devices"

        return @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Integration)
    }

    if ($ApiMode -eq "Integration") {
        $HostName = [string]$Connection.Host
        $Port = if ($Connection.PSObject.Properties["Port"] -and $Connection.Port) {
            [int]$Connection.Port
        }
        else {
            443
        }

        $SiteId = Resolve-UniFiSiteId -Connection $Connection
        $Uri = "https://${HostName}:${Port}/proxy/network/integration/v1/sites/$SiteId/devices"
        $Response = Invoke-UniFiApiRequest -Connection $Connection -Method Get -Uri $Uri
        return @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Integration)
    }

    $BaseUri = Get-UniFiApiBase -Connection $Connection
    try {
        $Response = Invoke-UniFiApiRequest `
            -Connection $Connection `
            -Method Get `
            -Uri "$BaseUri/stat/device"

        return @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Classic)
    }
    catch {
        if ($Connection.PSObject.Properties["ApiKey"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Connection.ApiKey) -and
            [string]$Connection.ControllerType -eq "UniFiOS") {
            $Connection | Add-Member -NotePropertyName ApiMode -NotePropertyValue Integration -Force
            return @(Get-UniFiInfrastructure -Connection $Connection)
        }

        throw
    }
}

Export-ModuleMember -Function Get-UniFiApiBase, Get-UniFiInfrastructure
function Get-UniFiClients {
    param(
        [Parameter(Mandatory)]
        $Connection
    )

    $ApiMode = Get-UniFiConnectionApiMode -Connection $Connection

    if ($ApiMode -eq "SiteManager") {
        $SiteId = Resolve-UniFiSiteId -Connection $Connection
        $Response = Invoke-UniFiSiteManagerRequest `
            -Connection $Connection `
            -Method Get `
            -Uri "https://api.ui.com/v1/sites/$SiteId/clients"

        return @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Integration)
    }

    if ($ApiMode -eq "Integration") {
        $HostName = [string]$Connection.Host
        $Port = if ($Connection.PSObject.Properties["Port"] -and $Connection.Port) {
            [int]$Connection.Port
        }
        else {
            443
        }

        $SiteId = Resolve-UniFiSiteId -Connection $Connection
        $Uri = "https://${HostName}:${Port}/proxy/network/integration/v1/sites/$SiteId/clients"
        $Response = Invoke-UniFiApiRequest -Connection $Connection -Method Get -Uri $Uri
        return @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Integration)
    }

    $BaseUri = Get-UniFiApiBase -Connection $Connection
    try {
        $Response = Invoke-UniFiApiRequest `
            -Connection $Connection `
            -Method Get `
            -Uri "$BaseUri/stat/sta"

        return @(ConvertFrom-UniFiApiResponse -Response $Response -ApiMode Classic)
    }
    catch {
        if (-not ($Connection.PSObject.Properties["ApiKey"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Connection.ApiKey))) {
            try {
                $Confirmed = Confirm-UniFiPasswordConnection -Connection $Connection
                $Connection | Add-Member -NotePropertyName ControllerType -NotePropertyValue $Confirmed.ControllerType -Force
                if ($Confirmed.PSObject.Properties["SiteApiSlug"]) {
                    $Connection | Add-Member -NotePropertyName SiteApiSlug -NotePropertyValue $Confirmed.SiteApiSlug -Force
                }
                return @(Get-UniFiClients -Connection $Connection)
            }
            catch {
                # Fall through to Integration retry or rethrow below.
            }
        }

        if ($Connection.PSObject.Properties["ApiKey"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Connection.ApiKey) -and
            [string]$Connection.ControllerType -eq "UniFiOS") {
            $Connection | Add-Member -NotePropertyName ApiMode -NotePropertyValue Integration -Force
            return @(Get-UniFiClients -Connection $Connection)
        }

        throw
    }
}

Export-ModuleMember -Function Get-UniFiClients
function ConvertFrom-UniFiClient {
    param(
        [Parameter(Mandatory)]
        $Client
    )

    $Name = if ($Client.PSObject.Properties["name"] -and $Client.name) {
        [string]$Client.name
    }
    elseif ($Client.PSObject.Properties["displayName"] -and $Client.displayName) {
        [string]$Client.displayName
    }
    elseif ($Client.PSObject.Properties["hostname"] -and $Client.hostname) {
        [string]$Client.hostname
    }
    else {
        "UniFi Client"
    }

    $Category = "Network Client"
    $IsWired = $null
    if ($Client.PSObject.Properties["is_wired"]) {
        $IsWired = [bool]$Client.is_wired
    }
    elseif ($Client.PSObject.Properties["isWired"]) {
        $IsWired = [bool]$Client.isWired
    }
    elseif ($Client.PSObject.Properties["type"] -and [string]$Client.type -match 'wired') {
        $IsWired = $true
    }

    if ($null -ne $IsWired -and -not $IsWired) {
        $Category = "Wireless Client"
    }

    $IP = if ($Client.PSObject.Properties["ip"] -and $Client.ip) {
        [string]$Client.ip
    }
    elseif ($Client.PSObject.Properties["ipAddress"]) {
        [string]$Client.ipAddress
    }
    else {
        $null
    }

    $MAC = if ($Client.PSObject.Properties["mac"] -and $Client.mac) {
        [string]$Client.mac
    }
    elseif ($Client.PSObject.Properties["macAddress"]) {
        [string]$Client.macAddress
    }
    else {
        $null
    }

    $Hostname = if ($Client.PSObject.Properties["hostname"] -and $Client.hostname) {
        [string]$Client.hostname
    }
    else {
        $Name
    }

    $Manufacturer = if ($Client.PSObject.Properties["oui"] -and $Client.oui) {
        [string]$Client.oui
    }
    elseif ($Client.PSObject.Properties["manufacturer"]) {
        [string]$Client.manufacturer
    }
    else {
        $null
    }

    [PSCustomObject]@{
        Name         = $Name
        Hostname     = $Hostname
        IP           = $IP
        MAC          = $MAC
        Manufacturer = $Manufacturer
        Category     = $Category
        Source       = "UniFi"
    }
}

function ConvertFrom-UniFiInfrastructureDevice {

    param(
        [Parameter(Mandatory)]
        $Device
    )

    $DeviceType = if ($Device.PSObject.Properties["type"] -and $Device.type) {
        [string]$Device.type
    }
    elseif ($Device.PSObject.Properties["deviceType"]) {
        [string]$Device.deviceType
    }
    else {
        ""
    }

    $Category = switch ($DeviceType.ToLowerInvariant()) {
        "ugw" { "Firewall" }
        "uap" { "Network Access Point" }
        "usw" { "Network Switch" }
        "uwg" { "Firewall" }
        "udm" { "Firewall" }
        default {
            if ($DeviceType -match 'switch') { "Network Switch" }
            elseif ($DeviceType -match 'ap|access') { "Network Access Point" }
            elseif ($DeviceType -match 'gateway|router|firewall|udm|ugw') { "Firewall" }
            else { "Network Infrastructure" }
        }
    }

    $Name = if ($Device.PSObject.Properties["name"] -and $Device.name) {
        [string]$Device.name
    }
    elseif ($Device.PSObject.Properties["displayName"] -and $Device.displayName) {
        [string]$Device.displayName
    }
    else {
        $Category
    }

    $IP = if ($Device.PSObject.Properties["ip"] -and $Device.ip) {
        [string]$Device.ip
    }
    elseif ($Device.PSObject.Properties["ipAddress"]) {
        [string]$Device.ipAddress
    }
    else {
        $null
    }

    $MAC = if ($Device.PSObject.Properties["mac"] -and $Device.mac) {
        [string]$Device.mac
    }
    elseif ($Device.PSObject.Properties["macAddress"]) {
        [string]$Device.macAddress
    }
    else {
        $null
    }

    [PSCustomObject]@{
        Name         = $Name
        Hostname     = $Name
        IP           = $IP
        MAC          = $MAC
        Manufacturer = "Ubiquiti"
        Category     = $Category
        Source       = "UniFi"
    }
}

Export-ModuleMember -Function ConvertFrom-UniFiClient, ConvertFrom-UniFiInfrastructureDevice

function Test-HALSUniFiConfigured {
    $ConfigPath = Join-Path (Get-HALSRoot) "Secrets\UniFi.json"
    if (Test-Path $ConfigPath) {
        return $true
    }

    if ($env:HALS_UNIFI_HOST -and $env:HALS_UNIFI_API_KEY) {
        return $true
    }

    ($env:HALS_UNIFI_HOST -and $env:HALS_UNIFI_USERNAME -and $env:HALS_UNIFI_PASSWORD)
}

function Initialize-UniFi {

    $Root = Get-HALSRoot
    $Folder = Join-Path $Root "Secrets"
    $Path = Join-Path $Folder "UniFi.json"

    Write-Host ""
    Write-Host "HALS UniFi setup" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "UniFi does not use OAuth." -ForegroundColor DarkGray
    Write-Host "HALS auto-detects legacy Cloud Key Gen1 (8443) and UniFi OS (443) controllers." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Authentication:" -ForegroundColor DarkGray
    Write-Host "  [1] ui.com cloud API key (unifi.ui.com/settings/api-keys)" -ForegroundColor DarkGray
    Write-Host "  [2] Local Cloud Key login (Gen1: try port 443 if 8443 fails)" -ForegroundColor DarkGray
    Write-Host ""

    $AuthChoice = (Read-Host "Authentication method [2]").Trim()
    if ([string]::IsNullOrWhiteSpace($AuthChoice)) {
        $AuthChoice = "2"
    }

    $UseApiKey = ($AuthChoice -eq "1")

    $HostName = "api.ui.com"
    $PreferredPort = 443

    if (-not $UseApiKey) {
        Write-Host "Enter the controller hostname or IP only (not the full dashboard URL)." -ForegroundColor DarkGray
        Write-Host "Example host: unifi-cloudkey or 192.168.1.10" -ForegroundColor DarkGray
        Write-Host ""

        do {
            $HostName = (Read-Host "Controller host").Trim().Trim('"').Trim("'")
            if (-not (Test-HALSNetworkHostInput -HostName $HostName)) {
                Write-Host "Enter a hostname or IP only (for example unifi-cloudkey)." -ForegroundColor Yellow
                Write-Host "Do not paste a file path, JSON file, or full URL." -ForegroundColor Gray
            }
        } while (-not (Test-HALSNetworkHostInput -HostName $HostName))

        Write-Host ""
        Write-Host "Gen1 Cloud Keys: the dashboard uses 8443, but API login often works on 443." -ForegroundColor DarkGray
        $PortText = (Read-Host "Controller port [443]").Trim()
        $PreferredPort = 443
        if (-not [string]::IsNullOrWhiteSpace($PortText)) {
            if ($PortText -match '^\d+$') {
                $PreferredPort = [int]$PortText
            }
            else {
                Write-Host "Invalid port. Using 443." -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "Cloud API keys use api.ui.com — no controller host or port is required." -ForegroundColor DarkGray
        Write-Host ""
    }

    $Username = $null
    $Password = $null
    $ApiKey = $null

    if ($UseApiKey) {
        Write-Host "Keys from https://unifi.ui.com/settings/api-keys use the cloud API, not 192.168.1.10." -ForegroundColor DarkGray
        $ApiKey = Read-HALSSecretInput `
            -Prompt "API key" `
            -Hint "Copy the full ui.com API key from the browser (shown only once at creation)." `
            -MinimumLength 20
    }
    else {
        $Username = (Read-Host "Username").Trim()
        $Password = Read-HALSSecretInput `
            -Prompt "Password" `
            -Hint "Enter the local Cloud Key admin password from Settings > System > Admins."
        if ([string]::IsNullOrWhiteSpace($Username)) {
            throw "Username is required."
        }
    }

    try {
        if ($UseApiKey) {
            $Login = Connect-UniFiWithSiteManagerApiKey -ApiKey $ApiKey
        }
        else {
            $Login = Connect-UniFiAuto `
                -ControllerHost $HostName `
                -Username $Username `
                -Password $Password `
                -PreferredPort $PreferredPort
        }
    }
    catch {
        Write-Host ""
        Write-Host "UniFi login failed. Configuration was not saved." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor DarkGray
        Write-Host ""
        throw
    }

    $Sites = @(Get-UniFiSites -Connection $Login)
    $Site = "default"
    $SiteId = if ($Login.PSObject.Properties["SiteId"]) { [string]$Login.SiteId } else { $null }
    $SiteApiSlug = $null

    if ($Sites.Count -gt 0) {

        Write-Host ""
        Write-Host "Available UniFi sites:" -ForegroundColor Yellow

        for ($Index = 0; $Index -lt $Sites.Count; $Index++) {
            $Entry = $Sites[$Index]
            $Slug = Get-UniFiSiteRecordName -SiteRecord $Entry
            if ([string]::IsNullOrWhiteSpace($Slug)) {
                $Slug = Get-UniFiSiteRecordId -SiteRecord $Entry
            }
            if ([string]::IsNullOrWhiteSpace($Slug)) {
                $Slug = [string]($Index + 1)
            }
            $Desc = if ($Entry.PSObject.Properties["desc"] -and $Entry.desc) {
                " ($($Entry.desc))"
            }
            elseif ($Entry.PSObject.Properties["description"] -and $Entry.description) {
                " ($($Entry.description))"
            }
            else {
                ""
            }
            Write-Host ("  [{0}] {1}{2}" -f ($Index + 1), $Slug, $Desc) -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "Site is the slug from your controller URL." -ForegroundColor DarkGray
        Write-Host "Example: https://unifi-cloudkey:8443/manage/default/dashboard -> site 'default'" -ForegroundColor DarkGray
        Write-Host "Press Enter or type 1 to select the site (do not paste a URL or IP)." -ForegroundColor DarkGray
        Write-Host ""

        $DefaultIndex = 1
        for ($Index = 0; $Index -lt $Sites.Count; $Index++) {
            $CandidateName = Get-UniFiSiteRecordName -SiteRecord $Sites[$Index]
            if ($CandidateName -eq "default") {
                $DefaultIndex = $Index + 1
                break
            }
        }

        $SiteChoice = (Read-Host "Choose site [1-$($Sites.Count)] (default $DefaultIndex)").Trim()
        if ([string]::IsNullOrWhiteSpace($SiteChoice)) {
            $SiteChoice = [string]$DefaultIndex
        }

        $SelectedSite = $null
        if ($SiteChoice -match '^\d+$') {
            $Idx = [int]$SiteChoice
            if ($Idx -ge 1 -and $Idx -le $Sites.Count) {
                $SelectedSite = $Sites[$Idx - 1]
            }
        }
        else {
            foreach ($Entry in $Sites) {
                $CandidateName = Get-UniFiSiteRecordName -SiteRecord $Entry
                if ($CandidateName -eq $SiteChoice -or
                    ($CandidateName -and $CandidateName.Equals($SiteChoice, [System.StringComparison]::OrdinalIgnoreCase))) {
                    $SelectedSite = $Entry
                    break
                }
            }
        }

        if ($SelectedSite) {
            $ResolvedName = Get-UniFiSiteRecordName -SiteRecord $SelectedSite
            $Site = Resolve-UniFiSiteName `
                -Site $(if ([string]::IsNullOrWhiteSpace($ResolvedName)) { "default" } else { $ResolvedName }) `
                -HostName $Login.Host
            $SiteId = Get-UniFiSiteRecordId -SiteRecord $SelectedSite
            $SiteApiSlug = if ($SiteId) { $SiteId } else { $Site }
        }
        else {
            Write-Host "Enter the list number only (for example 1). Using option $DefaultIndex." -ForegroundColor Yellow
            $SelectedSite = $Sites[$DefaultIndex - 1]
            $ResolvedName = Get-UniFiSiteRecordName -SiteRecord $SelectedSite
            $Site = Resolve-UniFiSiteName `
                -Site $(if ([string]::IsNullOrWhiteSpace($ResolvedName)) { "default" } else { $ResolvedName }) `
                -HostName $Login.Host
            $SiteId = Get-UniFiSiteRecordId -SiteRecord $SelectedSite
            $SiteApiSlug = if ($SiteId) { $SiteId } else { $Site }
        }

    }
    else {

        Write-Host ""
        Write-Host "Could not list sites automatically." -ForegroundColor DarkYellow
        if ($Login.PSObject.Properties["ApiMode"] -and [string]$Login.ApiMode -eq "SiteManager") {
            Write-Host "Using the site discovered from Site Manager." -ForegroundColor DarkGray
            if (@($Login.Sites).Count -eq 1) {
                $SiteId = Get-UniFiSiteRecordId -SiteRecord $Login.Sites[0]
                $Site = Get-UniFiSiteRecordName -SiteRecord $Login.Sites[0]
                if ([string]::IsNullOrWhiteSpace($Site)) { $Site = "default" }
            }
        }
        elseif ($Login.PSObject.Properties["ApiMode"] -and [string]$Login.ApiMode -eq "Integration") {
            Write-Host "Using the site id discovered during API key validation." -ForegroundColor DarkGray
        }
        else {
            Write-Host "Enter the site slug from your controller URL (usually 'default')." -ForegroundColor DarkGray
            Write-Host ""

            $SiteInput = (Read-Host "Site [default]").Trim()
            $Site = Resolve-UniFiSiteName `
                -Site $(if ([string]::IsNullOrWhiteSpace($SiteInput)) { "default" } else { $SiteInput }) `
                -HostName $Login.Host
        }

    }

    Set-UniFiConnectionProperty -Connection $Login -Name Site -Value $Site
    Set-UniFiConnectionProperty -Connection $Login -Name Sites -Value $Sites
    if ($SiteId) {
        Set-UniFiConnectionProperty -Connection $Login -Name SiteId -Value $SiteId
    }
    elseif ($Login.PSObject.Properties["ApiMode"] -and [string]$Login.ApiMode -eq "SiteManager") {
        Set-UniFiConnectionProperty -Connection $Login -Name SiteId -Value (Resolve-UniFiSiteId -Connection $Login)
    }
    elseif ($Login.PSObject.Properties["ApiMode"] -and [string]$Login.ApiMode -eq "Integration") {
        Set-UniFiConnectionProperty -Connection $Login -Name SiteId -Value (Resolve-UniFiSiteId -Connection $Login)
    }
    if ($SiteApiSlug) {
        Set-UniFiConnectionProperty -Connection $Login -Name SiteApiSlug -Value $SiteApiSlug
    }

    try {
        $null = Test-UniFiControllerAccess -Connection $Login
    }
    catch {
        Write-Host ""
        Write-Host "UniFi login succeeded, but inventory access failed." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor DarkGray
        Write-Host ""
        throw
    }

    if (-not (Test-Path $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }

    if ($UseApiKey) {
        $Config = @{
            Host           = $Login.Host
            Port           = $Login.Port
            Site           = $Site
            ControllerType = $Login.ControllerType
            AuthMethod     = "ApiKey"
            ApiMode        = $Login.ApiMode
            ApiKey         = $ApiKey
        }
        if ($SiteId) {
            $Config.SiteId = $SiteId
        }
        $Config | ConvertTo-Json | Set-Content -Path $Path
    }
    else {
        $PasswordConfig = @{
            Host           = $Login.Host
            Port           = $Login.Port
            Site           = $Site
            ControllerType = $Login.ControllerType
            AuthMethod     = "Password"
            ApiMode        = "Classic"
            Username       = $Username
            Password       = $Password
        }
        if ($Login.PSObject.Properties["SiteApiSlug"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Login.SiteApiSlug)) {
            $PasswordConfig.SiteApiSlug = [string]$Login.SiteApiSlug
        }
        if ($Login.PSObject.Properties["CsrfToken"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Login.CsrfToken)) {
            $PasswordConfig.CsrfToken = [string]$Login.CsrfToken
        }
        if ($SiteId) {
            $PasswordConfig.SiteId = $SiteId
        }
        $PasswordConfig | ConvertTo-Json | Set-Content -Path $Path
    }

    Write-Host ""
    Write-Host "UniFi connected and configuration saved." -ForegroundColor Green
    Write-Host "  Site: $Site" -ForegroundColor DarkGray
    Write-Host ("  Mode: {0} on port {1}" -f $Login.ControllerType, $Login.Port) -ForegroundColor DarkGray
    if ($Login.PSObject.Properties["ApiMode"]) {
        Write-Host ("  API: {0}" -f $Login.ApiMode) -ForegroundColor DarkGray
    }
    if ($UseApiKey) {
        Write-Host "  Auth: API key" -ForegroundColor DarkGray
    }
    Write-Host ""

    $Login
}

function Invoke-HALSUniFiInventory {

    param([Parameter(Mandatory)]$Knowledge)

    $Connection = Connect-HALSConfiguredUniFi
    if (-not $Connection) { return [PSCustomObject]@{ Devices = @() } }

    $Infrastructure = @(Get-UniFiInfrastructure -Connection $Connection)
    $Clients = @(Get-UniFiClients -Connection $Connection)
    $Devices = @()

    $Devices += @($Clients | ForEach-Object {
        ConvertTo-HALSDevice -Device (ConvertFrom-UniFiClient -Client $_) -Source UniFi -Knowledge $Knowledge
    })

    $Devices += @($Infrastructure | ForEach-Object {
        ConvertTo-HALSDevice -Device (ConvertFrom-UniFiInfrastructureDevice -Device $_) -Source UniFi -Knowledge $Knowledge
    })

    [PSCustomObject]@{
        Devices        = $Devices
        Infrastructure = $Infrastructure
        Clients        = $Clients
        Connection     = $Connection
        Data           = $Clients
    }
}

function Get-HALSUniFiPermissions {

    param([Parameter(Mandatory)]$Inventory)

    @(
        New-HALSPermission -Provider UniFi -Name "Read Clients" -Granted $true
        New-HALSPermission -Provider UniFi -Name "Read Infrastructure" -Granted $true
        New-HALSPermission -Provider UniFi -Name "Reconnect Clients" -Granted $false
        New-HALSPermission -Provider UniFi -Name "Restart Devices" -Granted $false
        New-HALSPermission -Provider UniFi -Name "Firmware Management" -Granted $false
    )
}

Export-ModuleMember -Function `
    Test-HALSUniFiConfigured,
    Initialize-UniFi,
    Invoke-HALSUniFiInventory,
    Get-HALSUniFiPermissions,
    Resolve-UniFiSiteName

if (Get-Command Register-HALSDeviceProvider -ErrorAction SilentlyContinue) {
    Register-HALSDeviceProvider `
        -Key "UniFi" `
        -Name "UniFi" `
        -TestConfiguredCommand "Test-HALSUniFiConfigured" `
        -InventoryCommand "Invoke-HALSUniFiInventory" `
        -PermissionCatalogCommand "Get-HALSUniFiPermissions" `
        -SetupCommands @(
            @{ Name = "Initialize-UniFi"; Description = "Set up a UniFi controller" }
        ) `
        -Order 10
}
