@echo off
setlocal
if exist "%~dp0config.json" (
  powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File "%~dp0Companion.ps1" -Launch
) else (
  powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\WarhammerAccess\App\Companion.ps1" -Launch
)
if errorlevel 1 pause
