#==========================================================
# HALS Uninstaller
#==========================================================

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallPath = "",
    [switch]$KeepData
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($InstallPath)) {
    $InstallPath = Join-Path $env:LOCALAPPDATA "Programs\HALS"
}

if (-not (Test-Path -LiteralPath $InstallPath)) {
    Write-Host "HALS is not installed at: $InstallPath" -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "Uninstalling HALS from:" -ForegroundColor Cyan
Write-Host "  $InstallPath"
Write-Host ""

if (-not $PSCmdlet.ShouldProcess($InstallPath, "Remove HALS installation")) {
    return
}

$StartMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\HALS"
if (Test-Path -LiteralPath $StartMenuDir) {
    Remove-Item -LiteralPath $StartMenuDir -Recurse -Force -ErrorAction SilentlyContinue
}

$DesktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "HALS.lnk"
if (Test-Path -LiteralPath $DesktopShortcut) {
    Remove-Item -LiteralPath $DesktopShortcut -Force -ErrorAction SilentlyContinue
}

if ($KeepData) {
    foreach ($Name in @("AI", "Core", "Providers", "Web", "Gateway", "Scripts", "Docs", "Install")) {
        $Path = Join-Path $InstallPath $Name
        if (Test-Path -LiteralPath $Path) {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Get-ChildItem -LiteralPath $InstallPath -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("VERSION") } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "Application files removed. Secrets/Config/Knowledge/Snapshots kept." -ForegroundColor Green
}
else {
    Remove-Item -LiteralPath $InstallPath -Recurse -Force
    Write-Host "HALS removed." -ForegroundColor Green
}

Write-Host ""
