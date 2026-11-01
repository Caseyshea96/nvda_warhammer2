# Update to the newest downloaded version in one step: finds the newest
# warhammer2-windows-<version>-nvda-automation-preview.zip in Downloads or on
# the Desktop, unpacks it to a temporary folder and runs its installer (which
# checks every file, closes the helper and upgrades in place). Nothing to
# extract by hand. -Zip picks a file; -Folder, -GamePath and -NoShortcut are
# for tests.
param([string]$Zip, [string[]]$Folder, [string]$GamePath, [switch]$NoShortcut)
$ErrorActionPreference = 'Stop'
function Get-ZipVersion([string]$Name) {
    $m = [regex]::Match($Name, '^warhammer2-windows-(\d+)\.(\d+)\.(\d+)-nvda-automation-preview( \(\d+\))?\.zip$')
    if ($m.Success) { return [version]('{0}.{1}.{2}' -f $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value) }
}
$temp = $null
try {
    $base = Join-Path $env:LOCALAPPDATA 'WarhammerAccess'
    $installed = $null
    try { $installed = [version](([string](Get-Content -LiteralPath (Join-Path $base 'receipt.json') -Raw | ConvertFrom-Json).version).Split('-')[0]) } catch { }
    if ($Zip) {
        $chosen = Get-Item -LiteralPath $Zip
        $version = Get-ZipVersion $chosen.Name
        if (-not $version) { throw "Not an accessibility mod ZIP: $($chosen.Name)" }
    } else {
        if (-not $Folder) {
            $Folder = @([Environment]::GetFolderPath('Desktop'))
            try {
                # The real Downloads folder (it can be moved), else the usual place.
                $downloads = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
                $Folder += [Environment]::ExpandEnvironmentVariables($downloads)
            } catch { }
            $Folder += Join-Path $env:USERPROFILE 'Downloads'
        }
        $chosen = $null; $version = $null
        foreach ($place in ($Folder | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique)) {
            foreach ($file in Get-ChildItem -LiteralPath $place -Filter 'warhammer2-windows-*.zip' -File) {
                $v = Get-ZipVersion $file.Name
                if ($v -and (-not $version -or $v -gt $version)) { $chosen, $version = $file, $v }
            }
        }
        if (-not $chosen) {
            Write-Host 'No update found. Save the new ZIP (its name starts with warhammer2-windows) in Downloads or on the Desktop, then run this again.'
            exit 1
        }
        if ($installed -and $version -le $installed) {
            Write-Host "Version $installed is installed; the newest download is $version. Nothing to update."
            exit 0
        }
    }
    Write-Host ($(if ($installed) { "Updating from version $installed to $version." } else { "Installing version $version." }))
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('warhammer-update-' + [guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $chosen.FullName -DestinationPath $temp
    $installer = Get-ChildItem -LiteralPath $temp -Recurse -Filter 'Install.ps1' -File | Select-Object -First 1
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
    if ($temp -and (Test-Path -LiteralPath $temp)) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
