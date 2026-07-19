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

function Get-HALSSanitizedSecret {

    param(
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    $Clean = -join (
        $Value.ToCharArray() |
            Where-Object { [int][char]$_ -ge 32 -or $_ -eq "`t" }
    )

    return $Clean.Trim()

}

function Read-HALSSecretInput {

    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$Hint = "Copy the full value to your clipboard, then press Enter.",

        [int]$MinimumLength = 1
    )

    Write-Host ""
    Write-Host $Hint -ForegroundColor DarkGray
    Write-Host "Masked PowerShell prompts only capture the first pasted character in PS 7." -ForegroundColor DarkGray
    Write-Host ""

    $Method = (Read-Host "Input method: [1] Clipboard  [2] Visible prompt [1]").Trim()
    if ([string]::IsNullOrWhiteSpace($Method)) {
        $Method = "1"
    }

    $Value = $null
    if ($Method -eq "2") {
        Write-Host "Input is visible while you type or paste." -ForegroundColor Yellow
        $Value = Read-Host $Prompt
    }
    else {
        $Ack = (Read-Host "Press Enter when ready, or paste the value here").Trim()
        if (-not [string]::IsNullOrWhiteSpace($Ack)) {
            $Value = $Ack
        }
        else {
            $Value = Get-Clipboard -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($Value)) {
                Write-Host "Clipboard is empty. Paste visibly instead." -ForegroundColor Yellow
                $Value = Read-Host $Prompt
            }
        }
    }

    $Clean = Get-HALSSanitizedSecret -Value $Value
    if ($Clean.Length -lt $MinimumLength) {
        throw "$Prompt looks too short ($($Clean.Length) characters)."
    }

    return $Clean

}

function Test-HALSNetworkHostInput {

    param(
        [Parameter(Mandatory)]
        [string]$HostName
    )

    $Candidate = $HostName.Trim().Trim('"').Trim("'")

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return $false
    }

    if ($Candidate -match '[/\\:@?#]') {
        return $false
    }

    if ($Candidate -match '\.(json|txt|exe|pdf|csv|xml)$') {
        return $false
    }

    if ($Candidate.Length -gt 253) {
        return $false
    }

    return $true

}

Export-ModuleMember -Function `
    Get-HALSRoot, `
    Test-HALSRootPath, `
    Get-HALSSanitizedSecret, `
    Read-HALSSecretInput, `
    Test-HALSNetworkHostInput
