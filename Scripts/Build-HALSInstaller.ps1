#==========================================================
# HALS - Windows installer builder
# Builds the portable package and compiles HALS-Setup-<version>.exe
#==========================================================

[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$OutputRoot = "",
    [switch]$SkipZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Content -LiteralPath (Join-Path $RepoRoot "VERSION") -Raw).Trim()
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot "dist"
}

$PackageScript = Join-Path $RepoRoot "Scripts\New-HALSPackage.ps1"
$IssFile = Join-Path $RepoRoot "Install\HALS.iss"
$StageRoot = Join-Path $OutputRoot "HALS-$Version"
$SetupExe = Join-Path $OutputRoot "HALS-Setup-$Version.exe"

Write-Host "Building HALS $Version installer..." -ForegroundColor Cyan

$PackageParams = @{
    Version    = $Version
    OutputRoot = $OutputRoot
}
if ($SkipZip) {
    $PackageParams.SkipZip = $true
}

& $PackageScript @PackageParams

$Iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $Iscc) {
    throw @"
Inno Setup 6 (ISCC.exe) was not found.
Install it from https://jrsoftware.org/isdl.php, then re-run:
  .\Scripts\Build-HALSInstaller.ps1
"@
}

Write-Host "Compiling $IssFile ..." -ForegroundColor Cyan

& $Iscc `
    "/DMyAppVersion=$Version" `
    "/DSourceDir=$StageRoot" `
    "/DOutputDir=$OutputRoot" `
    $IssFile

if (-not (Test-Path -LiteralPath $SetupExe)) {
    throw "Setup executable was not produced: $SetupExe"
}

Copy-Item (Join-Path $RepoRoot "Install\Install-HALS.ps1") (Join-Path $OutputRoot "Install-HALS.ps1") -Force
Copy-Item (Join-Path $RepoRoot "Install\Install-FromGitHub.ps1") (Join-Path $OutputRoot "Install-FromGitHub.ps1") -Force
Copy-Item (Join-Path $RepoRoot "Install\Install-HALS.cmd") (Join-Path $OutputRoot "Install-HALS.cmd") -Force

Write-Host ""
Write-Host "Installer ready:" -ForegroundColor Green
Write-Host "  $SetupExe" -ForegroundColor White
Write-Host "  $(Join-Path $OutputRoot "HALS-$Version.zip")" -ForegroundColor White
Write-Host ""

[PSCustomObject]@{
    Version  = $Version
    SetupExe = $SetupExe
    ZipPath  = Join-Path $OutputRoot "HALS-$Version.zip"
    StageRoot = $StageRoot
}
