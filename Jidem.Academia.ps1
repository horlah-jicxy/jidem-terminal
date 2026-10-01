# ==============================================================================
# Jidem.Academia.ps1 - Phase 5 academic workflow (JIDEM account)
#
# Needs Jidem.Core.ps1 and Jidem.Navigation.ps1 loaded first. Add to $PROFILE after them:
#     . "$HOME\PowerShell\Jidem.Academia.ps1"
#
# These commands REPLACE the plain jump commands of the same name. Each one still moves
# you into the folder, and now also shows a summary of it:
#
#   dissertation  research  writing  fieldwork  publications  papers  analysis  datasets
#
#   <command>          go there and show: contents (most recently active first),
#                      files modified in the last 14 days, and git state
#   <command> -Code    also open the folder in VS Code
#   <command> -Quiet   just go there, no summary (the old behaviour)
#
# Read-only: nothing is created, changed, committed, or deleted.
# ==============================================================================

if (-not (Get-Command Invoke-JidemGo -ErrorAction SilentlyContinue)) {
    Write-Host 'Jidem.Academia.ps1 needs Jidem.Core.ps1 and Jidem.Navigation.ps1 loaded first.' -ForegroundColor Yellow
    return
}

# command name -> heading shown in the summary
$Global:JidemAreas = [ordered]@{
    dissertation = 'DISSERTATION'
    research     = 'RESEARCH'
    writing      = 'WRITING'
    fieldwork    = 'FIELDWORK'
    publications = 'PUBLICATIONS'
    papers       = 'PAPERS'
    analysis     = 'ANALYSIS'
    datasets     = 'DATASETS'
}

# ---------- Helpers ----------

function Resolve-JidemPlacePath([string]$Name) {
    $place = $Global:JidemPlaces | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $place) { return $null }
    $place.Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
}

function Show-JidemArea([string]$Title, [string]$Path) {
    Write-JidemBanner $Title
    Write-Host 'LOCATION' -ForegroundColor Yellow
    Write-Host "  $((Get-JidemLocation $Path).Display)"
    Write-Host ''

    # --- Contents: subfolders, most recently active first ---
    $folders = @(Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue |
                 Where-Object { $Global:JidemIgnore -notcontains $_.Name -and -not $_.Name.StartsWith('.') })
    $loose = @(Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction SilentlyContinue)

    $rows = foreach ($f in $folders) {
        $files = @(Get-JidemFiles $f.FullName)
        $latest = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        [pscustomobject]@{
            Name   = $f.Name
            Path   = $f.FullName
            Files  = $files.Count
            Latest = if ($latest) { $latest.LastWriteTime } else { [datetime]::MinValue }
        }
    }
    $rows = @($rows | Sort-Object Latest -Descending)

    Write-Host 'CONTENTS' -ForegroundColor Yellow
    if (-not $rows.Count -and -not $loose.Count) { Write-Host '  (empty)' -ForegroundColor DarkGray }
    $shown = 0
    foreach ($r in $rows) {
        if ($shown -ge 12) { break }
        $age = if ($r.Latest -eq [datetime]::MinValue) { 'empty' } else { Format-Age $r.Latest }
        Write-Host ('  {0,-30}' -f $r.Name) -NoNewline -ForegroundColor Yellow
        Write-Host ('{0,5} files   {1}' -f $r.Files, $age) -ForegroundColor DarkGray
        $shown++
    }
    if ($rows.Count -gt 12) { Write-Host "  ... and $($rows.Count - 12) more folder(s)" -ForegroundColor DarkGray }
    if ($loose.Count) { Write-Host "  + $($loose.Count) file(s) directly in this folder" -ForegroundColor DarkGray }
    Write-Host ''

    # --- Recently modified files ---
    Write-Host 'MODIFIED IN THE LAST 14 DAYS' -ForegroundColor Yellow
    $recent = @(Get-JidemRecent -Since (Get-Date).AddDays(-14) -Top 5 -Path @($Path))
    if ($recent.Count) {
        foreach ($f in $recent) {
            $rel = $f.FullName.Substring($Path.Length).TrimStart('\', '/')
            Write-Host ('  {0,-9} {1}' -f (Format-Age $f.LastWriteTime), $rel)
        }
    }
    else { Write-Host '  Nothing.' -ForegroundColor DarkGray }
    Write-Host ''

    # --- Git: this folder's repository, or repositories one level down ---
    Write-Host 'GIT' -ForegroundColor Yellow
    $g = Get-JidemGit $Path
    if ($g) {
        Write-Host ("  {0}  [{1}]  {2} change(s)" -f (Split-Path $g.Root -Leaf), $g.Branch, $g.Changes.Count)
    }
    else {
        $found = 0
        if (Get-Command git -ErrorAction SilentlyContinue) {
            foreach ($f in $folders) {
                if (Test-Path -LiteralPath "$($f.FullName)\.git") {
                    $branch = git -C $f.FullName branch --show-current 2>$null
                    $count = @(git -C $f.FullName status --short 2>$null).Count
                    Write-Host ("  {0}  [{1}]  {2} change(s)" -f $f.Name, $branch, $count)
                    $found++
                }
            }
        }
        if (-not $found) { Write-Host '  No git repository here.' -ForegroundColor DarkGray }
    }
    Write-Host ''
    Write-JidemFooter
}

function Enter-JidemArea {
    param([string]$Name, [switch]$Code, [switch]$Quiet)
    if ($Global:JidemAccount -ne 'JIDEM') {
        Write-Host "'$Name' is assigned to the JIDEM account." -ForegroundColor Yellow
        return
    }
    $path = Resolve-JidemPlacePath $Name
    if (-not $path) { Invoke-JidemGo $Name; return }   # prints the "not found" message
    Set-Location -LiteralPath $path
    if (-not $Quiet) { Show-JidemArea $Global:JidemAreas[$Name] $path }
    if ($Code) {
        if (Get-Command code -ErrorAction SilentlyContinue) { code . }
        else { Write-Host "VS Code ('code') is not on PATH." -ForegroundColor Yellow }
    }
}

# ---------- Commands (generated from $JidemAreas) ----------

foreach ($area in $Global:JidemAreas.Keys) {
    $body = "param([switch]`$Code, [switch]`$Quiet) Enter-JidemArea '$area' -Code:`$Code -Quiet:`$Quiet"
    Set-Item -Path "Function:\global:$area" -Value ([scriptblock]::Create($body))
}

Remove-Variable area, body -ErrorAction SilentlyContinue
