# Update to the newest version in one step. First asks GitHub for the latest
# release of the mod; if it is newer than the installed version, downloads its
# ZIP, checks it against the published SHA-256 file, unpacks it to a temporary
# folder and runs its installer (which checks every file, closes the helper
# and upgrades in place). Without internet (or with -Offline) it uses the
# newest warhammer2-windows-<version>-nvda-automation-preview.zip saved in
# Downloads or on the Desktop, after asking (it is not checked the way a
# GitHub download is). -Zip picks a file. -Yes answers the question; -Folder,
# -ApiBase, -GamePath and -NoShortcut are for tests.
param([string]$Zip, [string[]]$Folder, [string]$GamePath, [switch]$NoShortcut, [switch]$Offline, [switch]$Yes,
    [string]$Repository = 'Caseyshea96/nvda_warhammer2', [string]$ApiBase = 'https://api.github.com')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # the progress bar makes downloads very slow in Windows PowerShell
function Get-ZipVersion([string]$Name) {
    $m = [regex]::Match($Name, '^warhammer2-windows-(\d+)\.(\d+)\.(\d+)-nvda-automation-preview( \(\d+\))?\.zip$')
    if ($m.Success) { return [version]('{0}.{1}.{2}' -f $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value) }
}
function Get-Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
$work = Join-Path ([IO.Path]::GetTempPath()) ('warhammer-update-' + [guid]::NewGuid().ToString('N'))
try {
    $base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
    $installed = $null
    try { $installed = [version](([string](Get-Content -LiteralPath (Join-Path $base 'receipt.json') -Raw | ConvertFrom-Json).version).Split('-')[0]) } catch { }
    $chosen = $null; $version = $null
    [void][IO.Directory]::CreateDirectory($work)
    if ($Zip) {
        $chosen = (Get-Item -LiteralPath $Zip).FullName
        $version = Get-ZipVersion (Split-Path -Leaf $chosen)
        if (-not $version) { throw "Not an accessibility mod ZIP: $(Split-Path -Leaf $chosen)" }
    }
    if (-not $chosen -and -not $Offline) {
        # The latest GitHub release: its ZIP and the ZIP's .sha256 file.
        $release = $null
        try {
            Write-Host 'Checking GitHub for the newest version.'
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $release = Invoke-RestMethod -Uri "$ApiBase/repos/$Repository/releases/latest" -Headers @{ 'User-Agent' = 'warhammer-access-update' } -TimeoutSec 30
        } catch {
            $status = $null
            try { $status = [int]$_.Exception.Response.StatusCode } catch { }
            if ($status -eq 404) { Write-Host 'No release on GitHub yet; looking in Downloads and on the Desktop instead.' }
            else { Write-Host 'Could not reach GitHub; looking in Downloads and on the Desktop instead.' }
        }
        if ($release) {
            $asset = $null; $assetVersion = $null
            foreach ($candidate in @($release.assets)) {
                $v = Get-ZipVersion ([string]$candidate.name)
                if ($v -and (-not $assetVersion -or $v -gt $assetVersion)) { $asset, $assetVersion = $candidate, $v }
            }
            if (-not $asset) {
                Write-Host 'The newest GitHub release has no mod ZIP; looking in Downloads and on the Desktop instead.'
            } elseif ($installed -and $assetVersion -le $installed) {
                Write-Host "Version $installed is installed; the newest release is $assetVersion. Nothing to update."
                exit 0
            } else {
                $check = @($release.assets) | Where-Object { $_.name -eq ($asset.name + '.sha256') } | Select-Object -First 1
                if (-not $check) { throw "The release has no checksum file for $($asset.name); not installing it." }
                Write-Host "Downloading version $assetVersion."
                $download = Join-Path $work $asset.name
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $download -UseBasicParsing -Headers @{ 'User-Agent' = 'warhammer-access-update' } -TimeoutSec 600
                # Saved to a file: GitHub serves it as binary, not text.
                $checkFile = Join-Path $work 'checksum.sha256'
                Invoke-WebRequest -Uri $check.browser_download_url -OutFile $checkFile -UseBasicParsing -Headers @{ 'User-Agent' = 'warhammer-access-update' } -TimeoutSec 60
                $expected = ([IO.File]::ReadAllText($checkFile)).Trim().Split(' ')[0].ToLowerInvariant()
                if ($expected -notmatch '^[0-9a-f]{64}$' -or (Get-Hash $download) -ne $expected) { throw 'The download does not match its checksum; not installing it. Try again later.' }
                $chosen, $version = $download, $assetVersion
            }
        }
    }
    if (-not $chosen) {
        if (-not $Folder) {
            $Folder = @([Environment]::GetFolderPath('Desktop'))
            try {
                # The real Downloads folder (it can be moved), else the usual place.
                $downloads = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
                $Folder += [Environment]::ExpandEnvironmentVariables($downloads)
            } catch { }
            $Folder += Join-Path $env:USERPROFILE 'Downloads'
        }
        foreach ($place in ($Folder | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique)) {
            foreach ($file in Get-ChildItem -LiteralPath $place -Filter 'warhammer2-windows-*.zip' -File) {
                $v = Get-ZipVersion $file.Name
                if ($v -and (-not $version -or $v -gt $version)) { $chosen, $version = $file.FullName, $v }
            }
        }
        if (-not $chosen) {
            Write-Host 'No update found. Connect to the internet, or save the new ZIP (its name starts with warhammer2-windows) in Downloads or on the Desktop, then run this again.'
            exit 1
        }
        if ($installed -and $version -le $installed) {
            Write-Host "Version $installed is installed; the newest download is $version. Nothing to update."
            exit 0
        }
        # Not from GitHub, so not checked against a published checksum: ask.
        if (-not $Yes) {
            $answer = Read-Host ("Install version $version from " + $chosen + '? Type Y and press Enter to install, or just press Enter to cancel')
            if ([string]$answer -notmatch '^\s*[Yy]') { Write-Host 'Update cancelled.'; exit 1 }
        }
    }
    Write-Host ($(if ($installed) { "Updating from version $installed to $version." } else { "Installing version $version." }))
    $unpacked = Join-Path $work 'package'
    Expand-Archive -LiteralPath $chosen -DestinationPath $unpacked
    $installer = Get-ChildItem -LiteralPath $unpacked -Recurse -Filter 'Install.ps1' -File | Select-Object -First 1
    if (-not $installer) { throw 'The ZIP has no installer.' }
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$installer.FullName)
    if ($GamePath) { $arguments += @('-GamePath',$GamePath) }
    if ($NoShortcut) { $arguments += '-NoShortcut' }
    & powershell.exe @arguments
    exit $LASTEXITCODE
} catch {
    Write-Host ('Update failed: ' + $_.Exception.Message)
    exit 1
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
