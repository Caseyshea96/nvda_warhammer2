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
foreach ($name in 'Write-SpeechTrace','Speak','Watch-GameStall') {
    $fn = $ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true)
    if (-not $fn) { throw "Function not found: $name" }
    . ([scriptblock]::Create($fn.Extent.Text))
}
function Set-Status([string]$Text) { }
function Log-Error([string]$Text) { throw $Text }
$script:Focused = $true
function Test-GameFocused { return $script:Focused }
$base = Join-Path ([IO.Path]::GetTempPath()) ('wh2-stall-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($base)
$state = Join-Path $base 'reader-state.tsv'
$texts = [WarhammerAccessibility.NvdaController]::Texts
$interrupts = [WarhammerAccessibility.NvdaController]::Interrupts
function Reset { $script:StallSeen = $false; $script:StallScreen = $null; $script:StallSaid = $false; $texts.Clear(); $interrupts.Clear(); $script:Focused = $true
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

    Reset; Watch-GameStall
    if ($texts.Count) { throw 'No heartbeat file: nothing to say' }

    Reset; Beat 'campaign'; Watch-GameStall; Age 4; Watch-GameStall
    if ($texts.Count) { throw 'A 4 s gap (camera jump) is not busy: ' + (Said) }
    Age 6; Watch-GameStall
    if ((Said) -ne 'The game is not responding.' -or $interrupts[0] -ne $false) { throw 'Busy after 5 s, queued: ' + (Said) }
    Age 9; Watch-GameStall; Age 20; Watch-GameStall
    if ($texts.Count -ne 1) { throw 'Busy is said once per stall: ' + (Said) }
    Beat 'campaign'; Watch-GameStall
    if ((Said) -ne 'The game is not responding. | The game is responding again.' -or $interrupts[1] -ne $false) { throw 'Back again: ' + (Said) }
    Beat 'campaign'; Watch-GameStall
    if ($texts.Count -ne 2) { throw 'Responding again is said once: ' + (Said) }
    Age 7; Watch-GameStall
    if ($texts.Count -ne 3 -or $texts[2] -ne 'The game is not responding.') { throw 'A second stall is announced again: ' + (Said) }
    'PASS: busy after 5 s once, responding again once, a new stall again'

    Reset; Beat 'campaign'; Watch-GameStall; $script:Focused = $false; Age 8; Watch-GameStall
    if ($texts.Count) { throw 'Game not in front: quiet' }
    $script:Focused = $true; Watch-GameStall
    if ((Said) -ne 'The game is not responding.') { throw 'Back in front during the stall: busy: ' + (Said) }

    Reset; Beat 'loading'; Watch-GameStall; Age 60; Watch-GameStall
    if ($texts.Count) { throw 'Loading screen / intro movies: quiet: ' + (Said) }
    Beat 'campaign'; Watch-GameStall
    if ($texts.Count) { throw 'Arriving after loading says nothing extra: ' + (Said) }

    Reset; Beat 'campaign' 40; Watch-GameStall
    if ($texts.Count) { throw 'A heartbeat never seen fresh (old session) is not a stall' }

    Reset; Beat 'campaign'; Watch-GameStall; Age 700; Watch-GameStall
    if ($texts.Count) { throw 'A heartbeat over 10 minutes old is not announced' }

    Reset; Beat 'main'; Watch-GameStall; Age 6; Watch-GameStall; Beat 'loading'; Watch-GameStall
    if ((Said) -ne 'The game is not responding.') { throw 'Busy then loading: no "responding again": ' + (Said) }
    'PASS: unfocused, loading/movies, old heartbeat, over 10 minutes and busy-then-loading stay quiet'
} finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
