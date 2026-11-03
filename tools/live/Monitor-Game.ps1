# Samples once a second until the game exits: reader heartbeat age, game
# responding, game CPU, game GPU 3D use, CPU performance (throttling), ACPI
# temperature (coarse). Writes CSV to -Out. Run it hidden next to a live
# session, outside the sandbox (performance counters). See
# docs/FREEZE_INVESTIGATION_2026-11-03.md.
param([Parameter(Mandatory=$true)][int]$GamePid, [Parameter(Mandatory=$true)][string]$Out)
$state = Join-Path $env:LOCALAPPDATA 'WarhammerAccess\reader-state.tsv'
'time,reader_age_s,responding,game_cpu_pct,gpu3d_pct,gpu_all_pct,cpu_perf_pct,temp_c,game_shared_mb' | Set-Content -Encoding ascii $Out
$cores = [Environment]::ProcessorCount
$game = Get-Process -Id $GamePid -ErrorAction Stop
$lastCpu = $game.CPU; $lastT = Get-Date
while ($true) {
    $game = Get-Process -Id $GamePid -ErrorAction SilentlyContinue
    if (-not $game) { break }
    $paths = @("\GPU Engine(pid_$GamePid*engtype_3D)\Utilization Percentage",
               "\GPU Engine(pid_$GamePid*)\Utilization Percentage",
               '\Processor Information(_Total)\% Processor Performance',
               '\Thermal Zone Information(*)\Temperature',
               "\GPU Process Memory(pid_$GamePid*)\Shared Usage")
    $s = (Get-Counter -Counter $paths -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue).CounterSamples
    $g3d = ($s | Where-Object { $_.Path -match 'engtype_3d\)' } | Measure-Object CookedValue -Sum).Sum
    $gall = ($s | Where-Object { $_.Path -match 'gpu engine' } | Measure-Object CookedValue -Sum).Sum
    $perf = ($s | Where-Object { $_.Path -match 'processor performance' } | Select-Object -First 1).CookedValue
    $temp = ($s | Where-Object { $_.Path -match 'temperature' } | Measure-Object CookedValue -Maximum).Maximum
    $mem = ($s | Where-Object { $_.Path -match 'shared usage' } | Measure-Object CookedValue -Sum).Sum
    $now = Get-Date; $game.Refresh()
    $cpu = [math]::Round(100 * ($game.CPU - $lastCpu) / ($now - $lastT).TotalSeconds / $cores, 1)
    $lastCpu = $game.CPU; $lastT = $now
    $fi = New-Object IO.FileInfo $state
    $age = if ($fi.Exists) { [math]::Round(($now - $fi.LastWriteTime).TotalSeconds, 1) } else { -1 }
    '{0:HH:mm:ss},{1},{2},{3},{4:F0},{5:F0},{6:F0},{7:F0},{8:F0}' -f $now, $age, $game.Responding, $cpu, $g3d, $gall, $perf, ($temp - 273), ($mem / 1MB) |
        Add-Content -Encoding ascii $Out
}
