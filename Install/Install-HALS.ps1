#==========================================================
# HALS Installer
# Version : 1.0.3
#
# Installs a portable HALS tree, creates shortcuts, and
# prepares empty Secrets/Config folders from examples.
#
# Examples:
#   .\Install-HALS.ps1
#   .\Install-HALS.ps1 -PackagePath .\HALS-1.0.3.zip
#   .\Install-HALS.ps1 -FromGitHub -Version 1.0.3
#==========================================================

[CmdletBinding(DefaultParameterSetName = "Auto")]
param(
    [Parameter(ParameterSetName = "Package")]
    [string]$PackagePath = "",

    [Parameter(ParameterSetName = "GitHub")]
    [switch]$FromGitHub,

    [Parameter(ParameterSetName = "GitHub")]
    [string]$Version = "latest",

    [string]$InstallPath = "",

    [string]$GitHubRepo = "PhillyOC/HALS",

    [switch]$AddDesktopShortcut,

    [switch]$LaunchAfterInstall,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Cyan
}

function Test-PowerShell7 {
    $Pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $Pwsh) {
        throw "PowerShell 7 (pwsh) is required. Install it from https://aka.ms/powershell and re-run the installer."
    }
}

function Get-DefaultInstallPath {
    Join-Path $env:LOCALAPPDATA "Programs\HALS"
}

function New-HALSShortcut {

    param(
        [Parameter(Mandatory)][string]$ShortcutPath,
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [string]$Description = "HALS",
        [string]$IconLocation = ""
    )

    $Folder = Split-Path -Parent $ShortcutPath
    if (-not (Test-Path -LiteralPath $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }

    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.WorkingDirectory = $WorkingDirectory
    $Shortcut.WindowStyle = 1
    $Shortcut.Description = $Description
    if (-not [string]::IsNullOrWhiteSpace($IconLocation) -and (Test-Path -LiteralPath $IconLocation)) {
        $Shortcut.IconLocation = "$IconLocation,0"
    }
    $Shortcut.Save()
}

function Expand-HALSPackage {

    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$Destination
    )

    $Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("HALS-install-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $Temp -Force | Out-Null

    try {
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $Temp -Force

        $Payload = $Temp
        $Children = @(Get-ChildItem -LiteralPath $Temp -Force)
        if ($Children.Count -eq 1 -and $Children[0].PSIsContainer) {
            $Payload = $Children[0].FullName
        }

        if (-not (Test-Path -LiteralPath (Join-Path $Payload "Start-HALS.cmd"))) {
            throw "Package does not look like a HALS release (Start-HALS.cmd missing)."
        }

        if (Test-Path -LiteralPath $Destination) {
            if (-not $Force) {
                throw "Install path already exists: $Destination. Re-run with -Force to replace it."
            }
            Remove-Item -LiteralPath $Destination -Recurse -Force
        }

        New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
        Copy-Item -LiteralPath $Payload -Destination $Destination -Recurse -Force
    }
    finally {
        Remove-Item -LiteralPath $Temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-GitHubReleaseAsset {

    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$RequestedVersion,
        [Parameter(Mandatory)][string]$DownloadDirectory
    )

    $ApiBase = "https://api.github.com/repos/$Repo/releases"
    $Uri = if ($RequestedVersion -eq "latest") {
        "$ApiBase/latest"
    }
    else {
        $Tag = if ($RequestedVersion -like "v*") { $RequestedVersion } else { "v$RequestedVersion" }
        "$ApiBase/tags/$Tag"
    }

    Write-Host "  Fetching release metadata: $Uri" -ForegroundColor DarkGray
    $Release = Invoke-RestMethod -Uri $Uri -Headers @{
        "User-Agent" = "HALS-Installer"
        Accept       = "application/vnd.github+json"
    }

    $Asset = @($Release.assets) |
        Where-Object { $_.name -like "HALS-*.zip" -and $_.name -notlike "*Setup*" } |
        Select-Object -First 1

    if (-not $Asset) {
        throw "No HALS-*.zip asset found on release '$($Release.tag_name)'."
    }

    $OutFile = Join-Path $DownloadDirectory $Asset.name
    Write-Host "  Downloading $($Asset.name)..." -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $OutFile -Headers @{
        "User-Agent" = "HALS-Installer"
    }

    [PSCustomObject]@{
        ZipPath = $OutFile
        Tag     = $Release.tag_name
        Version = ($Release.tag_name -replace '^v', '')
    }
}

function Initialize-HALSRuntimeFolders {

    param([Parameter(Mandatory)][string]$Root)

    foreach ($Folder in @(
            "Secrets"
            "Secrets\OAuth"
            "Config"
            "Knowledge"
            "Snapshots"
        )) {
        $Path = Join-Path $Root $Folder
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
    }
}

#----------------------------------------------------------
# Main
#----------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " HALS Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Test-PowerShell7

if ([string]::IsNullOrWhiteSpace($InstallPath)) {
    $InstallPath = Get-DefaultInstallPath
}

$DownloadDir = Join-Path ([System.IO.Path]::GetTempPath()) ("HALS-dl-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
$CleanupZip = $false

try {
    if ($PSCmdlet.ParameterSetName -eq "GitHub" -or ($FromGitHub) -or
        ($PSCmdlet.ParameterSetName -eq "Auto" -and [string]::IsNullOrWhiteSpace($PackagePath))) {

        # Prefer a local package next to this script when present.
        if ($PSCmdlet.ParameterSetName -eq "Auto") {
            $LocalZip = @(
                Get-ChildItem -LiteralPath $PSScriptRoot -Filter "HALS-*.zip" -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending
            ) | Select-Object -First 1

            $SiblingZip = @(
                Get-ChildItem -LiteralPath (Split-Path -Parent $PSScriptRoot) -Filter "HALS-*.zip" -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending
            ) | Select-Object -First 1

            if ($LocalZip) {
                $PackagePath = $LocalZip.FullName
            }
            elseif ($SiblingZip) {
                $PackagePath = $SiblingZip.FullName
            }
            else {
                $FromGitHub = $true
            }
        }
    }

    if ($FromGitHub -or ($PSCmdlet.ParameterSetName -eq "GitHub")) {
        Write-Step "Downloading HALS from GitHub ($GitHubRepo)..."
        $Release = Get-GitHubReleaseAsset -Repo $GitHubRepo -RequestedVersion $Version -DownloadDirectory $DownloadDir
        $PackagePath = $Release.ZipPath
        $CleanupZip = $true
        Write-Host "  Release: $($Release.Tag)" -ForegroundColor DarkGray
    }

    if ([string]::IsNullOrWhiteSpace($PackagePath)) {
        throw "No package specified. Pass -PackagePath <zip> or -FromGitHub."
    }

    if (-not (Test-Path -LiteralPath $PackagePath)) {
        throw "Package not found: $PackagePath"
    }

    Write-Step "Installing to:"
    Write-Host "  $InstallPath" -ForegroundColor White

    Expand-HALSPackage -ZipPath $PackagePath -Destination $InstallPath
    Initialize-HALSRuntimeFolders -Root $InstallPath

    $InstalledVersion = "unknown"
    $VersionFile = Join-Path $InstallPath "VERSION"
    if (Test-Path -LiteralPath $VersionFile) {
        $InstalledVersion = (Get-Content -LiteralPath $VersionFile -Raw).Trim()
    }

    Write-Step "Creating shortcuts..."
    $StartMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\HALS"
    $Launcher = Join-Path $InstallPath "Start-HALS.cmd"
    $UninstallCmd = Join-Path $InstallPath "Install\Uninstall-HALS.cmd"

    if (-not (Test-Path -LiteralPath (Split-Path -Parent $UninstallCmd))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $UninstallCmd) -Force | Out-Null
    }

    @(
        "@echo off"
        "pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"%~dp0Uninstall-HALS.ps1`" -InstallPath `"$InstallPath`""
    ) | Set-Content -LiteralPath $UninstallCmd -Encoding ASCII

    $IconPath = Join-Path $InstallPath "Assets\HALS.ico"

    New-HALSShortcut `
        -ShortcutPath (Join-Path $StartMenuDir "HALS.lnk") `
        -TargetPath $Launcher `
        -WorkingDirectory $InstallPath `
        -Description "Home Automation & Logging System" `
        -IconLocation $IconPath

    New-HALSShortcut `
        -ShortcutPath (Join-Path $StartMenuDir "Uninstall HALS.lnk") `
        -TargetPath $UninstallCmd `
        -WorkingDirectory $InstallPath `
        -Description "Uninstall HALS" `
        -IconLocation $IconPath

    if ($AddDesktopShortcut) {
        $Desktop = [Environment]::GetFolderPath("Desktop")
        New-HALSShortcut `
            -ShortcutPath (Join-Path $Desktop "HALS.lnk") `
            -TargetPath $Launcher `
            -WorkingDirectory $InstallPath `
            -Description "Home Automation & Logging System" `
            -IconLocation $IconPath
    }

    $InstallInfo = [PSCustomObject]@{
        Version     = $InstalledVersion
        InstallPath = $InstallPath
        InstalledAt = (Get-Date).ToString("o")
        GitHubRepo  = $GitHubRepo
    }
    $InstallInfo | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $InstallPath "Install\install.json")

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " HALS $InstalledVersion installed" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Location : $InstallPath" -ForegroundColor DarkGray
    Write-Host "  Launch   : Start Menu → HALS" -ForegroundColor DarkGray
    Write-Host "             or $Launcher" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Next     : Initialize-HALSDeviceProvider or Initialize-HALSAI" -ForegroundColor DarkGray
    Write-Host ""

    if ($LaunchAfterInstall) {
        Start-Process -FilePath $Launcher
    }
}
finally {
    if ($CleanupZip -and (Test-Path -LiteralPath $DownloadDir)) {
        Remove-Item -LiteralPath $DownloadDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
