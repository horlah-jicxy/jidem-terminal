# ==============================================================================
# Jidem.Projects.ps1 - Phase 3 project management (JIDEM account)
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE, AFTER the other lines
# (and after any older openproject/projectinfo functions defined in the profile):
#     . "$HOME\PowerShell\Jidem.Projects.ps1"
#
# Commands:
#   projects                      numbered list of projects, grouped, with git state
#   openproject [name|number]     go to a project and open VS Code (-NoCode to skip VS Code)
#   projectinfo [path]            summary of the current (or given) project folder
#   projectnew "Name" [-Git]      create Development\Name with a README (-WhatIf to preview)
#
# Pinned projects are listed below in a fixed order. Any other folder directly inside
# Development or GitHub is discovered automatically and listed under OTHER.
# ==============================================================================

if (-not (Get-Command Get-JidemGit -ErrorAction SilentlyContinue)) {
    Write-Host 'Jidem.Projects.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
    return
}

$d = $Global:JidemDocs

$Global:JidemPinnedProjects = @(
    @{ Name = 'Academic-papers';  Group = 'ACADEMIC';    Path = "$d\GitHub\Academic-papers" }
    @{ Name = 'Teaching-Toolkit'; Group = 'DEVELOPMENT'; Path = "$d\GitHub\teaching-toolkit-v43" }
    @{ Name = 'Personal-Editor';  Group = 'DEVELOPMENT'; Path = "$d\Development\Personal-Editor" }
    @{ Name = 'Python';           Group = 'DEVELOPMENT'; Path = "$d\Development\Python" }
    @{ Name = 'R';                Group = 'DEVELOPMENT'; Path = "$d\Development\R" }
    @{ Name = 'Experiments';      Group = 'DEVELOPMENT'; Path = "$d\Development\Experiments" }
)
$Global:JidemProjectRoots = @("$d\Development", "$d\GitHub")

# ---------- Helpers ----------

function Get-JidemProjects {
    # Pinned projects first, then discovered ones. Index numbers are what openproject uses.
    if ($Global:JidemAccount -ne 'JIDEM') { return @() }
    $items = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($p in $Global:JidemPinnedProjects) {
        [void]$items.Add(@{ Name = $p.Name; Group = $p.Group; Path = $p.Path })
        $seen[$p.Path.ToLower()] = $true
    }
    foreach ($root in $Global:JidemProjectRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $dirs = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                Where-Object { $Global:JidemIgnore -notcontains $_.Name } | Sort-Object Name
        foreach ($dir in $dirs) {
            if (-not $seen.ContainsKey($dir.FullName.ToLower())) {
                [void]$items.Add(@{ Name = $dir.Name; Group = 'OTHER'; Path = $dir.FullName })
                $seen[$dir.FullName.ToLower()] = $true
            }
        }
    }
    $result = @()
    for ($i = 0; $i -lt $items.Count; $i++) {
        $result += [pscustomobject]@{
            Index  = $i + 1
            Name   = $items[$i].Name
            Group  = $items[$i].Group
            Path   = $items[$i].Path
            Exists = (Test-Path -LiteralPath $items[$i].Path -PathType Container)
        }
    }
    $result
}

function Get-JidemProjectGit([string]$Path) {
    if (-not (Test-Path -LiteralPath "$Path\.git")) { return $null }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    [pscustomobject]@{
        Branch  = (git -C $Path branch --show-current 2>$null)
        Changes = @(git -C $Path status --short 2>$null).Count
    }
}

function Show-JidemProjects($Projects) {
    foreach ($group in @('ACADEMIC', 'DEVELOPMENT', 'OTHER')) {
        $members = @($Projects | Where-Object { $_.Group -eq $group })
        if (-not $members.Count) { continue }
        Write-Host $group -ForegroundColor Cyan
        foreach ($p in $members) {
            Write-Host ('  {0,2}  {1,-22}' -f $p.Index, $p.Name) -NoNewline -ForegroundColor $(if ($p.Exists) { 'Green' } else { 'DarkGray' })
            if (-not $p.Exists) { Write-Host 'NOT FOUND' -ForegroundColor DarkGray; continue }
            $g = Get-JidemProjectGit $p.Path
            if ($g) {
                $state = if ($g.Changes -eq 0) { 'clean' } else { "$($g.Changes) change(s)" }
                Write-Host ('{0,-14}{1}' -f $g.Branch, $state) -ForegroundColor $(if ($g.Changes -eq 0) { 'DarkGray' } else { 'Yellow' })
            }
            else { Write-Host '' }
        }
        Write-Host ''
    }
}

function Find-JidemProject($Projects, [string]$Query) {
    $n = 0
    if ([int]::TryParse($Query, [ref]$n)) {
        $hit = @($Projects | Where-Object { $_.Index -eq $n })
        if ($hit.Count) { return $hit[0] }
        Write-Host "No project number $n. Run 'projects' to see the list." -ForegroundColor Yellow
        return $null
    }
    $exact = @($Projects | Where-Object { $_.Name -ieq $Query })
    if ($exact.Count -eq 1) { return $exact[0] }
    $part = @($Projects | Where-Object { $_.Name -like "*$Query*" })
    if ($part.Count -eq 1) { return $part[0] }
    if ($part.Count -gt 1) {
        Write-Host "'$Query' matches more than one project:" -ForegroundColor Yellow
        foreach ($p in $part) { Write-Host ('  {0,2}  {1}' -f $p.Index, $p.Name) }
        return $null
    }
    Write-Host "No project matches '$Query'. Run 'projects' to see the list." -ForegroundColor Yellow
    $null
}

# ---------- Commands ----------

function projects {
    $list = @(Get-JidemProjects)
    if (-not $list.Count) {
        Write-Host "Projects are assigned to the JIDEM account (you are in $($Global:JidemAccount))." -ForegroundColor Yellow
        return
    }
    Write-JidemBanner "$($Global:JidemAccount) PROJECTS"
    Show-JidemProjects $list
    Write-Host 'Open one with: openproject <number or name>' -ForegroundColor DarkGray
    Write-Host ''
}

function openproject {
    param([string]$Name, [switch]$NoCode)
    $list = @(Get-JidemProjects)
    if (-not $list.Count) {
        Write-Host "Projects are assigned to the JIDEM account (you are in $($Global:JidemAccount))." -ForegroundColor Yellow
        return
    }
    if (-not $Name) {
        Write-JidemBanner "$($Global:JidemAccount) PROJECT LAUNCHER"
        Show-JidemProjects $list
        $Name = Read-Host 'Select project (number or name, Enter to cancel)'
        if ([string]::IsNullOrWhiteSpace($Name)) { return }
    }
    $project = Find-JidemProject $list $Name
    if (-not $project) { return }
    if (-not $project.Exists) {
        Write-Host "Project folder does not exist:`n  $($project.Path)" -ForegroundColor Red
        return
    }
    Write-Host "`nOpening:`n  $($project.Name)`n  $($project.Path)`n" -ForegroundColor Cyan
    Set-Location -LiteralPath $project.Path
    if ($NoCode) { return }
    if (Get-Command code -ErrorAction SilentlyContinue) { code . }
    else { Write-Host "VS Code ('code') is not on PATH; you are now in the project folder." -ForegroundColor Yellow }
}

function projectinfo {
    param([string]$Path = (Get-Location).Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Write-Host "Folder not found: $Path" -ForegroundColor Yellow
        return
    }
    $here = (Resolve-Path -LiteralPath $Path).Path
    Write-JidemBanner "$($Global:JidemAccount) PROJECT INFO"
    Write-Host 'PROJECT' -ForegroundColor Yellow; Write-Host "  $(Split-Path $here -Leaf)`n"
    Write-Host 'PATH' -ForegroundColor Yellow;    Write-Host "  $here`n"

    Write-Host 'GIT' -ForegroundColor Yellow
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Host '  Git: not installed' }
    elseif ($g = Get-JidemGit $here) {
        Write-Host '  Repository: Yes'
        Write-Host "  Branch:     $($g.Branch)"
        Write-Host "  Changes:    $($g.Changes.Count)"
        $last = git -C $here log -1 --format='%h %s (%cr)' 2>$null
        if ($last) { Write-Host "  Last commit: $last" }
        if ($g.Changes.Count) {
            Write-Host "`n  Changed files:" -ForegroundColor Yellow
            $g.Changes | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" }
            if ($g.Changes.Count -gt 10) { Write-Host "    ... and $($g.Changes.Count - 10) more" }
        }
    }
    else { Write-Host '  Repository: No' }

    Write-Host "`nCONTENTS" -ForegroundColor Yellow
    Write-Host ('  Files here:    {0}' -f @(Get-ChildItem -LiteralPath $here -File -Force -ErrorAction SilentlyContinue).Count)
    Write-Host ('  Folders here:  {0}' -f @(Get-ChildItem -LiteralPath $here -Directory -Force -ErrorAction SilentlyContinue).Count)
    $all = @(Get-JidemFiles $here)
    Write-Host ('  Files total:   {0}   ({1})' -f $all.Count, (Format-Size ([long](($all | Measure-Object Length -Sum).Sum))))

    $newest = @($all | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
    if ($newest.Count) {
        Write-Host "`nRECENTLY MODIFIED" -ForegroundColor Yellow
        foreach ($f in $newest) { Write-Host ('  {0,-9} {1}' -f (Format-Age $f.LastWriteTime), $f.FullName.Substring($here.Length).TrimStart('\', '/')) }
    }

    Write-Host "`nVS CODE" -ForegroundColor Yellow
    Write-Host ('  ' + $(if (Get-Command code -ErrorAction SilentlyContinue) { 'Available' } else { 'Not available in PATH' }))
    Write-Host ''
    Write-JidemFooter
}

function projectnew {
    # projectnew "Name" [-Git] [-WhatIf]   creates Documents\Development\<Name> with a README.md
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory = $true, Position = 0)][string]$Name, [switch]$Git)
    if ($Global:JidemAccount -ne 'JIDEM') {
        Write-Host "Projects are assigned to the JIDEM account (you are in $($Global:JidemAccount))." -ForegroundColor Yellow
        return
    }
    if ($Name -match '[\\/:*?"<>|]') {
        Write-Host 'Project names cannot contain  \ / : * ? " < > |' -ForegroundColor Yellow
        return
    }
    $path = Join-Path "$($Global:JidemDocs)\Development" $Name
    if (Test-Path -LiteralPath $path) {
        Write-Host "Already exists: $path" -ForegroundColor Yellow
        return
    }
    if ($PSCmdlet.ShouldProcess($path, 'Create project folder with README.md')) {
        New-Item -ItemType Directory -Path $path | Out-Null
        Set-Content -LiteralPath (Join-Path $path 'README.md') -Value "# $Name" -Encoding UTF8
        if ($Git) {
            if (Get-Command git -ErrorAction SilentlyContinue) { git -C $path init -q }
            else { Write-Host 'Git is not installed; skipped git init.' -ForegroundColor Yellow }
        }
        Write-Host "Created: $path" -ForegroundColor Green
        Write-Host "Open it with: openproject $Name" -ForegroundColor DarkGray
    }
}

Remove-Variable d -ErrorAction SilentlyContinue
