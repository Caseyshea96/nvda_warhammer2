# Print what the mod said (companion speech trace) after a UTC time, or wait
# for a phrase. The trace keeps older sessions too, so always pass -Since
# (e.g. the time you pressed a key); matching old lines fooled waits before.
#   Read-Speech.ps1 -Since $t                      lines after $t
#   Read-Speech.ps1 -Since $t -Wait 'ready' -Seconds 180
# With -Wait: prints the first matching line, or WAIT_TIMEOUT and exit 1.
param([Parameter(Mandatory=$true)][datetime]$Since, [string]$Wait, [int]$Seconds = 60)
$trace = Join-Path $env:LOCALAPPDATA 'WarhammerAccess\speech-trace.jsonl'
$since = $Since.ToUniversalTime()
# The companion writes time_utc in round-trip form (2026-11-01T18:24:44.4261754Z),
# so old lines are skipped by comparing text; only newer lines are parsed.
$sinceText = $since.ToString('yyyy-MM-ddTHH:mm:ss.fffffff') + 'Z'
function Get-Lines {
    if (-not (Test-Path -LiteralPath $trace)) { return }
    foreach ($line in [IO.File]::ReadAllLines($trace)) {
        $m = [regex]::Match($line, '"time_utc":"([^"]+)"')
        if (-not $m.Success -or [string]::CompareOrdinal($m.Groups[1].Value, $sinceText) -le 0) { continue }
        try { $o = $line | ConvertFrom-Json } catch { continue }
        [pscustomobject]@{ At = [datetime]::Parse($o.time_utc).ToUniversalTime(); Text = [string]$o.details.text }
    }
}
if (-not $Wait) { Get-Lines | ForEach-Object { $_.At.ToString('HH:mm:ss') + '  ' + $_.Text }; exit 0 }
$until = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $until) {
    $hit = Get-Lines | Where-Object { $_.Text -match $Wait } | Select-Object -First 1
    if ($hit) { $hit.At.ToString('HH:mm:ss') + '  ' + $hit.Text; exit 0 }
    Start-Sleep -Seconds 2
}
"WAIT_TIMEOUT $Wait"
exit 1
