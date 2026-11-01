# After Test-PlayerLaunch.ps1 and Start-Companion.ps1: wait for "ready",
# choose Continue Campaign on the main menu (checked by its spoken name) and
# wait until the campaign map is read. Loads the latest save; ends no turn.
# Exit 1 with the last speech when a step times out.
param([Parameter(Mandatory=$true)][int]$GamePid, [int]$ReadySeconds = 200, [int]$MapSeconds = 300)
$here = $PSScriptRoot
function Speech([datetime]$since, [string]$wait, [int]$seconds) {
    # Prints the matching line; returns only the exit code.
    $lines = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Read-Speech.ps1') -Since $since.ToString('o') -Wait $wait -Seconds $seconds
    $code = $LASTEXITCODE
    $lines | ForEach-Object { Write-Host $_ }
    return $code
}
$game = Get-CimInstance Win32_Process -Filter "ProcessId=$GamePid"
if (-not $game) { throw "Game PID $GamePid is not running." }
if ((Speech $game.CreationDate.ToUniversalTime() ' ready\.' $ReadySeconds) -ne 0) { exit 1 }
$moved = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Drive-Keys.ps1') -GamePid $GamePid -Keys 'Home,Down'
$moved
if (-not ($moved | Select-Object -Last 1) -or ($moved | Select-Object -Last 1) -notmatch 'Continue Campaign, button') { 'Continue Campaign not found on the main menu.'; exit 1 }
$pressed = (Get-Date).ToUniversalTime()
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Drive-Keys.ps1') -GamePid $GamePid -Keys 'Enter'
if ((Speech $pressed 'Campaign map, ' $MapSeconds) -ne 0) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Check-Reader.ps1') -GamePid $GamePid
    exit 1
}
