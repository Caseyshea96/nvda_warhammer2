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
$luac = Join-Path $root 'local/tools/lua-5.1.5-windows/luac5.1.exe'
$source = Join-Path $root 'diagnostics/scanner_compare.lua'
Push-Location $root
try {
    & $Python tests/check_scanner_compare.py
    if ($LASTEXITCODE) { throw 'Lua syntax check failed' }
    # Scanner comparison harness already executed above
    if ($LASTEXITCODE) { throw 'Activation fixtures failed' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/speech_trace_tests.ps1
    if ($LASTEXITCODE) { throw 'Speech trace tests failed' }
    $stage = Join-Path $root ('artifacts/scanner-compare-build-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($stage)
    $pack = Join-Path $stage 'warhammer_access.pack'
    & $rpfm --game warhammer_2 pack create -p $pack
    if ($LASTEXITCODE) { throw 'Pack creation failed' }
    & $rpfm --game warhammer_2 pack set-file-type -p $pack -f mod
    if ($LASTEXITCODE) { throw 'Pack type failed' }
    & $rpfm --game warhammer_2 pack add -p $pack -f ($source + ';script/_lib/mod/warhammer_access.lua')
    if ($LASTEXITCODE) { throw 'Pack insertion failed' }
    $roundtrip = Join-Path $stage 'roundtrip'
    & $rpfm --game warhammer_2 pack extract -p $pack -F ('/;' + $roundtrip)
    if ($LASTEXITCODE) { throw 'Pack extraction failed' }
    $extracted = Join-Path $roundtrip 'script/_lib/mod/warhammer_access.lua'
    if ((Get-FileHash $source).Hash -ne (Get-FileHash $extracted).Hash) { throw 'Roundtrip differs from source' }
    $output = Join-Path $root 'artifacts/warhammer_access_scanner_compare.pack'
    Copy-Item -LiteralPath $pack -Destination $output -Force
    ((Get-FileHash $output).Hash.ToLowerInvariant() + '  warhammer_access_scanner_compare.pack') | Set-Content ($output + '.sha256') -Encoding Ascii
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/package-nvda-addon.ps1
    if ($LASTEXITCODE) { throw 'Add-on packaging failed' }
    & $Python tools/package-pilot.py --scanner-compare
    if ($LASTEXITCODE) { throw 'Interactive packaging failed' }
} finally { Pop-Location }
