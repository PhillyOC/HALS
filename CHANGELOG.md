# Changelog

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
