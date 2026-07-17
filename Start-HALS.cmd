@echo off
title HALS

pwsh.exe ^
    -NoLogo ^
    -NoProfile ^
    -ExecutionPolicy Bypass ^
    -NoExit ^
    -File "%~dp0Start-HALS.ps1"
