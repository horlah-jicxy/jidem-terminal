# ==============================================================================
# Jidem.Audit.ps1 - v1.2.0 computer audit (REPORT-ONLY, both accounts)
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE AFTER Jidem.Help.ps1 and
# BEFORE Jidem.Dashboard.ps1 (the dashboard must stay the last line):
#     . "$HOME\PowerShell\Jidem.Audit.ps1"
#
# Command:
#   auditpc [-Root <folder>...] [-Top 40] [-MinMB 1] [-Csv] [-Cap 20000]
#
# Maps where your files actually live: for every top-level folder under your profile, OneDrive,
# OneDrive\Documents, Documents and the root of C:\, it reports how many files, how big, how old,
# which file types dominate, and a SUGGESTION for what kind of folder it is.
#
# NOTHING HERE MOVES, COPIES, RENAMES OR DELETES A FILE. It also never opens a file: it looks only
# at names, extensions, sizes and dates, and it prints FOLDER names and counts, never file names.
# -Csv saves the same table to $HOME\PowerShell\audit-logs for you to open later.
#
# Suggestions (labels):
#   FILED       already inside your Documents workspace
#   MIGRATE?    mostly documents, PDFs, sheets or slides: a candidate to copy into the workspace
#   SORT-PILE   loose files sitting directly in a root (use sortdownloads for Downloads/Desktop)
#   LEAVE-APP   program data or caches (Anaconda, Zotero, whisper, node_modules ...): do not touch
#   LEAVE-SENS  research-sensitive name (interview, Zoom, consent, IRB ...): do not move
#   REVIEW-MEDIA mostly audio or video: could be recordings; check before filing
#   PHOTOS      mostly pictures
#   CLEAN?      mostly installers or archives: probably safe to review and remove (by you)
#   PROJECT     mostly code or data: leave in place, or migrate by hand
#   EMPTY       no files
# ==============================================================================

foreach ($need in 'Write-JidemBanner', 'Write-JidemFooter') {
    if (-not (Get-Command $need -ErrorAction SilentlyContinue)) {
        Write-Host 'Jidem.Audit.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
        return
    }
}

$Global:JidemAuditLogs = Join-Path $HOME 'PowerShell\audit-logs'

# Folder names that are program data or caches: reported, never scanned deeply.
$Global:JidemAuditApp = '^(ana|mini)conda\d*$|^conda$|whisper|zotero|^node_modules$|^\.|^appdata$|^google ?drive$|^dropbox$|^onedrivetemp$|claude|^programdata$|^windows|^program files|^\$recycle|system volume|^recovery$|^perflogs$|^msocache$|^intel$|^config\.msi$|^boot$|huggingface|^(torch|cuda|nvidia)|virtualbox|vmware|^steam|epic games|^docker'
# Research-sensitive names: reported, never scanned, never to be moved.
$Global:JidemAuditSens = if ($Global:JidemSortKeep) { $Global:JidemSortKeep } else { 'zoom|interview|transcript|consent|\birb\b|participant|fieldnote|taguette|houston|recording' }

$Global:JidemAuditGroups = @{
    Writing  = @('.doc', '.docx', '.rtf', '.odt', '.txt', '.md', '.tex', '.pdf')
    Data     = @('.xls', '.xlsx', '.xlsm', '.csv', '.tsv', '.ods', '.sav', '.dta', '.rds', '.json')
    Slides   = @('.ppt', '.pptx', '.key', '.odp')
    Images   = @('.jpg', '.jpeg', '.png', '.gif', '.heic', '.webp', '.bmp', '.svg', '.tif', '.tiff')
    Media    = @('.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg', '.mp4', '.mov', '.avi', '.mkv', '.webm', '.wmv')
    Installers = @('.exe', '.msi', '.msix', '.iso', '.dmg', '.zip', '.rar', '.7z', '.tar', '.gz')
    Code     = @('.py', '.r', '.rmd', '.qmd', '.ipynb', '.js', '.ts', '.html', '.css', '.yml', '.yaml', '.sql', '.ps1', '.bat')
}

function Get-JidemAuditGroup([string]$Ext) {
    $e = $Ext.ToLower()
    foreach ($k in $Global:JidemAuditGroups.Keys) { if ($Global:JidemAuditGroups[$k] -contains $e) { return $k } }
    'Other'
}

function Format-JidemAuditSize([double]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N1} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N0} MB' -f ($Bytes / 1MB)) }
    '{0:N0} KB' -f ($Bytes / 1KB)
}

function Format-JidemAuditAge($When) {
    if (-not $When) { return '-' }
    $d = (Get-Date) - $When
    if ($d.TotalDays -lt 1)   { return 'today' }
    if ($d.TotalDays -lt 30)  { return ('{0}d' -f [int]$d.TotalDays) }
    if ($d.TotalDays -lt 365) { return ('{0}mo' -f [int]($d.TotalDays / 30)) }
    '{0:N1}y' -f ($d.TotalDays / 365)
}

# Count files (names, sizes, dates only) under a folder, stopping after $Cap files.
function Get-JidemAuditStats([string]$Path, [int]$Cap) {
    $files = 0; $bytes = 0.0; $newest = $null; $oldest = $null; $capped = $false
    $groups = @{}
    $seen = 0
    foreach ($f in (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        if ($f.FullName -match '[\\/](node_modules|\.git)[\\/]') { continue }
        $seen++
        if ($seen -gt $Cap) { $capped = $true; break }
        $files++
        $bytes += $f.Length
        if (-not $newest -or $f.LastWriteTime -gt $newest) { $newest = $f.LastWriteTime }
        if (-not $oldest -or $f.LastWriteTime -lt $oldest) { $oldest = $f.LastWriteTime }
        $g = Get-JidemAuditGroup $f.Extension
        if (-not $groups.ContainsKey($g)) { $groups[$g] = 0 }
        $groups[$g]++
    }
    [pscustomobject]@{ Files = $files; Bytes = $bytes; Newest = $newest; Oldest = $oldest; Groups = $groups; Capped = $capped }
}

function Get-JidemAuditSuggestion($Name, $Stats, [bool]$IsWorkspace) {
    if ($IsWorkspace) { return 'FILED' }
    if ($Name -match '^(Downloads|Desktop)$') { return 'SORT-PILE' }
    if ($Name -match $Global:JidemAuditSens) { return 'LEAVE-SENS' }
    if ($Name -match $Global:JidemAuditApp) { return 'LEAVE-APP' }
    if ($Stats.Files -eq 0) { return 'EMPTY' }
    $t = [double]$Stats.Files
    $share = { param($k) if ($Stats.Groups.ContainsKey($k)) { [double]$Stats.Groups[$k] / $t } else { 0.0 } }
    $docs = (& $share 'Writing') + (& $share 'Data') + (& $share 'Slides')
    if ((& $share 'Media') -ge 0.5) { return 'REVIEW-MEDIA' }
    if ((& $share 'Installers') -ge 0.5) { return 'CLEAN?' }
    if ((& $share 'Images') -ge 0.6) { return 'PHOTOS' }
    if ((& $share 'Code') -ge 0.4) { return 'PROJECT' }
    if ($docs -ge 0.55) { return 'MIGRATE?' }
    'PROJECT'
}

function Get-JidemAuditRoots {
    $r = @()
    $r += [pscustomobject]@{ Path = $HOME; Label = '~'; Workspace = $false; Skip = @('Documents', 'OneDrive', 'AppData', 'Application Data', 'Local Settings', 'My Documents', 'Cookies', 'NetHood', 'PrintHood', 'Recent', 'SendTo', 'Start Menu', 'Templates', 'Links', 'Searches', 'Saved Games', 'Contacts', 'Favorites', '3D Objects', 'PowerShell') }
    $r += [pscustomobject]@{ Path = (Join-Path $HOME 'Documents'); Label = 'Documents'; Workspace = $true; Skip = @() }
    $r += [pscustomobject]@{ Path = (Join-Path $HOME 'OneDrive'); Label = 'OneDrive'; Workspace = $false; Skip = @('Documents') }
    $r += [pscustomobject]@{ Path = (Join-Path $HOME 'OneDrive\Documents'); Label = 'OneDrive\Documents'; Workspace = $false; Skip = @() }
    $r += [pscustomobject]@{ Path = 'C:\'; Label = 'C:\'; Workspace = $false; Skip = @('Users', 'Windows', 'Program Files', 'Program Files (x86)', 'ProgramData', '$Recycle.Bin', 'System Volume Information', 'Recovery', 'PerfLogs', 'Intel', 'Config.Msi', 'MSOCache', 'Documents and Settings', 'OneDriveTemp', 'Boot') }
    $r
}

function auditpc {
    param(
        [string[]]$Root,
        [int]$Top = 40,
        [double]$MinMB = 1,
        [int]$Cap = 20000,
        [switch]$Csv
    )
    $roots = if ($Root) { @($Root | ForEach-Object { [pscustomobject]@{ Path = $_; Label = (Split-Path $_ -Leaf); Workspace = $false; Skip = @() } }) } else { Get-JidemAuditRoots }

    Write-JidemBanner 'COMPUTER AUDIT (REPORT ONLY)'
    Write-Host 'Looking at names, sizes and dates only. Nothing is opened, moved, copied or deleted.' -ForegroundColor DarkGray
    Write-Host 'This can take a few minutes on a big drive.' -ForegroundColor DarkGray
    Write-Host ''

    $rows = New-Object System.Collections.ArrayList
    foreach ($rt in $roots) {
        if (-not (Test-Path -LiteralPath $rt.Path -PathType Container)) { continue }
        Write-Host ('Scanning ' + $rt.Label + ' ...') -ForegroundColor DarkGray
        $children = @(Get-ChildItem -LiteralPath $rt.Path -Force -ErrorAction SilentlyContinue)
        $loose = @($children | Where-Object { -not $_.PSIsContainer -and $_.Name -notmatch '^(desktop\.ini|thumbs\.db|ntuser|pagefile|hiberfil|swapfile)' })
        if ($loose.Count -gt 0) {
            $lb = ($loose | Measure-Object Length -Sum).Sum
            $ln = ($loose | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
            $lo = ($loose | Sort-Object LastWriteTime | Select-Object -First 1).LastWriteTime
            $lg = @{}
            foreach ($f in $loose) { $g = Get-JidemAuditGroup $f.Extension; if (-not $lg.ContainsKey($g)) { $lg[$g] = 0 }; $lg[$g]++ }
            $sug = if ($rt.Workspace) { 'FILED' } elseif ($rt.Label -in @('~', 'C:\', 'OneDrive', 'OneDrive\Documents')) { 'SORT-PILE' } else { 'SORT-PILE' }
            [void]$rows.Add([pscustomobject]@{ Where = ($rt.Label + '  (loose files)'); Files = $loose.Count; Bytes = [double]$lb; Newest = $ln; Oldest = $lo; Types = $lg; Capped = $false; Suggestion = $sug })
        }
        foreach ($c in ($children | Where-Object { $_.PSIsContainer })) {
            if ($rt.Skip -contains $c.Name) { continue }
            if (([int]$c.Attributes -band 0x400) -ne 0) { continue }   # junctions and links
            $where = $rt.Label.TrimEnd('\') + '\' + $c.Name
            if ($c.Name -match $Global:JidemAuditSens -or $c.Name -match $Global:JidemAuditApp) {
                $sug = if ($c.Name -match $Global:JidemAuditSens) { 'LEAVE-SENS' } else { 'LEAVE-APP' }
                [void]$rows.Add([pscustomobject]@{ Where = $where; Files = -1; Bytes = 0.0; Newest = $c.LastWriteTime; Oldest = $null; Types = @{}; Capped = $false; Suggestion = $sug })
                continue
            }
            $st = Get-JidemAuditStats $c.FullName $Cap
            $sug = Get-JidemAuditSuggestion $c.Name $st $rt.Workspace
            [void]$rows.Add([pscustomobject]@{ Where = $where; Files = $st.Files; Bytes = $st.Bytes; Newest = $st.Newest; Oldest = $st.Oldest; Types = $st.Groups; Capped = $st.Capped; Suggestion = $sug })
        }
    }

    Write-Host ''
    $show = @($rows | Where-Object { $_.Files -lt 0 -or ($_.Bytes / 1MB) -ge $MinMB -or $_.Files -gt 0 } | Sort-Object @{ Expression = { $_.Bytes }; Descending = $true } | Select-Object -First $Top)
    Write-Host ('{0,-42}{1,9}{2,10}  {3,-7}{4,-8}{5,-26}{6}' -f 'WHERE', 'FILES', 'SIZE', 'NEWEST', 'OLDEST', 'MAIN TYPES', 'SUGGESTION') -ForegroundColor Cyan
    foreach ($r in $show) {
        $name = $r.Where
        if ($name.Length -gt 41) { $name = $name.Substring(0, 38) + '...' }
        if ($r.Files -lt 0) {
            Write-Host ('{0,-42}{1,9}{2,10}  {3,-7}{4,-8}{5,-26}{6}' -f $name, 'n/a', 'n/a', (Format-JidemAuditAge $r.Newest), '-', '(not scanned)', $r.Suggestion) -ForegroundColor DarkGray
            continue
        }
        $types = (($r.Types.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 2 | ForEach-Object { '{0} {1}' -f $_.Key, $_.Value }) -join ', ')
        $oldest = if ($r.Oldest) { $r.Oldest.ToString('yyyy') } else { '-' }
        $files = if ($r.Capped) { ('{0:N0}+' -f $r.Files) } else { ('{0:N0}' -f $r.Files) }
        $color = switch ($r.Suggestion) { 'MIGRATE?' { 'Green' } 'SORT-PILE' { 'Yellow' } 'REVIEW-MEDIA' { 'Yellow' } 'CLEAN?' { 'Yellow' } 'LEAVE-SENS' { 'Red' } default { 'Gray' } }
        Write-Host ('{0,-42}{1,9}{2,10}  {3,-7}{4,-8}{5,-26}{6}' -f $name, $files, (Format-JidemAuditSize $r.Bytes), (Format-JidemAuditAge $r.Newest), $oldest, $types, $r.Suggestion) -ForegroundColor $color
    }
    if ($rows.Count -gt $show.Count) { Write-Host ('  ... and {0} smaller or empty folder(s) not shown (use -Top or -MinMB 0)' -f ($rows.Count - $show.Count)) -ForegroundColor DarkGray }

    Write-Host ''
    Write-Host 'SUMMARY BY SUGGESTION' -ForegroundColor Yellow
    foreach ($g in ($rows | Group-Object Suggestion | Sort-Object Name)) {
        $f = ($g.Group | Where-Object { $_.Files -gt 0 } | Measure-Object Files -Sum).Sum
        $b = ($g.Group | Measure-Object Bytes -Sum).Sum
        if (-not $f) { $f = 0 }; if (-not $b) { $b = 0 }
        Write-Host ('  {0,-14}{1,4} folder(s)  {2,10:N0} files  {3,10}' -f $g.Name, $g.Count, $f, (Format-JidemAuditSize $b))
    }
    Write-Host ''
    Write-Host 'NEXT' -ForegroundColor Yellow
    Write-Host '  MIGRATE?    copy into the workspace, check, then remove the original yourself (one folder at a time)'
    Write-Host '  SORT-PILE   sortdownloads -Path <that folder>   (preview first)'
    Write-Host '  LEAVE-*     leave exactly where they are'
    Write-Host '  REVIEW/CLEAN? look at them yourself first; this report cannot tell what is inside'
    Write-Host ''

    if ($Csv) {
        try {
            if (-not (Test-Path -LiteralPath $Global:JidemAuditLogs)) { New-Item -ItemType Directory -Path $Global:JidemAuditLogs -Force | Out-Null }
            $out = Join-Path $Global:JidemAuditLogs ('audit-' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.csv')
            $rows | ForEach-Object { [pscustomobject]@{ Where = $_.Where; Files = $_.Files; SizeMB = [math]::Round($_.Bytes / 1MB, 1); Newest = $_.Newest; Oldest = $_.Oldest; Capped = $_.Capped; Suggestion = $_.Suggestion } } | Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8
            Write-Host ('Saved: ' + $out) -ForegroundColor Green
        } catch { Write-Host ('Could not save the CSV: ' + $_.Exception.Message) -ForegroundColor Red }
    }
    Write-JidemFooter
}

if (Get-Command Add-JidemHelp -ErrorAction SilentlyContinue) {
    Add-JidemHelp 'Maintenance' @('auditpc') 'ANY' 'Map where your files live: every top-level folder under your profile, OneDrive, Documents and C:\ with file count, size, age, main file types and a suggestion (migrate, sort, leave, review).' @('auditpc', 'auditpc -Csv', 'auditpc -Root "D:\Old" -Top 20') 'Report only: never opens, moves, copies or deletes anything, and prints folder names and counts, never file names. Program data and research-sensitive folders are listed but not scanned.'
}
