#==========================================================
# HALS - Release package builder
# Creates a clean portable tree and zip for GitHub Releases.
#==========================================================

[CmdletBinding()]
param(
    [string]$OutputRoot = "",
    [string]$Version = "",
    [switch]$SkipZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot "dist"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Content -LiteralPath (Join-Path $RepoRoot "VERSION") -Raw).Trim()
}

$PackageName = "HALS-$Version"
$StageRoot = Join-Path $OutputRoot $PackageName
$ZipPath = Join-Path $OutputRoot "$PackageName.zip"

$ExcludeDirNames = @(
    ".git"
    ".github"
    ".vscode"
    ".idea"
    "dist"
    "Test"
    "agent-tools"
    "agent-transcripts"
)

$ExcludeFileNames = @(
    ".DS_Store"
    "Thumbs.db"
    "*.log"
    "*.tmp"
    "*.clixml"
    "*.user"
    "PhilipsHue.json"
    "AI.json"
    "Connections.json"
    "UniFi.json"
    "SmartThings.json"
    "HomeAssistant.json"
)

function Test-ExcludedPath {

    param([Parameter(Mandatory)][string]$FullPath)

    $Relative = $FullPath.Substring($RepoRoot.Length).TrimStart("\", "/")
    $Parts = $Relative -split "[\\/]"

    foreach ($Part in $Parts) {
        if ($ExcludeDirNames -contains $Part) {
            return $true
        }
    }

    $Leaf = Split-Path -Leaf $FullPath
    foreach ($Pattern in $ExcludeFileNames) {
        if ($Leaf -like $Pattern) {
            return $true
        }
    }

    # Runtime data stays out of packages; keep folder placeholders only.
    if ($Relative -match '^(?i)Snapshots[\\/]' -and $Leaf -ne ".gitkeep") {
        return $true
    }

    if ($Relative -match '^(?i)Knowledge[\\/]' -and $Leaf -ne ".gitkeep") {
        return $true
    }

    if ($Relative -match '^(?i)Secrets[\\/]' -and $Leaf -notlike "*.example.json") {
        return $true
    }

    if ($Relative -match '^(?i)Config[\\/]' -and $Leaf -notlike "*.example.json" -and $Leaf -ne ".gitkeep") {
        return $true
    }

    return $false
}

Write-Host "Building HALS $Version package..." -ForegroundColor Cyan
Write-Host "  Source : $RepoRoot"
Write-Host "  Stage  : $StageRoot"

if (Test-Path -LiteralPath $OutputRoot) {
    # Only clear the staged package/zip for this version.
    if (Test-Path -LiteralPath $StageRoot) {
        Remove-Item -LiteralPath $StageRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }
}
else {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}

New-Item -ItemType Directory -Path $StageRoot -Force | Out-Null

Get-ChildItem -LiteralPath $RepoRoot -Force | ForEach-Object {
    $Name = $_.Name
    if ($ExcludeDirNames -contains $Name) { return }
    if ($Name -eq "dist") { return }

    $Destination = Join-Path $StageRoot $Name

    if ($_.PSIsContainer) {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
    else {
        if (-not (Test-ExcludedPath -FullPath $_.FullName)) {
            Copy-Item -LiteralPath $_.FullName -Destination $Destination -Force
        }
    }
}

# Second pass: strip anything that slipped through recursive copy.
Get-ChildItem -LiteralPath $StageRoot -Recurse -Force -File | ForEach-Object {
    $Mapped = $_.FullName.Replace($StageRoot, $RepoRoot)
    if (Test-ExcludedPath -FullPath $Mapped) {
        Remove-Item -LiteralPath $_.FullName -Force
    }
}

# Ensure empty runtime folders exist in the package.
foreach ($Folder in @("Snapshots", "Knowledge", "Secrets", "Secrets\OAuth", "Config")) {
    $Path = Join-Path $StageRoot $Folder
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

Set-Content -LiteralPath (Join-Path $StageRoot "Snapshots\.gitkeep") -Value ""
Set-Content -LiteralPath (Join-Path $StageRoot "Knowledge\.gitkeep") -Value ""

# Drop packaging internals that end users do not need in portable zip.
$OptionalRemove = @(
    "Scripts\New-HALSPackage.ps1"
    "Install\HALS.iss"
)
foreach ($Rel in $OptionalRemove) {
    $Path = Join-Path $StageRoot $Rel
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }
}

$FileCount = @(Get-ChildItem -LiteralPath $StageRoot -Recurse -File).Count
Write-Host "  Files  : $FileCount" -ForegroundColor DarkGray

if (-not $SkipZip) {
    Compress-Archive -Path (Join-Path $StageRoot "*") -DestinationPath $ZipPath -Force
    Write-Host "  Zip    : $ZipPath" -ForegroundColor Green
}

Write-Host "Package ready." -ForegroundColor Green

[PSCustomObject]@{
    Version   = $Version
    StageRoot = $StageRoot
    ZipPath   = $ZipPath
    FileCount = $FileCount
}
