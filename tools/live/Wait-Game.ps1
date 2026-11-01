# Wait for Warhammer2.exe to start and the mod to report a ready endpoint, then
# record the owned game process.
param([Parameter(Mandatory=$true)][string]$Evidence, [int]$TimeoutSeconds = 240)
$ErrorActionPreference = 'Stop'
$base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
$until = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
$game = $null
while (-not $game -and [datetime]::UtcNow -lt $until) {
    $game = Get-CimInstance Win32_Process -Filter "Name='Warhammer2.exe'"
    if (-not $game) { Start-Sleep -Seconds 2 }
}
if (-not $game) { throw 'Warhammer2.exe did not start (launcher not confirmed?).' }
$game | Select-Object ProcessId,Name,ExecutablePath,CommandLine,@{n='CreationDate';e={$_.CreationDate.ToString('o')}} |
    ConvertTo-Json | Set-Content (Join-Path $Evidence 'owned-game.json') -Encoding UTF8
"GAME=$($game.ProcessId)"
if ($game.CommandLine -notlike '*-dx11*') { 'WARNING: game command line lacks -dx11' }
$status = Join-Path $base 'automation-status.tsv'
while ([datetime]::UtcNow -lt $until) {
    if (Test-Path -LiteralPath $status) {
        $fields = (Get-Content -LiteralPath $status -Raw).Split("`t")
        if ($fields.Count -ge 16 -and $fields[13] -eq '1' -and $fields[14] -eq '1' -and
            (Get-Item -LiteralPath $status).LastWriteTimeUtc -gt $game.CreationDate.ToUniversalTime()) {
            "ENDPOINT=ready version=$($fields[1])"; return
        }
    }
    Start-Sleep -Seconds 2
}
throw 'Endpoint did not become ready; check native-ui-graphics-preview.log.'
