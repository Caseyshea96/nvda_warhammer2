# Simulates a stalled game for the companion's "The game is busy." check:
# pauses every thread of the owned game process for -Seconds, then resumes it
# (always, also on errors). Use only on the game PID this session launched.
param([Parameter(Mandatory=$true)][int]$GamePid, [ValidateRange(1,60)][int]$Seconds = 8)
$ErrorActionPreference = 'Stop'
$game = Get-Process -Id $GamePid
if ($game.ProcessName -ne 'Warhammer2') { throw "PID $GamePid is not Warhammer2." }
if (-not ('WarhammerTest.Pause' -as [type])) {
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
namespace WarhammerTest { public static class Pause {
    [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr h);
    [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr h);
} }
'@
}
$paused = [WarhammerTest.Pause]::NtSuspendProcess($game.Handle)
if ($paused -ne 0) { throw "Pause failed: $paused" }
"PAUSED=$((Get-Date).ToUniversalTime().ToString('HH:mm:ss'))"
try { Start-Sleep -Seconds $Seconds }
finally { $resumed = [WarhammerTest.Pause]::NtResumeProcess($game.Handle); "RESUMED=$((Get-Date).ToUniversalTime().ToString('HH:mm:ss')) CODE=$resumed" }
