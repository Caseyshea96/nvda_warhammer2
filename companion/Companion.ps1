param(
    [string]$GamePath,
    [switch]$Launch,
    [switch]$Console,
    [string]$ReplayFile,
    [switch]$NoHotkeys,  # accepted for older shortcuts; the companion has no global hotkeys
    [switch]$MenuKeys,
    [switch]$TraceSpeech,
    [ValidateSet('Nvda')][string]$ScreenReader = 'Nvda'  # NVDA only
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Protocol.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Bridge.cs')

if ($ReplayFile) {
    $state = New-ProtocolState
    foreach ($line in [IO.File]::ReadLines((Resolve-Path -LiteralPath $ReplayFile).Path)) {
        $r = Convert-BridgeRecord $line $state
        if ($null -ne $r) { Write-Output ($r.context + ': ' + $r.text) }
    }
    exit 0
}
$buildVersion = 'development'
$packageManifestPath = Join-Path $PSScriptRoot 'manifest.json'
$packageManifest = $null
if (Test-Path -LiteralPath $packageManifestPath) {
    $packageManifest = Get-Content -LiteralPath $packageManifestPath -Raw | ConvertFrom-Json
    if ($packageManifest.version) { $buildVersion = [string]$packageManifest.version }
    if ($packageManifest.stage -eq 'frontend-activation-preview') { $TraceSpeech = $true }
}
if (-not $GamePath) {
    $configPath = Join-Path $PSScriptRoot 'config.json'
    if (Test-Path -LiteralPath $configPath) { $GamePath = (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).game_path }
}
if (-not $GamePath -or -not (Test-Path -LiteralPath (Join-Path $GamePath 'Warhammer2.exe'))) {
    throw 'Game path missing. Run the installer or supply -GamePath.'
}
$base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
[void][IO.Directory]::CreateDirectory($base)
$lockStream = $null
try { $lockStream = [IO.File]::Open((Join-Path $base 'companion.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
catch { Write-Host 'The companion is already running. Close its window before starting another.'; exit 1 }

try {
    $script:NvdaConnected = $false
    $script:Muted = $false
    $script:Last = 'Warhammer accessibility is ready.'
    $script:StatusText = ''; $script:StatusControl = $null
    $script:LastError = ''; $script:LastErrorTime = [DateTime]::MinValue
    $diagnostic = Join-Path $base 'companion.log'
    $script:SpeechRequestId = 0L
    $speechTrace = Join-Path $base 'speech-trace.jsonl'
    function Write-SpeechTrace([string]$Event, [hashtable]$Details) {
        if (-not $TraceSpeech) { return }
        try {
            if ((Test-Path -LiteralPath $speechTrace) -and (Get-Item -LiteralPath $speechTrace).Length -gt 1048576) {
                Move-Item -LiteralPath $speechTrace -Destination ($speechTrace + '.previous') -Force
            }
            $record = @{ time_utc = [DateTime]::UtcNow.ToString('o'); process_id = $PID;
                event = $Event; request_id = $script:SpeechRequestId; details = $Details }
            Add-Content -LiteralPath $speechTrace -Value ($record | ConvertTo-Json -Compress -Depth 4) -Encoding UTF8
        } catch { } # Diagnostic I/O must never prevent speech.
    }
    if ((Test-Path -LiteralPath $diagnostic) -and (Get-Item -LiteralPath $diagnostic).Length -gt 1048576) {
        Move-Item -LiteralPath $diagnostic -Destination ($diagnostic + '.previous') -Force
    }
    function Set-Status([string]$Text) {
        if ($script:StatusText -eq $Text) { return }
        $script:StatusText = $Text
        if ($script:StatusControl) { $script:StatusControl.Text = $Text }
        Write-Host $Text
    }
    function Log-Error([string]$Text) {
        if ($script:LastError -eq $Text -and ([DateTime]::UtcNow - $script:LastErrorTime).TotalSeconds -lt 30) { return }
        $script:LastError = $Text; $script:LastErrorTime = [DateTime]::UtcNow
        try {
            if ((Test-Path -LiteralPath $diagnostic) -and (Get-Item -LiteralPath $diagnostic).Length -gt 1048576) {
                Move-Item -LiteralPath $diagnostic -Destination ($diagnostic + '.previous') -Force
            }
            Add-Content -LiteralPath $diagnostic -Value ((Get-Date -Format o) + ' ' + $Text) -Encoding UTF8
        } catch {}
    }
    function Connect-ScreenReader {
        if ($Console) { return $true }
        try {
            if (-not ('WarhammerAccessibility.NvdaController' -as [type])) {
                Add-Type -Path (Join-Path $PSScriptRoot 'NvdaController.cs')
            }
            [WarhammerAccessibility.NvdaController]::Initialize((Join-Path $PSScriptRoot 'nvdaControllerClient.dll'))
            $code = [WarhammerAccessibility.NvdaController]::TestIfRunning()
            if ($code -ne 0) { throw [ComponentModel.Win32Exception]::new($code) }
            $script:NvdaConnected = $true
            Set-Status 'NVDA connected. Waiting for game messages.'
            return $true
        } catch {
            $script:NvdaConnected = $false
            Set-Status 'NVDA unavailable. Start NVDA, then choose Test NVDA to reconnect.'
            Log-Error $_.Exception.Message
            return $false
        }
    }
    # Interrupt: speech that answers a key press cuts off what was being said,
    # as a screen reader does when focus moves; anything else (a notification,
    # "arrived at ...") waits its turn, so it never cuts off a result.
    function Speak([string]$Text, [switch]$Force, [bool]$Interrupt = $true) {
        $script:SpeechRequestId++
        Write-SpeechTrace 'request' @{ text = $Text; characters = $Text.Length; reader = 'Nvda';
            muted = [bool]$script:Muted; forced = [bool]$Force; connected = [bool]$script:NvdaConnected; interrupt = $Interrupt }
        $script:Last = $Text
        if ($Console) { Write-Output $Text; return }
        if ($script:Muted -and -not $Force) { return }
        if (-not $script:NvdaConnected) { return }
        try {
            $code = [WarhammerAccessibility.NvdaController]::Speak($Text, $Interrupt)
            Write-SpeechTrace 'nvda-return' @{ code = $code; interrupt_previous = $Interrupt }
            if ($code -ne 0) { throw [ComponentModel.Win32Exception]::new($code) }
            $brailleCode = [WarhammerAccessibility.NvdaController]::Braille($Text)
            if ($brailleCode -ne 0) { Log-Error ('NVDA braille output failed: ' + $brailleCode) }
        } catch {
            $script:NvdaConnected = $false
            Write-SpeechTrace 'nvda-error' @{ message = $_.Exception.Message }
            Set-Status 'NVDA disconnected. Start NVDA, then choose Test NVDA to reconnect.'
            Log-Error $_.Exception.Message
        }
    }
    function Stop-Speech {
        Write-SpeechTrace 'stop-request' @{}
        if (-not $script:NvdaConnected) { return }
        try {
            $code = [WarhammerAccessibility.NvdaController]::CancelSpeech()
            if ($code -ne 0) { throw [ComponentModel.Win32Exception]::new($code) }
        } catch { $script:NvdaConnected = $false; Log-Error $_.Exception.Message }
    }
    function Test-Speech {
        if (-not (Connect-ScreenReader)) { return $false }
        Speak 'Warhammer accessibility. NVDA speech test successful.' -Force
        return $true
    }
    function Toggle-Mute {
        $script:Muted = -not $script:Muted
        Stop-Speech
        Speak $(if ($script:Muted) { 'Speech muted.' } else { 'Speech enabled.' }) -Force
    }
    function Launch-Game {
        if (-not $script:NvdaConnected -and -not (Connect-ScreenReader)) {
            Set-Status 'NVDA must be connected before the game can launch.'
            return $false
        }
        if (Get-Process -Name Warhammer2 -ErrorAction SilentlyContinue) {
            Speak 'Warhammer is already running.' -Force
            return $true
        }
        # Start the game with only the accessibility mod, the same command line
        # TW Mod Manager's Play uses, so no launcher window has to be read.
        # Needs Steam running and the installed pack; otherwise use Steam.
        $exe = $(if ($GamePath) { Join-Path $GamePath 'Warhammer2.exe' } else { '' })
        $pack = $(if ($GamePath) { Join-Path $GamePath 'data\warhammer_access.pack' } else { '' })
        $steamRunning = [bool](Get-Process -Name steam -ErrorAction SilentlyContinue)
        if ($exe -and (Test-Path -LiteralPath $exe -PathType Leaf) -and (Test-Path -LiteralPath $pack -PathType Leaf) -and $steamRunning) {
            $list = Join-Path $base 'nvda_mods.txt'
            $lines = @(('add_working_directory "' + ((Join-Path $GamePath 'data') -replace '\\','/') + '";'), 'mod "warhammer_access.pack";')
            [IO.File]::WriteAllText($list, ($lines -join "`n") + "`n", (New-Object Text.UTF8Encoding $false))
            Start-Process -FilePath $exe -WorkingDirectory $GamePath -ArgumentList ('"' + $list + '"'),'; -dx11'
            Set-Status 'Starting Warhammer with the accessibility mod.'
            Speak 'Starting Warhammer with the accessibility mod.' -Force
        } else {
            Start-Process 'steam://rungameid/594570'
            $why = $(if (-not $steamRunning) { 'Steam is not running, so the game starts through Steam.' } else { 'The game starts through Steam.' })
            Set-Status $why
            Speak ($why + ' In the Mod Manager, make sure warhammer access is ticked, then press Play.') -Force
        }
        return $true
    }
    $tails = @(
        [WarhammerAccessibility.Tail]::new((Join-Path $base 'bridge.jsonl'), $true),
        [WarhammerAccessibility.Tail]::new((Join-Path $GamePath 'warhammer_access.jsonl'), $true)
    )
    $states = @((New-ProtocolState), (New-ProtocolState))
    # Standard menu keys (arrows, Tab, Home/End, Enter/Space, Backspace,
    # letters) go to the mod through keys.tsv, only while the game is focused
    # and the mod's reader-state.tsv heartbeat is fresh and reports the frontend.
    $script:MenuKeysObj = $null
    $script:KeyOwner = [guid]::NewGuid().ToString('N')
    $script:KeySeq = 0
    $script:KeyRing = New-Object System.Collections.Generic.List[string]
    $script:Reader = $null
    $script:LastMenuKeyFailures = 0
    $script:KeyPending = $false # a key was sent since the last speech
    function Write-AtomicText([string]$Path, [string]$Text) {
        $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
        try {
            [IO.File]::WriteAllText($temporary, $Text, (New-Object Text.UTF8Encoding $false))
            if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
            else { [IO.File]::Move($temporary, $Path) }
        } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
    }
    function Read-ReaderState {
        $path = Join-Path $base 'reader-state.tsv'
        try {
            $info = New-Object IO.FileInfo $path
            # 15 s, not 3: the game sometimes stalls the mod's timers for a few
            # seconds (camera jumps); releasing the keys then sent Enter to the
            # game (live 0.6.68). Keys pressed meanwhile wait in keys.tsv. Map
            # controls (Shift+F2) and leaving the game still release them at once.
            if (-not $info.Exists -or ([DateTime]::UtcNow - $info.LastWriteTimeUtc).TotalSeconds -gt 15) { return $null }
            $fields = ([IO.File]::ReadAllText($path)).TrimEnd("`r", "`n").Split("`t")
            if ($fields.Count -ne 5 -or $fields[0] -ne 'WH2READER1' -or $fields[3] -ne '1') { return $null }
            return [pscustomobject]@{ session = $fields[1]; generation = $fields[2]; screen = $fields[4] }
        } catch { return $null }
    }
    function Write-MenuKeys {
        $session = '-'; $generation = '-'
        if ($script:Reader) { $session = $script:Reader.session; $generation = $script:Reader.generation }
        $lines = @("WH2KEYS1`t" + $script:KeyOwner + "`t" + $session + "`t" + $generation) + $script:KeyRing
        Write-AtomicText (Join-Path $base 'keys.tsv') (($lines -join "`n") + "`n")
    }
    function Send-MenuKey([string]$Action) {
        if (-not $script:Reader) { return }
        $script:KeySeq++
        $script:KeyPending = $true
        $script:KeyRing.Add(([string]$script:KeySeq) + "`t" + $Action)
        while ($script:KeyRing.Count -gt 16) { $script:KeyRing.RemoveAt(0) }
        Write-MenuKeys
    }
    # A stalled game leaves a blind player in silence (live, Nov 1: graphics
    # driver timeouts stopped the game's main loop and with it the mod). When
    # the mod's heartbeat stops for over 5 s while the game is in front, say so
    # once, and say when it is back. The mod marks loading screens and the
    # intro movies 'loading'; those never count.
    $script:StallSeen = $false; $script:StallScreen = $null; $script:StallSaid = $false
    function Test-GameFocused { return [WarhammerAccessibility.MenuKeys]::GameFocused() }
    function Watch-GameStall {
        $info = New-Object IO.FileInfo (Join-Path $base 'reader-state.tsv')
        if (-not $info.Exists) { return }
        $age = ([DateTime]::UtcNow - $info.LastWriteTimeUtc).TotalSeconds
        if ($age -le 3) {
            $fields = ([IO.File]::ReadAllText($info.FullName)).TrimEnd("`r", "`n").Split("`t")
            if ($fields.Count -ne 5 -or $fields[0] -ne 'WH2READER1') { return }
            if ($script:StallSaid -and $fields[4] -ne 'loading') { Speak 'The game is responding again.' -Interrupt $false }
            $script:StallSaid = $false; $script:StallSeen = $true; $script:StallScreen = $fields[4]
            return
        }
        if ($script:StallSaid -or -not $script:StallSeen -or $script:StallScreen -eq 'loading' -or $age -le 5 -or $age -gt 600) { return }
        if (-not (Test-GameFocused)) { return }
        $script:StallSaid = $true
        Speak 'The game is busy.' -Interrupt $false
    }
    function Read-Bridge {
        if ($script:MenuKeysObj) {
            try { Watch-GameStall } catch { Log-Error ('Stall watch: ' + $_.Exception.Message) }
            $script:Reader = Read-ReaderState
            $failures = $script:MenuKeysObj.SetActive($null -ne $script:Reader, ($null -ne $script:Reader -and $script:Reader.screen -eq 'campaign'))
            if ($failures -and $failures -ne $script:LastMenuKeyFailures) {
                Log-Error ('Menu keys: ' + $failures + ' could not be registered or released (another program may own them).')
            }
            $script:LastMenuKeyFailures = $failures
        }
        $latest = $null; $batch = New-SpeechBatch
        for ($i = 0; $i -lt $tails.Count; $i++) {
            try {
                foreach ($line in $tails[$i].Poll()) {
                    $r = Convert-BridgeRecord $line $states[$i]
                    if ($null -eq $r -or $r.kind -eq 'hover') { continue }
                    $latest = $r; Add-SpeechRecord $batch $r
                }
            } catch { Log-Error $_.Exception.Message }
        }
        if ($latest) {
            Set-Status ('Connected to game: ' + $latest.context + '. Last message: ' + $latest.text.Substring(0, [Math]::Min(100, $latest.text.Length)))
            if ($batch.Dropped) { Log-Error ("Speech batch overflow: " + $batch.Dropped + " records; original messages remain in the bridge file.") }
            Speak (Get-SpeechBatchText $batch) -Interrupt $script:KeyPending
            $script:KeyPending = $false
        }
    }
    if ($Console) {
        Write-Host 'Console bridge; Ctrl+C to stop. Existing log history is skipped.'
        while ($true) { Read-Bridge; Start-Sleep -Milliseconds 100 }
    }
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    if ($MenuKeys) {
        Add-Type -Path (Join-Path $PSScriptRoot 'MenuKeys.cs') -ReferencedAssemblies @('System.dll','System.Windows.Forms.dll')
        $script:MenuKeysObj = [WarhammerAccessibility.MenuKeys]::new()
        $script:MenuKeysObj.Add_Pressed({ param($sender, $eventArgs)
            try { Send-MenuKey $eventArgs.Action } catch { Log-Error ('Menu key failed: ' + $_.Exception.Message) }
        })
        # Announce this companion to the mod with no events, so the first real
        # key press is not mistaken for an old backlog.
        Write-MenuKeys
    }
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $form = New-Object Windows.Forms.Form
    $form.Text = 'Warhammer II NVDA accessibility ' + $buildVersion
    $form.Width = 700; $form.Height = 490
    $form.StartPosition = 'CenterScreen'
    $panel = New-Object Windows.Forms.FlowLayoutPanel
    $panel.Dock = 'Fill'; $panel.FlowDirection = 'TopDown'; $panel.WrapContents = $false; $panel.AutoScroll = $true
    $form.Controls.Add($panel)
    $label = New-Object Windows.Forms.Label
    $label.Text = 'Read-only keyboard browser. In the main menu, tap F2 for next or F3 for previous. F4 is disabled. No mouse or game command is used.'
    if ($packageManifest -and $packageManifest.stage -eq 'frontend-activation-preview') {
        $label.Text = 'In the game menus: Up and Down arrows or Tab move, Home and End jump, Enter or Space activates, Backspace goes back a step, a letter jumps to the next item starting with it, Escape is the game''s Back key. F2, F3 and F4 also work.'
    }
    $label.Width = 650; $label.Height = 60; $panel.Controls.Add($label)
    $script:StatusControl = New-Object Windows.Forms.TextBox
    $script:StatusControl.ReadOnly = $true; $script:StatusControl.Multiline = $true
    $script:StatusControl.Width = 650; $script:StatusControl.Height = 55
    $script:StatusControl.AccessibleName = 'Connection status'
    $panel.Controls.Add($script:StatusControl)
    function Add-Button([string]$Name, [scriptblock]$Action) {
        $button = New-Object Windows.Forms.Button
        $button.Text = $Name; $button.Width = 640; $button.Height = 29
        $button.Add_Click($Action); $panel.Controls.Add($button)
    }
    Add-Button '&Test NVDA / reconnect' { [void](Test-Speech) }
    Add-Button '&Launch game' { [void](Launch-Game) }
    Add-Button '&Repeat last message' { Speak $script:Last -Force }
    Add-Button '&Stop speech' { Stop-Speech }
    Add-Button '&Mute / unmute' { Toggle-Mute }
    Add-Button '&Open diagnostic folder' { Start-Process explorer.exe -ArgumentList $base }
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 100
    $timer.Add_Tick({ Read-Bridge })
    $form.Add_Shown({
        $connected = Test-Speech
        $timer.Start()
        if ($Launch -and $connected) { [void](Launch-Game) }
        elseif ($Launch) { Set-Status 'NVDA must be connected before the game can launch.' }
    })
    try { [void]$form.ShowDialog() }
    finally { $timer.Stop(); $timer.Dispose(); if ($script:MenuKeysObj) { $script:MenuKeysObj.Dispose() }; $form.Dispose(); Stop-Speech }
} catch {
    Write-Host ('Warhammer accessibility failed: ' + $_.Exception.Message)
    if (Get-Command Log-Error -ErrorAction SilentlyContinue) { Log-Error $_.Exception.Message }
    exit 1
} finally { if ($lockStream) { $lockStream.Dispose() } }
