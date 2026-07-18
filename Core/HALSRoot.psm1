#==========================================================
# HALS - Root Path Resolver
# Version : 1.1.0
#
# Provides Get-HALSRoot so every module resolves paths
# relative to the HALS folder that was launched, rather
# than hardcoding a drive letter or install directory.
#
# Priority order:
#   1. $env:HALS_ROOT when it points at a valid HALS tree
#   2. The parent folder of this module (Core\)
#
# Launchers (Start-HALS.ps1, HALS.ps1, Start-HALSWeb.ps1)
# always set $env:HALS_ROOT from their own location so the
# tree remains portable when copied or moved between drives.
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-HALSRootPath {

    param([Parameter(Mandatory)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }

    return (
        (Test-Path -LiteralPath (Join-Path $Path "HALS.ps1") -PathType Leaf) -or
        (Test-Path -LiteralPath (Join-Path $Path "Start-HALS.ps1") -PathType Leaf)
    )
}

function Get-HALSRoot {

    $ModuleDir = Split-Path -Parent $PSCommandPath
    $ModuleRoot = Split-Path -Parent $ModuleDir

    if (-not [string]::IsNullOrWhiteSpace($env:HALS_ROOT)) {
        $Candidate = $env:HALS_ROOT.TrimEnd('\').TrimEnd('/')
        if (Test-HALSRootPath -Path $Candidate) {
            return $Candidate
        }
    }

    return $ModuleRoot

}

Export-ModuleMember -Function Get-HALSRoot, Test-HALSRootPath
