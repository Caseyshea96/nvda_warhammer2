# The companion says "The game is not responding." once when the mod's heartbeat stops
# for over 5 s while the game is in front, and "The game is responding again."
# when it comes back. Loading screens / intro movies ('loading'), an old
# heartbeat never seen fresh, and an unfocused game stay quiet. Runs the
# companion's own Watch-GameStall against a stand-in NVDA.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not ('WarhammerAccessibility.NvdaController' -as [type])) {
Add-Type -TypeDefinition @'
namespace WarhammerAccessibility {
    public static class NvdaController {
        public static System.Collections.Generic.List<bool> Interrupts = new System.Collections.Generic.List<bool>();
        public static System.Collections.Generic.List<string> Texts = new System.Collections.Generic.List<string>();
        public static int Speak(string text, bool interrupt) { Texts.Add(text); Interrupts.Add(interrupt); return 0; }
        public static int Braille(string text) { return 0; }
        public static int CancelSpeech() { return 0; }
    }
}
'@
}
$path = Join-Path $root 'companion/Companion.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors -join "`n") }
foreach ($name in 'Write-SpeechTrace','Speak','Watch-GameStall','Read-StateFile','Read-ReaderState','Restore-Speech') {
    $fn = $ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true)
    if (-not $fn) { throw "Function not found: $name" }
    . ([scriptblock]::Create($fn.Extent.Text))
}
function Set-Status([string]$Text) { }
function Log-Error([string]$Text) { throw $Text }
$script:Focused = $true
function Test-GameFocused { return $script:Focused }
$script:GameStarted = [DateTime]::MinValue
function Test-HeartbeatFromRunningGame([DateTime]$WriteUtc) { return $script:GameStarted -le $WriteUtc }
function W { Watch-GameStall (Read-StateFile) }
$base = Join-Path ([IO.Path]::GetTempPath()) ('wh2-stall-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($base)
$state = Join-Path $base 'reader-state.tsv'
$texts = [WarhammerAccessibility.NvdaController]::Texts
$interrupts = [WarhammerAccessibility.NvdaController]::Interrupts
function Reset { $script:StateFile = $null; $script:GameStarted = [DateTime]::MinValue; $script:StallSeen = $false; $script:StallScreen = $null; $script:StallSaid = $false; $texts.Clear(); $interrupts.Clear(); $script:Focused = $true
    if (Test-Path $state) { Remove-Item $state } }
function Beat([string]$Screen, [double]$AgeSeconds = 0) {
    [IO.File]::WriteAllText($state, "WH2READER1`tcampaign:player:x`t1`t1`t$Screen`n")
    (Get-Item $state).LastWriteTimeUtc = [DateTime]::UtcNow.AddSeconds(-$AgeSeconds)
}
function Age([double]$AgeSeconds) { (Get-Item $state).LastWriteTimeUtc = [DateTime]::UtcNow.AddSeconds(-$AgeSeconds) }
function Said { return ($texts -join ' | ') }
try {
    $TraceSpeech = $false; $Console = $false
    $script:Muted = $false; $script:NvdaConnected = $true; $script:SpeechRequestId = 0L

    Reset; W
    if ($texts.Count) { throw 'No heartbeat file: nothing to say' }

    Reset; Beat 'campaign'; W; Age 4; W
    if ($texts.Count) { throw 'A 4 s gap (camera jump) is not busy: ' + (Said) }
    Age 6; W
    if ((Said) -ne 'The game is not responding.' -or $interrupts[0] -ne $false) { throw 'Busy after 5 s, queued: ' + (Said) }
    Age 9; W; Age 20; W
    if ($texts.Count -ne 1) { throw 'Busy is said once per stall: ' + (Said) }
    Beat 'campaign'; W
    if ((Said) -ne 'The game is not responding. | The game is responding again.' -or $interrupts[1] -ne $false) { throw 'Back again: ' + (Said) }
    Beat 'campaign'; W
    if ($texts.Count -ne 2) { throw 'Responding again is said once: ' + (Said) }
    Age 7; W
    if ($texts.Count -ne 3 -or $texts[2] -ne 'The game is not responding.') { throw 'A second stall is announced again: ' + (Said) }
    'PASS: busy after 5 s once, responding again once, a new stall again'

    Reset; Beat 'campaign'; W; $script:Focused = $false; Age 8; W
    if ($texts.Count) { throw 'Game not in front: quiet' }
    $script:Focused = $true; W
    if ((Said) -ne 'The game is not responding.') { throw 'Back in front during the stall: busy: ' + (Said) }

    Reset; Beat 'loading'; W; Age 60; W
    if ($texts.Count) { throw 'Loading screen / intro movies: quiet: ' + (Said) }
    Beat 'campaign'; W
    if ($texts.Count) { throw 'Arriving after loading says nothing extra: ' + (Said) }

    Reset; Beat 'campaign' 40; W
    if ($texts.Count) { throw 'A heartbeat never seen fresh (old session) is not a stall' }

    Reset; Beat 'campaign'; W; Age 700; W
    if ($texts.Count) { throw 'A heartbeat over 10 minutes old is not announced' }

    Reset; Beat 'main'; W; Age 6; W; Beat 'loading'; W
    if ((Said) -ne 'The game is not responding.') { throw 'Busy then loading: no "responding again": ' + (Said) }
    'PASS: unfocused, loading/movies, old heartbeat, over 10 minutes and busy-then-loading stay quiet'
    # 0.6.75: a heartbeat written before the running game started (a crash, then a relaunch): quiet.
    Reset; Beat 'campaign'; W; $script:GameStarted = [DateTime]::UtcNow.AddSeconds(1); Age 8; W
    if ($texts.Count) { throw 'Heartbeat from an earlier game run is not a stall: ' + (Said) }
    # 0.6.75: a locked or half-written file keeps the last good contents (keys stay on).
    Reset; Beat 'campaign'; $first = Read-StateFile
    $lock = [IO.File]::Open($state, 'Open', 'ReadWrite', 'None')
    try { $locked = Read-StateFile } finally { $lock.Dispose() }
    if (-not $locked -or $locked.Fields[4] -ne 'campaign' -or -not (Read-ReaderState $locked)) { throw 'A locked file must keep the keys on' }
    [IO.File]::WriteAllText($state, 'WH2READ')
    $half = Read-StateFile
    if (-not $half -or $half.Fields[4] -ne 'campaign' -or -not (Read-ReaderState $half)) { throw 'A half-written file must keep the keys on' }
    Beat 'campaign' 20
    if (Read-ReaderState (Read-StateFile)) { throw 'A heartbeat over 15 s old releases the keys' }
    [IO.File]::WriteAllText($state, "WH2READER1`ts`t1`t0`tcampaign`n")
    if (Read-ReaderState (Read-StateFile)) { throw 'Map controls (flag 0) release the keys' }
    'PASS: earlier-run heartbeat quiet; locked or half-written file keeps the keys; old heartbeat and map controls release them'
    # 0.6.75: speech reconnects by itself (every 5 s at most) after an NVDA error.
    Reset; $script:NextReconnect = [DateTime]::MinValue; $script:Tries = 0; $script:NvdaUp = $false
    function Connect-ScreenReader { $script:Tries++; $script:NvdaConnected = $script:NvdaUp; return $script:NvdaUp }
    $script:NvdaConnected = $false; Restore-Speech; Restore-Speech
    if ($script:Tries -ne 1 -or $texts.Count) { throw 'NVDA down: one try per 5 s, nothing said' }
    $script:NvdaUp = $true; $script:NextReconnect = [DateTime]::MinValue; Restore-Speech
    if ((Said) -ne 'Speech reconnected.' -or -not $script:NvdaConnected) { throw 'Reconnected and said so: ' + (Said) }
    Restore-Speech; if ($script:Tries -ne 2) { throw 'No more tries while connected' }
    'PASS: NVDA reconnects by itself every 5 s and says so'
} finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
