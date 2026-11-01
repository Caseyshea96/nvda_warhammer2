@rem One line on purpose: the update replaces this file while it runs.
@powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update.ps1" %* & pause & exit /b
