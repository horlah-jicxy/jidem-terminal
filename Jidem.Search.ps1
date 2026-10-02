# ==============================================================================
# Jidem.Search.ps1 - Phase 8 search
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE after the other Jidem lines:
#     . "$HOME\PowerShell\Jidem.Search.ps1"
#
# Commands (work in both accounts; they search that account's workspace roots):
#   findfile <name>        files whose NAME contains the text (wildcards * ? allowed)
#   findtext <text>        text INSIDE files: .md .txt .csv .py .r .rmd .qmd .tex .bib
#                          .json .html and Word .docx (use -NoDocx to skip Word files)
#   search <text>          both of the above in one screen
#
# Switches:  -Here             search only the current folder (default: the whole workspace)
#            -IncludeArchive   also search folders named Archive / Archives
#            -Top <n>          how many results to show
#            -Regex            (findtext/search) treat the text as a regular expression
#
# Always skipped: .git, node_modules, __pycache__, virtual environments, and (unless
# -IncludeArchive) Archive/Archives folders. Read-only: nothing is changed.
# ==============================================================================

if (-not (Get-Command Get-JidemFiles -ErrorAction SilentlyContinue)) {
    Write-Host 'Jidem.Search.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
    return
}

$Global:JidemSearchSkip = @('Archive', 'Archives')
$Global:JidemTextExt = @('.md', '.txt', '.csv', '.py', '.r', '.rmd', '.qmd', '.tex', '.bib', '.json', '.html', '.xml', '.yaml', '.yml')

# ---------- Helpers ----------

function Get-JidemSearchFiles {
    param([switch]$Here, [switch]$IncludeArchive)
    if ($Here) { $roots = @((Get-Location).Path) }
    else { $roots = @($Global:JidemRoots.Values | Where-Object { Test-Path -LiteralPath $_ }) }
    foreach ($root in $roots) {
        foreach ($f in (Get-JidemFiles $root)) {
            if (-not $IncludeArchive) {
                # Only look at the part of the path below the search root.
                $parts = $f.FullName.Substring($root.Length) -split '[\\/]'
                $skip = $false
                foreach ($s in $Global:JidemSearchSkip) { if ($parts -contains $s) { $skip = $true; break } }
                if ($skip) { continue }
            }
            $f
        }
    }
}

function Get-JidemSearchScope([switch]$Here) {
    if ($Here) { return (Get-Location).Path }
    ($Global:JidemRoots.Keys -join ', ')
}

function Get-JidemDocxText([string]$Path) {
    # Plain text of a Word file (paragraphs separated by newlines). Empty string on any problem.
    try {
        Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
        $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Read)
            $entry = $zip.GetEntry('word/document.xml')
            if (-not $entry) { return '' }
            $reader = New-Object System.IO.StreamReader($entry.Open())
            try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        finally { $fs.Dispose() }
        $xml = $xml -replace '</w:p>', "`n"
        $xml = $xml -replace '<[^>]+>', ''
        [System.Net.WebUtility]::HtmlDecode($xml)
    }
    catch { '' }
}

function Get-JidemMatchIndex([string]$Line, [string]$Text, [bool]$UseRegex) {
    if ($UseRegex) {
        $m = [regex]::Match($Line, $Text, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { return $m.Index } else { return -1 }
    }
    $Line.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase)
}

function Get-JidemSnippet([string]$Line, [int]$Index) {
    $start = [math]::Max(0, $Index - 50)
    $len = [math]::Min(140, $Line.Length - $start)
    $s = $Line.Substring($start, $len).Trim()
    if ($start -gt 0) { $s = '...' + $s }
    if (($start + $len) -lt $Line.Length) { $s = $s + '...' }
    $s
}

function Find-JidemText {
    # Returns match objects (File, LineNo, Snippet), newest files first, stopping at $Top matches.
    param($Files, [string]$Text, [int]$Top, [bool]$UseRegex, [bool]$NoDocx, [int]$PerFile = 3)
    $hits = New-Object System.Collections.ArrayList
    foreach ($f in $Files) {
        if ($hits.Count -ge $Top) { break }
        $ext = $f.Extension.ToLower()
        $isDocx = ($ext -eq '.docx') -and (-not $NoDocx) -and (-not $f.Name.StartsWith('~$'))
        $isText = ($Global:JidemTextExt -contains $ext) -and ($f.Length -lt 5MB)
        if (-not ($isDocx -or $isText)) { continue }
        try {
            if ($isDocx) { $lines = (Get-JidemDocxText $f.FullName) -split "`n" }
            else { $lines = [System.IO.File]::ReadAllLines($f.FullName) }
        }
        catch { continue }
        $found = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($found -ge $PerFile -or $hits.Count -ge $Top) { break }
            $idx = Get-JidemMatchIndex $lines[$i] $Text $UseRegex
            if ($idx -ge 0) {
                [void]$hits.Add([pscustomobject]@{ File = $f; LineNo = $i + 1; Snippet = (Get-JidemSnippet $lines[$i] $idx) })
                $found++
            }
        }
    }
    @($hits)
}

function Show-JidemTextHits($Hits) {
    $last = ''
    foreach ($h in $Hits) {
        $rel = Get-JidemRelative $h.File.FullName
        if ($rel -ne $last) { Write-Host $rel -ForegroundColor Yellow; $last = $rel }
        Write-Host ('  {0,5}: {1}' -f $h.LineNo, $h.Snippet)
    }
}

function Test-JidemRegex([string]$Pattern) {
    try { [void](New-Object System.Text.RegularExpressions.Regex($Pattern)); $true }
    catch { Write-Host "Not a valid regular expression: $Pattern" -ForegroundColor Yellow; $false }
}

# ---------- Commands ----------

function findfile {
    param([Parameter(Mandatory = $true, Position = 0)][string]$Pattern,
          [switch]$Here, [switch]$IncludeArchive, [int]$Top = 30)
    $like = if ($Pattern -match '[\*\?]') { $Pattern } else { "*$Pattern*" }
    $files = @(Get-JidemSearchFiles -Here:$Here -IncludeArchive:$IncludeArchive |
               Where-Object { $_.Name -like $like } | Sort-Object LastWriteTime -Descending)
    Write-Host "FILES matching '$Pattern'   [$(Get-JidemSearchScope -Here:$Here)]" -ForegroundColor Cyan
    if (-not $files.Count) { Write-Host '  No files found.' -ForegroundColor DarkGray; return }
    Show-JidemFileList ($files | Select-Object -First $Top)
    if ($files.Count -gt $Top) { Write-Host "Showing $Top of $($files.Count). Use -Top to see more." -ForegroundColor DarkGray }
}

function findtext {
    param([Parameter(Mandatory = $true, Position = 0)][string]$Text,
          [switch]$Here, [switch]$IncludeArchive, [switch]$Regex, [switch]$NoDocx, [int]$Top = 40)
    if ($Regex -and -not (Test-JidemRegex $Text)) { return }
    $files = @(Get-JidemSearchFiles -Here:$Here -IncludeArchive:$IncludeArchive | Sort-Object LastWriteTime -Descending)
    Write-Host "TEXT matching '$Text'   [$(Get-JidemSearchScope -Here:$Here)]" -ForegroundColor Cyan
    $hits = @(Find-JidemText -Files $files -Text $Text -Top $Top -UseRegex ([bool]$Regex) -NoDocx ([bool]$NoDocx))
    if (-not $hits.Count) { Write-Host '  No matches.' -ForegroundColor DarkGray; return }
    Show-JidemTextHits $hits
    $fileCount = @($hits | ForEach-Object { $_.File.FullName } | Select-Object -Unique).Count
    Write-Host ("{0} match(es) in {1} file(s), newest files first (up to 3 per file)" -f $hits.Count, $fileCount) -ForegroundColor DarkGray
}

function search {
    param([Parameter(Mandatory = $true, Position = 0)][string]$Text,
          [switch]$Here, [switch]$IncludeArchive, [switch]$Regex, [switch]$NoDocx, [int]$Top = 15)
    if ($Regex -and -not (Test-JidemRegex $Text)) { return }
    $files = @(Get-JidemSearchFiles -Here:$Here -IncludeArchive:$IncludeArchive | Sort-Object LastWriteTime -Descending)
    Write-JidemBanner "$($Global:JidemAccount) SEARCH"
    Write-Host ('{0,-10}{1}' -f 'FOR', $Text) -ForegroundColor Yellow
    Write-Host ('{0,-10}{1}   ({2} files)' -f 'IN', (Get-JidemSearchScope -Here:$Here), $files.Count)
    Write-Host ''

    Write-Host 'FILE NAMES' -ForegroundColor Yellow
    $like = "*$Text*"
    $byName = @($files | Where-Object { $_.Name -like $like })
    if ($byName.Count) {
        Show-JidemFileList ($byName | Select-Object -First $Top)
        if ($byName.Count -gt $Top) { Write-Host "  ... and $($byName.Count - $Top) more (findfile '$Text')" -ForegroundColor DarkGray }
    }
    else { Write-Host '  None.' -ForegroundColor DarkGray; Write-Host '' }

    Write-Host 'INSIDE FILES' -ForegroundColor Yellow
    $hits = @(Find-JidemText -Files $files -Text $Text -Top $Top -UseRegex ([bool]$Regex) -NoDocx ([bool]$NoDocx))
    if ($hits.Count) {
        Show-JidemTextHits $hits
        Write-Host "  (first $Top matches; findtext '$Text' for more)" -ForegroundColor DarkGray
    }
    else { Write-Host '  No matches.' -ForegroundColor DarkGray }
    Write-Host ''
    Write-JidemFooter
}
