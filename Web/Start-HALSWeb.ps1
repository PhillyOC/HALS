#==========================================================
# HALS Web Server
# Version : 1.0.0
#
# Serves the portable web frontend and REST API.
# Default: http://localhost:8080
#==========================================================

param(
    [int]$Port = 8080,
    [string]$Bind = "localhost"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host ""
    Write-Host "  HALS Web requires PowerShell 7 or later." -ForegroundColor Yellow
    Write-Host "  Use Start-HALSWeb.cmd or run: pwsh .\Start-HALSWeb.ps1" -ForegroundColor White
    Write-Host ""
    exit 1
}

$HALSRoot = if ($env:HALS_ROOT) { $env:HALS_ROOT } else { Split-Path -Parent $PSScriptRoot }
$env:HALS_ROOT = $HALSRoot
Set-Location $HALSRoot

Import-Module "$HALSRoot\Core\HALSRoot.psm1" -Force
Import-Module "$HALSRoot\Web\HALSWebApi.psm1" -Force

$WebRoot = Join-Path $PSScriptRoot "www"

#----------------------------------------------------------
# MIME types
#----------------------------------------------------------

$MimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".webmanifest" = "application/manifest+json"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".ico"  = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2"= "font/woff2"
}

#----------------------------------------------------------
# Response helpers
#----------------------------------------------------------

function Write-HALSWebResponse {

    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode = 200,
        [string]$ContentType = "application/json",
        [string]$Body = "",
        [hashtable]$Headers = @{}
    )

    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType

    foreach ($Key in $Headers.Keys) {
        $Response.Headers[$Key] = $Headers[$Key]
    }

    if ($Body) {
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $Response.ContentLength64 = $Bytes.Length
        $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
    }
    else {
        $Response.ContentLength64 = 0
    }

    $Response.OutputStream.Close()
    $Response.Close()
}

function Get-HALSWebCorsHeaders {
    @{
        "Access-Control-Allow-Origin"  = "*"
        "Access-Control-Allow-Methods" = "GET, POST, OPTIONS"
        "Access-Control-Allow-Headers" = "Content-Type"
    }
}

function Send-HALSWebFile {

    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-HALSWebResponse -Response $Response -StatusCode 404 `
            -ContentType "text/plain" -Body "Not found" -Headers (Get-HALSWebCorsHeaders)
        return
    }

    $Ext  = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $Mime = if ($MimeTypes.ContainsKey($Ext)) { $MimeTypes[$Ext] } else { "application/octet-stream" }
    $Body = [System.IO.File]::ReadAllText($FilePath)

    Write-HALSWebResponse -Response $Response -StatusCode 200 `
        -ContentType $Mime -Body $Body -Headers (Get-HALSWebCorsHeaders)
}

#----------------------------------------------------------
# Start
#----------------------------------------------------------

[Console]::Title = "HALS Web"

Initialize-HALSWebSession

$Listener = [System.Net.HttpListener]::new()
$Listener.Prefixes.Add("http://${Bind}:${Port}/")

try {
    $Listener.Start()
}
catch [System.Net.HttpListenerException] {

    if ($Bind -eq "+" -or $Bind -eq "*") {
        Write-Host ""
        Write-Host "  [!] Network binding requires elevated permissions on Windows." -ForegroundColor Yellow
        Write-Host "      Run once as Administrator:" -ForegroundColor DarkGray
        Write-Host "      netsh http add urlacl url=http://+:${Port}/ user=$env:USERNAME" -ForegroundColor White
        Write-Host ""
        Write-Host "      Or start with localhost-only access:" -ForegroundColor DarkGray
        Write-Host "      .\Start-HALSWeb.ps1 -Bind localhost" -ForegroundColor White
        Write-Host ""
    }

    throw
}

$LocalUrl = "http://localhost:${Port}/"

$LanIp = $null
try {
    $LanIp = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object { $_.IPAddress -notlike "127.*" -and $_.PrefixOrigin -ne "WellKnown" } |
        Select-Object -First 1 -ExpandProperty IPAddress
}
catch { }

Write-Host ""
Write-Host "  +================================================+" -ForegroundColor Cyan
Write-Host "  |              HALS Web Control Panel            |" -ForegroundColor Cyan
Write-Host "  +================================================+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Local URL    $LocalUrl" -ForegroundColor Green
if ($LanIp -and ($Bind -eq "+" -or $Bind -eq "*")) {
    Write-Host "  Network URL  http://${LanIp}:${Port}/" -ForegroundColor Green
}
Write-Host "  API          ${LocalUrl}api/status" -ForegroundColor DarkGray
Write-Host "  Web root     $WebRoot" -ForegroundColor DarkGray
Write-Host ""
if ($Bind -eq "localhost") {
    Write-Host "  Listening on localhost only. Use -Bind + for LAN access." -ForegroundColor DarkGray
}
else {
    Write-Host "  Open the network URL from any device on your LAN." -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  Press Ctrl+C to stop." -ForegroundColor DarkGray
Write-Host ""

try {

    while ($Listener.IsListening) {

        $Context  = $Listener.GetContext()
        $Request  = $Context.Request
        $Response = $Context.Response

        $Method = $Request.HttpMethod.ToUpper()
        $Path   = $Request.Url.AbsolutePath.TrimEnd("/")
        if ([string]::IsNullOrWhiteSpace($Path)) { $Path = "/" }

        # CORS preflight
        if ($Method -eq "OPTIONS") {
            Write-HALSWebResponse -Response $Response -StatusCode 204 `
                -ContentType "text/plain" -Headers (Get-HALSWebCorsHeaders)
            continue
        }

        # API routes
        if ($Path -like "/api/*") {

            $Body = ""
            if ($Method -in @("POST","PUT","PATCH")) {
                $Reader = [System.IO.StreamReader]::new($Request.InputStream, $Request.ContentEncoding)
                $Body   = $Reader.ReadToEnd()
                $Reader.Close()
            }

            $ApiPath = $Path.TrimStart("/")
            $Query   = @{}

            foreach ($Key in $Request.QueryString.AllKeys) {
                if ($Key) { $Query[$Key] = $Request.QueryString[$Key] }
            }

            $Result  = Invoke-HALSWebRoute -Method $Method -Path $ApiPath -Body $Body -Query $Query

            $Json = $Result.Body | ConvertTo-Json -Depth 20 -Compress

            Write-HALSWebResponse -Response $Response `
                -StatusCode $Result.Status `
                -ContentType "application/json; charset=utf-8" `
                -Body $Json `
                -Headers (Get-HALSWebCorsHeaders)

            continue
        }

        # Static files
        $Relative = if ($Path -eq "/") { "index.html" } else { $Path.TrimStart("/") }
        $FilePath = Join-Path $WebRoot ($Relative -replace "/", [IO.Path]::DirectorySeparatorChar)

        # Prevent path traversal
        $Resolved = [System.IO.Path]::GetFullPath($FilePath)
        $WebResolved = [System.IO.Path]::GetFullPath($WebRoot)

        if (-not $Resolved.StartsWith($WebResolved)) {
            Write-HALSWebResponse -Response $Response -StatusCode 403 `
                -ContentType "text/plain" -Body "Forbidden" -Headers (Get-HALSWebCorsHeaders)
            continue
        }

        Send-HALSWebFile -Response $Response -FilePath $Resolved
    }

}
finally {

    Write-Host ""
    Write-Host "  Stopping HALS Web..." -ForegroundColor Yellow

    if ($Listener.IsListening) { $Listener.Stop() }
    $Listener.Close()

}
