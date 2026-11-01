# Screenshot the screen every few seconds from game launch until the mod's
# endpoint is ready plus a margin, to see whether startup movies play.
param([Parameter(Mandatory=$true)][string]$Evidence, [int]$IntervalSeconds = 3, [int]$AfterReadySeconds = 12, [int]$TimeoutSeconds = 240)
$ErrorActionPreference = 'Stop'
$status = Join-Path $env:LOCALAPPDATA 'WarhammerAccess\automation-status.tsv'
$start = Get-Date; $ready = $null; $n = 0
while (((Get-Date) - $start).TotalSeconds -lt $TimeoutSeconds) {
    $game = Get-CimInstance Win32_Process -Filter "Name='Warhammer2.exe'"
    if ($game -and -not $ready -and (Test-Path $status) -and (Get-Item $status).LastWriteTimeUtc -gt $game.CreationDate.ToUniversalTime()) {
        $f = (Get-Content $status -Raw).Split("`t"); if ($f.Count -ge 16 -and $f[13] -eq '1') { $ready = Get-Date }
    }
    $t = [int]((Get-Date) - $start).TotalSeconds
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Capture-Screen.ps1') -Path (Join-Path $Evidence ('startup-{0:D3}s.png' -f $t)) -Scale 0.25 | Out-Null
    $n++
    if ($ready -and ((Get-Date) - $ready).TotalSeconds -ge $AfterReadySeconds) { break }
    Start-Sleep -Seconds $IntervalSeconds
}
"shots=$n ready_at=$(if ($ready) { [int]($ready - $start).TotalSeconds } else { 'never' })s"
