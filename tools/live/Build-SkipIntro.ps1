# Build work/skip-intro/warhammer_skip_intro.pack: three empty files named like the
# game's startup movies, so the game skips them. Test launches only; the game
# folder and TW Mod Manager's profile are never touched.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$rpfm = Join-Path $repo 'local\tools\rpfm-4.5.4-windows\rpfm_cli.exe'
$dir = Join-Path $repo 'work\skip-intro'
$src = Join-Path $dir 'src'
[void][IO.Directory]::CreateDirectory($src)
$pack = Join-Path $dir 'warhammer_skip_intro.pack'
if (Test-Path -LiteralPath $pack) { Remove-Item -LiteralPath $pack }
& $rpfm --game warhammer_2 pack create -p $pack 2>$null
& $rpfm --game warhammer_2 pack set-file-type -p $pack -f mod 2>$null
# Startup movies, plus the High Elves campaign intro used by the Tyrion test
# campaign (the in-engine flyover still plays).
$movies = @('movies/startup_movie_01.ca_vp8','movies/startup_movie_02.ca_vp8','movies/startup_movie_03.ca_vp8',
    'movies/warhammer2/hef/hef_intro.ca_vp8')
foreach ($movie in $movies) {
    $file = Join-Path $src ($movie -replace '[/\\]','_')
    [IO.File]::WriteAllBytes($file, [byte[]]@())
    & $rpfm --game warhammer_2 pack add -p $pack -f ($file + ';' + $movie) 2>$null
    if ($LASTEXITCODE) { throw "Adding $movie failed." }
}
$listed = @(& $rpfm --game warhammer_2 pack list -p $pack 2>$null | Where-Object { $_ -like 'movies/*' })
if ($listed.Count -ne $movies.Count) { throw "Expected $($movies.Count) movie entries, found $($listed.Count)." }
"BUILT=$pack"
