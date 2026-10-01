# ==============================================================================
# Jidem.Core.ps1 - Phase 1 core control (account-aware)
#
# Loads AFTER JidemCommands.ps1 and never edits it. Add to $PROFILE:
#     . "$HOME\PowerShell\JidemCommands.ps1"
#     . "$HOME\PowerShell\Jidem.Core.ps1"
#
# Commands: status, jwhere, workspace, recent, today, tree (alias map), size
# The same file works in both Windows accounts; the workspace it scans depends on
# which account ($HOME) is running, matching the account guards in JidemCommands.ps1.
# ==============================================================================

$Global:JidemDocs = Join-Path $HOME 'Documents'
$d = $Global:JidemDocs

# Account is taken from the profile folder name: C:\Users\jidem -> JIDEM, C:\Users\makin -> MAKIN.
$Global:JidemAccount = (Split-Path $HOME -Leaf).ToUpper()

# The bridge between the two accounts: a folder both can open (outside either profile).
$sharedBridge = 'C:\Users\Public\Documents\Shared'

# Workspace roots per account (name -> folder). Roots that do not exist are skipped silently,
# so optional folders can be listed without producing noise.
$allRoots = switch ($Global:JidemAccount) {
    'JIDEM' { [ordered]@{
        Academia    = "$d\Academia"
        ACADEMIC    = "$d\ACADEMIC"
        Development = "$d\Development"
        GitHub      = "$d\GitHub"
        Shared      = $sharedBridge
    } }
    'MAKIN' { [ordered]@{
        'UC-Merced'    = "$d\UC-Merced"
        'Current-Work' = "$d\Current-Work"
        Shared         = $sharedBridge
    } }
    default { [ordered]@{ Documents = $d } }
}
$Global:JidemRoots = [ordered]@{}
foreach ($r in $allRoots.GetEnumerator()) {
    if (Test-Path -LiteralPath $r.Value) { $Global:JidemRoots[$r.Key] = $r.Value }
}

# Folders skipped by every scan.
$Global:JidemIgnore = @('.git', 'node_modules', '__pycache__', '.venv', 'venv', '.Rproj.user', '.ipynb_checkpoints')

# ---------- Helpers ----------

function Write-JidemBanner([string]$Title) {
    $line = '=' * 40
    Write-Host ''
    Write-Host $line -ForegroundColor Cyan
    Write-Host ($Title.PadLeft(20 + [int]($Title.Length / 2))) -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    Write-Host ''
}

function Write-JidemFooter { Write-Host ('=' * 40) -ForegroundColor DarkGray; Write-Host '' }

function Format-Size([long]$Bytes) {
    if ($Bytes -ge 1GB) { '{0:N1} GB' -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { '{0:N1} MB' -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { '{0:N0} KB' -f ($Bytes / 1KB) }
    else { "$Bytes B" }
}

function Format-Age([datetime]$When) {
    $s = (Get-Date) - $When
    if ($s.TotalMinutes -lt 60) { return '{0}m ago' -f [int][math]::Max(1, $s.TotalMinutes) }
    if ($s.TotalHours -lt 24)   { return '{0}h ago' -f [int]$s.TotalHours }
    if ($s.TotalDays -lt 30)    { return '{0}d ago' -f [int]$s.TotalDays }
    '{0}mo ago' -f [int]($s.TotalDays / 30)
}

function Get-JidemFiles([string]$Path) {
    Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $parts = $_.FullName -split '[\\/]'
            -not ($Global:JidemIgnore | Where-Object { $parts -contains $_ })
        }
}

function Get-JidemRelative([string]$FullName) {
    # Path relative to Documents, for compact display.
    if ($FullName.StartsWith($Global:JidemDocs, [StringComparison]::OrdinalIgnoreCase)) {
        return $FullName.Substring($Global:JidemDocs.Length).TrimStart('\', '/')
    }
    $FullName
}

function Get-JidemLocation([string]$Path = (Get-Location).Path) {
    # Identify which workspace root the path is in. Area is $null outside the workspace.
    foreach ($r in $Global:JidemRoots.GetEnumerator()) {
        $root = $r.Value.TrimEnd('\')
        if ($Path.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
            $Path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
            $rest = $Path.Substring($root.Length).Trim('\')
            $parts = @($r.Key) + @($rest -split '\\' | Where-Object { $_ })
            return [pscustomobject]@{ Area = $r.Key; Display = ($parts -join ' > ') }
        }
    }
    [pscustomobject]@{ Area = $null; Display = $Path }
}

function Get-JidemRecent([datetime]$Since, [int]$Top = 20, [string[]]$Extension, [string[]]$Path) {
    if (-not $Path) { $Path = @($Global:JidemRoots.Values | Where-Object { Test-Path -LiteralPath $_ }) }
    $files = foreach ($p in $Path) { Get-JidemFiles $p | Where-Object { $_.LastWriteTime -ge $Since } }
    if ($Extension) {
        $exts = $Extension | ForEach-Object { '.' + $_.TrimStart('.').ToLower() }
        $files = $files | Where-Object { $exts -contains $_.Extension.ToLower() }
    }
    @($files | Sort-Object LastWriteTime -Descending | Select-Object -First $Top)
}

function Show-JidemFileList($Files) {
    $Files | ForEach-Object {
        [pscustomobject]@{
            When = Format-Age $_.LastWriteTime
            Size = Format-Size $_.Length
            File = Get-JidemRelative $_.FullName
        }
    } | Format-Table -AutoSize
}

function Get-JidemGit([string]$Path = (Get-Location).Path) {
    # Returns $null when not in a repo (or git is missing).
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    $top = git -C $Path rev-parse --show-toplevel 2>$null
    if (-not $top) { return $null }
    [pscustomobject]@{
        Root    = $top
        Branch  = (git -C $Path branch --show-current 2>$null)
        Changes = @(git -C $Path status --short 2>$null)
    }
}

# ---------- Commands ----------

function jwhere {
    # Current location, which workspace it belongs to, and git state.
    # (Named jwhere because 'where' is a built-in alias for Where-Object.)
    $here = (Get-Location).Path
    $loc  = Get-JidemLocation $here
    Write-JidemBanner "$($Global:JidemAccount) LOCATION"
    Write-Host 'CURRENT' -ForegroundColor Yellow
    Write-Host "  $($loc.Display)"
    Write-Host "  $here" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'WORKSPACE' -ForegroundColor Yellow
    Write-Host ('  ' + $(if ($loc.Area) { $loc.Area } else { 'Outside the Jidem workspace' }))
    if ($g = Get-JidemGit) {
        Write-Host ''
        Write-Host 'GIT' -ForegroundColor Yellow
        Write-Host "  $(Split-Path $g.Root -Leaf)  [$($g.Branch)]  $($g.Changes.Count) change(s)"
    }
    Write-Host ''
    Write-JidemFooter
}

function workspace {
    # The whole workspace: every root and its subfolders, with size of activity.
    Write-JidemBanner "$($Global:JidemAccount) WORKSPACE"
    foreach ($r in $Global:JidemRoots.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $r.Value)) {
            Write-Host ('{0}  [NOT FOUND] {1}' -f $r.Key, $r.Value) -ForegroundColor DarkGray
            continue
        }
        Write-Host $r.Key -ForegroundColor Cyan
        $subs = @(Get-ChildItem -LiteralPath $r.Value -Directory -Force -ErrorAction SilentlyContinue |
                  Where-Object { $Global:JidemIgnore -notcontains $_.Name } | Sort-Object Name)
        if (-not $subs.Count) { Write-Host '  (no folders)' -ForegroundColor DarkGray }
        foreach ($s in $subs) {
            $files  = @(Get-JidemFiles $s.FullName)
            $latest = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            Write-Host ('  {0,-28}' -f $s.Name) -NoNewline -ForegroundColor Yellow
            Write-Host ('{0,5} files   {1}' -f $files.Count, $(if ($latest) { Format-Age $latest.LastWriteTime } else { 'empty' })) -ForegroundColor DarkGray
        }
        Write-Host ''
    }
    Write-JidemFooter
}

function recent {
    # recent [-Days 14] [-Top 20] [-Extension md,docx] [-Path <dir>]
    param([int]$Days = 14, [int]$Top = 20, [string[]]$Extension, [string]$Path)
    $opts = @{ Since = (Get-Date).AddDays(-$Days); Top = $Top }
    if ($Extension) { $opts.Extension = $Extension }
    if ($Path)      { $opts.Path = @((Resolve-Path -LiteralPath $Path).Path) }
    $files = Get-JidemRecent @opts
    if (-not $files.Count) { Write-Host "Nothing modified in the last $Days days." -ForegroundColor DarkGray; return }
    Show-JidemFileList $files
}

function today {
    # Everything modified since midnight.
    param([int]$Top = 50, [string[]]$Extension)
    $opts = @{ Since = (Get-Date).Date; Top = $Top }
    if ($Extension) { $opts.Extension = $Extension }
    $files = Get-JidemRecent @opts
    Write-Host ("TODAY  {0}" -f (Get-Date -Format 'dddd, MMM d')) -ForegroundColor Cyan
    if (-not $files.Count) { Write-Host 'Nothing modified yet today.' -ForegroundColor DarkGray; return }
    Show-JidemFileList $files
    Write-Host ("{0} file(s) modified today" -f $files.Count) -ForegroundColor DarkGray
}

function tree {
    # tree [-Depth 2] [-Files] [-Path <dir>]   controlled folder tree (skips .git, node_modules, ...)
    param([int]$Depth = 2, [switch]$Files, [string]$Path = (Get-Location).Path)
    $root = (Resolve-Path -LiteralPath $Path).Path
    Write-Host (Split-Path $root -Leaf) -ForegroundColor Cyan
    function Walk([string]$Dir, [string]$Prefix, [int]$Level) {
        $items = @(Get-ChildItem -LiteralPath $Dir -Force -ErrorAction SilentlyContinue |
                   Where-Object { $Global:JidemIgnore -notcontains $_.Name -and ($_.PSIsContainer -or $Files) } |
                   Sort-Object @{ Expression = { -not $_.PSIsContainer } }, Name)
        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            $last = $i -eq $items.Count - 1
            Write-Host $Prefix -NoNewline
            Write-Host ($(if ($last) { '\-- ' } else { '|-- ' }) + $item.Name) -NoNewline `
                -ForegroundColor $(if ($item.PSIsContainer) { 'Yellow' } else { 'Gray' })
            if ($item.PSIsContainer) {
                Write-Host ("  ({0} files)" -f @(Get-JidemFiles $item.FullName).Count) -ForegroundColor DarkGray
                if ($Level -lt $Depth) { Walk $item.FullName ($Prefix + $(if ($last) { '    ' } else { '|   ' })) ($Level + 1) }
            }
            else { Write-Host '' }
        }
    }
    Walk $root '' 1
}
Set-Alias map tree -Scope Global

function size {
    # size [-Top 15] [-Files] [-Path <dir>]   biggest subfolders (or biggest files with -Files)
    param([int]$Top = 15, [switch]$Files, [string]$Path = (Get-Location).Path)
    $root = (Resolve-Path -LiteralPath $Path).Path
    if ($Files) {
        $big = Get-JidemFiles $root | Sort-Object Length -Descending | Select-Object -First $Top
        $big | ForEach-Object { [pscustomobject]@{ Size = Format-Size $_.Length; File = $_.FullName.Substring($root.Length).TrimStart('\', '/') } } |
            Format-Table -AutoSize
        return
    }
    $rows = foreach ($sub in Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue |
                             Where-Object { $Global:JidemIgnore -notcontains $_.Name }) {
        $f = @(Get-JidemFiles $sub.FullName)
        [pscustomobject]@{ Bytes = [long](($f | Measure-Object Length -Sum).Sum); Folder = $sub.Name; Files = $f.Count }
    }
    $loose = @(Get-ChildItem -LiteralPath $root -File -Force -ErrorAction SilentlyContinue)
    $rows = @($rows) + [pscustomobject]@{ Bytes = [long](($loose | Measure-Object Length -Sum).Sum); Folder = '(files here)'; Files = $loose.Count }
    $total = ($rows | Measure-Object Bytes -Sum).Sum
    $rows | Sort-Object Bytes -Descending | Select-Object -First $Top | ForEach-Object {
        [pscustomobject]@{ Size = Format-Size $_.Bytes; Share = if ($total) { '{0:P0}' -f ($_.Bytes / $total) } else { '-' }; Files = $_.Files; Folder = $_.Folder }
    } | Format-Table -AutoSize
    Write-Host ("Total: {0}  ({1})" -f (Format-Size ([long]$total)), $root) -ForegroundColor DarkGray
}

function status {
    # One-screen overview: where you are, the workspace, recent work, git.
    $loc = Get-JidemLocation
    Write-JidemBanner "$($Global:JidemAccount) STATUS"

    Write-Host 'CURRENT' -ForegroundColor Yellow
    Write-Host "  $($loc.Display)"
    Write-Host ''

    Write-Host 'WORKSPACE' -ForegroundColor Yellow
    foreach ($r in $Global:JidemRoots.GetEnumerator()) {
        if (Test-Path -LiteralPath $r.Value) {
            $n = @(Get-ChildItem -LiteralPath $r.Value -Directory -ErrorAction SilentlyContinue |
                   Where-Object { $Global:JidemIgnore -notcontains $_.Name }).Count
            Write-Host ('  {0,-12}{1} folder(s)' -f $r.Key, $n)
        }
        else { Write-Host ('  {0,-12}[NOT FOUND]' -f $r.Key) -ForegroundColor DarkGray }
    }
    Write-Host ''

    Write-Host 'RECENT (last 7 days)' -ForegroundColor Yellow
    $recentFiles = Get-JidemRecent -Since (Get-Date).AddDays(-7) -Top 5
    if ($recentFiles.Count) {
        foreach ($f in $recentFiles) { Write-Host ('  {0,-9} {1}' -f (Format-Age $f.LastWriteTime), (Get-JidemRelative $f.FullName)) }
    }
    else { Write-Host '  Nothing modified.' -ForegroundColor DarkGray }
    Write-Host ''

    Write-Host 'GIT' -ForegroundColor Yellow
    if ($g = Get-JidemGit) {
        Write-Host "  Repository: $($g.Root)"
        Write-Host "  Branch:     $($g.Branch)"
        Write-Host "  Changes:    $($g.Changes.Count)"
        $g.Changes | Select-Object -First 8 | ForEach-Object { Write-Host "    $_" }
        if ($g.Changes.Count -gt 8) { Write-Host "    ... and $($g.Changes.Count - 8) more" }
    }
    else { Write-Host '  Not inside a Git repository.' }
    Write-Host ''
    Write-JidemFooter
}

Remove-Variable d, allRoots, r, sharedBridge -ErrorAction SilentlyContinue
