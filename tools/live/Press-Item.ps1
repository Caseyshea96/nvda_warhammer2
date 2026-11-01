# In the campaign HUD reader: press a letter until the spoken item starts with
# -Name, then press Enter (-Times, for confirmations). Prints what was spoken.
param([Parameter(Mandatory=$true)][string]$Letter, [Parameter(Mandatory=$true)][string]$Name,
    [int]$Times = 1, [int]$WaitMs = 6000, [int]$Tries = 10)
$bridge = Join-Path $env:LOCALAPPDATA 'WarhammerAccess\bridge.jsonl'
$keys = Join-Path $PSScriptRoot 'Send-Keys.ps1'
function Last { (Get-Content $bridge -Encoding UTF8 -Tail 1 | ConvertFrom-Json).text }
$start = (Get-Content $bridge).Count
for ($i = 0; $i -lt $Tries; $i++) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $keys -Keys $Letter -DelayMs 1000 | Out-Null
    if ((Last) -like "$Name*") { break }
}
if ((Last) -notlike "$Name*") { "NOT FOUND: $Name"; exit 1 }
for ($n = 0; $n -lt $Times; $n++) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $keys -Keys Enter -DelayMs 1500 | Out-Null }
Start-Sleep -Milliseconds $WaitMs
Get-Content $bridge -Encoding UTF8 | Select-Object -Skip $start | ForEach-Object { ($_ | ConvertFrom-Json).text } |
    Where-Object { $_ -notlike "$Letter*, *of *" -or $_ -like "$Name*" } | ForEach-Object { $_.Substring(0, [Math]::Min(110, $_.Length)) }
