# HALS 1.0.10 — UniFi-stable release

**Home Automation & Logging System** for Windows + PowerShell 7. Connect SmartThings, UniFi, Home Assistant, Hue, Nest, and more; control devices with natural language via HALSAI.

## Download

| Asset | Use case |
|-------|----------|
| **[HALS-Setup-1.0.10.exe](https://github.com/PhillyOC/HALS/releases/download/v1.0.10/HALS-Setup-1.0.10.exe)** | Recommended Windows installer (no admin required) |
| **[HALS-1.0.10.zip](https://github.com/PhillyOC/HALS/releases/download/v1.0.10/HALS-1.0.10.zip)** | Portable copy — unzip anywhere and run `Start-HALS.cmd` |

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

## Highlights (1.0.10)

### UniFi (verified on Cloud Key Gen1)
- **Local admin login** for legacy controllers — port 443/8443 auto-detection, site picker, startup reconnect
- **ui.com Site Manager API keys** — optional cloud path for accounts without local Integration keys
- **Inventory on startup** — gateways, access points, switches, and clients populate HOME OVERVIEW
- **PS 7 secret paste fix** — clipboard/visible input for API keys and passwords (no more one-character `-MaskInput` bug)

### Prior release features (1.0.5 → 1.0.8)
- SmartThings OAuth via httpbin desktop flow
- OAuth gateway auto-start on port 8000
- Provider setup wizards with validation
- Windows installer + portable zip + GitHub bootstrap install

## UniFi setup tips

| Controller | Auth | HALS option |
|------------|------|-------------|
| Cloud Key Gen1 (Network 7.x) | Local admin password | Option **2** — host `192.168.x.x`, port **443** or **8443** |
| ui.com API key | Site Manager + Network scope | Option **1** — paste full key via clipboard |

UniFi is **read-only** in HALS (inventory visibility). Device control uses SmartThings, Hue, WiZ, etc.

## Requirements

- Windows 10/11
- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
