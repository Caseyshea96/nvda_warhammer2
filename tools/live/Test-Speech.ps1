# Check that what the mod sent to NVDA this session follows screen reader
# conventions: name, role, value/state, then "N of M"; screen names spoken on
# arrival; no engine words or developer messages in item announcements.
param([Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
$bridge = Join-Path $env:LOCALAPPDATA 'WarhammerAccess\bridge.jsonl'
$texts = @(Get-Content -LiteralPath $bridge -Encoding UTF8 | ForEach-Object { ($_ | ConvertFrom-Json).text })
$texts | Set-Content -LiteralPath (Join-Path $Evidence 'spoken.txt') -Encoding UTF8
$items = @($texts | Where-Object { $_ -match ', \d+ of \d+(, |$)' })
"announcements=$($texts.Count) items=$($items.Count)"
$bad = @($items | Where-Object { $_ -match 'read only|, active\b|NewState|Lord choice:|campaign choice|Lord setup, \d|Controls, \d|Campaign selection, \d' })
if ($bad.Count) { $bad | Select-Object -First 5; throw "$($bad.Count) item announcements use the old format." }
$dev = @($texts | Where-Object { $_ -match 'nodes examined|No game action was sent|native preview log|Input sent to' })
if ($dev.Count) { $dev | Select-Object -First 5; throw "$($dev.Count) developer messages were spoken." }
foreach ($expected in @(
    '^Main menu\. New Campaign, button, 1 of 22$',
    '^Select Campaign\. The Eye of the Vortex, radio button, (checked|not checked), 1 of 17$',
    '^Select Lord\. Select Lord, heading, 1 of \d+$',
    '^Start Campaign, button, \d+ of \d+$',
    '^Enable campaign introduction, check box, (checked|not checked), \d+ of \d+, ',
    '^Campaign difficulty, combo box, \w+, \d+ of \d+$',
    '^Tyrion, radio button, (checked|not checked), \d+ of \d+$')) {
    if (-not ($texts | Where-Object { $_ -match $expected })) { throw "Expected an announcement matching $expected" }
}
'PASS: speech follows the conventional format.'
