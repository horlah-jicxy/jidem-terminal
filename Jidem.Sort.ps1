# ==============================================================================
# Jidem.Sort.ps1 - v1.2.0 sort a pile of loose files into the Archive (both accounts)
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE AFTER Jidem.Help.ps1 and
# BEFORE Jidem.Dashboard.ps1 (the dashboard must stay the last line):
#     . "$HOME\PowerShell\Jidem.Sort.ps1"
#
# Commands:
#   sortdownloads [-Path <folder>] [-Days 14] [-Apply] [-Yes] [-IncludeMedia] [-ShowNames] [-FilesOnly] [-WhatIf]
#                      PREVIEW by default. Sorts loose files in Downloads (or another pile such as
#                      Desktop) by file TYPE and ARRIVAL YEAR into
#                      Documents\Archive\<folder name>\<Category>\<Year>\
#   sortundo [<manifest>] [-Apply] [-Yes]
#                      lists past sorts; with a manifest name, puts those files back
#
# It never reads inside a file. It looks only at names, extensions, sizes and dates, and the
# preview prints counts, not file names (use -ShowNames to see names on your own screen).
#
# This is the one command that MOVES files, so it is deliberately cautious:
#   - preview unless you add -Apply, and even then it asks y/n (unless -Yes)
#   - never overwrites (a name clash gets "(2)"), never deletes
#   - top-level files and folders only; folders move intact, never emptied out (-FilesOnly leaves ALL folders alone)
#   - leaves alone: anything changed in the last -Days days, partial downloads, cloud-only
#     OneDrive placeholders, audio and video (unless -IncludeMedia), and anything whose name
#     matches $Global:JidemSortKeep (interviews, Zoom, transcripts, consent forms, IRB, ...)
#   - writes a manifest (a CSV of every move) to $HOME\PowerShell\sort-logs so sortundo can reverse it
# ==============================================================================

foreach ($need in 'Write-JidemBanner', 'Write-JidemFooter') {
    if (-not (Get-Command $need -ErrorAction SilentlyContinue)) {
        Write-Host 'Jidem.Sort.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
        return
    }
}

# Names (case-insensitive) that are NEVER moved. Research-sensitive material stays where it is.
$Global:JidemSortKeep = 'zoom|interview|transcript|consent|\birb\b|participant|fieldnote|taguette|houston|recording|pdfgear'

$Global:JidemSortLogs = Join-Path $HOME 'PowerShell\sort-logs'

# extension -> category
$Global:JidemSortCategories = @{
    Documents   = @('.doc', '.docx', '.rtf', '.odt', '.txt', '.md', '.pages', '.tex')
    PDFs        = @('.pdf')
    Spreadsheets = @('.xls', '.xlsx', '.xlsm', '.csv', '.tsv', '.ods', '.numbers')
    Slides      = @('.ppt', '.pptx', '.key', '.odp')
    Images      = @('.jpg', '.jpeg', '.png', '.gif', '.heic', '.webp', '.bmp', '.svg', '.tif', '.tiff')
    Compressed  = @('.zip', '.rar', '.7z', '.tar', '.gz', '.tgz')
    Installers  = @('.exe', '.msi', '.msix', '.iso', '.dmg', '.pkg')
    CodeData    = @('.py', '.r', '.rmd', '.qmd', '.ipynb', '.js', '.ts', '.json', '.xml', '.html', '.css', '.yml', '.yaml', '.sql', '.rds', '.sav', '.dta')
    Media       = @('.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg', '.mp4', '.mov', '.avi', '.mkv', '.webm', '.wmv')
}
$Global:JidemSortIncomplete = @('.crdownload', '.tmp', '.part', '.partial', '.download', '.opdownload')
$Global:JidemSortIgnore     = @('desktop.ini', 'thumbs.db', '.ds_store')

# ---------- Helpers ----------

function Get-JidemDownloadsPath {
    try {
        $p = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path
        if ($p -and (Test-Path -LiteralPath $p -PathType Container)) { return $p }
    } catch { }
    Join-Path $HOME 'Downloads'
}

function Get-JidemSortCategory([string]$Extension) {
    $e = $Extension.ToLower()
    foreach ($k in $Global:JidemSortCategories.Keys) {
        if ($Global:JidemSortCategories[$k] -contains $e) { return $k }
    }
    'Other'
}

function Get-JidemFreePath([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $Path }
    $dir  = Split-Path $Path -Parent
    $leaf = Split-Path $Path -Leaf
    $ext  = [IO.Path]::GetExtension($leaf)
    $stem = [IO.Path]::GetFileNameWithoutExtension($leaf)
    if (Test-Path -LiteralPath $Path -PathType Container) { $stem = $leaf; $ext = '' }
    for ($i = 2; $i -lt 1000; $i++) {
        $try = Join-Path $dir ('{0} ({1}){2}' -f $stem, $i, $ext)
        if (-not (Test-Path -LiteralPath $try)) { return $try }
    }
    $Path + '.' + [guid]::NewGuid().ToString('N').Substring(0, 6)
}

function Format-JidemMB([double]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N1} GB' -f ($Bytes / 1GB)) }
    '{0:N1} MB' -f ($Bytes / 1MB)
}

function Test-JidemCloudOnly($Item) {
    $a = [int]$Item.Attributes
    # RecallOnOpen (0x40000), RecallOnDataAccess (0x400000), Offline (0x1000)
    (($a -band 0x40000) -ne 0) -or (($a -band 0x400000) -ne 0) -or (($a -band 0x1000) -ne 0)
}

# ---------- sortdownloads ----------

function sortdownloads {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Path = '',
        [int]$Days = 14,
        [string]$Destination = '',
        [switch]$Apply,
        [switch]$Yes,
        [switch]$IncludeMedia,
        [switch]$ShowNames,
        [switch]$FilesOnly
    )
    if (-not $Path) { $Path = Get-JidemDownloadsPath }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Write-Host ('Folder not found: ' + $Path) -ForegroundColor Yellow
        return
    }
    $src = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\', '/')
    $docs = Join-Path $HOME 'Documents'
    $refuse = @($HOME.TrimEnd('\', '/'), $docs, [IO.Path]::GetPathRoot($src).TrimEnd('\', '/'), 'C:\Users\Public\Documents\Shared')
    foreach ($r in $refuse) {
        if ($r -and ($src -ieq $r)) {
            Write-Host ('Refusing to sort ' + $src + ' (it is a root, your Documents, or the Shared bridge).') -ForegroundColor Yellow
            Write-Host 'Point -Path at a loose pile such as Downloads or Desktop.' -ForegroundColor DarkGray
            return
        }
    }
    if ($Days -lt 0) { $Days = 0 }
    $root = if ($Destination) { $Destination } else { Join-Path $docs 'Archive' }
    $label = Split-Path $src -Leaf
    $dest = Join-Path $root $label
    if ($dest.StartsWith($src + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host 'The destination is inside the folder being sorted. Choose another -Destination.' -ForegroundColor Yellow
        return
    }

    $cutoff = (Get-Date).AddDays(-$Days)
    $left = [ordered]@{ 'recent' = 0; 'sensitive name' = 0; 'audio/video' = 0; 'cloud-only' = 0; 'partial download' = 0; 'folder (recent or hidden)' = 0 }
    $plan = New-Object System.Collections.ArrayList
    $leftNames = New-Object System.Collections.ArrayList

    foreach ($item in @(Get-ChildItem -LiteralPath $src -Force -ErrorAction SilentlyContinue)) {
        $name = $item.Name
        if ($Global:JidemSortIgnore -contains $name.ToLower()) { continue }
        $arrived = if ($item.CreationTime -gt $item.LastWriteTime) { $item.CreationTime } else { $item.LastWriteTime }
        $year = $arrived.ToString('yyyy')

        if ($item.PSIsContainer) {
            if ($FilesOnly) { $left['folder (recent or hidden)']++; [void]$leftNames.Add("folder (left by -FilesOnly): $name"); continue }
            if ($name.StartsWith('.')) { $left['folder (recent or hidden)']++; [void]$leftNames.Add("folder (hidden): $name"); continue }
            if ($name -match $Global:JidemSortKeep) { $left['sensitive name']++; [void]$leftNames.Add("sensitive name: $name"); continue }
            if ($arrived -gt $cutoff) { $left['folder (recent or hidden)']++; [void]$leftNames.Add("folder (recent): $name"); continue }
            [void]$plan.Add([pscustomobject]@{ Item = $item; Category = 'Folders'; Year = $year; Size = 0; IsFolder = $true })
            continue
        }

        $ext = $item.Extension.ToLower()
        if ($Global:JidemSortIncomplete -contains $ext) { $left['partial download']++; [void]$leftNames.Add("partial download: $name"); continue }
        if (Test-JidemCloudOnly $item) { $left['cloud-only']++; [void]$leftNames.Add("cloud-only: $name"); continue }
        if ($name -match $Global:JidemSortKeep) { $left['sensitive name']++; [void]$leftNames.Add("sensitive name: $name"); continue }
        if ($arrived -gt $cutoff) { $left['recent']++; [void]$leftNames.Add("recent: $name"); continue }
        $cat = Get-JidemSortCategory $ext
        if ($cat -eq 'Media' -and -not $IncludeMedia) { $left['audio/video']++; [void]$leftNames.Add("audio/video: $name"); continue }
        [void]$plan.Add([pscustomobject]@{ Item = $item; Category = $cat; Year = $year; Size = $item.Length; IsFolder = $false })
    }

    $files   = @($plan | Where-Object { -not $_.IsFolder })
    $folders = @($plan | Where-Object { $_.IsFolder })
    $mode = if ($Apply) { 'APPLY' } else { 'PREVIEW' }
    Write-JidemBanner ('SORT ' + $label.ToUpper() + ' (' + $mode + ')')
    Write-Host ('Folder:       ' + $src)
    Write-Host ('Destination:  ' + $dest)
    Write-Host ('Leaving anything that arrived or changed in the last {0} day(s).' -f $Days) -ForegroundColor DarkGray
    Write-Host ''

    if ($plan.Count -eq 0) {
        Write-Host 'Nothing to sort.' -ForegroundColor Green
    } else {
        $total = ($files | Measure-Object Size -Sum).Sum
        if (-not $total) { $total = 0 }
        $verb = if ($Apply) { 'Moving' } else { 'Would move' }
        Write-Host ('{0} {1:N0} file(s), {2}:' -f $verb, $files.Count, (Format-JidemMB $total)) -ForegroundColor Cyan
        foreach ($g in ($files | Group-Object Category | Sort-Object Name)) {
            $mb = ($g.Group | Measure-Object Size -Sum).Sum
            Write-Host ('  {0,-13}{1,6:N0}   {2,10}' -f $g.Name, $g.Count, (Format-JidemMB $mb))
        }
        if ($folders.Count) { Write-Host ('{0} {1:N0} folder(s) intact into Folders\<year>.' -f $verb, $folders.Count) -ForegroundColor Cyan }
    }
    Write-Host ''
    $anyLeft = $false
    foreach ($k in $left.Keys) { if ($left[$k] -gt 0) { $anyLeft = $true } }
    if ($anyLeft) {
        Write-Host 'Left where they are:' -ForegroundColor Yellow
        foreach ($k in $left.Keys) { if ($left[$k] -gt 0) { Write-Host ('  {0,-28}{1,6:N0}' -f $k, $left[$k]) } }
        if ($left['audio/video'] -gt 0) { Write-Host '  (audio/video can be recordings; check them, then add -IncludeMedia if they are safe to file)' -ForegroundColor DarkGray }
        Write-Host ''
    }

    if ($ShowNames) {
        if ($plan.Count) {
            Write-Host 'Would move:' -ForegroundColor Cyan
            foreach ($p in ($plan | Sort-Object Category, Year)) { Write-Host ('  {0}\{1}\{2}' -f $p.Category, $p.Year, $p.Item.Name) }
            Write-Host ''
        }
        if ($leftNames.Count) {
            Write-Host 'Left alone:' -ForegroundColor Yellow
            foreach ($n in $leftNames) { Write-Host ('  ' + $n) }
            Write-Host ''
        }
    }

    if (-not $Apply) {
        Write-Host 'Preview only. Nothing was moved.' -ForegroundColor Green
        if ($plan.Count) { Write-Host 'To move them: sortdownloads -Apply   (it will ask first, and it can be undone with sortundo)' -ForegroundColor DarkGray }
        Write-JidemFooter
        return
    }
    if ($plan.Count -eq 0) { Write-JidemFooter; return }

    if (-not $Yes -and -not $WhatIfPreference) {
        $ans = Read-Host ('Move {0:N0} file(s) and {1:N0} folder(s) now? (y/n)' -f $files.Count, $folders.Count)
        if ($ans -notmatch '^(y|yes)$') { Write-Host 'Cancelled. Nothing was moved.' -ForegroundColor Yellow; Write-JidemFooter; return }
    }

    $rows = New-Object System.Collections.ArrayList
    $ok = 0; $failed = 0
    foreach ($p in $plan) {
        $target = Get-JidemFreePath (Join-Path (Join-Path (Join-Path $dest $p.Category) $p.Year) $p.Item.Name)
        if ($PSCmdlet.ShouldProcess($p.Item.FullName, 'move to ' + $target)) {
            try {
                $tdir = Split-Path $target -Parent
                if (-not (Test-Path -LiteralPath $tdir)) { New-Item -ItemType Directory -Path $tdir -Force -ErrorAction Stop | Out-Null }
                Move-Item -LiteralPath $p.Item.FullName -Destination $target -ErrorAction Stop
                [void]$rows.Add([pscustomobject]@{ Time = (Get-Date).ToString('s'); Source = $p.Item.FullName; Destination = $target; Category = $p.Category; Result = 'moved' })
                $ok++
            } catch {
                [void]$rows.Add([pscustomobject]@{ Time = (Get-Date).ToString('s'); Source = $p.Item.FullName; Destination = $target; Category = $p.Category; Result = ('FAILED: ' + $_.Exception.Message) })
                $failed++
            }
        }
    }
    if ($rows.Count) {
        try {
            if (-not (Test-Path -LiteralPath $Global:JidemSortLogs)) { New-Item -ItemType Directory -Path $Global:JidemSortLogs -Force | Out-Null }
            $mf = Get-JidemFreePath (Join-Path $Global:JidemSortLogs ('sort-' + (Get-Date).ToString('yyyyMMdd-HHmmss-fff') + '.csv'))
            $rows | Export-Csv -LiteralPath $mf -NoTypeInformation -Encoding UTF8
            Write-Host ('Moved {0:N0}, failed {1:N0}.' -f $ok, $failed) -ForegroundColor Green
            Write-Host ('Manifest: ' + $mf) -ForegroundColor DarkGray
            Write-Host ('To reverse it: sortundo ' + (Split-Path $mf -Leaf) + ' -Apply') -ForegroundColor DarkGray
        } catch {
            Write-Host ('Moved {0:N0}, failed {1:N0}. WARNING: could not write the manifest: {2}' -f $ok, $failed, $_.Exception.Message) -ForegroundColor Red
        }
    }
    Write-JidemFooter
}

# ---------- sortundo ----------

function sortundo {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Position = 0)][string]$Manifest = '',
        [switch]$Apply,
        [switch]$Yes
    )
    $logs = $Global:JidemSortLogs
    if (-not $Manifest) {
        $all = @()
        if (Test-Path -LiteralPath $logs) { $all = @(Get-ChildItem -LiteralPath $logs -Filter 'sort-*.csv' | Sort-Object LastWriteTime -Descending) }
        if ($all.Count -eq 0) { Write-Host 'No sort manifests found. Nothing to undo.' -ForegroundColor Yellow; return }
        Write-Host 'Past sorts (newest first):' -ForegroundColor Cyan
        foreach ($m in $all) {
            $n = @(Import-Csv -LiteralPath $m.FullName | Where-Object { $_.Result -eq 'moved' }).Count
            Write-Host ('  {0}   {1:N0} item(s)' -f $m.Name, $n)
        }
        Write-Host 'Reverse one with: sortundo <name> -Apply' -ForegroundColor DarkGray
        return
    }
    $file = if (Test-Path -LiteralPath $Manifest) { $Manifest } else { Join-Path $logs $Manifest }
    if (-not (Test-Path -LiteralPath $file)) { Write-Host ('Manifest not found: ' + $Manifest) -ForegroundColor Yellow; return }
    $rows = @(Import-Csv -LiteralPath $file | Where-Object { $_.Result -eq 'moved' })
    $restorable = @($rows | Where-Object { (Test-Path -LiteralPath $_.Destination) -and -not (Test-Path -LiteralPath $_.Source) })
    $blocked = $rows.Count - $restorable.Count
    Write-Host ('{0:N0} item(s) in this sort; {1:N0} can be put back; {2:N0} cannot (already moved again, or the original name is taken).' -f $rows.Count, $restorable.Count, $blocked) -ForegroundColor Cyan
    if (-not $Apply) { Write-Host 'Preview only. Add -Apply to put them back.' -ForegroundColor Green; return }
    if ($restorable.Count -eq 0) { return }
    if (-not $Yes -and -not $WhatIfPreference) {
        $ans = Read-Host ('Put {0:N0} item(s) back where they were? (y/n)' -f $restorable.Count)
        if ($ans -notmatch '^(y|yes)$') { Write-Host 'Cancelled.' -ForegroundColor Yellow; return }
    }
    $back = 0; $failed = 0
    foreach ($r in $restorable) {
        if ($PSCmdlet.ShouldProcess($r.Destination, 'move back to ' + $r.Source)) {
            try {
                $sdir = Split-Path $r.Source -Parent
                if (-not (Test-Path -LiteralPath $sdir)) { New-Item -ItemType Directory -Path $sdir -Force -ErrorAction Stop | Out-Null }
                Move-Item -LiteralPath $r.Destination -Destination $r.Source -ErrorAction Stop
                $back++
            } catch { $failed++ }
        }
    }
    Write-Host ('Put back {0:N0}, failed {1:N0}.' -f $back, $failed) -ForegroundColor Green
}

if (Get-Command Add-JidemHelp -ErrorAction SilentlyContinue) {
    Add-JidemHelp 'Maintenance' @('sortdownloads') 'ANY' 'Sort a loose pile (Downloads by default) into Documents\Archive by file type and arrival year. Preview first; counts only, never reads inside files.' @('sortdownloads', 'sortdownloads -Days 30 -ShowNames', 'sortdownloads -Apply', 'sortdownloads -Path "$HOME\Desktop" -FilesOnly') 'The one command that moves files. Preview unless -Apply, then asks y/n. Never overwrites or deletes. Leaves recent files, partial downloads, cloud-only files, audio/video (unless -IncludeMedia) and names matching $Global:JidemSortKeep (interview, Zoom, transcript, consent, IRB ...). Folders move intact. Writes a manifest to $HOME\PowerShell\sort-logs.'
    Add-JidemHelp 'Maintenance' @('sortundo') 'ANY' 'List past sorts, or put the files from one sort back where they were.' @('sortundo', 'sortundo sort-20261002-101500-123.csv -Apply') 'Preview unless -Apply. Skips anything that has moved again or whose original name is now taken.'
}
