#==========================================================
# HALS - HALSAI System Prompt
# Version : 1.0.0
#==========================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HALSAISystemPromptPath {

    Join-Path (Get-HALSRoot) "AI\HALSAI-SystemPrompt.txt"

}

function Get-HALSAISystemPrompt {

    $Path = Get-HALSAISystemPromptPath

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "HALSAI system prompt not found: $Path"
    }

    return (Get-Content -LiteralPath $Path -Raw).TrimEnd()

}

function New-HALSAIProviderInitializationPrompt {

    @"
$(Get-HALSAISystemPrompt)

==========================================================
PROVIDER SETUP ACKNOWLEDGMENT
==========================================================

You are being configured as a HALSAI provider for HALS.

Confirm that you understand your role and will obey these rules on every request.

Reply with exactly:
HALSAI ready.
"@

}

Export-ModuleMember -Function `
    Get-HALSAISystemPromptPath,
    Get-HALSAISystemPrompt,
    New-HALSAIProviderInitializationPrompt
