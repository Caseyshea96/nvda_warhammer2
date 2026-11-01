@echo off
setlocal
if exist "%~dp0config.json" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\WarhammerAccess\App\Uninstall.ps1"
)
set "result=%errorlevel%"
pause
exit /b %result%
