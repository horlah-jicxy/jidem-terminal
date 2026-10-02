# ==============================================================================
# Jidem.Search.ps1 - Phase 8 search
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE after the other Jidem lines:
#     . "$HOME\PowerShell\Jidem.Search.ps1"
#
# Commands (work in both accounts; they search that account's workspace roots):
#   findfile <name> [where]    files whose NAME contains the text (wildcards * ? allowed)
#   findtext <text> [where]    text INSIDE files: .md .txt .csv .py .r .rmd .qmd .tex .bib
#                              .html and Word .docx (use -NoDocx to skip Word files)
#   search <text> [where]      both of the above in one screen
#
# [where] narrows the search. It can be:
#   a folder path          findtext masculinity "GitHub\Academic-papers\projects\SSHA"
#   a jump-command name    findtext masculinity dissertation        (also: research, papers ...)
#   a folder name          findtext masculinity SSHA                (found anywhere in the workspace)
# Write it as the second word, or as  -In <where> . With no [where] the whole workspace is searched;
# -Here searches the current folder only.
#
# Other switches:  -IncludeArchive   also search folders named Archive / Archives
#                  -IncludeHidden    also search dot-folders (.writing-snapshots, .vscode) and dot-files
#                  -Top <n>          how many results to show
#                  -Regex            (findtext/search) treat the text as a regular expression
#
# Always skipped: .git, node_modules, __pycache__, virtual environments. Read-only.
# ==============================================================================

if (-not (Get-Command Get-JidemFiles -ErrorAction SilentlyContinue)) {
    Write-Host 'Jidem.Search.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
    return
}

$Global:JidemSearchSkip = @('Archive', 'Archives')
$Global:JidemTextExt = @('.md', '.txt', '.csv', '.py', '.r', '.rmd', '.qmd', '.tex', '.bib', '.html', '.xml', '.yaml', '.yml')

# ---------- Scope ----------

function Resolve-JidemSearchRoot([string]$In) {
    # 1. a real folder path (absolute, or relative to the current folder)
    if (Test-Path -LiteralPath $In -PathType Container) { return (Resolve-Path -LiteralPath $In).Path }

    # 2. a jump-command name such as dissertation, research, papers
    if ($Global:JidemPlaces) {
        $place = $Global:JidemPlaces | Where-Object { $_.Name -ieq $In } | Select-Object -First 1
        if ($place) {
            $p = $place.Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
            if ($p) { return $p }
        }
    }

    # 3. a folder with that name anywhere in the workspace (exact name first, then partial)
    $dirs = @()
    foreach ($root in $Global:JidemRoots.Values) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $dirs += @(Get-ChildItem -LiteralPath $root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                   Where-Object {
                       $_.Name -like "*$In*" -and
                       -not ($_.FullName.Substring($root.Length) -split '[\\/]' | Where-Object { $_.StartsWith('.') -or $Global:JidemIgnore -contains $_ })
                   })
    }
    $exact = @($dirs | Where-Object { $_.Name -ieq $In })
    $pick = if ($exact.Count) { $exact } else { $dirs }
    if ($pick.Count -eq 1) { return $pick[0].FullName }
    if ($pick.Count -gt 1) {
        Write-Host "'$In' matches more than one folder. Use a more specific name or a path:" -ForegroundColor Yellow
        foreach ($d in ($pick | Select-Object -First 10)) { Write-Host "  $(Get-JidemRelative $d.FullName)" }
        return $null
    }
    Write-Host "No folder, command or path matches '$In'." -ForegroundColor Yellow
    $null
}

function Get-JidemSearchScope {
    param([switch]$Here, [string]$In)
    if ($In) {
        $r = Resolve-JidemSearchRoot $In
        if (-not $r) { return $null }
        return [pscustomobject]@{ Roots = @($r); Label = (Get-JidemRelative $r) }
    }
    if ($Here) {
        $p = (Get-Location).Path
        return [pscustomobject]@{ Roots = @($p); Label = $p }
    }
    $roots = @($Global:JidemRoots.Values | Where-Object { Test-Path -LiteralPath $_ })
    [pscustomobject]@{ Roots = $roots; Label = ($Global:JidemRoots.Keys -join ', ') }
}

function Get-JidemSearchFiles {
    param([string[]]$Roots, [switch]$IncludeArchive, [switch]$IncludeHidden)
    foreach ($root in $Roots) {
        foreach ($f in (Get-JidemFiles $root)) {
            # Only look at the part of the path below the search root.
            $parts = @($f.FullName.Substring($root.Length) -split '[\\/]' | Where-Object { $_ })
            $skip = $false
            if (-not $IncludeArchive) {
                foreach ($s in $Global:JidemSearchSkip) { if ($parts -contains $s) { $skip = $true; break } }
            }
            if (-not $skip -and -not $IncludeHidden) {
                foreach ($p in $parts) { if ($p.StartsWith('.')) { $skip = $true; break } }
            }
            if ($skip) { continue }
            $f
        }
    }
}

# ---------- Text helpers ----------

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

function Show-JidemSearchFileList($Files) {
    # One line per file, full path (no table, so nothing gets cut off).
    foreach ($f in $Files) {
        Write-Host ('{0,-9} {1,8}  ' -f (Format-Age $f.LastWriteTime), (Format-Size $f.Length)) -NoNewline -ForegroundColor DarkGray
        Write-Host (Get-JidemRelative $f.FullName)
    }
}

function Test-JidemRegex([string]$Pattern) {
    try { [void](New-Object System.Text.RegularExpressions.Regex($Pattern)); $true }
    catch { Write-Host "Not a valid regular expression: $Pattern" -ForegroundColor Yellow; $false }
}

# ---------- Commands ----------

function findfile {
    param([Parameter(Mandatory = $true, Position = 0)][string]$Pattern,
          [Parameter(Position = 1)][string]$In,
          [switch]$Here, [switch]$IncludeArchive, [switch]$IncludeHidden, [int]$Top = 30)
    $scope = Get-JidemSearchScope -Here:$Here -In $In
    if (-not $scope) { return }
    $like = if ($Pattern -match '[\*\?]') { $Pattern } else { "*$Pattern*" }
    $files = @(Get-JidemSearchFiles -Roots $scope.Roots -IncludeArchive:$IncludeArchive -IncludeHidden:$IncludeHidden |
               Where-Object { $_.Name -like $like } | Sort-Object LastWriteTime -Descending)
    Write-Host "FILES matching '$Pattern'   [$($scope.Label)]" -ForegroundColor Cyan
    if (-not $files.Count) { Write-Host '  No files found.' -ForegroundColor DarkGray; return }
    Show-JidemSearchFileList ($files | Select-Object -First $Top)
    if ($files.Count -gt $Top) { Write-Host "Showing $Top of $($files.Count). Use -Top to see more." -ForegroundColor DarkGray }
}

function findtext {
    param([Parameter(Mandatory = $true, Position = 0)][string]$Text,
          [Parameter(Position = 1)][string]$In,
          [switch]$Here, [switch]$IncludeArchive, [switch]$IncludeHidden, [switch]$Regex, [switch]$NoDocx, [int]$Top = 40)
    if ($Regex -and -not (Test-JidemRegex $Text)) { return }
    $scope = Get-JidemSearchScope -Here:$Here -In $In
    if (-not $scope) { return }
    $files = @(Get-JidemSearchFiles -Roots $scope.Roots -IncludeArchive:$IncludeArchive -IncludeHidden:$IncludeHidden | Sort-Object LastWriteTime -Descending)
    Write-Host "TEXT matching '$Text'   [$($scope.Label)]" -ForegroundColor Cyan
    $hits = @(Find-JidemText -Files $files -Text $Text -Top $Top -UseRegex ([bool]$Regex) -NoDocx ([bool]$NoDocx))
    if (-not $hits.Count) { Write-Host '  No matches.' -ForegroundColor DarkGray; return }
    Show-JidemTextHits $hits
    $fileCount = @($hits | ForEach-Object { $_.File.FullName } | Select-Object -Unique).Count
    Write-Host ("{0} match(es) in {1} file(s), newest files first (up to 3 per file)" -f $hits.Count, $fileCount) -ForegroundColor DarkGray
}

function search {
    param([Parameter(Mandatory = $true, Position = 0)][string]$Text,
          [Parameter(Position = 1)][string]$In,
          [switch]$Here, [switch]$IncludeArchive, [switch]$IncludeHidden, [switch]$Regex, [switch]$NoDocx, [int]$Top = 15)
    if ($Regex -and -not (Test-JidemRegex $Text)) { return }
    $scope = Get-JidemSearchScope -Here:$Here -In $In
    if (-not $scope) { return }
    $files = @(Get-JidemSearchFiles -Roots $scope.Roots -IncludeArchive:$IncludeArchive -IncludeHidden:$IncludeHidden | Sort-Object LastWriteTime -Descending)
    Write-JidemBanner "$($Global:JidemAccount) SEARCH"
    Write-Host ('{0,-10}{1}' -f 'FOR', $Text) -ForegroundColor Yellow
    Write-Host ('{0,-10}{1}   ({2} files)' -f 'IN', $scope.Label, $files.Count)
    Write-Host ''

    Write-Host 'FILE NAMES' -ForegroundColor Yellow
    $like = "*$Text*"
    $byName = @($files | Where-Object { $_.Name -like $like })
    if ($byName.Count) {
        Show-JidemSearchFileList ($byName | Select-Object -First $Top)
        if ($byName.Count -gt $Top) { Write-Host "  ... and $($byName.Count - $Top) more (findfile '$Text')" -ForegroundColor DarkGray }
    }
    else { Write-Host '  None.' -ForegroundColor DarkGray }
    Write-Host ''

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
