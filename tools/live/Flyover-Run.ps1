# One timed campaign start for the flyover-freeze comparison: launch, Select
# Lord, Start Campaign, screenshot at -ShotSeconds after starting, close.
# Use campaign-reader-off.flag in %LOCALAPPDATA%\WarhammerAccess to compare
# with the campaign reader off.
param([Parameter(Mandatory=$true)][string]$Version, [Parameter(Mandatory=$true)][string]$Evidence,
    [int]$ShotSeconds = 170)
$ErrorActionPreference = 'Stop'
$live = $PSScriptRoot
function Run([string]$Script, [string[]]$More) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $live $Script) @More }
[void][IO.Directory]::CreateDirectory($Evidence)
Run 'Start-Session.ps1' @('-Direct','-Evidence',$Evidence) | Out-Null
Run 'Wait-Game.ps1' @('-Evidence',$Evidence) | Out-Null
Start-Sleep -Seconds 4
Run 'Reach-Lord.ps1' @('-Version',$Version,'-Evidence',$Evidence) | Out-Null
Start-Sleep -Seconds 4
$started = Get-Date
Run 'Test-StartCampaign.ps1' @('-Version',$Version,'-Evidence',$Evidence,'-WatchSeconds','30') | Out-Null
$left = $ShotSeconds - ((Get-Date) - $started).TotalSeconds
if ($left -gt 0) { Start-Sleep -Seconds ([int]$left) }
$shot = Join-Path $Evidence 'flyover-check.png'
Run 'Capture-Screen.ps1' @('-Path',$shot,'-Scale','0.3') | Out-Null
$status = Join-Path $env:LOCALAPPDATA 'WarhammerAccess\campaign-discovery-status.json'
Run 'Stop-Session.ps1' @('-Evidence',$Evidence) | Out-Null
"SHOT=$shot"
