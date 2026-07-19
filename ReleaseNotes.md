# HALS 1.0.11 — Session & setup polish

**Home Automation & Logging System** for Windows + PowerShell 7. Connect SmartThings, UniFi, Home Assistant, Hue, Nest, and more; control devices with natural language via HALSAI.

## Download

| Asset | Use case |
|-------|----------|
| **[HALS-Setup-1.0.11.exe](https://github.com/PhillyOC/HALS/releases/download/v1.0.11/HALS-Setup-1.0.11.exe)** | Recommended Windows installer (no admin required) |
| **[HALS-1.0.11.zip](https://github.com/PhillyOC/HALS/releases/download/v1.0.11/HALS-1.0.11.zip)** | Portable copy — unzip anywhere and run `Start-HALS.cmd` |

Default install location: `%LOCALAPPDATA%\Programs\HALS`

### One-line install

```powershell
irm https://github.com/PhillyOC/HALS/releases/latest/download/Install-FromGitHub.ps1 | iex
```

## Quick start

1. Install using the **Setup.exe** or zip above.
2. Launch **HALS** from the Start Menu (or `Start-HALS.cmd`).
3. Run **`Initialize-HALSDeviceProvider`** to connect SmartThings, UniFi, Hue, etc.
4. Run **`Initialize-HALSAI`** to set up OpenAI, Claude, Gemini, or Ollama.
5. Use **`Ask-HALSAI`** for natural-language control.
6. Type **`HALSHelp`** for the HALS command list (not PowerShell's built-in `help`).

## Highlights (1.0.11)

### Interactive session
- **Session commands work from Start Menu launch** — `HALS`, `CompareHALS`, `Knowledge`, `Version`, and OAuth helpers stay available in the interactive session.
- **`HALSHelp`** — quick command reference; use instead of lowercase `help` (which runs `Get-Help`).

### SmartThings
- **OAuth preferred over stale PAT** — incomplete OAuth prompts reconnect instead of silently using an old personal access token.
- **Reliable token paste** — legacy PAT setup uses clipboard/visible paste (PowerShell 7 `-MaskInput` fix).
- **OAuth completion** — removes legacy PAT file when OAuth succeeds.

### Home Assistant
- **Long-lived token paste** — setup uses the same reliable secret input as UniFi and SmartThings.

### Documentation
- Updated **`Docs/HALS-Reference.txt`** and new **`Docs/HALS-Intro.txt`** for public sharing.

## Prior highlights (1.0.10)

- UniFi Gen1 Cloud Key and ui.com Site Manager API key support
- SmartThings OAuth desktop flow with auto-start gateway
- Windows installer + portable zip + GitHub bootstrap install

## Requirements

- Windows 10/11
- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
