# Print what the mod said (companion speech trace) after a UTC time, or wait
# for a phrase. The trace keeps older sessions too, so always pass -Since
# (e.g. the time you pressed a key); matching old lines fooled waits before.
#   Read-Speech.ps1 -Since $t                      lines after $t
#   Read-Speech.ps1 -Since $t -Wait 'ready' -Seconds 180
# With -Wait: prints the first matching line, or WAIT_TIMEOUT and exit 1.
param([Parameter(Mandatory=$true)][datetime]$Since, [string]$Wait, [int]$Seconds = 60)
$trace = Join-Path $env:LOCALAPPDATA 'WarhammerAccess\speech-trace.jsonl'
$since = $Since.ToUniversalTime()
function Get-Lines {
    if (-not (Test-Path -LiteralPath $trace)) { return }
    foreach ($line in [IO.File]::ReadAllLines($trace)) {
        try { $o = $line | ConvertFrom-Json } catch { continue }
        $at = [datetime]::Parse($o.time_utc).ToUniversalTime()
        if ($at -gt $since) { [pscustomobject]@{ At = $at; Text = [string]$o.details.text } }
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
