# Press companion menu keys one at a time with the game focused, then print
# what the mod said since the first key. Key names as in Send-Keys.ps1
# (Down Up Home End Enter Backspace F6 ShiftF6 F7, letters...).
#   Drive-Keys.ps1 -GamePid 1234 -Keys F6
#   Drive-Keys.ps1 -GamePid 1234 -Keys 'F7,Home,Enter,Enter' -WaitMs 1200
# Keys reach the companion only while the reader's heartbeat is fresh; check
# with Check-Reader.ps1 when nothing is said.
param([Parameter(Mandatory=$true)][int]$GamePid, [Parameter(Mandatory=$true)][string]$Keys, [int]$WaitMs = 1500, [int]$SettleMs = 0)
$since = (Get-Date).ToUniversalTime()
$shell = New-Object -ComObject WScript.Shell
foreach ($key in ($Keys -split ',' | Where-Object { $_ })) {
    if (-not $shell.AppActivate($GamePid)) { "WARNING: could not focus game PID $GamePid" }
    Start-Sleep -Milliseconds 400
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Send-Keys.ps1') -Keys $key | Out-Null
    Start-Sleep -Milliseconds $WaitMs
}
if ($SettleMs -gt 0) { Start-Sleep -Milliseconds $SettleMs }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Read-Speech.ps1') -Since $since.ToString('o')
