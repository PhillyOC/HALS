#==========================================================
# HALS - Root Path Resolver
# Version : 1.0.0
#
# Provides Get-HALSRoot so every module resolves paths
# relative to wherever HALS is installed, rather than
# hardcoding an installation directory.
#
# Priority order:
#   1. $env:HALS_ROOT  (set this to move HALS anywhere)
#   2. The parent folder of this file at runtime
#
# To use a custom installation directory:
#   [System.Environment]::SetEnvironmentVariable(
#       "HALS_ROOT", "<path-to-HALS>", "Machine")
# Or for the current session only:
#   $env:HALS_ROOT = "<path-to-HALS>"
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSRoot {

    #
    # If the environment variable is set, use it.
    #

    if (-not [string]::IsNullOrWhiteSpace($env:HALS_ROOT)) {
        return $env:HALS_ROOT.TrimEnd('\').TrimEnd('/')
    }

    #
    # Fall back to the directory containing this module,
    # which is always Core\ -- so go up one level.
    #

    $ModuleDir = Split-Path -Parent $PSCommandPath
    return Split-Path -Parent $ModuleDir

}

Export-ModuleMember -Function Get-HALSRoot
