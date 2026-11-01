$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'companion/Protocol.ps1')
Add-Type -Path (Join-Path $root 'companion/Bridge.cs')
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Line([string]$Session, [long]$Sequence, [string]$Text) {
    return (@{version=1; session=$Session; sequence=$Sequence; context='campaign'; kind='speech'; text=$Text} | ConvertTo-Json -Compress)
}
$tmp = Join-Path $root ('local/bridge-test-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tmp)
try {
    $path = Join-Path $tmp 'events.jsonl'
    [IO.File]::WriteAllText($path, ((Line 'old' 1 'stale') + "`n"))
    $tail = [WarhammerAccessibility.Tail]::new($path, $true)
    Assert ($tail.Poll().Count -eq 0) 'Must skip preexisting history'
    $text = (Line 'current' 1 'Café') + "`n"
    $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    $stream = [IO.File]::Open($path, 'Append', 'Write', 'ReadWrite')
    $stream.Write($bytes,0,5); $stream.Dispose()
    Assert ($tail.Poll().Count -eq 0) 'Partial record was emitted'
    $stream = [IO.File]::Open($path, 'Append', 'Write', 'ReadWrite')
    $stream.Write($bytes,5,$bytes.Length-5); $stream.Dispose()
    $lines = $tail.Poll()
    Assert ($lines.Count -eq 1) 'Completed record missing'
    $state = New-ProtocolState
    $record = Convert-BridgeRecord $lines[0] $state
    Assert ($record.text -eq 'Café') 'Record changed'
    Assert ($null -eq (Convert-BridgeRecord $lines[0] $state)) 'Duplicate not rejected'
    Assert ($null -eq (Convert-BridgeRecord '{invalid' $state)) 'Invalid JSON not rejected'
    Assert ($null -eq (Convert-BridgeRecord (Line 'current' 0 'bad') $state)) 'Invalid sequence accepted'
    [void](Convert-BridgeRecord (Line 'new' 1 'new context') $state)
    Assert ($null -eq (Convert-BridgeRecord (Line 'current' 9 'retired') $state)) 'Retired session replayed'
    # Replace with longer content; length-only truncation detection would miss this.
    [IO.File]::WriteAllText($path, ((Line 'replacement' 1 ('x' * 400)) + "`n"))
    Assert ($tail.Poll().Count -eq 1) 'Replacement/regrowth was not detected'
    # Split a UTF-8 multi-byte character between polls.
    $unicode = [Text.Encoding]::UTF8.GetBytes(([string][char]0x00e9) + "`n")
    $stream = [IO.File]::Open($path, 'Append', 'Write', 'ReadWrite')
    $stream.Write($unicode,0,1); $stream.Dispose()
    Assert ($tail.Poll().Count -eq 0) 'Partial UTF-8 decoded prematurely'
    $stream = [IO.File]::Open($path, 'Append', 'Write', 'ReadWrite')
    $stream.Write($unicode,1,$unicode.Length-1); $stream.Dispose()
    Assert ($tail.Poll()[0] -eq [string][char]0x00e9) 'UTF-8 character corrupted'
    [IO.File]::AppendAllText($path, ('a' * 40000) + "`n" + (Line 'replacement' 2 'after oversized') + "`n")
    $lines = $tail.Poll()
    Assert ($tail.OversizedRecords -eq 1 -and $lines.Count -eq 1) 'Oversized record recovery failed'
    $stream = [IO.File]::Open($path, 'Append', 'Write', 'ReadWrite')
    $bad = [byte[]]@(255,10); $stream.Write($bad,0,2); $stream.Dispose()
    Assert ($tail.Poll().Count -eq 0 -and $tail.InvalidUtf8Records -eq 1) 'Malformed UTF-8 recovery failed'
    Remove-Item -LiteralPath $path
    Assert ($tail.Poll().Count -eq 0) 'Deleted file mishandled'
    [IO.File]::WriteAllText($path, ((Line 'reborn' 1 'again') + "`n"))
    Assert ($tail.Poll().Count -eq 1) 'New file not read'
    # Parse every shipped PowerShell file, not just the companion.
    foreach ($directory in @('companion','packaging/pilot')) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root $directory) -Filter '*.ps1') {
            $tokens=$null; $errors=$null
            $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
            Assert ($errors.Count -eq 0) ("Parser errors: " + $file.Name + ' ' + $errors)
        }
    }
    Write-Output 'PASS: incremental UTF-8, partial lines, bounded records, replacement/truncation, history suppression, sequence/session checks, script parsing'
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
