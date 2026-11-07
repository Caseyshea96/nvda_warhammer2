param([string]$ClientPath=(Join-Path $PSScriptRoot '..\tools\live\Campaign-ReadOnly.ps1'))
$ErrorActionPreference='Stop'
$client=(Resolve-Path -LiteralPath $ClientPath).Path
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixture=Join-Path $tempRoot ('wh2-campaign-client-' + [guid]::NewGuid().ToString('N'))
$resolved=[IO.Path]::GetFullPath($fixture)
if (-not $resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped temp root.' }
[void][IO.Directory]::CreateDirectory($fixture)
$enc=New-Object Text.UTF8Encoding($false)
$owner='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
$expires=[datetime]::UtcNow.AddMinutes(10).ToString('yyyy-MM-ddTHH:mm:ssZ')
$flag=Join-Path $fixture 'campaign-discovery.tsv'
$statusPath=Join-Path $fixture 'campaign-discovery-status.json'
$requestPath=Join-Path $fixture 'campaign-discovery-request.tsv'
$state=[pscustomobject]@{protocol='WH2CAMSTATUS1';version='0.6.75';owner=$owner;session=('campaign:'+$owner+':fixture');generation=2;phase='ready';request='';result='capture-complete';attempts=1;run=1;count=4;index=1;errors=0;complete=$true;expires=$expires;selected_key='campaign:tree.child0:text';label='Fixture HUD'}
function Save-State { [IO.File]::WriteAllText($statusPath,($state | ConvertTo-Json -Compress)+"`n",$enc) }
function Invoke-Client([string]$Action,[int]$Timeout=1500) {
    $previous=$ErrorActionPreference;$ErrorActionPreference='Continue'
    $output=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -Action $Action -BasePath $fixture -TimeoutMs $Timeout 2>&1
    $code=$LASTEXITCODE;$ErrorActionPreference=$previous
    return [pscustomobject]@{Code=$code;Text=($output -join "`n")}
}
$job=$null
try {
    [IO.File]::WriteAllText($flag,"WH2CAM1`t$owner`t$expires`tverify`n",$enc);Save-State
    $reply=Invoke-Client Status
    if ($reply.Code -or ($reply.Text | ConvertFrom-Json).label -ne 'Fixture HUD') { throw ('Status failed: '+$reply.Text) }
    $state.owner='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';Save-State
    if ((Invoke-Client Capture).Code -eq 0 -or (Test-Path -LiteralPath $requestPath)) { throw 'Wrong owner wrote a request.' }
    $state.owner=$owner;$state.generation='2';Save-State
    if ((Invoke-Client Capture).Code -eq 0 -or (Test-Path -LiteralPath $requestPath)) { throw 'Bad generation wrote a request.' }
    $state.generation=2;Save-State
    if ((Invoke-Client Activate).Code -eq 0 -or (Test-Path -LiteralPath $requestPath)) { throw 'Client accepted an activation action.' }
    [IO.File]::WriteAllText($flag,"WH2CAM1`t$owner`t2000-01-01T00:00:00Z`tverify`n",$enc)
    if ((Invoke-Client Capture).Code -eq 0 -or (Test-Path -LiteralPath $requestPath)) { throw 'Expired flag wrote a request.' }
    [IO.File]::WriteAllText($flag,"WH2CAM1`t$owner`t$expires`tverify`n",$enc);Save-State
    $job=Start-Job -ArgumentList $fixture,$state -ScriptBlock {
        param($root,$snapshot)
        $deadline=[datetime]::UtcNow.AddSeconds(10)
        while ([datetime]::UtcNow -lt $deadline) {
            $path=Join-Path $root 'campaign-discovery-request.tsv'
            if (Test-Path -LiteralPath $path) {
                $parts=[IO.File]::ReadAllText($path).TrimEnd("`n").Split("`t")
                if ($parts.Count -ne 6 -or $parts[0] -ne 'WH2CAMCAP1' -or $parts[1] -ne $snapshot.owner -or $parts[2] -ne $snapshot.session -or $parts[3] -ne '2' -or $parts[4] -notmatch '^[a-f0-9]{32}$') { throw 'Invalid capture contract.' }
                $snapshot.request=$parts[4];$snapshot.result='accepted';$snapshot.phase='waiting';$snapshot.generation=3
                [IO.File]::WriteAllText((Join-Path $root 'campaign-discovery-status.json'),($snapshot | ConvertTo-Json -Compress)+"`n",(New-Object Text.UTF8Encoding($false)))
                return $parts[4]
            }
            Start-Sleep -Milliseconds 50
        }
        throw 'No mock capture request arrived.'
    }
    $reply=Invoke-Client Capture 5000
    if ($reply.Code -or ($reply.Text | ConvertFrom-Json).result -ne 'accepted') { throw ('Capture acknowledgement failed: '+$reply.Text) }
    $null=Wait-Job $job -Timeout 10
    $token=Receive-Job $job -ErrorAction Stop
    if (($reply.Text | ConvertFrom-Json).request -ne $token) { throw 'Acknowledgement token mismatch.' }
    Remove-Job $job;$job=$null
    # A read-only request timeout is reported and never resent automatically.
    $state.generation=3;Save-State
    $reply=Invoke-Client Capture 250
    if ($reply.Code -eq 0 -or $reply.Text -notlike '*No capture acknowledgement*') { throw 'Missing acknowledgement was not reported.' }
    if (@(Get-ChildItem -LiteralPath $fixture -Filter '*.tmp').Count) { throw 'Atomic writer leaked temporary files.' }
    'PASS: campaign client status, owner/type/expiry guards, capture-only schema, exact acknowledgement and no retry on timeout'
} finally {
    if ($job) { Stop-Job $job -ErrorAction SilentlyContinue;Remove-Job $job -Force -ErrorAction SilentlyContinue }
    $check=[IO.Path]::GetFullPath($fixture)
    if ($check -ne $resolved -or -not $check.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing cleanup outside verified fixture.' }
    Remove-Item -LiteralPath $check -Recurse -Force
}
