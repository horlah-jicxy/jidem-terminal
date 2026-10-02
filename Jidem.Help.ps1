# ==============================================================================
# Jidem.Help.ps1 - Phase 12 help system
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE BEFORE Jidem.Dashboard.ps1 (Dashboard stays last):
#     . "$HOME\PowerShell\Jidem.Help.ps1"
#
# Commands:
#   jhelp                 every command for this account, grouped
#   jhelp <command>       what one command does, how to use it, examples
#   jhelp <group>         the commands in one group (core, navigation, git, search, teaching, system ...)
#   jhelp <word>          anything whose name or description contains the word
#   jhelp -All            include commands that belong to the other account (marked with *)
#
# To document a new command, add one Add-JidemHelp line in the table below.
# ==============================================================================

if (-not (Get-Command Write-JidemBanner -ErrorAction SilentlyContinue)) {
    Write-Host 'Jidem.Help.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
    return
}

$Global:JidemHelpGroups = @('Core', 'Navigation', 'Academic workflow', 'Projects', 'Git', 'Writing and VS Code', 'Search', 'Maintenance', 'Teaching', 'System')
$Global:JidemHelp = New-Object System.Collections.ArrayList

function Add-JidemHelp {
    param([string]$Group, [string[]]$Names, [string]$Account, [string]$Synopsis, [string[]]$Usage, [string]$Notes = '')
    [void]$Global:JidemHelp.Add([pscustomobject]@{ Group = $Group; Names = $Names; Account = $Account; Synopsis = $Synopsis; Usage = $Usage; Notes = $Notes })
}

# ---------- The help table: Group, Names, Account (ANY / JIDEM / MAKIN), Synopsis, Usage, Notes ----------

# --- Core ---
Add-JidemHelp 'Core' @('status') 'ANY' 'One screen: where you are, your workspace folders, the last 7 days of work, and git state.' @('status')
Add-JidemHelp 'Core' @('jwhere') 'ANY' 'Where you are: an arrow path, which workspace area it belongs to, and git.' @('jwhere') "Named jwhere because 'where' is a built-in PowerShell alias for Where-Object."
Add-JidemHelp 'Core' @('workspace') 'ANY' 'Every workspace root and its subfolders, with file counts and last activity.' @('workspace')
Add-JidemHelp 'Core' @('recent') 'ANY' 'Recently modified files across your workspace, newest first.' @('recent [-Days 14] [-Top 20] [-Extension md,docx] [-Path <folder>]', 'recent -Days 3 -Extension docx')
Add-JidemHelp 'Core' @('today') 'ANY' 'Files modified since midnight.' @('today [-Top 50] [-Extension md]')
Add-JidemHelp 'Core' @('tree', 'map') 'ANY' 'A folder tree with file counts, skipping .git, node_modules and similar.' @('tree [-Depth 2] [-Files] [-Path <folder>]', 'tree -Files -Depth 1') 'map is an alias for tree.'
Add-JidemHelp 'Core' @('size') 'ANY' 'Biggest subfolders (with percentage), or biggest files with -Files.' @('size [-Top 15] [-Files] [-Path <folder>]')

# --- Navigation ---
Add-JidemHelp 'Navigation' @('places') 'ANY' 'Lists every jump command for this account and whether its folder exists.' @('places [-All]') '-All also shows the other account''s commands.'
Add-JidemHelp 'Navigation' @('jidem', 'shared', 'archive', 'reference') 'ANY' 'Jump to Documents (jidem), the Shared bridge, the archive, or the reference folder.' @('jidem', 'shared') 'shared is C:\Users\Public\Documents\Shared, the one folder both accounts can open.'
Add-JidemHelp 'Navigation' @('academia', 'development', 'personaleditor', 'pythonwork', 'rwork', 'experiments', 'teachingtoolkit', 'github', 'archives') 'JIDEM' 'Jump to a JIDEM folder.' @('academia', 'development', 'github') "In the MAKIN account these print 'assigned to the JIDEM account'."
Add-JidemHelp 'Navigation' @('makin', 'school', 'makinarchive') 'MAKIN' 'Jump to a MAKIN folder (makin = Documents, school = UC-Merced).' @('school') "In the JIDEM account these print 'assigned to the MAKIN account'."

# --- Academic workflow (JIDEM) ---
Add-JidemHelp 'Academic workflow' @('dissertation', 'research', 'writing', 'fieldwork', 'publications', 'analysis', 'datasets', 'papers') 'JIDEM' 'Go to the folder AND show a summary: contents (most recently active first), files changed in the last 14 days, git state.' @('dissertation [-Code] [-Quiet]', 'papers', 'research -Quiet') "-Code also opens VS Code; -Quiet just jumps. dissertation = Academic-papers\projects\dissertation (falls back to Academia\Dissertation); papers = Academic-papers\projects."

# --- Projects (JIDEM) ---
Add-JidemHelp 'Projects' @('projects') 'JIDEM' 'A numbered list of your projects with git branch and uncommitted changes.' @('projects')
Add-JidemHelp 'Projects' @('openproject') 'JIDEM' 'Go to a project and open it in VS Code.' @('openproject', 'openproject 3', 'openproject paper -NoCode') 'Takes a number or part of a name. -NoCode skips VS Code.'
Add-JidemHelp 'Projects' @('projectinfo') 'JIDEM' 'Summary of a project folder: git, file counts, newest files, VS Code.' @('projectinfo [path]')
Add-JidemHelp 'Projects' @('projectnew') 'JIDEM' 'Creates Documents\Development\<name> with a README.md.' @('projectnew "My Project" [-Git] [-WhatIf]') 'Never overwrites. -Git also runs git init. -WhatIf previews.'

# --- Git (read-only) ---
Add-JidemHelp 'Git' @('gitstatus') 'ANY' 'Repository, branch, sync with upstream (as of last fetch), state, last commit.' @('gitstatus') 'All git commands only read. Nothing commits, stages, pulls, pushes or switches branches.'
Add-JidemHelp 'Git' @('gitchanges') 'ANY' 'Changed files grouped as staged, modified, untracked, conflicts.' @('gitchanges [-Stat]')
Add-JidemHelp 'Git' @('gitlog') 'ANY' 'Recent commits, one line each.' @('gitlog [-Count 10]')
Add-JidemHelp 'Git' @('gitbranch') 'ANY' 'Current branch, upstream, and branches sorted by recent activity.' @('gitbranch [-All]') '-All adds remote branches.'
Add-JidemHelp 'Git' @('gitroot') 'ANY' 'Prints the repository root folder.' @('gitroot [-Go]') '-Go moves you there.'

# --- Writing and VS Code ---
Add-JidemHelp 'Writing and VS Code' @('openvscode') 'ANY' 'Open a folder (default: here) or a file in VS Code.' @('openvscode [path]')
Add-JidemHelp 'Writing and VS Code' @('edit') 'ANY' 'Open a file in VS Code by path or by part of its name, searching under the current folder.' @('edit <file>', 'edit abstract') 'If several files match, it lists them newest first and asks you to be more specific.'
Add-JidemHelp 'Writing and VS Code' @('jwrite') 'JIDEM' 'Go to a writing project and open it in VS Code.' @('jwrite [project] [-NoCode]', 'jwrite ssha -NoCode') "Named jwrite because 'write' is a built-in alias. With no name it uses the pinned project (set JidemWritingProject in Jidem.Writing.ps1) or the most recently edited one."
Add-JidemHelp 'Writing and VS Code' @('focus') 'JIDEM' 'One-screen status of a writing project: location, editor, git, last edited files.' @('focus [project] [-Code]') 'Opens nothing unless you add -Code. Git counts only changes inside that project.'

# --- Search ---
Add-JidemHelp 'Search' @('findfile') 'ANY' 'Find files by NAME (wildcards * ? allowed).' @('findfile <name> [where]', 'findfile abstract', 'findfile "*.docx" SSHA') "[where] = a folder path, a jump-command name (dissertation, papers), or a folder name (SSHA). Skips dot-folders and Archive folders unless you add -IncludeHidden / -IncludeArchive."
Add-JidemHelp 'Search' @('findtext') 'ANY' 'Find text INSIDE files, including Word .docx files.' @('findtext <text> [where]', 'findtext masculinity SSHA', 'findtext "heal.*" -Regex') 'Switches: -Here (current folder only), -Regex, -NoDocx, -Top <n>, -IncludeHidden, -IncludeArchive. Reads .md .txt .csv .py .r .rmd .qmd .tex .bib .html .xml .yaml .yml and .docx.'
Add-JidemHelp 'Search' @('search') 'ANY' 'File names and text matches together on one screen.' @('search <text> [where]', 'search healing papers') 'Same switches as findtext.'

# --- Maintenance (report-only) ---
Add-JidemHelp 'Maintenance' @('inbox') 'JIDEM' 'Go to the inbox and report what is waiting, how old it is, and a guessed category for each item.' @('inbox [-Quiet]') 'Report only: nothing is moved. The category is a guess from file names and types.'
Add-JidemHelp 'Maintenance' @('duplicates') 'ANY' 'Files with identical content (same size and SHA-256), biggest wasted space first.' @('duplicates [where] [-MinKB 1] [-Top 15]') 'Report only: nothing is deleted.'
Add-JidemHelp 'Maintenance' @('empty') 'ANY' 'Empty folders and zero-byte files.' @('empty [where]') 'Empty folders may be intentional scaffolding. Report only.'
Add-JidemHelp 'Maintenance' @('cleanup') 'ANY' 'One-screen clutter report: inbox, stale areas, empty items, duplicates.' @('cleanup [-Quick] [-StaleDays 90]') '-Quick skips the duplicate check, which can be slow. Report only.'

# --- Teaching (MAKIN) ---
Add-JidemHelp 'Teaching' @('teach') 'MAKIN' 'Go to UC-Merced and show the teaching overview: current course, contents, recent work, Shared bridge.' @('teach [-Code] [-Quiet]') 'Edit the current course in Jidem.Teaching.ps1 ($Global:JidemCurrentCourse).'
Add-JidemHelp 'Teaching' @('course') 'MAKIN' 'List your course folders, or go to one (partial names work).' @('course', 'course 211', 'course ANTH -Code') 'Course folders live in UC-Merced\TA.'
Add-JidemHelp 'Teaching' @('coursenew') 'MAKIN' 'Create a course folder in TA with Syllabus, Materials, Assignments, Attendance, Grades, Reports.' @('coursenew "IH 211" [-Term "Fall 2024"] [-WhatIf]') 'Spaces become hyphens; -Term is appended after an underscore. Never overwrites.'
Add-JidemHelp 'Teaching' @('courses', 'ta', 'teaching', 'university', 'administration', 'admin', 'currentwork') 'MAKIN' 'Go to the folder and show a summary: contents, files changed in the last 14 days.' @('ta [-Code] [-Quiet]', 'administration')

# --- System ---
Add-JidemHelp 'System' @('health') 'ANY' 'Checks the whole setup: PowerShell, profile and its load order, every command file, expected commands, git, VS Code, folders, backups.' @('health') 'Read-only. Shows OK / WARN / FAIL.'
Add-JidemHelp 'System' @('validate') 'ANY' 'Lists any folder your commands point at that does not exist, with the command to create it.' @('validate') 'Read-only.'
Add-JidemHelp 'System' @('backup') 'ANY' 'Copies your command files and profile into a new dated folder under $HOME\PowerShell\backups.' @('backup [-WhatIf]') 'Never overwrites or deletes.'
Add-JidemHelp 'System' @('repair') 'ANY' 'Preview, then apply, safe fixes: unblock downloaded files, create missing folders.' @('repair', 'repair -Apply', 'repair -Apply -CreateFolders') 'Preview by default. -Apply backs up first. Never edits your profile or code.'
Add-JidemHelp 'System' @('dashboard', 'desk') 'ANY' 'Your desk: JIDEM academic desk or MAKIN teaching desk, with a numbered quick-action menu.' @('dashboard [-NoMenu]')
Add-JidemHelp 'System' @('jhelp') 'ANY' 'This help.' @('jhelp', 'jhelp git', 'jhelp findtext', 'jhelp -All')

# ---------- Helpers ----------

function Write-JidemWrapped([string[]]$Items, [string]$Indent = '  ', [int]$Width = 72) {
    $line = $Indent
    foreach ($i in $Items) {
        if ((($line.Length + $i.Length + 2) -gt $Width) -and $line.Trim().Length) { Write-Host $line; $line = $Indent }
        $line += $i + '  '
    }
    if ($line.Trim().Length) { Write-Host $line }
}

function Get-JidemHelpAccountText([string]$Account) {
    switch ($Account) { 'ANY' { 'both accounts' } 'JIDEM' { 'JIDEM account only' } 'MAKIN' { 'MAKIN account only' } default { $Account } }
}

function Show-JidemHelpEntry($Entry, [string]$Name) {
    Write-Host ''
    Write-Host ($Name.ToUpper()) -NoNewline -ForegroundColor Cyan
    Write-Host ("   {0}  |  {1}" -f $Entry.Group, (Get-JidemHelpAccountText $Entry.Account)) -ForegroundColor DarkGray
    Write-Host "  $($Entry.Synopsis)"
    Write-Host ''
    Write-Host 'USAGE' -ForegroundColor Yellow
    foreach ($u in $Entry.Usage) { Write-Host "  $u" }
    if ($Entry.Notes) {
        Write-Host ''
        Write-Host 'NOTES' -ForegroundColor Yellow
        Write-Host "  $($Entry.Notes)"
    }
    $others = @($Entry.Names | Where-Object { $_ -ine $Name })
    if ($others.Count) {
        Write-Host ''
        Write-Host 'SAME HELP APPLIES TO' -ForegroundColor Yellow
        Write-JidemWrapped $others
    }
    Write-Host ''
}

# ---------- Command ----------

function jhelp {
    param([Parameter(Position = 0)][string]$Topic, [switch]$All)
    $acct = $Global:JidemAccount
    $catalog = @($Global:JidemHelp)
    $visible = @($catalog | Where-Object { $All -or $_.Account -eq 'ANY' -or $_.Account -eq $acct })
    $mark = { param($e) if ($e.Account -ne 'ANY' -and $e.Account -ne $acct) { '*' } else { '' } }

    # --- Overview ---
    if (-not $Topic) {
        Write-JidemBanner "$acct COMMANDS"
        foreach ($g in $Global:JidemHelpGroups) {
            $entries = @($visible | Where-Object { $_.Group -eq $g })
            if (-not $entries.Count) { continue }
            Write-Host $g.ToUpper() -ForegroundColor Yellow
            $names = @()
            foreach ($e in $entries) { foreach ($n in $e.Names) { $names += ($n + (& $mark $e)) } }
            Write-JidemWrapped $names
            Write-Host ''
        }
        Write-Host '  jhelp <command>   details and examples        jhelp <group>   one group' -ForegroundColor DarkGray
        if ($All) { Write-Host '  * belongs to the other account' -ForegroundColor DarkGray }
        else { Write-Host '  jhelp -All        include the other account''s commands' -ForegroundColor DarkGray }
        Write-Host ''
        Write-JidemFooter
        return
    }

    $t = $Topic.Trim()

    # --- Exact command ---
    $hit = @($catalog | Where-Object { $_.Names -contains $t })
    if ($hit.Count) { Show-JidemHelpEntry $hit[0] $t; return }

    # --- A group (whole name, or the start of it) ---
    $norm = ($t.ToLower() -replace '[^a-z0-9]', '')
    $group = $Global:JidemHelpGroups | Where-Object { (($_.ToLower() -replace '[^a-z0-9]', '') -like "$norm*") } | Select-Object -First 1
    if ($group -and $norm.Length -ge 3) {
        Write-Host ''
        Write-Host $group.ToUpper() -ForegroundColor Cyan
        foreach ($e in @($catalog | Where-Object { $_.Group -eq $group })) {
            if (-not $All -and $e.Account -ne 'ANY' -and $e.Account -ne $acct) { continue }
            Write-Host ('  {0,-22}' -f (($e.Names | Select-Object -First 3) -join ', ')) -NoNewline -ForegroundColor Yellow
            Write-Host $e.Synopsis
        }
        Write-Host ''
        Write-Host '  jhelp <command> for details.' -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    # --- Partial match on names or descriptions ---
    $found = @($catalog | Where-Object { ($_.Names -join ' ') -like "*$t*" -or $_.Synopsis -like "*$t*" })
    if ($found.Count) {
        Write-Host ''
        Write-Host "Nothing named '$t'. Related:" -ForegroundColor Yellow
        foreach ($e in $found) { Write-Host ('  {0,-22}' -f ($e.Names[0])) -NoNewline -ForegroundColor Yellow; Write-Host $e.Synopsis }
        Write-Host ''
        return
    }
    Write-Host "No help found for '$t'. Run jhelp to see every command." -ForegroundColor Yellow
}
