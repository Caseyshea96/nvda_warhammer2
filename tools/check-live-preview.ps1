param(
    [string]$ExpectedVersion = '0.6.2-nvda-campaign-preview',
    [switch]$RequireNativeNavigation,
    [switch]$RequireNewCampaign
)
$ErrorActionPreference = 'Stop'
# Read-only desktop diagnostic. Run outside an AppContainer when process
# presence matters; a sandbox may hide the real desktop's processes.
$pilotBase = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
$receipt = Get-Content -LiteralPath (Join-Path $pilotBase 'receipt.json') -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath (Join-Path $pilotBase 'App\manifest.json') -Raw | ConvertFrom-Json
$packPath = Join-Path $receipt.game_path 'data\warhammer_access.pack'
$packHash = (Get-FileHash -LiteralPath $packPath -Algorithm SHA256).Hash.ToLowerInvariant()
$nativePath = Join-Path $pilotBase 'native-ui-graphics-preview.log'
$nativeText = if (Test-Path -LiteralPath $nativePath) { [IO.File]::ReadAllText($nativePath) } else { '' }
$lines = $nativeText -split '\r?\n'
$header = if ($lines.Length) { $lines[0] } else { '' }
$newCampaignSeen = $nativeText.Contains("activation.observed_result`tstring`tNew Campaign")
$navigationCount = [regex]::Matches($nativeText, '(?m)^navigation\.COMPLETE\t').Count
$shortcutCount = [regex]::Matches($nativeText, '(?m)^shortcut\.seen\t').Count
$latestScreen = [regex]::Matches($nativeText, '(?m)^capture\.screen\tstring\t([^\r\n]+)')
$game = Get-Process -Name Warhammer2 -ErrorAction SilentlyContinue
$result = [ordered]@{
    expected_version = $ExpectedVersion
    installed_version = $receipt.version
    installed_version_matches = ($receipt.version -eq $ExpectedVersion -and $manifest.version -eq $ExpectedVersion)
    installed_pack_matches = ($packHash -eq $receipt.pack_sha256 -and $packHash -eq $manifest.files.'warhammer_access.pack')
    native_log_header = $header
    native_version_matches = ($header -eq ('WH2 native UI diagnostic ' + $ExpectedVersion))
    native_shortcut_events = $shortcutCount
    native_navigation_completions = $navigationCount
    native_new_campaign_result_seen = $newCampaignSeen
    native_error_records = [regex]::Matches($nativeText, '(?m)^[^\t\r\n]+\.ERROR\t').Count
    native_dispatches = [regex]::Matches($nativeText, '(?m)^activation\.dispatch\t').Count
    latest_captured_screen = if ($latestScreen.Count) { $latestScreen[$latestScreen.Count-1].Groups[1].Value } else { $null }
    game_running = [bool]$game
    evidence_scope = 'latest native log; these fields alone do not prove audible completion or a live input route'
}
$result | ConvertTo-Json -Depth 4
if (-not $result.installed_version_matches -or -not $result.installed_pack_matches) { exit 1 }
if ($RequireNativeNavigation -and (-not $result.native_version_matches -or $navigationCount -eq 0 -or $shortcutCount -eq 0)) { exit 2 }
if ($RequireNewCampaign -and (-not $result.native_version_matches -or -not $newCampaignSeen)) { exit 3 }
