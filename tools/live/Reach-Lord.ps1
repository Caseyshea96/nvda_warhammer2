# From a fresh main menu, use the native automation channel to open
# New Campaign, then Continue on Select Campaign. Exactly two native clicks.
# Visually confirm the main menu before running, and Select Lord afterwards.
param([Parameter(Mandatory=$true)][string]$Version, [Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
$helper = Join-Path $env:LOCALAPPDATA 'WarhammerAccess\App\Automation.ps1'
$full = "$Version-nvda-automation-preview"
[void][IO.Directory]::CreateDirectory($Evidence)
$results = [Collections.Generic.List[object]]::new()
function Step([string]$Action, [string]$ExpectedKey = '') {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$helper,'-Action',$Action)
    if ($ExpectedKey) { $arguments += @('-ExpectedSelectedKey',$ExpectedKey,'-DoubleConfirm') }
    $output = & powershell.exe @arguments
    if ($LASTEXITCODE) { throw "Client failed for $Action; inspect state and do not resend uncertain input." }
    $state = ($output -join "`n") | ConvertFrom-Json
    $results.Add([pscustomobject]@{action=$Action; state=$state})
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Evidence 'transitions.json') -Encoding UTF8
    if ($state.version -ne $full -or -not $state.ready -or -not $state.enabled) { throw 'Wrong or unavailable endpoint.' }
    return $state
}
$state = Step 'Status'
if ($state.sequence -ne 0 -or $state.control_count -ne 0) { throw 'Expected a fresh session; no action sent.' }
$state = Step 'Next'
if ($state.screen -ne 'main' -or $state.control_count -ne 22 -or $state.label -ne 'New Campaign') { throw 'Unexpected main-menu state.' }
$state = Step 'Activate' 'tree.child2.child1.child0.child0.child0.child0.child1'
if ($state.result -ne 'input-sent') { throw 'New Campaign was not sent; no retry.' }
$state = Step 'Next'
if ($state.screen -ne 'campaign_selection' -or $state.control_count -ne 17) { throw 'Select Campaign result not observed.' }
$state = Step 'Next'
if ($state.label -ne 'Mortal Empires, campaign choice') { throw 'Campaign reader order changed.' }
$state = Step 'Next'
if ($state.label -ne 'Continue, button' -or $state.selected_key -ne 'tree.child2.child2.child0') { throw 'Continue is not selected.' }
$state = Step 'Activate' 'tree.child2.child2.child0'
if ($state.result -ne 'input-sent') { throw 'Continue did not dispatch; do not retry.' }
'PASS: New Campaign and Continue acknowledged. Visually confirm Select Lord before Test-LordReader.ps1.'
