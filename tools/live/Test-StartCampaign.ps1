# On Select Lord: start the campaign through the reader (the first request
# asks, the second starts), then watch the game leave the menus: the mod's
# reader-state heartbeat stops and screenshots show loading and the campaign.
param(
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$Evidence,
    [int]$WatchSeconds = 150
)
$ErrorActionPreference = 'Stop'
$base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
$helper = Join-Path $base 'App\Automation.ps1'
$log = Join-Path $base 'native-ui-graphics-preview.log'
$full = "$Version-nvda-automation-preview"
function Client([string[]]$More) {
    $response = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $helper @More
    $code = $LASTEXITCODE
    return @($code, (($response -join "`n") | ConvertFrom-Json))
}
# Reach the Start Campaign entry (Next pages discovery itself).
for ($i = 0; $i -lt 120; $i++) {
    $code, $s = Client @('-Action','Next')
    if ($code -or $s.version -ne $full -or $s.screen -ne 'lord_discovery') { throw "Reader unavailable (screen=$($s.screen))." }
    if ($s.label -eq 'Start Campaign') { break }
}
if ($s.label -ne 'Start Campaign') { throw 'Start Campaign entry not found.' }
$before = @(Get-Content $log | Where-Object { $_ -like 'activation.dispatch*' }).Count
$code, $r = Client @('-Action','Activate','-ExpectedSelectedKey',$s.selected_key,'-DoubleConfirm')
$r | ConvertTo-Json | Set-Content (Join-Path $Evidence 'start-campaign.json') -Encoding UTF8
if ($code -or $r.result -ne 'input-sent') { throw "Start Campaign was not sent (exit $code, result $($r.result)); no retry." }
$prompt = @(Get-Content (Join-Path $base 'bridge.jsonl') -Encoding UTF8 | ForEach-Object { ($_ | ConvertFrom-Json).text } | Where-Object { $_ -like 'Start the campaign*' })
if (-not $prompt) { throw 'The confirmation prompt was not spoken.' }
"PROMPT: $($prompt[-1])"
if (-not (Select-String $log -Pattern "activation.dispatch`tstring`tStart Campaign" -Quiet)) { throw 'No Start Campaign dispatch logged.' }
$after = @(Get-Content $log | Where-Object { $_ -like 'activation.dispatch*' }).Count
if ($after -ne $before + 1) { throw "Expected exactly one new native click ($before -> $after)." }
'PASS: Start Campaign asked, then one native click was sent.'
# Watch the transition. The frontend heartbeat stops when the campaign loads.
$state = Join-Path $base 'reader-state.tsv'
$start = Get-Date; $left = $null
while (((Get-Date) - $start).TotalSeconds -lt $WatchSeconds) {
    $t = [int]((Get-Date) - $start).TotalSeconds
    if (-not (Get-Process -Name Warhammer2 -ErrorAction SilentlyContinue)) { throw "The game exited ${t}s after Start Campaign." }
    $age = ((Get-Date).ToUniversalTime() - (Get-Item $state).LastWriteTimeUtc).TotalSeconds
    if (-not $left -and $age -gt 5) { $left = $t; "LEFT_FRONTEND after ~${t}s (heartbeat stopped)" }
    if ($t % 10 -lt 3) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Capture-Screen.ps1') -Path (Join-Path $Evidence ('campaign-{0:D3}s.png' -f $t)) -Scale 0.4 | Out-Null
    }
    Start-Sleep -Seconds 3
}
if (-not $left) { throw 'The menus never stopped (heartbeat still fresh); the campaign did not load.' }
"WATCHED ${WatchSeconds}s; game still running."
