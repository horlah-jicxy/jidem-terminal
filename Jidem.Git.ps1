# ==============================================================================
# Jidem.Git.ps1 - Phase 4 git intelligence (READ-ONLY)
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE after the other Jidem lines.
# Works in whichever repository you are currently inside (or pass -Path).
#
# Commands:
#   gitstatus              repository, branch, sync with upstream, state, last commit
#   gitchanges [-Stat]     changed files grouped: staged / modified / untracked / conflicts
#   gitlog [-Count 10]     recent commits, one line each
#   gitbranch [-All]       current branch and local branches (-All adds remote ones)
#   gitroot [-Go]          print the repository root (-Go moves you there)
#
# Nothing here commits, stages, pulls, pushes, fetches, or switches branches.
# Sync information reflects your last fetch; it does not contact the remote.
# ==============================================================================

if (-not (Get-Command Get-JidemGit -ErrorAction SilentlyContinue)) {
    Write-Host 'Jidem.Git.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
    return
}

# ---------- Helpers ----------

function Get-JidemRepoRoot([string]$Path = (Get-Location).Path) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host 'Git is not installed or not on PATH.' -ForegroundColor Yellow
        return $null
    }
    $root = git -C $Path rev-parse --show-toplevel 2>$null
    if (-not $root) {
        Write-Host 'Not inside a Git repository.' -ForegroundColor Yellow
        return $null
    }
    $root -replace '/', '\'
}

function Get-JidemChangeList([string]$Root) {
    $lines = @(git -C $Root -c core.quotepath=false status --porcelain 2>$null)
    foreach ($l in $lines) {
        if ($l.Length -lt 4) { continue }
        [pscustomobject]@{
            X    = [string]$l[0]
            Y    = [string]$l[1]
            Path = $l.Substring(3).Trim('"')
        }
    }
}

function Get-JidemStatusWord([string]$Code) {
    switch ($Code) {
        'M' { 'modified' }
        'A' { 'added' }
        'D' { 'deleted' }
        'R' { 'renamed' }
        'C' { 'copied' }
        'T' { 'type changed' }
        default { $Code }
    }
}

# ---------- Commands ----------

function gitroot {
    param([switch]$Go, [string]$Path = (Get-Location).Path)
    $root = Get-JidemRepoRoot $Path
    if (-not $root) { return }
    if ($Go) { Set-Location -LiteralPath $root } else { Write-Host $root }
}

function gitstatus {
    param([string]$Path = (Get-Location).Path)
    $root = Get-JidemRepoRoot $Path
    if (-not $root) { return }

    Write-JidemBanner "$($Global:JidemAccount) GIT STATUS"
    Write-Host 'REPOSITORY' -ForegroundColor Yellow
    Write-Host "  $(Split-Path $root -Leaf)"
    Write-Host "  $root" -ForegroundColor DarkGray
    Write-Host ''

    $branch = git -C $root branch --show-current 2>$null
    if (-not $branch) { $branch = '(detached HEAD) ' + (git -C $root rev-parse --short HEAD 2>$null) }
    Write-Host 'BRANCH' -ForegroundColor Yellow
    Write-Host "  $branch"
    Write-Host ''

    Write-Host 'SYNC (as of last fetch)' -ForegroundColor Yellow
    $upstream = git -C $root rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    if ($upstream) {
        $counts = (git -C $root rev-list --left-right --count '@{u}...HEAD' 2>$null) -split '\s+'
        $behind = [int]$counts[0]; $ahead = [int]$counts[1]
        if ($ahead -eq 0 -and $behind -eq 0) { Write-Host "  Up to date with $upstream" }
        else { Write-Host "  $ahead ahead, $behind behind $upstream" -ForegroundColor Yellow }
    }
    else { Write-Host '  No upstream branch set' -ForegroundColor DarkGray }
    Write-Host ''

    $changes = @(Get-JidemChangeList $root)
    Write-Host 'STATUS' -ForegroundColor Yellow
    if (-not $changes.Count) { Write-Host '  Clean' -ForegroundColor Green }
    else {
        $staged    = @($changes | Where-Object { $_.X -ne ' ' -and $_.X -ne '?' -and $_.X -ne 'U' }).Count
        $modified  = @($changes | Where-Object { $_.Y -ne ' ' -and $_.Y -ne '?' -and $_.Y -ne 'U' }).Count
        $untracked = @($changes | Where-Object { $_.X -eq '?' }).Count
        $conflicts = @($changes | Where-Object { $_.X -eq 'U' -or $_.Y -eq 'U' }).Count
        Write-Host ("  {0} staged, {1} modified, {2} untracked" -f $staged, $modified, $untracked) -ForegroundColor Yellow
        if ($conflicts) { Write-Host "  $conflicts conflict(s)" -ForegroundColor Red }
        Write-Host '  Details: gitchanges' -ForegroundColor DarkGray
    }
    Write-Host ''

    Write-Host 'LAST COMMIT' -ForegroundColor Yellow
    $fmt = '--format=%h %s (%cr, %an)'
    $last = git -C $root log -1 $fmt 2>$null
    if ($last) { Write-Host "  $last" } else { Write-Host '  No commits yet' -ForegroundColor DarkGray }
    Write-Host ''
    Write-JidemFooter
}

function gitchanges {
    param([switch]$Stat, [string]$Path = (Get-Location).Path)
    $root = Get-JidemRepoRoot $Path
    if (-not $root) { return }
    $changes = @(Get-JidemChangeList $root)
    if (-not $changes.Count) { Write-Host 'No changes. Working tree is clean.' -ForegroundColor Green; return }

    Write-Host "$(Split-Path $root -Leaf)  [$(git -C $root branch --show-current 2>$null)]" -ForegroundColor Cyan
    Write-Host ''

    $conflicts = @($changes | Where-Object { $_.X -eq 'U' -or $_.Y -eq 'U' })
    $staged    = @($changes | Where-Object { $_.X -ne ' ' -and $_.X -ne '?' -and $_.X -ne 'U' -and $_.Y -ne 'U' })
    $modified  = @($changes | Where-Object { $_.Y -ne ' ' -and $_.Y -ne '?' -and $_.X -ne 'U' -and $_.Y -ne 'U' })
    $untracked = @($changes | Where-Object { $_.X -eq '?' })

    if ($conflicts.Count) {
        Write-Host "CONFLICTS ($($conflicts.Count))" -ForegroundColor Red
        foreach ($c in $conflicts) { Write-Host "  $($c.Path)" }
        Write-Host ''
    }
    if ($staged.Count) {
        Write-Host "STAGED - will be in the next commit ($($staged.Count))" -ForegroundColor Green
        foreach ($c in $staged) { Write-Host ('  {0,-12}{1}' -f (Get-JidemStatusWord $c.X), $c.Path) }
        Write-Host ''
    }
    if ($modified.Count) {
        Write-Host "MODIFIED - not staged ($($modified.Count))" -ForegroundColor Yellow
        foreach ($c in $modified) { Write-Host ('  {0,-12}{1}' -f (Get-JidemStatusWord $c.Y), $c.Path) }
        Write-Host ''
    }
    if ($untracked.Count) {
        Write-Host "UNTRACKED - new files git does not know yet ($($untracked.Count))" -ForegroundColor DarkYellow
        foreach ($c in $untracked) { Write-Host "  $($c.Path)" }
        Write-Host ''
    }
    if ($Stat) {
        Write-Host 'SIZE OF CHANGES' -ForegroundColor Cyan
        git -C $root diff --stat 2>$null
        $cached = git -C $root diff --cached --stat 2>$null
        if ($cached) { Write-Host '(staged)' -ForegroundColor DarkGray; $cached }
        Write-Host ''
    }
}

function gitlog {
    param([int]$Count = 10, [string]$Path = (Get-Location).Path)
    $root = Get-JidemRepoRoot $Path
    if (-not $root) { return }
    $fmt = '--format=%h|%ad|%an|%s'
    $lines = @(git -C $root log -n $Count --date=short $fmt 2>$null)
    if (-not $lines.Count) { Write-Host 'No commits yet.' -ForegroundColor DarkGray; return }
    Write-Host "$(Split-Path $root -Leaf)  [$(git -C $root branch --show-current 2>$null)]" -ForegroundColor Cyan
    foreach ($l in $lines) {
        $p = $l -split '\|', 4
        Write-Host ('  {0}  {1}  ' -f $p[0], $p[1]) -NoNewline -ForegroundColor Yellow
        Write-Host ('{0,-14} ' -f $p[2]) -NoNewline -ForegroundColor DarkGray
        Write-Host $p[3]
    }
}

function gitbranch {
    param([switch]$All, [string]$Path = (Get-Location).Path)
    $root = Get-JidemRepoRoot $Path
    if (-not $root) { return }
    $current = git -C $root branch --show-current 2>$null
    Write-Host "CURRENT  $current" -ForegroundColor Cyan
    $upstream = git -C $root rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    if ($upstream) { Write-Host "UPSTREAM $upstream" -ForegroundColor DarkGray }
    Write-Host ''
    $refs = @('refs/heads')
    if ($All) { $refs += 'refs/remotes' }
    $fmt = '--format=%(HEAD)|%(refname:short)|%(committerdate:relative)'
    $lines = @(git -C $root for-each-ref --sort=-committerdate $fmt @refs 2>$null)
    foreach ($l in $lines) {
        $p = $l -split '\|', 3
        $isCurrent = ($p[0] -eq '*')
        Write-Host ('  {0} {1,-30}' -f $(if ($isCurrent) { '*' } else { ' ' }), $p[1]) -NoNewline -ForegroundColor $(if ($isCurrent) { 'Green' } else { 'Gray' })
        Write-Host $p[2] -ForegroundColor DarkGray
    }
}
