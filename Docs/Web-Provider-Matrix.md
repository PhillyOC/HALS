# Web Provider Matrix — Integration Testing for 1.2.0

Fill this in while testing each integration from the HALS console.  
This drives which commands and UI controls HALS 1.2.0 web must expose.

**Legend:** ☐ not tested · ✅ working · ⚠️ partial · ❌ blocked

| Provider | Configured | Inventory | Control | Auth notes | Status |
|----------|------------|-----------|---------|------------|--------|
| SmartThings | | | | httpbin OAuth | |
| UniFi | ✅ | ✅ | N/A (read-only) | local admin or ui.com API key | ✅ Gen1 Cloud Key verified |
| Home Assistant | | | | token sanitize | |
| Philips Hue | ✅ | ✅ | ⚠️ | bridge user | no lights to test; connection flawless |
| Google Nest | | | | OAuth | not tested yet |
| WiZ Pro | | | | OAuth PKCE | not tested yet |
| Ecobee | | | | OAuth | not tested yet |
| Pushbullet | ✅ | ✅ | ✅ notify | OAuth gateway | works well |

## AI providers

| Provider | Configured | Ask-HALSAI | Execute plan | Notes |
|----------|------------|------------|--------------|-------|
| OpenAI | | | | |
| Claude | ✅ | ✅ | ✅ | okay |
| Gemini | | | | |
| Ollama | | | | |
| Together AI | ✅ | ✅ | ✅ | successful |
| Mistral | | | | |

## Command catalog samples

Paste example command names + parameters discovered during testing (one block per provider):

```
# SmartThings example
# TurnOnLight, TurnOffLight, SetColor, SetColorTemperature, ...
```

## Blockers for web (core fixes before 1.2.0 UI)

- **UniFi** — fixed: auto-detect legacy vs UniFi OS API paths (8443 `/api/login` vs 443 `/api/auth/login` + `/proxy/network/...`). Re-run `Initialize-UniFi` with port **auto**.
- **Philips Hue** — no blockers; need bulbs/scenes for control testing when available.
- **Pushbullet** — no blockers.
- **Claude / Together AI** — no blockers.

## Web must show (from testing)

| Provider | Web must show |
|----------|---------------|
| UniFi | network map, clients, APs, gateways |
| Philips Hue | rooms, lights, scenes |
| Pushbullet | notify-only actions |
| SmartThings | full device control when OAuth complete |
