$ErrorActionPreference = 'Stop'
try {
    if (Get-Process -Name 'Warhammer2' -ErrorAction SilentlyContinue) { throw 'Close Warhammer II first.' }
    $base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
    # Close the accessibility helper if it is running (it holds the lock).
    $helpers = @()
    try {
        $helpers = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction Stop | Where-Object {
            $_.CommandLine -and $_.CommandLine.IndexOf((Join-Path $base 'App\Companion.ps1'), [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    } catch { }
    if ($helpers.Count) {
        Write-Host 'Closing the accessibility helper.'
        foreach ($helper in $helpers) { Stop-Process -Id $helper.ProcessId -Force -ErrorAction SilentlyContinue }
        $until = (Get-Date).AddSeconds(5)
        while ((Get-Date) -lt $until -and @($helpers | Where-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }).Count) { Start-Sleep -Milliseconds 200 }
    }
    $lock = [IO.File]::Open((Join-Path $base 'companion.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    try {
        $receipt = Get-Content -LiteralPath (Join-Path $base 'receipt.json') -Raw | ConvertFrom-Json
        $app = Join-Path $base 'App'
        if ($receipt.app_path -ne $app) { throw 'Receipt App path does not match this user.' }
        $manifest = Get-Content -LiteralPath (Join-Path $app 'manifest.json') -Raw | ConvertFrom-Json
        $target = Join-Path $receipt.game_path 'data/warhammer_access.pack'
        if (Test-Path -LiteralPath $target) {
            if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $receipt.pack_sha256) {
                throw 'Installed pack changed; it was left untouched. Back it up and remove it manually if desired.'
            }
            Remove-Item -LiteralPath $target
        }
        $installedNames = @('Companion.ps1','Bridge.cs','NvdaController.cs','MenuKeys.cs','Protocol.ps1','Uninstall.ps1','README.txt',
            'Start Pilot.cmd','Uninstall.cmd','nvdaControllerClient.dll','LICENSE-NVDA-CONTROLLER.txt','warhammer2-quiet-mode-0.1.0.nvda-addon',
            'Update.ps1','Update.cmd')
        if ($manifest.automation_protocol -eq 1) { $installedNames += 'Automation.ps1' }
        foreach ($name in $installedNames) {
            $path = Join-Path $app $name
            if ((Test-Path -LiteralPath $path) -and (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $manifest.files.$name) {
                Remove-Item -LiteralPath $path
            }
        }
        foreach ($name in @('config.json','manifest.json')) { Remove-Item -LiteralPath (Join-Path $app $name) -ErrorAction SilentlyContinue }
        if (@(Get-ChildItem -LiteralPath $app -Force).Count -eq 0) { Remove-Item -LiteralPath $app }
        if ($env:OS -eq 'Windows_NT') {
            foreach ($pair in @(@('Warhammer NVDA Pilot.lnk','Start Pilot.cmd'), @('Warhammer NVDA Update.lnk','Update.cmd'))) {
                $shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) $pair[0]
                if (Test-Path -LiteralPath $shortcutPath) {
                    $shell = New-Object -ComObject WScript.Shell
                    if ($shell.CreateShortcut($shortcutPath).TargetPath -eq (Join-Path $app $pair[1])) { Remove-Item -LiteralPath $shortcutPath }
                }
            }
        }
        Remove-Item -LiteralPath (Join-Path $base 'receipt.json')
        Write-Host 'Removed. Saves, other mods and diagnostic logs were kept.'
        Write-Host 'Remove Warhammer II Quiet Mode separately in NVDA Add-on Manager, then restart NVDA.'
    } finally { $lock.Dispose() }
    exit 0
} catch { Write-Host ('Uninstall failed: ' + $_.Exception.Message); exit 1 }
