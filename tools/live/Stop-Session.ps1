# Revoke the lease, copy evidence and stop only the processes recorded as
# owned by this session (matched on PID, executable path and start time).
param([Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
$base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $base 'App\Automation.ps1') -Action Disable
if ($LASTEXITCODE) { 'WARNING: lease disable reported failure' }
$statusPath = Join-Path $base 'automation-status.tsv'
$acknowledged = $false
$until = [datetime]::UtcNow.AddSeconds(5)
do {
    if (Test-Path -LiteralPath $statusPath) {
        $state = Get-Content -LiteralPath $statusPath -Raw
        if ($state.Split("`t")[14] -eq '0') { $acknowledged = $true; break }
    }
    Start-Sleep -Milliseconds 250
} while ([datetime]::UtcNow -lt $until)
if ($state) { $state | Set-Content (Join-Path $Evidence 'disabled-status.tsv') -Encoding UTF8 }
"NATIVE_DISABLED_ACK=$acknowledged"
$campaignRecord = Join-Path $Evidence 'owned-campaign-flag.json'
if (Test-Path -LiteralPath $campaignRecord) {
    $campaignOwner = Get-Content -LiteralPath $campaignRecord -Raw | ConvertFrom-Json
    $campaignFlag = Join-Path $base 'campaign-discovery.tsv'
    if ((Test-Path -LiteralPath $campaignFlag) -and [IO.File]::ReadAllText($campaignFlag) -ceq $campaignOwner.raw) {
        Remove-Item -LiteralPath $campaignFlag
        'Owned campaign discovery flag removed.'
        $campaignRequest = Join-Path $base 'campaign-discovery-request.tsv'
        if ((Test-Path -LiteralPath $campaignRequest) -and
            [IO.File]::ReadAllText($campaignRequest).StartsWith(("WH2CAMCAP1`t" + $campaignOwner.owner + "`t"),[StringComparison]::Ordinal)) {
            Copy-Item -LiteralPath $campaignRequest -Destination $Evidence -Force
            Remove-Item -LiteralPath $campaignRequest
            'Owned read-only capture request removed.'
        }
    }
}
$probe = Join-Path $base 'string-find-probe.flag'
if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe }
foreach ($name in @('native-ui-graphics-preview.log','native-ui-lord-discovery.jsonl','native-ui-campaign-discovery.jsonl','campaign-discovery-status.json','bridge.jsonl','speech-trace.jsonl','receipt.json')) {
    $source = Join-Path $base $name
    if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $Evidence -Force }
}
function Stop-Owned([string]$record, [int]$graceSeconds) {
    $path = Join-Path $Evidence $record
    if (-not (Test-Path -LiteralPath $path)) { return "${record}: none recorded" }
    $owned = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $live = Get-CimInstance Win32_Process -Filter "ProcessId=$($owned.ProcessId)"
    if (-not $live) { return "${record}: already exited" }
    $sameStart = [math]::Abs(($live.CreationDate - [datetime]$owned.CreationDate).TotalSeconds) -lt 1
    if ($live.ExecutablePath -ne $owned.ExecutablePath -or -not $sameStart) { return "${record}: PID reused by another process; left alone" }
    if ($graceSeconds -gt 0) {
        $p = Get-Process -Id $owned.ProcessId -ErrorAction SilentlyContinue
        if ($p -and $p.MainWindowHandle -ne 0) { [void]$p.CloseMainWindow() }
        $deadline = [datetime]::UtcNow.AddSeconds($graceSeconds)
        while ([datetime]::UtcNow -lt $deadline -and (Get-Process -Id $owned.ProcessId -ErrorAction SilentlyContinue)) { Start-Sleep -Milliseconds 500 }
        if (-not (Get-Process -Id $owned.ProcessId -ErrorAction SilentlyContinue)) { return "${record}: closed gracefully" }
    }
    Stop-Process -Id $owned.ProcessId -Force
    return "${record}: stopped (verified PID $($owned.ProcessId))"
}
Stop-Owned 'owned-game.json' 20
Stop-Owned 'owned-companion.json' 0
