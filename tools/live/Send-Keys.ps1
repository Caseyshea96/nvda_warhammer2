# Inject key presses (as a user would type them) for live tests of the
# companion's menu keys. The game itself ignores injected keys; the companion's
# focus-scoped hotkeys receive them. Names: Down Up Tab ShiftTab Home End Backspace
# Enter Space Escape F6 ShiftF6 F7, or a single letter A-Z.
param([Parameter(Mandatory=$true)][string[]]$Keys, [int]$DelayMs = 500)
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class KeyInput {
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@
$Keys = @($Keys | ForEach-Object { $_ -split ',' } | Where-Object { $_ })  # -File passes "a,b" as one string
$codes = @{ Down=0x28; Up=0x26; Tab=0x09; Home=0x24; End=0x23; Enter=0x0D; Space=0x20; Escape=0x1B; Backspace=0x08; F6=0x75; F7=0x76 }
foreach ($name in $Keys) {
    $shift = $false
    if ($name -eq 'ShiftTab') { $vk = 0x09; $shift = $true }
    elseif ($name -eq 'ShiftF6') { $vk = 0x75; $shift = $true }
    elseif ($codes.ContainsKey($name)) { $vk = $codes[$name] }
    elseif ($name -match '^[A-Za-z]$') { $vk = [int][char]$name.ToUpperInvariant() }
    else { throw "Unknown key name: $name" }
    $extended = if ($vk -in 0x23,0x24,0x26,0x28) { 1 } else { 0 }
    if ($shift) { [KeyInput]::keybd_event(0x10, 0, 0, [UIntPtr]::Zero) }
    [KeyInput]::keybd_event([byte]$vk, 0, $extended, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [KeyInput]::keybd_event([byte]$vk, 0, (2 -bor $extended), [UIntPtr]::Zero)
    if ($shift) { [KeyInput]::keybd_event(0x10, 0, 2, [UIntPtr]::Zero) }
    "SENT $name"
    Start-Sleep -Milliseconds $DelayMs
}
