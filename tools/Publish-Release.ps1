# Publish a built version as the latest GitHub release, so players' "Warhammer
# NVDA Update" shortcut downloads it. Uploads the ZIP and its .sha256 file
# (Update.ps1 refuses a ZIP without a matching checksum).
#   powershell -File tools/Publish-Release.ps1 -Version 0.6.69 -Notes "What changed"
#   powershell -File tools/Publish-Release.ps1 -Version 0.6.69 -NotesFile notes.md   (several lines)
# Refuses unless: the ZIP and checksum exist and match, the version is the one
# in source, HEAD is pushed to origin/main, and the tag does not exist yet.
# Publishing is public: run it only when the owner wants this version out.
param([Parameter(Mandatory=$true)][string]$Version, [string]$Notes, [string]$NotesFile)
$ErrorActionPreference = 'Stop'
if ($NotesFile) { $Notes = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $NotesFile).Path) }
if (-not $Notes) { throw 'Give -Notes "..." or -NotesFile <file>.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$name = "warhammer2-windows-$Version-nvda-automation-preview.zip"
$zip = Join-Path $repo "artifacts\$name"
$sha = "$zip.sha256"
if (-not (Test-Path -LiteralPath $zip) -or -not (Test-Path -LiteralPath $sha)) { throw "Build not found: $name (and .sha256)" }
$recorded = ([IO.File]::ReadAllText($sha)).Trim().Split(' ')[0].ToLowerInvariant()
if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $recorded) { throw 'The ZIP does not match its .sha256 file; rebuild.' }
$sourceVersion = [regex]::Match((Get-Content -LiteralPath (Join-Path $repo 'tools\package-pilot.py') -Raw), 'version = "([0-9.]+)-nvda').Groups[1].Value
if ($Version -ne $sourceVersion) { throw "Source is at $sourceVersion, not $Version." }
Push-Location $repo
try {
    git fetch -q origin main
    if ((git rev-parse HEAD) -ne (git rev-parse origin/main)) { throw 'HEAD is not pushed to origin/main; push first.' }
    if (git tag --list "v$Version") { throw "Tag v$Version already exists." }
    $existing = gh release view "v$Version" 2>$null
    if ($LASTEXITCODE -eq 0) { throw "Release v$Version already exists." }
    gh release create "v$Version" $zip $sha --title "Warhammer accessibility $Version" --notes $Notes --target (git rev-parse HEAD) --latest
    if ($LASTEXITCODE) { throw 'gh release create failed.' }
    gh release view "v$Version" --json url,assets --jq '.url, (.assets[].name)'
} finally { Pop-Location }
