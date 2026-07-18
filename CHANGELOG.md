# Changelog

## 1.0.3 — 2026-07-18

### Fixed
- OpenAI setup no longer crashes after a successful connection test when prompting to switch providers
- Gemini setup now loads the live model list from your API key instead of stale preview model names
- Gemini setup and provider calls show clearer messages for missing models and billing/quota errors

### Added
- `Scripts\Build-HALSInstaller.ps1` to build `HALS-Setup-<version>.exe` locally with Inno Setup

## 1.0.2 — 2026-07-18

### Fixed
- AI setup wizards (Gemini, Together AI, Ollama, Claude, Mistral) now load provider modules before connection tests, so `Invoke-*` / `Get-OllamaModels` are available during Initialize

## 1.0.1 — 2026-07-18

### Added
- Official HALS application icon for the Windows installer, Start Menu, and desktop shortcuts
- `Remove-HALSAIProvider` and `Remove-HALSDeviceProvider` to disconnect integrations cleanly

### Changed
- Installer and shortcut branding now use `Assets\HALS.ico`

## 1.0.0 — 2026-07-17

First public packaged release.

### Highlights
- Modular device and AI provider registries (optional providers, optional AI)
- Official WiZ Pro example integration with AI-ready command schemas
- Portable folder layout with session-bound root resolution
- Windows installer (`HALS-Setup-1.0.0.exe`) and PowerShell installer
- GitHub Releases packaging (portable zip + setup)

### Installer
- Default install location: `%LOCALAPPDATA%\Programs\HALS`
- Start Menu shortcuts and optional desktop shortcut
- One-line bootstrap from GitHub Releases

### Notes
- Keep live credentials only in a private working copy (for example `D:\HALS`)
- Never commit `Secrets\*.json` (non-example) or `Config\AI.json`
