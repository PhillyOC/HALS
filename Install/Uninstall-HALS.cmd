@echo off
title Uninstall HALS
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-HALS.ps1" %*
