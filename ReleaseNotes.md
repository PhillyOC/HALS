# HALS 1.0.8 — OAuth-ready release

**Home Automation & Logging System** for Windows + PowerShell 7. Connect SmartThings, UniFi, Home Assistant, Hue, Nest, and more; control devices with natural language via HALSAI.

## Download

| Asset | Use case |
|-------|----------|
| **[HALS-Setup-1.0.8.exe](https://github.com/PhillyOC/HALS/releases/download/v1.0.8/HALS-Setup-1.0.8.exe)** | Recommended Windows installer (no admin required) |
| **[HALS-1.0.8.zip](https://github.com/PhillyOC/HALS/releases/download/v1.0.8/HALS-1.0.8.zip)** | Portable copy — unzip anywhere and run `Start-HALS.cmd` |

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

## Highlights (1.0.5 → 1.0.8)

### SmartThings OAuth (verified working)
- Desktop OAuth via `https://httpbin.org/get` — no ngrok required for initial setup
- **`Reconnect-SmartThingsOAuth`** finishes authorization when credentials are saved but tokens are missing
- Automatic clipboard detection with stale-URL protection
- Correct token exchange (`client_id` in POST body)

### OAuth & setup reliability
- OAuth gateway auto-starts on port 8000
- Setup wizards for all major providers with validation and clearer error messages
- UniFi site auto-correction (`default` vs hostname mistakes)
- StrictMode fixes across AI and OAuth flows

### AI (HALSAI)
- Canonical system prompt on every request
- Immediate plan execution (`-Verbose` to preview)
- Plan repair for color and all-lights requests

## SmartThings OAuth tip

Create your app with the SmartThings CLI (`smartthings apps:create`, type **OAuth-In App**), register redirect URI **`https://httpbin.org/get`**, then run **`Initialize-SmartThings`** or **`Reconnect-SmartThingsOAuth`**. After browser login, copy the **address bar URL** (Ctrl+L, Ctrl+C).

## Requirements

- Windows 10/11
- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
- Provider credentials stored locally in `Secrets\` (never committed)

Full changelog: see [CHANGELOG.md](CHANGELOG.md) in the repository.
