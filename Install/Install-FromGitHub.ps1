#==========================================================
# One-line bootstrap: download and install the latest HALS
# release from GitHub.
#
#   irm https://github.com/PhillyOC/HALS/releases/latest/download/Install-FromGitHub.ps1 | iex
#==========================================================

[CmdletBinding()]
param(
    [string]$Version = "latest",
    [string]$InstallPath = "",
    [switch]$AddDesktopShortcut,
    [switch]$LaunchAfterInstall,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("HALS-bootstrap-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    $InstallerUrl = if ($Version -eq "latest") {
        "https://github.com/PhillyOC/HALS/releases/latest/download/Install-HALS.ps1"
    }
    else {
        $Tag = if ($Version -like "v*") { $Version } else { "v$Version" }
        "https://github.com/PhillyOC/HALS/releases/download/$Tag/Install-HALS.ps1"
    }

    $InstallerPath = Join-Path $TempDir "Install-HALS.ps1"
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -Headers @{ "User-Agent" = "HALS-Bootstrap" }

    $Args = @{
        FromGitHub = $true
        Version    = $Version
        Force      = [bool]$Force
    }
    if ($InstallPath) { $Args.InstallPath = $InstallPath }
    if ($AddDesktopShortcut) { $Args.AddDesktopShortcut = $true }
    if ($LaunchAfterInstall) { $Args.LaunchAfterInstall = $true }

    & $InstallerPath @Args
}
finally {
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
