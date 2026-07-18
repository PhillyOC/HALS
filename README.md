# HALS

HALS (Home Automation & Logging System) is a PowerShell 7 application that inventories and controls smart-home devices through optional provider modules, including UniFi, SmartThings, Home Assistant, Google Nest, Philips Hue, WiZ Pro, Ecobee, and Pushbullet. It includes an interactive console, a local web control panel, and optional AI providers.

**Current release: 1.0.1**

## Requirements

- Windows with [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
- Access to the local devices and provider APIs you configure
- Provider credentials stored locally; never commit real credentials

## Install (recommended)

### Option A — Windows installer

1. Open the latest [GitHub Release](https://github.com/PhillyOC/HALS/releases/latest)
2. Download `HALS-Setup-1.0.1.exe`
3. Run the installer (no admin rights required)
4. Launch **HALS** from the Start Menu

Default install location: `%LOCALAPPDATA%\Programs\HALS`

### Option B — One-line PowerShell install

```powershell
irm https://github.com/PhillyOC/HALS/releases/latest/download/Install-FromGitHub.ps1 | iex
```

### Option C — Portable zip

1. Download `HALS-1.0.1.zip` from [Releases](https://github.com/PhillyOC/HALS/releases/latest)
2. Unzip anywhere (for example `D:\HALS`)
3. Run `Start-HALS.cmd`

### Option D — From source

```powershell
git clone https://github.com/PhillyOC/HALS.git
Set-Location HALS
.\Start-HALS.cmd
```

After install, use `Initialize-HALSDeviceProvider` or `Initialize-HALSAI` to connect platforms and AI. Keep live credentials in a private working copy; do not commit them.

## Web control panel

```powershell
.\Web\Start-HALSWeb.ps1
```

Open `http://localhost:8080`. The default binding is localhost-only.

The web API can scan networks and control devices and does not currently provide user authentication. Do not bind it to a LAN address or expose it through a tunnel/reverse proxy unless you add an authentication layer and restrict CORS.

## Configuration

- HALS is folder-portable: launch with `Start-HALS.ps1`, `Start-HALS.cmd`, or `HALS.ps1` from the copy you want to use. Launchers bind the session to that folder, so you can move or copy the tree between drives without editing paths.
- `HALS_ROOT` is set automatically for the session. A stale machine/user `HALS_ROOT` pointing at an old location is ignored when that path is no longer a valid HALS tree.
- `HALS_UNIFI_HOST`, `HALS_UNIFI_PORT`, `HALS_UNIFI_SITE`, `HALS_UNIFI_USERNAME`, and `HALS_UNIFI_PASSWORD` may be used instead of `Secrets\UniFi.json`.
- `Config\AI.json` selects and configures the AI provider.
- `Secrets\` contains local provider credentials and OAuth tokens.
- `Knowledge\` and `Snapshots\` contain private runtime device and network data.

Example files contain placeholders only. Keep local files at their non-`.example` names so `.gitignore` excludes them.

### WiZ Pro example integration

Run `Initialize-WiZ` (or choose WiZ Pro from `Initialize-HALSDeviceProvider`) and enter the client ID and redirect URI registered with [WiZ Pro](https://docs.pro.wizconnected.com/#introduction). HALS opens the OAuth-PKCE authorization page, stores the resulting tokens in `Secrets\OAuth\WiZ.json`, inventories the authorized building topology, and exposes supported light operations to HALSAI. WiZ Pro credentials are issued by WiZ; this official cloud integration is separate from the undocumented consumer-bulb LAN protocol.

## Remove an integration

Inside a HALS session:

```powershell
Remove-HALSAIProvider -Provider Ollama
Remove-HALSDeviceProvider -Provider PhilipsHue
```

AI removal edits `Config\AI.json` (and deletes it if nothing remains). Device removal deletes that provider's `Secrets\*.json` / `Secrets\OAuth\*.json` files. Run `HALS` afterward to refresh inventory.

## Uninstall HALS itself

- Start Menu → **Uninstall HALS**, or
- Run `Install\Uninstall-HALS.cmd` from the install folder, or
- Remove the portable folder if you used the zip

## Security

See [SECURITY.md](SECURITY.md). If credentials have ever been placed in a copy of this project, rotate them before publishing that copy.

## Development

CI parses every PowerShell source file for syntax errors. Provider integrations require local credentials and hardware, so they are not exercised in CI.

### Build a local release package

```powershell
.\Scripts\New-HALSPackage.ps1
```

Output lands in `dist\`:

- `HALS-1.0.1\` — clean portable tree
- `HALS-1.0.1.zip` — portable archive
- `Assets\HALS.ico` / `Assets\HALS.png` — application branding

### Publish a GitHub Release

1. Ensure `VERSION` matches the release (currently `1.0.1`)
2. Commit and push to `main`
3. Tag and push:

```powershell
git tag v1.0.1
git push origin v1.0.1
```

The Release workflow builds the zip, compiles `HALS-Setup-<version>.exe` with Inno Setup, and uploads the assets.

## License

MIT
