# Switches to today's version branch, named for the person doing the work:
# <first name>_MMDDYY, e.g. Casey_110726 or Lucas_110726 (owner, Nov 7, 2026).
# The name comes from git's user.name (first word), with known GitHub logins
# mapped to first names; -Name overrides it. An existing branch (here or on
# GitHub) is checked out; otherwise it is created from the current commit
# (start from your newest branch). -Push publishes a new branch to GitHub.
# Also turns on the repo's pre-push check (.githooks), which refuses to push a
# <name>_MMDDYY branch carrying someone else's name.
param([string]$Name, [switch]$Push)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repo
try {
    git config core.hooksPath .githooks
    if (-not $Name) {
        $logins = @{ 'luperdoof' = 'Lucas'; 'caseyshea96' = 'Casey' }
        $user = [string](git config user.name)
        $first = ($user.Trim() -split '\s+')[0]
        if ($logins.ContainsKey($first.ToLowerInvariant())) { $Name = $logins[$first.ToLowerInvariant()] } else { $Name = $first }
    }
    if ($Name -notmatch '^[A-Za-z]+$') { throw "Use -Name with your first name (letters only); git user.name gave '$Name'." }
    $Name = $Name.Substring(0,1).ToUpperInvariant() + $Name.Substring(1).ToLowerInvariant()
    $branch = '{0}_{1}' -f $Name, (Get-Date -Format 'MMddyy')
    $current = (git rev-parse --abbrev-ref HEAD).Trim()
    if ($current -eq $branch) { "Already on $branch."; return }
    git fetch -q origin
    $exists = (git branch --list $branch) -or (git ls-remote --heads origin $branch)
    # Uncommitted changes come along to a new branch (usually wanted); switching
    # to an existing one with them could mix work, so that needs a clean tree.
    if ($exists -and (git status --porcelain --untracked-files=no)) { throw "Commit your changes first, then run this again to switch to $branch." }
    if (git branch --list $branch) { git checkout -q $branch; "Switched to $branch." }
    elseif (git ls-remote --heads origin $branch) { git checkout -q -b $branch --track "origin/$branch"; "Switched to $branch (from GitHub)." }
    else {
        git checkout -q -b $branch
        "Created $branch from $current."
        if ($Push) { git push -q -u origin $branch; "Pushed $branch to GitHub." }
    }
} finally { Pop-Location }
