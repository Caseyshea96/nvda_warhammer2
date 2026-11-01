# Start the installed companion hidden, as a player would (menu keys, speech
# trace on), and record it in <Evidence>/owned-companion.json in the format
# Stop-Session.ps1 checks (PID, executable path, ISO start time).
# Use after Test-PlayerLaunch.ps1 (player-mode tests, no lease).
param([Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
[void][IO.Directory]::CreateDirectory($Evidence)
$app = Join-Path $env:LOCALAPPDATA 'WarhammerAccess\App\Companion.ps1'
if (-not (Test-Path -LiteralPath $app)) { throw 'The companion is not installed.' }
$running = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*WarhammerAccess\App\Companion.ps1*' }
if ($running) { throw ('A companion is already running (PID ' + (($running | ForEach-Object ProcessId) -join ', ') + ').') }
$p = Start-Process powershell.exe -WindowStyle Hidden -PassThru -ArgumentList @(
    '-NoProfile','-Sta','-ExecutionPolicy','Bypass','-File',$app,'-MenuKeys','-TraceSpeech')
$until = (Get-Date).AddSeconds(10)
do { Start-Sleep -Milliseconds 250; $c = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" } while (-not $c -and (Get-Date) -lt $until)
if (-not $c) { throw 'The companion did not start.' }
[pscustomobject]@{ ProcessId = $c.ProcessId; Name = $c.Name; ExecutablePath = $c.ExecutablePath
    CommandLine = $c.CommandLine; CreationDate = $c.CreationDate.ToString('o') } |
    ConvertTo-Json | Set-Content (Join-Path $Evidence 'owned-companion.json') -Encoding UTF8
"COMPANION=$($p.Id)"
