# Run the installed companion's Launch-Game function on its own (speech
# stubbed), to test the player's one-step launch when NVDA is not running.
# Records the started game process in <Evidence>/owned-game.json.
param([Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
[void][IO.Directory]::CreateDirectory($Evidence)
if (Get-Process -Name Warhammer2 -ErrorAction SilentlyContinue) { throw 'Game already running; close it first.' }
$app = Join-Path $env:LOCALAPPDATA 'WarhammerAccess\App'
$source = [IO.File]::ReadAllText((Join-Path $app 'Companion.ps1'))
$start = $source.IndexOf('    function Launch-Game {')
$end = $source.IndexOf("`n    }", $start)
if ($start -lt 0 -or $end -lt 0) { throw 'Launch-Game not found in the installed companion.' }
$function = $source.Substring($start, $end - $start + 6)
$script:Spoken = @()
function Speak([string]$Text, [switch]$Force) { $script:Spoken += $Text }
function Set-Status([string]$Text) { }
function Connect-ScreenReader { $true }
$ScreenReader = 'Nvda'; $script:NvdaConnected = $true; $readerName = 'NVDA'
$base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
$GamePath = (Get-Content -LiteralPath (Join-Path $app 'config.json') -Raw | ConvertFrom-Json).game_path
. ([ScriptBlock]::Create($function))
$result = Launch-Game
"LAUNCH=$result"
$script:Spoken | ForEach-Object { "SPOKE=$_" }
"MODS=" + ((Get-Content -LiteralPath (Join-Path $base 'nvda_mods.txt') -ErrorAction SilentlyContinue) -join ' | ')
$until = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $until -and -not (Get-CimInstance Win32_Process -Filter "Name='Warhammer2.exe'")) { Start-Sleep -Seconds 1 }
$game = Get-CimInstance Win32_Process -Filter "Name='Warhammer2.exe'"
if (-not $game) { throw 'The game did not start.' }
$game | Select-Object ProcessId,Name,ExecutablePath,CommandLine,@{n='CreationDate';e={$_.CreationDate.ToString('o')}} |
    ConvertTo-Json | Set-Content (Join-Path $Evidence 'owned-game.json') -Encoding UTF8
"GAME=$($game.ProcessId)"
"COMMAND=$($game.CommandLine)"
