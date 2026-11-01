# On Select Lord with a complete capture: select -Lord through its lord-choice
# entry (two separately accepted Activate requests), confirm the game observed
# it, check that re-selecting the selected lord is refused, then optionally
# return to -RestoreLord. Never touches Start Campaign.
param(
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$Evidence,
    [string]$Lord = 'Teclis',
    [string]$RestoreLord = 'Tyrion'
)
$ErrorActionPreference = 'Stop'
$base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
$helper = Join-Path $base 'App\Automation.ps1'
$log = Join-Path $base 'native-ui-graphics-preview.log'
$full = "$Version-nvda-automation-preview"
$steps = [Collections.Generic.List[object]]::new()
function Client([string]$Action, [string]$ExpectedKey = '', [switch]$Double) {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$helper,'-Action',$Action)
    if ($ExpectedKey) { $arguments += @('-ExpectedSelectedKey',$ExpectedKey) }
    if ($Double) { $arguments += '-DoubleConfirm' }
    $response = & powershell.exe @arguments
    $code = $LASTEXITCODE
    $state = ($response -join "`n") | ConvertFrom-Json
    $steps.Add([pscustomobject]@{action=$Action; exit=$code; state=$state})
    $steps | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Evidence 'select-steps.json') -Encoding UTF8
    if ($state.version -ne $full) { throw 'Wrong endpoint version.' }
    return @($code, $state)
}
function LastSpeech { (Get-Content (Join-Path $base 'bridge.jsonl') -Tail 1) -replace '.*"text":"','' -replace '"}$','' }
function Observed { @(Select-String $log -Pattern "activation.observed_result`tstring`tlord-" | ForEach-Object Line) }
function Dispatches { @(Get-Content $log | Where-Object { $_ -like 'activation.dispatch*' }).Count }
function Find-Choice([string]$Name) {
    for ($i = 0; $i -lt 120; $i++) {
        $code, $s = Client 'Next'
        if ($code -or $s.screen -ne 'lord_discovery') { throw "Reader unavailable while looking for $Name (screen=$($s.screen))." }
        if ($s.label -eq "Lord choice: $Name") { return $s }
    }
    throw "Lord choice $Name not found."
}
function Complete-Capture {
    # Selection requires a complete capture; Next pages discovery itself.
    for ($i = 0; $i -lt 120; $i++) {
        $page = @(Get-Content (Join-Path $base 'native-ui-lord-discovery.jsonl') | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object kind -eq 'page')[-1]
        if ($page -and $page.complete) { return }
        $code, $s = Client 'Next'
        if ($code -or $s.screen -ne 'lord_discovery') { throw 'Reader unavailable while completing capture.' }
    }
    throw 'Capture did not complete.'
}
function Select-Lord([string]$Name) {
    Complete-Capture
    $choice = Find-Choice $Name
    $before = Dispatches
    $observedBefore = (Observed).Count
    $code, $s = Client 'Activate' $choice.selected_key -Double
    if ($code -or $s.result -ne 'input-sent') { throw "Selecting $Name did not send input (exit $code, result $($s.result)); no retry." }
    if ((Dispatches) -ne $before + 1) { throw 'Expected exactly one new native click.' }
    Start-Sleep -Seconds 2
    $code, $s = Client 'Next'
    $spoken = LastSpeech
    if ($code -or $s.screen -ne 'lord_discovery' -or $spoken -notlike "$Name is now selected.*") { throw "Selection of $Name not confirmed in speech ($spoken)." }
    # The selected-lord field is captured on the first page; read until it is.
    for ($i = 0; $i -lt 10 -and (Observed).Count -eq $observedBefore; $i++) { $code, $s = Client 'Next' }
    if ((Observed).Count -ne $observedBefore + 1) { throw "No observed result after selecting $Name." }
    $observed = @(Observed)[-1]  # @() keeps a single line as an array in PS 5.1
    if ($observed -notlike "*lord-match:$Name") { throw "Observed result was '$observed'." }
    "PASS: selected $Name (one click; change announced; observed $observed)."
}
Select-Lord $Lord
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Capture-Screen.ps1') -Path (Join-Path $Evidence "screen-selected-$Lord.png") | Out-Null
# Re-selecting the selected lord must be refused with no click.
Complete-Capture
$choice = Find-Choice $Lord
$before = Dispatches
$code, $s = Client 'Activate' $choice.selected_key
if ($s.result -ne 'blocked' -and $s.result -ne 'completed' -or (Dispatches) -ne $before -or (LastSpeech) -notlike '*is already selected*') {
    throw "Re-selecting $Lord was not refused (result $($s.result), '$(LastSpeech)')."
}
"PASS: re-selecting $Lord refused with no click."
if ($RestoreLord -and $RestoreLord -ne 'none') {  # 'none': powershell -File drops '' arguments
    Select-Lord $RestoreLord
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Capture-Screen.ps1') -Path (Join-Path $Evidence "screen-restored-$RestoreLord.png") | Out-Null
}
"Native clicks this session: $(Dispatches)"
