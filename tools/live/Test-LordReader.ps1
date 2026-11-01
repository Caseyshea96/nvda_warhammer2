# On Select Lord: traverse every captured entry with Next (which pages
# discovery itself), check labels against the expected catalog, test wrap in
# both directions, an explicit Discover refresh, and that F4 on captured
# Start Campaign asks first and moving away cancels, with no extra native click.
param(
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$Evidence,
    [string]$Catalog = ''
)
$ErrorActionPreference = 'Stop'
# PowerShell 5.1 leaves $PSScriptRoot empty inside param defaults.
if (-not $Catalog) { $Catalog = Join-Path $PSScriptRoot '..\..\tests\fixtures\lord_expected_catalog.json' }
$base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
$helper = Join-Path $base 'App\Automation.ps1'
$full = "$Version-nvda-automation-preview"
# PowerShell 5.1 emits a JSON array as one object; unroll it explicitly.
$catalogEntries = @(Get-Content -LiteralPath $Catalog -Raw | ConvertFrom-Json | ForEach-Object { $_ })
$expected = @{}
foreach ($entry in $catalogEntries) { $expected[$entry.key] = $entry.name }
$seen = [Collections.Generic.HashSet[string]]::new()
$steps = [Collections.Generic.List[object]]::new()
function Invoke-Client([string]$Action, [string]$ExpectedKey = '') {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$helper,'-Action',$Action)
    # Single request only (no -DoubleConfirm): the game must block it as read only.
    if ($ExpectedKey) { $arguments += @('-ExpectedSelectedKey',$ExpectedKey) }
    $response = & powershell.exe @arguments
    $code = $LASTEXITCODE
    $state = ($response -join "`n") | ConvertFrom-Json
    $steps.Add([pscustomobject]@{action=$Action; exit=$code; state=$state})
    $steps | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Evidence 'reader-steps.json') -Encoding UTF8
    return @($code, $state)
}
function Next-State([string]$Action) {
    $code, $state = Invoke-Client $Action
    if ($code) { throw "$Action failed (exit $code); no retry performed." }
    if ($state.version -ne $full -or $state.result -ne 'completed' -or $state.screen -ne 'lord_discovery') {
        throw "Unexpected reader state after $Action (result=$($state.result), screen=$($state.screen))."
    }
    if ($state.selected_key -ne '-') {
        if (-not $expected.ContainsKey($state.selected_key)) { throw "Unknown captured entry $($state.selected_key)." }
        if ($state.label -ne $expected[$state.selected_key]) {
            throw "Label mismatch at $($state.selected_key): got '$($state.label)', expected '$($expected[$state.selected_key])'."
        }
        [void]$seen.Add($state.selected_key)
    }
    return $state
}
function Last-Page {
    $pages = @(Get-Content -LiteralPath (Join-Path $base 'native-ui-lord-discovery.jsonl') | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.kind -eq 'page' })
    return $pages[-1]
}
$finished = $false
for ($i = 0; $i -lt 100; $i++) {
    $state = Next-State 'Next'
    $last = Last-Page
    if ($last.limited -or $last.errors) { throw 'Discovery limit/error encountered.' }
    $atEnd = $state.selected_key -eq $catalogEntries[0].key -or $state.selected_key -eq $catalogEntries[-1].key
    if ($last.complete -and $seen.Count -eq $catalogEntries.Count -and $atEnd) { $finished = $true; break }
}
if (-not $finished) { throw "Traversal incomplete: $($seen.Count) of $($catalogEntries.Count) entries." }
"PASS: Next fetched $($last.page) pages and read all $($seen.Count) entries with expected labels."
# Wrap checks work from either end (a run resumed mid-list ends on entry 1).
if ($state.selected_key -eq $catalogEntries[-1].key) {
    $state = Next-State 'Next'; if ($state.selected_key -ne $catalogEntries[0].key) { throw 'Forward wrap failed.' }
    $state = Next-State 'Previous'; if ($state.selected_key -ne $catalogEntries[-1].key) { throw 'Backward wrap failed.' }
} elseif ($state.selected_key -eq $catalogEntries[0].key) {
    $state = Next-State 'Previous'; if ($state.selected_key -ne $catalogEntries[-1].key) { throw 'Backward wrap failed.' }
    $state = Next-State 'Next'; if ($state.selected_key -ne $catalogEntries[0].key) { throw 'Forward wrap failed.' }
} else { throw "Traversal ended mid-list at $($state.selected_key)." }
'PASS: wrap in both directions.'
# Explicit refresh: Discover after a complete capture must reread the scope.
$code, $refresh = Invoke-Client 'Discover'
if ($code -or $refresh.result -ne 'discovery-page' -or $refresh.selected_key -ne '-') { throw 'Refresh did not start a fresh capture.' }
for ($page = 0; $page -lt 12 -and $refresh.result -eq 'discovery-page'; $page++) {
    $code, $refresh = Invoke-Client 'Discover'
    if ($code) { throw 'Refresh page failed; no retry.' }
}
if ($refresh.result -ne 'discovery-complete' -or $refresh.control_count -ne $catalogEntries.Count) {
    throw "Refresh did not recover the complete catalog (result=$($refresh.result), count=$($refresh.control_count))."
}
'PASS: explicit refresh recovered the complete catalog.'
$state = Next-State 'Next'; $state = Next-State 'Next'
if ($state.label -ne 'Start Campaign') { throw "Expected captured Start Campaign text, got '$($state.label)'." }
$log = Join-Path $base 'native-ui-graphics-preview.log'
$clicksBefore = @(Get-Content $log | Where-Object { $_ -like '*activation.dispatch*' }).Count
# One press only asks ("Start the campaign as ...?"); moving away cancels.
$code, $asked = Invoke-Client 'Activate' $state.selected_key
if ($code -or $asked.result -ne 'armed') { throw "Start Campaign did not ask first (result $($asked.result))." }
$state = Next-State 'Next'
$clicksAfter = @(Get-Content $log | Where-Object { $_ -like '*activation.dispatch*' }).Count
if ($clicksBefore -ne 2 -or $clicksAfter -ne $clicksBefore) { throw "Unexpected native click count ($clicksBefore before, $clicksAfter after)." }
'PASS: Start Campaign asked first and moving away cancelled it; exactly two native clicks in the session.'
