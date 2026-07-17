# HALS

HALS (Home Automation & Logging System) is a PowerShell 7 application that inventories and controls smart-home devices through UniFi, SmartThings, Home Assistant, Google Nest, Philips Hue, Ecobee, and Pushbullet. It includes an interactive console, a local web control panel, and optional AI providers.

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

- `HALS_ROOT` optionally overrides the repository root.
- `HALS_UNIFI_HOST`, `HALS_UNIFI_PORT`, `HALS_UNIFI_SITE`, `HALS_UNIFI_USERNAME`, and `HALS_UNIFI_PASSWORD` may be used instead of `Secrets\UniFi.json`.
- `Config\AI.json` selects and configures the AI provider.
- `Secrets\` contains local provider credentials and OAuth tokens.
- `Knowledge\` and `Snapshots\` contain private runtime device and network data.

Example files contain placeholders only. Keep local files at their non-`.example` names so `.gitignore` excludes them.

## Security

See [SECURITY.md](SECURITY.md). If credentials have ever been placed in a copy of this project, rotate them before publishing that copy.

## Development

There is no build step. The CI workflow parses every PowerShell source file to catch syntax errors. Provider integrations require local credentials and hardware, so they are not exercised in CI.

## License

MIT
