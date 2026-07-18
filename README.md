# HALS

HALS (Home Automation & Logging System) is a PowerShell 7 application that inventories and controls smart-home devices through optional provider modules, including UniFi, SmartThings, Home Assistant, Google Nest, Philips Hue, WiZ Pro, Ecobee, and Pushbullet. It includes an interactive console, a local web control panel, and optional AI providers.

## Requirements

- Windows with [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
- Access to the local devices and provider APIs you configure
- Provider credentials stored locally; never commit real credentials

## Install

```powershell
git clone https://github.com/YOUR_ACCOUNT/HALS.git
Set-Location HALS
Copy-Item .\Secrets\UniFi.example.json .\Secrets\UniFi.json
Copy-Item .\Config\AI.example.json .\Config\AI.json
```

Edit the copied files or use the initialization commands shown by HALS. Runtime credentials, device knowledge, and snapshots are ignored by Git.

Start the interactive console:

```powershell
.\Start-HALS.ps1
```

Or use `Start-HALS.cmd`.

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

## Security

See [SECURITY.md](SECURITY.md). If credentials have ever been placed in a copy of this project, rotate them before publishing that copy.

## Development

There is no build step. The CI workflow parses every PowerShell source file to catch syntax errors. Provider integrations require local credentials and hardware, so they are not exercised in CI.

## License

MIT
