# Speech that answers a key press interrupts NVDA; anything else (notifications,
# "arrived at ...") queues behind it, so it never cuts off a result. Runs the
# companion's own Speak / Send-MenuKey / Read-Bridge against a stand-in NVDA.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
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
. (Join-Path $root 'companion/Protocol.ps1')
$path = Join-Path $root 'companion/Companion.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors -join "`n") }
foreach ($name in 'Write-SpeechTrace','Speak','Write-AtomicText','Write-MenuKeys','Send-MenuKey','Read-Bridge') {
    $fn = $ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true)
    if (-not $fn) { throw "Function not found: $name" }
    . ([scriptblock]::Create($fn.Extent.Text))
}
function Set-Status([string]$Text) { }
function Log-Error([string]$Text) { throw $Text }
$base = Join-Path ([IO.Path]::GetTempPath()) ('wh2-interrupt-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($base)
try {
    $TraceSpeech = $false; $Console = $false
    $script:Muted = $false; $script:NvdaConnected = $true; $script:SpeechRequestId = 0L
    $script:MenuKeysObj = $null; $script:KeyOwner = 'owner'; $script:KeySeq = 0; $script:KeyPending = $false
    $script:KeyRing = New-Object System.Collections.Generic.List[string]
    $script:Reader = [pscustomobject]@{ session = 's'; generation = '1'; screen = 'campaign' }
    $script:Lines = New-Object System.Collections.Generic.List[string]
    $tail = New-Object psobject
    $tail | Add-Member -MemberType ScriptMethod -Name Poll -Value { $out = $script:Lines.ToArray(); $script:Lines.Clear(); return ,$out }
    $tails = @($tail)
    $states = @((New-ProtocolState))
    $seq = 0
    function Say([string]$Text) { $script:seq++; $script:Lines.Add('{"version":1,"session":"game","sequence":' + $script:seq + ',"context":"campaign","kind":"speech","text":"' + $Text + '"}') }
    $calls = [WarhammerAccessibility.NvdaController]::Interrupts
    Send-MenuKey 'activate'; Say 'Moving to Lothern.'; Read-Bridge
    if ($calls.Count -ne 1 -or $calls[0] -ne $true) { throw 'Speech answering a key must interrupt' }
    Say 'Research available'; Read-Bridge
    if ($calls.Count -ne 2 -or $calls[1] -ne $false) { throw 'A notification must queue, not cut off the result' }
    Say 'Tyrion arrived at Lothern.'; Read-Bridge
    if ($calls[2] -ne $false) { throw 'An unsolicited result must queue' }
    Send-MenuKey 'next'; Say 'Lothern, button, 1 of 16'; Read-Bridge
    if ($calls[3] -ne $true) { throw 'The next key answer interrupts again' }
    Speak 'Speech enabled.' -Force
    if ($calls[4] -ne $true) { throw 'Direct calls (tests, mute) keep interrupting' }
    'PASS: speech answering a key interrupts; notifications and unsolicited results queue'
} finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
