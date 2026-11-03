# Read-only campaign snapshot requests. This client cannot start campaigns,
# activate UI, select units, or send gameplay input.
param(
    [ValidateSet('Status','Capture')][string]$Action='Status',
    [string]$BasePath=(Join-Path $env:LOCALAPPDATA 'WarhammerAccess'),
    [ValidateRange(250,15000)][int]$TimeoutMs=5000
)
$ErrorActionPreference='Stop'
$encoding=New-Object Text.UTF8Encoding($false,$true)
function Read-SharedText([string]$Path) {
    if (-not [IO.File]::Exists($Path)) { return $null }
    $stream=$null; $reader=$null
    try {
        $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        if ($stream.Length -gt 8192) { return $null }
        $reader=New-Object IO.StreamReader($stream,$encoding,$false)
        return $reader.ReadToEnd()
    } catch { return $null }
    finally { if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() } }
}
function Read-Lease {
    $raw=Read-SharedText (Join-Path $BasePath 'campaign-discovery.tsv')
    if (-not $raw -or $raw -notmatch '\AWH2CAM1\t([a-f0-9]{32})\t([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)\t(capture|verify)\n\z') { return $null }
    $owner=$Matches[1]; $expires=$Matches[2]
    $parsed=[datetime]::MinValue
    if (-not [datetime]::TryParseExact($expires,'yyyy-MM-ddTHH:mm:ssZ',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal,[ref]$parsed) -or $parsed -lt [datetime]::UtcNow) { return $null }
    return [pscustomobject]@{owner=$owner;expires=$expires}
}
function Read-Status($Lease) {
    $path=Join-Path $BasePath 'campaign-discovery-status.json'
    $raw=Read-SharedText $path
    if (-not $raw -or -not $raw.EndsWith("`n")) { return $null }
    try {
        if (([datetime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($path)).TotalSeconds -gt 4) { return $null }
        $s=$raw | ConvertFrom-Json
        if ($s.expires -is [datetime]) { $s.expires=$s.expires.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
        if ($s.protocol -ne 'WH2CAMSTATUS1' -or $s.version -ne '0.6.71' -or $s.owner -cne $Lease.owner -or $s.expires -cne $Lease.expires -or
            $s.session -isnot [string] -or -not $s.session.StartsWith(('campaign:'+$Lease.owner+':')) -or $s.session.Length -gt 200 -or $s.session -match '[\t\r\n]') { return $null }
        if ($s.generation -isnot [int] -and $s.generation -isnot [long]) { return $null }
        if ($s.generation -lt 1 -or $s.generation -gt 16777215 -or $s.phase -notin @('initialising','waiting','waiting-timeout','scanning','ready','limited','cancelled','error')) { return $null }
        return $s
    } catch { return $null }
}
function Write-Atomic([string]$Path,[string]$Text) {
    $temporary=Join-Path $BasePath ('campaign-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temporary,$Text,$encoding)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary,$Path,[NullString]::Value) }
        else { [IO.File]::Move($temporary,$Path) }
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
$mutex=New-Object Threading.Mutex($false,'Local\WarhammerA11yCampaignReadOnly')
$locked=$false
try {
    try { $locked=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked=$true }
    if (-not $locked) { throw 'Another campaign capture client is active.' }
    $lease=Read-Lease
    if (-not $lease) { throw 'Campaign discovery flag is missing or expired.' }
    $state=Read-Status $lease
    if (-not $state) { throw 'No fresh matching campaign diagnostic endpoint.' }
    if ($Action -eq 'Status') { $state | ConvertTo-Json; exit 0 }
    if ($state.phase -eq 'error') { throw 'Campaign diagnostic is stopped; inspect its log.' }
    $token=[guid]::NewGuid().ToString('N')
    $expires=[datetime]::UtcNow.AddSeconds(5).ToString('yyyy-MM-ddTHH:mm:ssZ')
    if ([string]::CompareOrdinal($expires,$lease.expires) -gt 0) { throw 'Lease is too close to expiry; nothing was sent.' }
    $fields=@('WH2CAMCAP1',$lease.owner,$state.session,[string]$state.generation,$token,$expires)
    Write-Atomic (Join-Path $BasePath 'campaign-discovery-request.tsv') (($fields -join "`t")+"`n")
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while ($watch.ElapsedMilliseconds -lt $TimeoutMs) {
        $reply=Read-Status $lease
        if ($reply -and $reply.session -cne $state.session) { throw 'Game session changed; do not resend automatically.' }
        if ($reply -and $reply.request -ceq $token) {
            $reply | ConvertTo-Json
            if ($reply.result -notin @('accepted','scanning','capture-complete')) { exit 2 }
            exit 0
        }
        Start-Sleep -Milliseconds 100
    }
    throw 'No capture acknowledgement; inspect status before issuing another request. No automatic retry.'
} finally { if ($locked) { [void]$mutex.ReleaseMutex() }; $mutex.Dispose() }
