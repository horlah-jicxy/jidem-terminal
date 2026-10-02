# ==============================================================================
# Jidem.Maintenance.ps1 - Phase 9 academic maintenance (REPORT-ONLY)
#
# Needs Jidem.Core.ps1, Jidem.Navigation.ps1 and Jidem.Search.ps1 loaded first. Add to $PROFILE
# after them:
#     . "$HOME\PowerShell\Jidem.Maintenance.ps1"
#
# Commands:
#   inbox              JIDEM: go to the inbox and report what is waiting, how old it is, and
#                      a guessed category for each item (-Quiet: just go there)
#   duplicates [where] files with identical content (same size, same SHA-256), biggest waste first
#   empty [where]      empty folders and zero-byte files
#   cleanup            one-screen clutter report: inbox, stale areas, empty items, duplicates
#                      (-Quick skips the duplicate check, which can be slow on big workspaces)
#
# [where] works like in search: a folder path, a jump-command name, or a folder name.
# Switches: -Here (current folder only), -IncludeHidden, -IncludeArchive (duplicates), -Top <n>.
#
# NOTHING HERE DELETES, MOVES, RENAMES, OR CHANGES A FILE. You decide what to do with the report.
# ==============================================================================

foreach ($need in 'Get-JidemFiles', 'Get-JidemSearchFiles', 'Get-JidemSearchScope') {
    if (-not (Get-Command $need -ErrorAction SilentlyContinue)) {
        Write-Host 'Jidem.Maintenance.ps1 needs Jidem.Core.ps1, Jidem.Navigation.ps1 and Jidem.Search.ps1 loaded first.' -ForegroundColor Yellow
        return
    }
}

# Zero-byte files that are normal and should not be reported.
$Global:JidemKeepEmpty = @('__init__.py', '.gitkeep', '.keep', '.gitignore')

# Inbox guesses: first matching rule wins (matched against the lower-case file name).
$Global:JidemInboxRules = @(
    @{ Category = 'Teaching';     Pattern = 'syllabus|assignment|rubric|grading|grades|attendance|lecture|section|anth[-_ ]?\d|\bih[-_ ]?\d' }
    @{ Category = 'Dissertation'; Pattern = 'dissertation|chapter|candidacy|prospectus' }
    @{ Category = 'Research';     Pattern = 'fieldnote|interview|transcript|corpus|codebook|survey|consent|irb' }
    @{ Category = 'Writing';      Pattern = 'draft|abstract|proposal|paper|manuscript|essay|cv|statement' }
)
$Global:JidemInboxDataExt  = @('.csv', '.xlsx', '.xls', '.sav', '.dta', '.rds', '.json')
$Global:JidemInboxMediaExt = @('.jpg', '.jpeg', '.png', '.gif', '.heic', '.mp3', '.m4a', '.wav', '.mp4', '.mov')
$Global:JidemInboxWritingExt = @('.docx', '.doc', '.md', '.txt', '.rtf')

# ---------- Helpers ----------

function Test-JidemPathSkipped([string]$FullName, [string]$Root, [bool]$IncludeHidden) {
    foreach ($p in @($FullName.Substring($Root.Length) -split '[\\/]' | Where-Object { $_ })) {
        if ($Global:JidemIgnore -contains $p) { return $true }
        if (-not $IncludeHidden -and $p.StartsWith('.')) { return $true }
    }
    $false
}

function Resolve-JidemMaintPlace([string]$Name) {
    $place = $Global:JidemPlaces | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $place) { return $null }
    $place.Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
}

function Get-JidemInboxCategory($Item) {
    $name = $Item.Name.ToLower()
    foreach ($r in $Global:JidemInboxRules) { if ($name -match $r.Pattern) { return $r.Category } }
    if ($Item.PSIsContainer) { return 'Other' }
    $ext = $Item.Extension.ToLower()
    if ($Global:JidemInboxDataExt -contains $ext)    { return 'Data' }
    if ($ext -eq '.pdf')                              { return 'Reading' }
    if ($Global:JidemInboxMediaExt -contains $ext)   { return 'Media' }
    if ($Global:JidemInboxWritingExt -contains $ext) { return 'Writing' }
    'Other'
}

function Get-JidemEmptyItems {
    param([string[]]$Roots, [bool]$IncludeHidden)
    $emptyDirs = @{}
    foreach ($root in $Roots) {
        foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -Recurse -Force -ErrorAction SilentlyContinue)) {
            if (Test-JidemPathSkipped $d.FullName $root $IncludeHidden) { continue }
            $has = Get-ChildItem -LiteralPath $d.FullName -File -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $has) { $emptyDirs[$d.FullName.ToLower()] = $d }
        }
    }
    # Report only the top-most empty folders (a folder inside an already-empty folder is implied).
    $folders = @($emptyDirs.Values | Where-Object { -not ($_.Parent -and $emptyDirs.ContainsKey($_.Parent.FullName.ToLower())) } | Sort-Object FullName)
    $zero = @()
    foreach ($root in $Roots) {
        $zero += @(Get-JidemFiles $root | Where-Object {
            $_.Length -eq 0 -and ($Global:JidemKeepEmpty -notcontains $_.Name) -and -not (Test-JidemPathSkipped $_.FullName $root $IncludeHidden)
        })
    }
    [pscustomobject]@{ Folders = $folders; Files = $zero }
}

function Get-JidemDuplicateSets {
    param($Files)
    $sets = @()
    $sizeGroups = @($Files | Group-Object Length | Where-Object { $_.Count -gt 1 })
    foreach ($g in $sizeGroups) {
        $hashed = @(foreach ($f in $g.Group) {
            $h = Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue
            if ($h) { [pscustomobject]@{ Hash = $h.Hash; File = $f } }
        })
        foreach ($hg in @($hashed | Group-Object Hash | Where-Object { $_.Count -gt 1 })) {
            $copies = @($hg.Group | ForEach-Object { $_.File } | Sort-Object LastWriteTime)
            $size = [long]$copies[0].Length
            $sets += [pscustomobject]@{ Size = $size; Copies = $copies; Wasted = ($size * ($copies.Count - 1)) }
        }
    }
    @($sets | Sort-Object Wasted -Descending)
}

function Get-JidemStaleAreas([int]$Days) {
    $cut = (Get-Date).AddDays(-$Days)
    foreach ($r in $Global:JidemRoots.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $r.Value)) { continue }
        $subs = Get-ChildItem -LiteralPath $r.Value -Directory -ErrorAction SilentlyContinue |
                Where-Object { $Global:JidemIgnore -notcontains $_.Name -and -not $_.Name.StartsWith('.') }
        foreach ($sub in $subs) {
            $latest = Get-JidemFiles $sub.FullName | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latest -and $latest.LastWriteTime -lt $cut) {
                [pscustomobject]@{ Area = $r.Key; Name = $sub.Name; Latest = $latest.LastWriteTime }
            }
        }
    }
}

function Show-JidemInboxReport([string]$Path) {
    $items = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
               Where-Object { -not $_.Name.StartsWith('.') } | Sort-Object LastWriteTime)
    Write-Host ('{0,-10}{1}' -f 'INBOX', (Get-JidemLocation $Path).Display) -ForegroundColor Yellow
    if (-not $items.Count) { Write-Host '  Empty. Nothing is waiting.' -ForegroundColor Green; return }
    $oldest = $items[0]
    Write-Host ("  {0} item(s) awaiting classification" -f $items.Count)
    Write-Host ("  Oldest: {0}  ({1}, {2})" -f $oldest.Name, $oldest.LastWriteTime.ToString('MMM d, yyyy'), (Format-Age $oldest.LastWriteTime))
    Write-Host ''
    Write-Host 'SUGGESTED CATEGORIES (a guess from the file names and types)' -ForegroundColor Yellow
    $byCat = $items | Group-Object { Get-JidemInboxCategory $_ } | Sort-Object Count -Descending
    foreach ($c in $byCat) { Write-Host ('  {0,-13}{1}' -f $c.Name, $c.Count) }
    Write-Host ''
    Write-Host 'OLDEST FIRST' -ForegroundColor Yellow
    foreach ($i in ($items | Select-Object -First 15)) {
        Write-Host ('  {0,-9} {1,-12} {2}' -f (Format-Age $i.LastWriteTime), (Get-JidemInboxCategory $i), $i.Name)
    }
    if ($items.Count -gt 15) { Write-Host "  ... and $($items.Count - 15) more" -ForegroundColor DarkGray }
}

# ---------- Commands ----------

function inbox {
    param([switch]$Quiet)
    if ($Global:JidemAccount -ne 'JIDEM') {
        Write-Host "'inbox' is assigned to the JIDEM account." -ForegroundColor Yellow
        return
    }
    $path = Resolve-JidemMaintPlace 'inbox'
    if (-not $path) { Invoke-JidemGo 'inbox'; return }   # prints the "not found" message
    Set-Location -LiteralPath $path
    if ($Quiet) { return }
    Write-JidemBanner "$($Global:JidemAccount) INBOX"
    Show-JidemInboxReport $path
    Write-Host ''
    Write-Host 'Report only: nothing was moved or changed.' -ForegroundColor DarkGray
    Write-Host ''
    Write-JidemFooter
}

function duplicates {
    param([Parameter(Position = 0)][string]$In, [switch]$Here, [switch]$IncludeArchive, [switch]$IncludeHidden,
          [int]$MinKB = 1, [int]$Top = 15)
    $scope = Get-JidemSearchScope -Here:$Here -In $In
    if (-not $scope) { return }
    $files = @(Get-JidemSearchFiles -Roots $scope.Roots -IncludeArchive:$IncludeArchive -IncludeHidden:$IncludeHidden |
               Where-Object { $_.Length -ge ($MinKB * 1KB) })
    Write-Host "DUPLICATES   [$($scope.Label)]   ($($files.Count) files of at least $MinKB KB)" -ForegroundColor Cyan
    $candidates = @($files | Group-Object Length | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    Write-Host "Comparing $([int]$candidates) file(s) that share a size ..." -ForegroundColor DarkGray
    $sets = @(Get-JidemDuplicateSets $files)
    if (-not $sets.Count) { Write-Host 'No duplicate files found.' -ForegroundColor Green; return }
    Write-Host ''
    foreach ($s in ($sets | Select-Object -First $Top)) {
        Write-Host ('{0} copies, {1} each  (wasted {2})' -f $s.Copies.Count, (Format-Size $s.Size), (Format-Size $s.Wasted)) -ForegroundColor Yellow
        foreach ($c in $s.Copies) {
            Write-Host ('  {0,-9} {1}' -f (Format-Age $c.LastWriteTime), (Get-JidemRelative $c.FullName))
        }
        Write-Host ''
    }
    if ($sets.Count -gt $Top) { Write-Host "... and $($sets.Count - $Top) more set(s). Use -Top to see more." -ForegroundColor DarkGray }
    $wasted = ($sets | Measure-Object Wasted -Sum).Sum
    $extra = ($sets | ForEach-Object { $_.Copies.Count - 1 } | Measure-Object -Sum).Sum
    Write-Host ("{0} set(s); {1} redundant file(s); {2} could be freed." -f $sets.Count, $extra, (Format-Size ([long]$wasted))) -ForegroundColor Cyan
    Write-Host 'Report only: nothing was deleted. Keep the copy that is in the right place and remove the others yourself.' -ForegroundColor DarkGray
}

function empty {
    param([Parameter(Position = 0)][string]$In, [switch]$Here, [switch]$IncludeHidden, [int]$Top = 40)
    $scope = Get-JidemSearchScope -Here:$Here -In $In
    if (-not $scope) { return }
    Write-Host "EMPTY ITEMS   [$($scope.Label)]" -ForegroundColor Cyan
    $r = Get-JidemEmptyItems -Roots $scope.Roots -IncludeHidden ([bool]$IncludeHidden)
    Write-Host ''
    Write-Host "EMPTY FOLDERS ($($r.Folders.Count))   (some may be intentional scaffolding, e.g. a Chapters folder you have not filled yet)" -ForegroundColor Yellow
    if (-not $r.Folders.Count) { Write-Host '  None.' -ForegroundColor DarkGray }
    foreach ($d in ($r.Folders | Select-Object -First $Top)) { Write-Host "  $(Get-JidemRelative $d.FullName)" }
    if ($r.Folders.Count -gt $Top) { Write-Host "  ... and $($r.Folders.Count - $Top) more" -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host "ZERO-BYTE FILES ($($r.Files.Count))" -ForegroundColor Yellow
    if (-not $r.Files.Count) { Write-Host '  None.' -ForegroundColor DarkGray }
    foreach ($f in ($r.Files | Select-Object -First $Top)) { Write-Host "  $(Get-JidemRelative $f.FullName)" }
    if ($r.Files.Count -gt $Top) { Write-Host "  ... and $($r.Files.Count - $Top) more" -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host 'Report only: nothing was deleted.' -ForegroundColor DarkGray
}

function cleanup {
    param([switch]$Quick, [int]$StaleDays = 90)
    Write-JidemBanner "$($Global:JidemAccount) CLEANUP REPORT"
    $roots = @($Global:JidemRoots.Values | Where-Object { Test-Path -LiteralPath $_ })

    if ($Global:JidemAccount -eq 'JIDEM') {
        $inboxPath = Resolve-JidemMaintPlace 'inbox'
        Write-Host 'INBOX' -ForegroundColor Yellow
        if ($inboxPath) {
            $items = @(Get-ChildItem -LiteralPath $inboxPath -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.Name.StartsWith('.') } | Sort-Object LastWriteTime)
            if ($items.Count) { Write-Host ("  {0} item(s) waiting; oldest {1}   (details: inbox)" -f $items.Count, (Format-Age $items[0].LastWriteTime)) }
            else { Write-Host '  Empty.' -ForegroundColor Green }
        }
        else { Write-Host '  Inbox folder not found.' -ForegroundColor DarkGray }
        Write-Host ''
    }

    Write-Host "STALE AREAS (nothing changed in $StaleDays days)" -ForegroundColor Yellow
    $stale = @(Get-JidemStaleAreas $StaleDays | Sort-Object Latest)
    if ($stale.Count) {
        foreach ($s in ($stale | Select-Object -First 12)) { Write-Host ('  {0,-12}{1,-32}{2}' -f $s.Area, $s.Name, (Format-Age $s.Latest)) }
        if ($stale.Count -gt 12) { Write-Host "  ... and $($stale.Count - 12) more" -ForegroundColor DarkGray }
    }
    else { Write-Host '  None.' -ForegroundColor Green }
    Write-Host ''

    Write-Host 'EMPTY ITEMS' -ForegroundColor Yellow
    $e = Get-JidemEmptyItems -Roots $roots -IncludeHidden $false
    Write-Host ("  {0} empty folder(s), {1} zero-byte file(s)   (details: empty)" -f $e.Folders.Count, $e.Files.Count)
    Write-Host ''

    Write-Host 'DUPLICATES' -ForegroundColor Yellow
    if ($Quick) { Write-Host '  Skipped (-Quick). Run: duplicates' -ForegroundColor DarkGray }
    else {
        $files = @(Get-JidemSearchFiles -Roots $roots | Where-Object { $_.Length -ge 1KB })
        $sets = @(Get-JidemDuplicateSets $files)
        if ($sets.Count) {
            $wasted = ($sets | Measure-Object Wasted -Sum).Sum
            Write-Host ("  {0} set(s) of identical files; {1} could be freed   (details: duplicates)" -f $sets.Count, (Format-Size ([long]$wasted)))
        }
        else { Write-Host '  None.' -ForegroundColor Green }
    }
    Write-Host ''
    Write-Host 'Report only: nothing was moved, renamed, or deleted.' -ForegroundColor DarkGray
    Write-Host ''
    Write-JidemFooter
}
