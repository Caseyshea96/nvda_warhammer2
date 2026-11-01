# Is the mod's reader alive? Screenshots cannot tell: a still campaign map
# looks the same as a frozen one. The reader writes reader-state.tsv about
# once a second; over 3 s old means stalled, and the companion drops its keys
# when it is over 15 s old.
# Prints READER=alive|silent, its age, the screen it reports, whether the
# game window responds, and the game's CPU use over 3 s (one full core with
# a silent reader = the old frozen-timer state).
param([int]$GamePid)
$base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
$state = New-Object IO.FileInfo (Join-Path $base 'reader-state.tsv')
$age = if ($state.Exists) { [int]([datetime]::Now - $state.LastWriteTime).TotalSeconds } else { -1 }
$screen = if ($state.Exists) { ([IO.File]::ReadAllText($state.FullName)).TrimEnd().Split("`t")[-1] } else { 'none' }
$alive = $state.Exists -and $age -le 3
"READER=$(if ($alive) { 'alive' } else { 'silent' }) AGE=${age}s SCREEN=$screen"
$game = if ($GamePid) { Get-Process -Id $GamePid -ErrorAction SilentlyContinue } else { Get-Process Warhammer2 -ErrorAction SilentlyContinue | Select-Object -First 1 }
if (-not $game) { 'GAME=not running'; exit 0 }
$cpu = $game.CPU; Start-Sleep -Seconds 3; $game.Refresh()
"GAME=$($game.Id) RESPONDING=$($game.Responding) CPU3S=$([math]::Round($game.CPU - $cpu,1))"
