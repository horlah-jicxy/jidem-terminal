# ==============================================================================
# Jidem.Writing.ps1 - Phase 7 writing + VS Code bridge
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE after the other Jidem lines:
#     . "$HOME\PowerShell\Jidem.Writing.ps1"
#
# Commands:
#   openvscode [path]      open a folder (default: here) or file in VS Code
#   edit <file>            open a file in VS Code: exact path, or a (partial) file name
#                          found under the current folder
#   jwrite [project]       JIDEM: go to a writing project and open it in VS Code
#                          (-NoCode: just go there). No name = the one you pinned,
#                          otherwise the most recently edited.
#   focus [project]        JIDEM: show a one-screen status of the writing project
#                          (-Code also opens VS Code). Opens nothing by default.
#
# (It is jwrite, not write: 'write' is a built-in alias for Write-Output.)
#
# Writing projects = the folders directly inside the roots below. Read-only apart from
# launching VS Code and changing directory.
# ==============================================================================

if (-not (Get-Command Get-JidemGit -ErrorAction SilentlyContinue)) {
    Write-Host 'Jidem.Writing.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
    return
}

$d = $Global:JidemDocs

# Folders whose subfolders count as writing projects.
$Global:JidemWritingRoots = @("$d\GitHub\Academic-papers\projects", "$d\Academia\Writing")

# Pin a project by (part of) its folder name to make jwrite/focus default to it,
# e.g. 'dissertation'. Leave empty to default to the most recently edited project.
$Global:JidemWritingProject = ''

# ---------- Helpers ----------

function Test-JidemCode {
    if (Get-Command code -ErrorAction SilentlyContinue) { return $true }
    Write-Host "VS Code ('code') is not on PATH." -ForegroundColor Yellow
    $false
}

function Get-JidemWritingProjects {
    $list = @()
    foreach ($root in $Global:JidemWritingRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $dirs = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                Where-Object { -not $_.Name.StartsWith('.') -and $Global:JidemIgnore -notcontains $_.Name }
        foreach ($dir in $dirs) {
            $newest = Get-JidemFiles $dir.FullName | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $list += [pscustomobject]@{
                Name   = $dir.Name
                Path   = $dir.FullName
                Latest = if ($newest) { $newest.LastWriteTime } else { [datetime]::MinValue }
                Newest = $newest
            }
        }
    }
    @($list | Sort-Object Latest -Descending)
}

function Resolve-JidemWritingProject([string]$Name) {
    $all = @(Get-JidemWritingProjects)
    if (-not $all.Count) {
        Write-Host 'No writing projects found in:' -ForegroundColor Yellow
        foreach ($r in $Global:JidemWritingRoots) { Write-Host "  $r" }
        return $null
    }
    if (-not $Name) { $Name = $Global:JidemWritingProject }
    if (-not $Name) { return $all[0] }
    $exact = @($all | Where-Object { $_.Name -ieq $Name })
    if ($exact.Count -eq 1) { return $exact[0] }
    $part = @($all | Where-Object { $_.Name -like "*$Name*" })
    if ($part.Count -eq 1) { return $part[0] }
    if ($part.Count -gt 1) {
        Write-Host "'$Name' matches more than one writing project:" -ForegroundColor Yellow
        foreach ($p in $part) { Write-Host "  $($p.Name)" }
        return $null
    }
    Write-Host "No writing project matches '$Name'. Projects:" -ForegroundColor Yellow
    foreach ($p in $all) { Write-Host "  $($p.Name)" }
    $null
}

function Test-JidemAccountJidem([string]$Command) {
    if ($Global:JidemAccount -eq 'JIDEM') { return $true }
    Write-Host "'$Command' is assigned to the JIDEM account." -ForegroundColor Yellow
    $false
}

# ---------- Commands ----------

function openvscode {
    param([Parameter(Position = 0)][string]$Path = '.')
    if (-not (Test-JidemCode)) { return }
    if (-not (Test-Path -LiteralPath $Path)) { Write-Host "Not found: $Path" -ForegroundColor Yellow; return }
    code (Resolve-Path -LiteralPath $Path).Path
}

function edit {
    param([Parameter(Position = 0)][string]$Target)
    if (-not $Target) { Write-Host 'Usage: edit <file path or part of a file name>' -ForegroundColor Yellow; return }
    if (-not (Test-JidemCode)) { return }
    if (Test-Path -LiteralPath $Target) { code (Resolve-Path -LiteralPath $Target).Path; return }

    $hits = @(Get-JidemFiles (Get-Location).Path | Where-Object { $_.Name -like "*$Target*" } |
              Sort-Object LastWriteTime -Descending)
    if (-not $hits.Count) { Write-Host "No file matching '$Target' under $((Get-Location).Path)" -ForegroundColor Yellow; return }
    if ($hits.Count -eq 1) { code $hits[0].FullName; return }

    Write-Host "'$Target' matches $($hits.Count) files (newest first). Be more specific:" -ForegroundColor Yellow
    $here = (Get-Location).Path
    foreach ($h in ($hits | Select-Object -First 10)) {
        Write-Host ('  {0,-9} {1}' -f (Format-Age $h.LastWriteTime), $h.FullName.Substring($here.Length).TrimStart('\', '/'))
    }
    if ($hits.Count -gt 10) { Write-Host "  ... and $($hits.Count - 10) more" -ForegroundColor DarkGray }
}

function jwrite {
    param([Parameter(Position = 0)][string]$Name, [switch]$NoCode)
    if (-not (Test-JidemAccountJidem 'jwrite')) { return }
    $p = Resolve-JidemWritingProject $Name
    if (-not $p) { return }
    Set-Location -LiteralPath $p.Path
    Write-Host "Writing: $($p.Name)" -ForegroundColor Cyan
    Write-Host "  $($p.Path)" -ForegroundColor DarkGray
    if ($p.Newest) { Write-Host ("  Last edit: {0}  ({1})" -f $p.Newest.Name, (Format-Age $p.Latest)) }
    if ($g = Get-JidemGit $p.Path) { Write-Host ("  Git: [{0}]  {1} change(s)" -f $g.Branch, $g.PathChanges.Count) }
    if (-not $NoCode -and (Test-JidemCode)) { code . }
}

function focus {
    param([Parameter(Position = 0)][string]$Name, [switch]$Code)
    if (-not (Test-JidemAccountJidem 'focus')) { return }
    $p = Resolve-JidemWritingProject $Name
    if (-not $p) { return }

    Write-JidemBanner "$($Global:JidemAccount) FOCUS"
    Write-Host ('{0,-10}{1}' -f 'PROJECT', $p.Name) -ForegroundColor Yellow
    Write-Host ('{0,-10}{1}' -f 'LOCATION', (Get-JidemLocation $p.Path).Display)
    Write-Host ('{0,-10}{1}' -f 'EDITOR', $(if (Get-Command code -ErrorAction SilentlyContinue) { 'VS Code (available)' } else { 'VS Code not found on PATH' }))

    if ($g = Get-JidemGit $p.Path) {
        $state = if ($g.PathChanges.Count -eq 0) { 'clean' } else { "$($g.PathChanges.Count) uncommitted change(s)" }
        Write-Host ('{0,-10}{1}  [{2}]  {3}' -f 'GIT', (Split-Path $g.Root -Leaf), $g.Branch, $state)
    }
    else { Write-Host ('{0,-10}{1}' -f 'GIT', 'not a git repository') -ForegroundColor DarkGray }

    $recent = @(Get-JidemRecent -Since (Get-Date).AddDays(-14) -Top 3 -Path @($p.Path))
    Write-Host ''
    Write-Host 'LAST EDITED' -ForegroundColor Yellow
    if ($recent.Count) {
        foreach ($f in $recent) {
            Write-Host ('  {0,-9} {1}' -f (Format-Age $f.LastWriteTime), $f.FullName.Substring($p.Path.Length).TrimStart('\', '/'))
        }
    }
    else { Write-Host '  Nothing in the last 14 days.' -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host 'Ready.' -ForegroundColor Green
    Write-Host ''
    Write-JidemFooter
    if ($Code -and (Test-JidemCode)) { Set-Location -LiteralPath $p.Path; code . }
}

Remove-Variable d -ErrorAction SilentlyContinue
