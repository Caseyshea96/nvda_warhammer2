param([string]$GamePath, [switch]$NoShortcut)
$ErrorActionPreference = 'Stop'
function Get-Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Test-GameFolder([string]$Path) {
    return $Path -and
        (Test-Path -LiteralPath (Join-Path $Path 'Warhammer2.exe') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Path 'data') -PathType Container)
}
function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json } catch { return $null }
}
function Same-Folder([string]$A, [string]$B) {
    return $A -and $B -and ([IO.Path]::GetFullPath($A).TrimEnd('\','/') -eq [IO.Path]::GetFullPath($B).TrimEnd('\','/'))
}
try {
    $manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
    # Only fixed local filenames from our package can be installed.
    $expectedNames = @('warhammer_access.pack','Companion.ps1','Bridge.cs','NvdaController.cs','MenuKeys.cs','Protocol.ps1','Uninstall.ps1',
        'Start Pilot.cmd','Uninstall.cmd','README.txt','nvdaControllerClient.dll','LICENSE-NVDA-CONTROLLER.txt','warhammer2-quiet-mode-0.1.0.nvda-addon')
    if ($manifest.automation_protocol -eq 1) { $expectedNames += 'Automation.ps1' }
    foreach ($name in $expectedNames) {
        $expected = $manifest.files.$name
        if (-not $expected -or (Get-Hash (Join-Path $PSScriptRoot $name)) -ne $expected) { throw "Package verification failed: $name" }
    }
    if (Get-Process -Name 'Warhammer2' -ErrorAction SilentlyContinue) { throw 'Close Warhammer II before installing.' }
    if (-not $GamePath) {
        # Resolve the standard Steam locations first. This avoids a prompt on
        # the normal 64-bit Windows installation.
        $standardRoots = @(
            [Environment]::GetFolderPath('ProgramFilesX86'),
            [Environment]::GetFolderPath('ProgramFiles')
        ) | Where-Object { $_ } | Select-Object -Unique
        foreach ($programRoot in $standardRoots) {
            $normal = Join-Path $programRoot 'Steam\steamapps\common\Total War WARHAMMER II'
            if (Test-GameFolder $normal) { $GamePath = $normal; break }
        }
    }
    if (-not $GamePath) {
        $roots = @()
        $steam = Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue
        if ($steam.SteamPath) { $roots += $steam.SteamPath }
        if (${env:ProgramFiles(x86)}) { $roots += (Join-Path ${env:ProgramFiles(x86)} 'Steam') }
        if ($env:ProgramFiles) { $roots += (Join-Path $env:ProgramFiles 'Steam') }
        foreach ($steamRoot in @($roots)) {
            $libraries = Join-Path $steamRoot 'steamapps/libraryfolders.vdf'
            if (Test-Path -LiteralPath $libraries) {
                $vdf = Get-Content -LiteralPath $libraries -Raw
                foreach ($match in [regex]::Matches($vdf, '"path"\s+"((?:\\.|[^"\\])*)"')) {
                    $roots += $match.Groups[1].Value.Replace('\\','\')
                }
            }
        }
        $candidates = @($roots | Select-Object -Unique | ForEach-Object {
            Join-Path $_ 'steamapps/common/Total War WARHAMMER II'
        } | Where-Object { Test-GameFolder $_ })
        if ($candidates.Count -eq 1) { $GamePath = $candidates[0] }
        else { $GamePath = Read-Host 'Enter the game folder (Steam > Manage > Browse local files)' }
    }
    $GamePath = (Resolve-Path -LiteralPath $GamePath.Trim('"')).Path
    if (-not (Test-Path -LiteralPath (Join-Path $GamePath 'Warhammer2.exe') -PathType Leaf)) { throw 'Windows Warhammer2.exe not found.' }
    $data = Join-Path $GamePath 'data'
    if (-not (Test-Path -LiteralPath $data -PathType Container)) { throw 'Game data directory missing.' }
    Write-Host "Using game folder: $GamePath"
    $base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
    [void][IO.Directory]::CreateDirectory($base)

    # Versions up to 0.6.64 used other names: the pack data\jaws_access.pack and
    # the folder %LOCALAPPDATA%\JawsWarhammer2. That install is moved over
    # here: its pack and files are removed only when they match its own
    # receipt and manifest; option flags are copied; its logs stay behind.
    $oldBase = Join-Path $env:LOCALAPPDATA 'JawsWarhammer2'
    $oldApp = Join-Path $oldBase 'App'
    $oldReceipt = Read-Json (Join-Path $oldBase 'receipt.json')
    $oldManifest = Read-Json (Join-Path $oldApp 'manifest.json')
    $oldPack = Join-Path $data 'jaws_access.pack'
    $oldLock = $null
    if (Test-Path -LiteralPath $oldPack) {
        $oldOurs = $oldReceipt -and $oldReceipt.pack_sha256 -and (Same-Folder ([string]$oldReceipt.game_path) $GamePath) -and
            ((Get-Hash $oldPack) -eq ([string]$oldReceipt.pack_sha256).ToLowerInvariant())
        if (-not $oldOurs) {
            throw 'An older jaws_access.pack that this installer cannot confirm is in the game data folder. Back it up and remove it, then run Install.cmd again.'
        }
    }
    if ($oldReceipt) {
        # The old companion must not be running (it holds this lock).
        try { $oldLock = [IO.File]::Open((Join-Path $oldBase 'companion.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
        catch { throw 'Close the Warhammer accessibility helper before installing.' }
    }

    # Refuse to replace files while the companion owns its lock.
    $lock = [IO.File]::Open((Join-Path $base 'companion.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    try {
        $app = Join-Path $base 'App'
        $target = Join-Path $data 'warhammer_access.pack'
        # An earlier version installed by this installer is upgraded in place:
        # its pack matches the receipt and its files match its own manifest.
        # Anything else (a pack or file we did not install, or one changed
        # since) is still left alone.
        $previous = Read-Json (Join-Path $base 'receipt.json')
        $previousManifest = Read-Json (Join-Path $app 'manifest.json')
        $replacePack = $false
        if ((Test-Path -LiteralPath $target) -and (Get-Hash $target) -ne $manifest.files.'warhammer_access.pack') {
            $ours = $previous -and $previous.pack_sha256 -and (Same-Folder ([string]$previous.game_path) $GamePath) -and
                ((Get-Hash $target) -eq ([string]$previous.pack_sha256).ToLowerInvariant())
            if (-not $ours) {
                throw 'A warhammer_access.pack that this installer did not install (or that was changed) is in the game data folder. Back it up and remove it, then run Install.cmd again.'
            }
            $replacePack = $true
        }
        # Verify existing application files before replacing or reusing them.
        if (Test-Path -LiteralPath $app) {
            foreach ($name in $expectedNames) {
                if ($name -eq 'warhammer_access.pack') { continue }
                $existing = Join-Path $app $name
                if ((Test-Path -LiteralPath $existing) -and (Get-Hash $existing) -ne $manifest.files.$name) {
                    $earlier = $previousManifest -and $previousManifest.files -and $previousManifest.files.$name -and
                        ((Get-Hash $existing) -eq ([string]$previousManifest.files.$name).ToLowerInvariant())
                    if (-not $earlier) { throw "Existing companion file was changed: $name. Back up the App folder, run Uninstall.cmd, then Install.cmd again." }
                }
            }
        }
        [void][IO.Directory]::CreateDirectory($app)
        foreach ($name in $expectedNames) {
            if ($name -eq 'warhammer_access.pack') { continue }
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $app $name) -Force
            if ((Get-Hash (Join-Path $app $name)) -ne $manifest.files.$name) { throw "Copy verification failed: $name" }
        }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Destination (Join-Path $app 'manifest.json') -Force
        @{ game_path = $GamePath; version = $manifest.version } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $app 'config.json') -Encoding UTF8
        if ($replacePack) {
            # Copy beside it, verify, then swap, so a failed copy keeps the old pack.
            $incoming = $target + '.new'
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'warhammer_access.pack') -Destination $incoming -Force
            if ((Get-Hash $incoming) -ne $manifest.files.'warhammer_access.pack') { Remove-Item -LiteralPath $incoming; throw 'Copy verification failed: warhammer_access.pack' }
            Move-Item -LiteralPath $incoming -Destination $target -Force
        }
        if (-not (Test-Path -LiteralPath $target)) {
            $sourceStream = [IO.File]::OpenRead((Join-Path $PSScriptRoot 'warhammer_access.pack'))
            try {
                $destStream = [IO.File]::Open($target, 'CreateNew', 'Write')
                try { $sourceStream.CopyTo($destStream) } finally { $destStream.Dispose() }
            } finally { $sourceStream.Dispose() }
        }
        if ((Get-Hash $target) -ne $manifest.files.'warhammer_access.pack') { throw 'Installed pack checksum failed.' }
        $receipt = @{ version = $manifest.version; game_path = $GamePath; pack_sha256 = $manifest.files.'warhammer_access.pack'; app_path = $app }
        $receipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $base 'receipt.json') -Encoding UTF8

        # The new install is complete: now remove the old one (see above).
        $movedFrom = ''
        if ($oldReceipt) {
            foreach ($flag in @(Get-ChildItem -LiteralPath $oldBase -Filter '*.flag' -File -ErrorAction SilentlyContinue)) {
                $destination = Join-Path $base $flag.Name
                if (-not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath $flag.FullName -Destination $destination }
            }
            if (Test-Path -LiteralPath $oldPack) { Remove-Item -LiteralPath $oldPack }
            if ($oldManifest -and $oldManifest.files -and (Test-Path -LiteralPath $oldApp)) {
                foreach ($file in @(Get-ChildItem -LiteralPath $oldApp -File)) {
                    $recorded = $oldManifest.files.($file.Name)
                    if (($recorded -and (Get-Hash $file.FullName) -eq ([string]$recorded).ToLowerInvariant()) -or
                        $file.Name -eq 'manifest.json' -or $file.Name -eq 'config.json') { Remove-Item -LiteralPath $file.FullName }
                }
                if (@(Get-ChildItem -LiteralPath $oldApp -Force).Count -eq 0) { Remove-Item -LiteralPath $oldApp }
            }
            Remove-Item -LiteralPath (Join-Path $oldBase 'receipt.json')
            $movedFrom = ([string]$oldReceipt.version).Split('-')[0]
        }
        if (-not $NoShortcut -and $env:OS -eq 'Windows_NT') {
            try {
                $shell = New-Object -ComObject WScript.Shell
                $desktop = [Environment]::GetFolderPath('Desktop')
                $shortcut = $shell.CreateShortcut((Join-Path $desktop 'Warhammer NVDA Pilot.lnk'))
                $shortcut.TargetPath = Join-Path $app 'Start Pilot.cmd'
                $shortcut.WorkingDirectory = $app
                $shortcut.Save()
            } catch { Write-Host 'Desktop shortcut unavailable; use Start Pilot.cmd in the installed App folder.' }
        }
        $shownVersion = ([string]$manifest.version).Split('-')[0]
        $previousVersion = $(if ($movedFrom) { $movedFrom } elseif ($previous -and $previous.version) { ([string]$previous.version).Split('-')[0] } else { '' })
        if ($previousVersion -and $previousVersion -ne $shownVersion) { Write-Host "Upgraded from version $previousVersion to $shownVersion." }
        else { Write-Host "Installed version $shownVersion." }
        Write-Host "Installed: $app"
        Write-Host 'Start NVDA and Steam, then run the desktop shortcut (or Start Pilot.cmd). It tests NVDA and starts the game with the accessibility mod; no Mod Manager is needed.'
        Write-Host 'Before testing, install warhammer2-quiet-mode-0.1.0.nvda-addon from the App folder and restart NVDA.'
        Write-Host 'If Steam is not running, the game opens through Steam: tick warhammer_access in the Mod Manager and press Play.'
        Write-Host 'This is an experimental prototype; please report what works and what does not.'
    } finally { $lock.Dispose(); if ($oldLock) { $oldLock.Dispose() } }
    exit 0
} catch {
    Write-Host ('Installation failed: ' + $_.Exception.Message)
    Write-Host 'Close the helper/game if running. If Program Files access is denied, run Install.cmd as administrator.'
    Write-Host 'Use the SAME Windows account; a different administrator account has a different LocalAppData folder.'
    exit 1
}
