param(
    [ValidateSet('Enable','Status','Next','Previous','Activate','Discover','Disable')][string]$Action = 'Status',
    [string]$ExpectedSelectedKey,
    [switch]$DoubleConfirm,
    [ValidateRange(1,1800)][int]$LeaseSeconds = 900,
    [ValidateRange(250,15000)][int]$TimeoutMs = 5000,
    [string]$BasePath = (Join-Path $env:LOCALAPPDATA 'WarhammerAccess')
)
$ErrorActionPreference = 'Stop'
$encoding = New-Object Text.UTF8Encoding($false,$true)
$leasePath = Join-Path $BasePath 'automation-enabled.tsv'
$requestPath = Join-Path $BasePath 'automation-request.tsv'
$statusPath = Join-Path $BasePath 'automation-status.tsv'
$manifest = Get-Content -LiteralPath (Join-Path $BasePath 'App\manifest.json') -Raw | ConvertFrom-Json
if ($manifest.automation_protocol -ne 1) { throw 'Installed preview does not support the opt-in automation protocol.' }
if ($DoubleConfirm -and $Action -ne 'Activate') { throw 'DoubleConfirm is only valid for Activate.' }
function Unix-Now { return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
function Read-SharedText([string]$Path) {
    $stream = $null; $reader = $null
    try {
        $stream = [IO.FileStream]::new($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        if ($stream.Length -gt 4096) { return $null }
        $reader = [IO.StreamReader]::new($stream,$encoding,$false,1024)
        return $reader.ReadToEnd()
    } catch [IO.IOException] { return $null }
    finally { if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() } }
}
function Read-Lease {
    $text = Read-SharedText $leasePath
    if (-not $text -or $text -notmatch '\AWH2LEASE1\t([0-9a-f]{32})\t([0-9]{1,10})\r?\n\z') { return $null }
    return @{ owner=$Matches[1]; expires=[long]$Matches[2] }
}
function Read-Status {
    $text = Read-SharedText $statusPath
    if (-not $text -or -not $text.EndsWith("`n")) { return $null }
    $line = $text.TrimEnd([char[]]"`r`n")
    if ($line.Contains("`n") -or $line.Contains("`r")) { return $null }
    $parts = $line.Split([char]9)
    if ($parts.Length -ne 16 -or $parts[0] -ne 'WH2STATUS1' -or $parts[1] -ne $manifest.version) { return $null }
    foreach ($index in @(3,4,5,10,12,15)) {
        if ($parts[$index] -notmatch '\A[0-9]{1,10}\z') { return $null }
    }
    if ($parts[13] -notin @('0','1') -or $parts[14] -notin @('0','1')) { return $null }
    return [pscustomobject]@{
        version=$parts[1]; session=$parts[2]; generation=[long]$parts[3]; revision=[long]$parts[4]
        sequence=[long]$parts[5]; result=$parts[6]; screen=$parts[7]; selected_key=$parts[8]; label=$parts[9]
        control_count=[int]$parts[10]; pending_key=$parts[11]; pending_deadline=[long]$parts[12]
        ready=($parts[13] -eq '1'); enabled=($parts[14] -eq '1'); lease_expires=[long]$parts[15]
    }
}
function Write-Atomic([string]$Path,[string]$Text) {
    $temporary = Join-Path $BasePath ('automation-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temporary,$Text,$encoding)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary,$Path,[NullString]::Value) }
        else { [IO.File]::Move($temporary,$Path) }
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Send-Once([string]$Command,$PriorState) {
    $lease = Read-Lease; $state = Read-Status
    if (-not $lease -or $lease.expires -lt (Unix-Now)) { throw 'Automation lease is missing or expired. Enable it before launching the game.' }
    if (-not $state -or -not $state.enabled -or -not $state.ready) { throw 'No ready game automation endpoint.' }
    if (-not (Get-Process -Name Warhammer2 -ErrorAction SilentlyContinue)) { throw 'Game process is not running.' }
    if ($Command -eq 'activate') {
        if (-not $ExpectedSelectedKey -or $state.selected_key -ne $ExpectedSelectedKey) { throw 'Activation requires an explicit matching ExpectedSelectedKey.' }
    }
    if ($PriorState -and ($state.session -ne $PriorState.session -or $state.generation -ne $PriorState.generation -or $state.revision -ne $PriorState.revision -or $state.selected_key -ne $PriorState.selected_key -or $state.sequence -ne $PriorState.sequence)) {
        throw 'Game state changed between confirmation requests; no second request sent.'
    }
    $number = $state.sequence + 1
    $fields = @('WH2REQ1',$lease.owner,$state.session,[string]$number,[string]$state.generation,[string]$state.revision,$Command,$state.selected_key,[string]((Unix-Now)+5))
    # Exactly one write. Timeouts or uncertain native results are never retried.
    Write-Atomic $requestPath (($fields -join "`t") + "`n")
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.ElapsedMilliseconds -lt $TimeoutMs) {
        $reply = Read-Status
        if ($reply -and $reply.session -ne $state.session) { throw 'Game session changed after the request; do not retry uncertain input.' }
        if ($reply -and $reply.sequence -eq $number) { return $reply }
        if ($reply -and $reply.sequence -gt $number) { throw 'Another command advanced the sequence; inspect the game before continuing.' }
        Start-Sleep -Milliseconds 50
    }
    throw 'No acknowledgement before timeout. Input outcome is uncertain; inspect logs and do not resend automatically.'
}
$mutex = [Threading.Mutex]::new($false,'Local\WarhammerA11yAutomationClient')
$locked = $false
try {
    try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'Another automation client is active.' }
    switch ($Action) {
        'Enable' {
            $lease = Read-Lease
            if ($lease -and $lease.expires -gt (Unix-Now)) {
                [pscustomobject]@{ enabled=$true; expires=$lease.expires; reused=$true } | ConvertTo-Json
            } else {
                if (Get-Process -Name Warhammer2 -ErrorAction SilentlyContinue) { throw 'Close the game before enabling a new automation lease.' }
                $expires = (Unix-Now)+$LeaseSeconds
                Write-Atomic $leasePath ("WH2LEASE1`t" + [guid]::NewGuid().ToString('N') + "`t" + $expires + "`n")
                [pscustomobject]@{ enabled=$true; expires=$expires; reused=$false } | ConvertTo-Json
            }
        }
        'Disable' {
            foreach ($path in @($leasePath,$requestPath)) { if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
            [pscustomobject]@{ enabled=$false; note='Only the automation lease/request were removed; logs and installation are preserved.' } | ConvertTo-Json
        }
        'Status' {
            $state = Read-Status
            if ($state) { $state | ConvertTo-Json }
            else { [pscustomobject]@{ ready=$false; enabled=$false; result='No complete current-version status; launch with an active lease.' } | ConvertTo-Json }
        }
        default {
            $reply = Send-Once $Action.ToLowerInvariant() $null
            if ($DoubleConfirm -and $reply.result -ne 'input-sent') {
                # input-sent on the first request: the game uses single-press activation.
                if ($reply.result -ne 'armed' -or $reply.pending_key -ne $ExpectedSelectedKey -or $reply.pending_deadline -lt (Unix-Now)) {
                    $reply | ConvertTo-Json; exit 2
                }
                $reply = Send-Once 'activate' $reply
            }
            $reply | ConvertTo-Json
            if ($reply.result -notin @('completed','armed','input-sent','discovery-page','discovery-complete')) { exit 2 }
        }
    }
} finally { if ($locked) { [void]$mutex.ReleaseMutex() }; $mutex.Dispose() }
