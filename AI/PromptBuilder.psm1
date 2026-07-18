#==========================================================
# HALS - Prompt Builder
# Version : 5.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command Get-HALSAISystemPrompt -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path (Get-HALSRoot) "AI\HALSAIPrompt.psm1") -Force
}

function New-HALSAIPrompt {

    param(

        [Parameter(Mandatory)]
        [string]$Context,

        [Parameter(Mandatory)]
        [string]$Question

    )

    $SystemPrompt = Get-HALSAISystemPrompt

    return @"
$SystemPrompt

==========================================================
CURRENT HALS ENVIRONMENT
==========================================================

$Context

==========================================================
USER REQUEST
==========================================================

$Question

"@

}

Export-ModuleMember -Function New-HALSAIPrompt
