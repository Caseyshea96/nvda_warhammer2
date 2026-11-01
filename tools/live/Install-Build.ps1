# Install a built automation-preview ZIP over the current install, keeping a
# full backup of the previous App folder, logs and pack under work/.
# -Upgrade runs the shipped installer the way a player does (no uninstall
# first, game folder found by the installer), to test upgrading in place.
param([Parameter(Mandatory=$true)][string]$Version, [switch]$Upgrade)  # e.g. 0.6.18
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$base = Join-Path $env:LOCALAPPDATA 'JawsWarhammer2'
$gamePath = 'C:\Program Files (x86)\Steam\steamapps\common\Total War WARHAMMER II'
$full = "$Version-nvda-automation-preview"
$zip = Join-Path $repo "artifacts\warhammer2-windows-$full.zip"
if (-not (Test-Path -LiteralPath $zip)) { throw "Build not found: $zip" }
if (Get-CimInstance Win32_Process -Filter "Name='Warhammer2.exe'") { throw 'Game is running; no update performed.' }
if (Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*JawsWarhammer2\App\Companion.ps1*' }) {
    throw 'Companion is running; no update performed.'
}
$backup = Join-Path $repo ('work\preinstall-' + $Version + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
[void][IO.Directory]::CreateDirectory($backup)
Copy-Item -LiteralPath (Join-Path $base 'App') -Destination (Join-Path $backup 'App') -Recurse
foreach ($name in @('receipt.json','bridge.jsonl','native-ui-graphics-preview.log','speech-trace.jsonl','native-ui-lord-discovery.jsonl','native-ui-campaign-discovery.jsonl')) {
    $path = Join-Path $base $name
    if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination (Join-Path $backup $name) }
}
Copy-Item -LiteralPath (Join-Path $gamePath 'data\jaws_access.pack') -Destination (Join-Path $backup 'jaws_access.pack')
$package = Join-Path $backup 'package'
Expand-Archive -LiteralPath $zip -DestinationPath $package
if ($Upgrade) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $package "warhammer2-windows-$full\Install.ps1")
} else {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $backup 'App\Uninstall.ps1')
    if ($LASTEXITCODE) { throw "Uninstall failed; backup preserved at $backup" }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $package "warhammer2-windows-$full\Install.ps1") -GamePath $gamePath
}
if ($LASTEXITCODE) { throw "Install failed; backup preserved at $backup" }
$manifest = Get-Content -LiteralPath (Join-Path $base 'App\manifest.json') -Raw | ConvertFrom-Json
if ($manifest.version -ne $full) { throw "Wrong installed version: $($manifest.version)" }
if ((Get-FileHash -LiteralPath (Join-Path $gamePath 'data\jaws_access.pack')).Hash.ToLowerInvariant() -ne $manifest.files.'jaws_access.pack') {
    throw 'Installed pack hash mismatch.'
}
"BACKUP=$backup"
"INSTALLED=$full"
