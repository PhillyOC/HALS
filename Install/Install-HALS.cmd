@echo off
title HALS Installer
setlocal

set "SCRIPT=%~dp0Install-HALS.ps1"

where pwsh >nul 2>&1
if errorlevel 1 (
  echo PowerShell 7 (pwsh) is required.
  echo Install it from https://aka.ms/powershell
  pause
  exit /b 1
)

pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
  echo.
  echo Installer exited with code %EXITCODE%.
  pause
)
exit /b %EXITCODE%
