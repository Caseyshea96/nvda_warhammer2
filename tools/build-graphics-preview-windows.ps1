param([string]$Python)
$ErrorActionPreference = 'Stop'
if (-not $Python) {
    # Windows ships a Microsoft Store "python.exe" stub; prefer the py launcher.
    if (Get-Command py -ErrorAction SilentlyContinue) { $Python = (& py -3 -c "import sys; print(sys.executable)").Trim() }
    elseif ($cmd = Get-Command python -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike "*WindowsApps*" }) { $Python = $cmd.Source }
    else { throw "Python 3 not found. Install it or pass -Python <path>." }
}
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$rpfm = Join-Path $root 'local/tools/rpfm-4.5.4-windows/rpfm_cli.exe'
$source = Join-Path $root 'diagnostics/graphics_preview.lua'
Push-Location $root
try {
    & $Python -X utf8 tests/check_graphics_preview.py
    if ($LASTEXITCODE) { throw 'Graphics preview syntax or fixture checks failed' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/speech_trace_tests.ps1
    if ($LASTEXITCODE) { throw 'Speech trace tests failed' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/companion_interrupt_tests.ps1
    if ($LASTEXITCODE) { throw 'Companion interrupt tests failed' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/companion_stall_tests.ps1
    if ($LASTEXITCODE) { throw 'Companion stall tests failed' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/automation_atomic_tests.ps1
    if ($LASTEXITCODE) { throw 'Windows PowerShell atomic request tests failed' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/automation_atomic_tests.ps1 -ClientPath tools/live/Campaign-ReadOnly.ps1
    if ($LASTEXITCODE) { throw 'Campaign read-only atomic request tests failed' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/campaign_readonly_client_tests.ps1
    if ($LASTEXITCODE) { throw 'Campaign read-only client checks failed' }
    $stage = Join-Path $root ('artifacts/graphics-preview-build-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($stage)
    $pack = Join-Path $stage 'warhammer_access.pack'
    & $rpfm --game warhammer_2 pack create -p $pack
    if ($LASTEXITCODE) { throw 'Pack creation failed' }
    & $rpfm --game warhammer_2 pack set-file-type -p $pack -f mod
    if ($LASTEXITCODE) { throw 'Pack type failed' }
    & $rpfm --game warhammer_2 pack add -p $pack -f ($source + ';script/_lib/mod/warhammer_access.lua')
    if ($LASTEXITCODE) { throw 'Pack insertion failed' }
    $campaignSource = Join-Path $root 'diagnostics/campaign_readonly.lua'
    & $rpfm --game warhammer_2 pack add -p $pack -f ($campaignSource + ';script/_lib/mod/warhammer_access_campaign.lua')
    if ($LASTEXITCODE) { throw 'Campaign discovery insertion failed' }
    $roundtrip = Join-Path $stage 'roundtrip'
    & $rpfm --game warhammer_2 pack extract -p $pack -F ('/;' + $roundtrip)
    if ($LASTEXITCODE) { throw 'Pack extraction failed' }
    $extracted = Join-Path $roundtrip 'script/_lib/mod/warhammer_access.lua'
    if ((Get-FileHash $source).Hash -ne (Get-FileHash $extracted).Hash) { throw 'Roundtrip differs from source' }
    if ((Get-FileHash $campaignSource).Hash -ne (Get-FileHash (Join-Path $roundtrip 'script/_lib/mod/warhammer_access_campaign.lua')).Hash) { throw 'Campaign discovery roundtrip differs from source' }
    $output = Join-Path $root 'artifacts/warhammer_access_graphics_preview.pack'
    Copy-Item -LiteralPath $pack -Destination $output -Force
    ((Get-FileHash $output).Hash.ToLowerInvariant() + '  warhammer_access_graphics_preview.pack') | Set-Content ($output + '.sha256') -Encoding Ascii
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/package-nvda-addon.ps1
    if ($LASTEXITCODE) { throw 'Add-on packaging failed' }
    & $Python -X utf8 tools/package-pilot.py --graphics-preview
    if ($LASTEXITCODE) { throw 'Interactive packaging failed' }
} finally { Pop-Location }
