# Changelog

## 1.0.5 — 2026-07-18

Stabilization release focused on OAuth reliability, provider setup wizards, and first-run experience. SmartThings OAuth is now practical on a desktop PC without ngrok; the OAuth gateway starts automatically; and several StrictMode and validation bugs that blocked saving configuration or completing authorization are fixed.

### Added

- **OAuth gateway auto-start** — `Core\HALSGatewayManager.psm1` with `Initialize-HALSGateway` (alias `Ensure-HALSGateway`). The gateway on port 8000 starts automatically from `Start-HALS.cmd` / `Scripts\Start-HALSEnvironment.ps1` and during OAuth wizards (Nest, Pushbullet, Ecobee tunnel mode, etc.). No more manual “is the gateway running?” step.
- **SmartThings desktop OAuth flow** — `Core\HALSSmartThingsOAuth.psm1` with browser login, clipboard watcher, and httpbin callback support (`https://httpbin.org/get`) for SmartThings apps that cannot use localhost redirects.
- **`Reconnect-SmartThingsOAuth`** — finish or refresh SmartThings OAuth when Client ID/Secret are saved but tokens are missing or expired.
- **`Test-HALSSmartThingsOAuthPending`** — detects incomplete SmartThings OAuth; startup and inventory show a yellow “Finish OAuth” hint instead of a generic “not configured” message.
- **`Ensure-HALSOAuthConfiguration`** — creates `Secrets\OAuth\{Provider}.json` from `.example.json` templates during setup (Google Nest, Pushbullet, SmartThings, Ecobee, etc.).
- **OAuth redirect guidance** — `Test-HALSOAuthRedirectUriForProvider` and `Get-HALSOAuthRedirectUriGuidance` explain valid redirect URIs per provider (SmartThings requires public HTTPS or the httpbin desktop flow).
- **UniFi site resolution** — `Resolve-UniFiSiteName` auto-corrects mistaken site names (e.g. hostname `unifi-cloudkey` → `default`), lists available sites during setup, and validates inventory before saving credentials.
- **Network host validation** — `Test-HALSNetworkHostInput` rejects paths, JSON fragments, and other invalid host strings during UniFi and similar setup.
- **Secret sanitization** — `Get-HALSSanitizedSecret` strips control characters from pasted tokens (Home Assistant, API keys).
- **Typo-friendly startup commands** — global `Initiate-HALSDeviceProvider` and `Initiazize-HALSDeviceProvider` wrappers in `Start-HALS.ps1` for the device setup wizard.
- **Updated OAuth example templates** — `Secrets\OAuth\SmartThings.example.json`, `GoogleNest.example.json`, and `Pushbullet.example.json` with current redirect guidance.

### Changed

- **`Start-HALS.cmd`** now launches `Scripts\Start-HALSEnvironment.ps1` (gateway + session) instead of bypassing the environment bootstrap.
- **SmartThings setup** — OAuth is the default path; PAT remains as legacy option. Setup instructions point to `smartthings apps:create` (OAuth-In App), not Developer Workspace.
- **SmartThings token endpoint** — corrected to `https://api.smartthings.com/oauth/token` (was `/v1/oauth/token`).
- **SmartThings OAuth scope URL** — scopes joined with `+` for authorization requests.
- **Ecobee token refresh** — uses body-only refresh grant (no Basic Auth header).
- **Provider startup panel** — shows “Finish OAuth (Reconnect-SmartThingsOAuth)” when SmartThings credentials exist without tokens.
- **OpenAI / AI setup** — step-based wizard with `Send-HALSAIProviderInitialization`; StrictMode-safe provider switch prompts.
- **Gemini setup** — clearer 403 (API disabled) message and updated default model names.
- **Help text** — documents `Reconnect-SmartThingsOAuth` and device/AI removal commands.

### Fixed

- **StrictMode OAuth callback crash** — clipboard-detected SmartThings callback no longer fails on missing `AuthorizationCode` property when only `RedirectUrl` is present (`ContainsKey` checks).
- **OpenAI setup save crash** — `$CurrentProvider?` StrictMode interpolation in `Initialize-HALSAI.psm1` and related modules.
- **Ask-HALSAI empty plan** — `PlanParser.psm1` skips blank `Device` rows; `PlanRepair.psm1` repairs color plans on empty AI responses.
- **OpenAI model selection** — choosing list index `1` no longer sends invalid model id `1` to the API.
- **Google Nest OAuth template** — setup wizard creates missing `Secrets\OAuth\GoogleNest.json` from example.
- **Philips Hue post-auth test** — no longer fails under StrictMode during setup verification.
- **UniFi offline after setup** — wrong site name and invalid host input no longer leave UniFi appearing connected in setup but offline in inventory.
- **SmartThings 401 after OAuth** — token exchange and redirect handling stabilized for desktop httpbin flow.

### Upgrade notes

1. **Existing SmartThings OAuth users (1.0.4 and earlier):** if setup saved Client ID/Secret but authorization never completed, run `Reconnect-SmartThingsOAuth` after upgrading — do not re-enter credentials unless prompted.
2. **SmartThings redirect URI:** register `https://httpbin.org/get` in your SmartThings OAuth-In app for the desktop flow, or use `Initialize-SmartThings -UseTunnel` for ngrok + local gateway.
3. **UniFi site:** if devices show offline, re-run `Initialize-UniFi` and confirm site is `default` (or your actual site id from the controller).
4. **Portable copies:** launch from the folder you want HALS to use; stale `HALS_ROOT` values pointing at old paths are ignored when that tree no longer exists.

## 1.0.4 — 2026-07-18

### Added
- Canonical HALSAI system prompt (`AI\HALSAI-SystemPrompt.txt`) injected on every `Ask-HALSAI` request
- Automatic HALSAI initialization during AI provider setup (`Send-HALSAIProviderInitialization`)
- `AI\PlanRepair.psm1` to correct common AI mistakes (named colors using `SetColor`, all-lights requests)
- `Scripts\Build-HALSInstaller.ps1` for local Windows installer builds
- `Controllable` asset flag and `ProviderRoles` in HALSAI context (inventory-only vs controllable providers)

### Changed
- `Ask-HALSAI` executes action plans immediately; use `-Verbose` to preview and confirm
- SmartThings bulbs are categorized as `Light Bulb` when color/switch capabilities are present
- UniFi inventory uses configured port/site, assigns network categories, and includes infrastructure devices
- Philips Hue setup no longer fails on the post-auth connection test under StrictMode
- Clearer SmartThings command catalog descriptions for color vs color-temperature

### Fixed
- HALSAI choosing `SetColorTemperature` or `TurnOnLight` when user requests a named color like green
- UniFi clients appearing as uncategorized unknown devices instead of network inventory
- OpenAI provider switch prompt crash under StrictMode (`${CurrentProvider}?` interpolation)

## 1.0.1 — 2026-07-18
