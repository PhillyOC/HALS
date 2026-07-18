# Changelog

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
