# Repeat camera jumps (Enter on province rows, alternating) and check after
# each that the campaign reader is still ticking. Run with the HUD read and
# HUD reading on (developer verify mode does that). Prints one line per jump.
param([int]$Jumps = 10, [string[]]$Rows = @('Straits of Lothern, list item','Eagle Gate, list item'), [switch]$SkipTab)
$ErrorActionPreference = 'Stop'
$live = $PSScriptRoot
$base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
$status = Join-Path $base 'campaign-discovery-status.json'
function Age { ((Get-Date).ToUniversalTime() - (Get-Item $status).LastWriteTimeUtc).TotalSeconds }
function Phase { try { ((Get-Content $status -Raw) | ConvertFrom-Json).phase } catch { '?' } }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $live 'Click-Screen.ps1') -X 600 -Y 14 | Out-Null
Start-Sleep -Seconds 1
if (-not $SkipTab) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $live 'Press-Item.ps1') -Letter P -Name 'Provinces, tab' -WaitMs 2000 | Out-Null }
for ($j = 1; $j -le $Jumps; $j++) {
    # Wait until the reader is ready again (re-reads take ~30 s in developer mode).
    $until = (Get-Date).AddSeconds(90)
    while ((Get-Date) -lt $until -and (Phase) -notin @('ready','limited')) {
        if ((Age) -gt 10) { "JUMP $j SILENT before jump (status $([int](Age)) s old, phase $(Phase))"; exit 2 }
        Start-Sleep -Seconds 2
    }
    $row = $Rows[($j - 1) % $Rows.Count]
    $letter = $row.Substring(0,1)
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $live 'Press-Item.ps1') -Letter $letter -Name $row -Times 1 -WaitMs 8000 -Tries 25
    if (($out -join "`n") -like '*NOT FOUND*') { "JUMP $j ROW NOT FOUND '$row'"; exit 3 }
    $age = [int](Age)
    if ($age -gt 10) { "JUMP $j SILENT after '$row' (status $age s old, phase $(Phase))"; exit 2 }
    "JUMP $j ok '$row' (status $age s, phase $(Phase))"
}
'ALL JUMPS OK'
