# ==============================================================================
# Jidem.Dashboard.ps1 - Phase 10 dashboard (the "desk")
#
# Needs Jidem.Core.ps1 and Jidem.Navigation.ps1 loaded first; uses Projects, Teaching,
# Maintenance and others when they are loaded. Add to $PROFILE as the LAST line:
#     . "$HOME\PowerShell\Jidem.Dashboard.ps1"
#
# Commands:
#   dashboard           show the desk for this account, then a numbered menu of quick actions
#   dashboard -NoMenu   show the desk only (no prompt)
#   desk                short name for dashboard
#
# JIDEM  = ACADEMIC DESK : today, academia activity, inbox, development projects
# MAKIN  = TEACHING DESK : today, current course, TA activity, shared bridge
#
# The menu only runs the commands listed on screen. Read-only apart from what those commands do.
#
# Optional: set $Global:JidemDashboardOnStart = $true below to show the desk (without the menu)
# every time PowerShell opens. It is off by default because it scans your files on each start.
# ==============================================================================

foreach ($need in 'Get-JidemRecent', 'Invoke-JidemGo') {
    if (-not (Get-Command $need -ErrorAction SilentlyContinue)) {
        Write-Host 'Jidem.Dashboard.ps1 needs Jidem.Core.ps1 and Jidem.Navigation.ps1 loaded first.' -ForegroundColor Yellow
        return
    }
}

$Global:JidemDashboardOnStart = $false

# Activity window used for "Active" / "Quiet".
$Global:JidemDeskDays = 14

# Academic areas shown on the JIDEM desk, in this order (names of jump commands).
$Global:JidemDeskAreas = @('dissertation', 'papers', 'research', 'writing', 'publications', 'fieldwork', 'analysis')

# Quick actions per account (only commands that are actually loaded are listed).
$Global:JidemDeskActionsJidem = @('dissertation', 'research', 'writing', 'papers', 'projects', 'inbox', 'recent', 'status')
$Global:JidemDeskActionsMakin = @('teach', 'course', 'ta', 'shared', 'today', 'status')

# ---------- Helpers ----------

function Get-JidemDeskPlace([string]$Name) {
    $place = $Global:JidemPlaces | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $place) { return $null }
    $place.Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
}

function Get-JidemNewestIn($Recent, [string]$Path) {
    # $Recent is sorted newest first, so the first file under $Path is the newest one.
    if (-not $Path) { return $null }
    $prefix = $Path.TrimEnd('\') + '\'
    $Recent | Where-Object { $_.FullName.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
}

function Write-DeskRow([string]$Label, [string]$Value, [string]$Color = 'Gray') {
    Write-Host ('  {0,-17}' -f $Label) -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor $Color
}

function Write-DeskActivity([string]$Label, $Newest) {
    if ($Newest) { Write-DeskRow $Label ("Active ({0})" -f (Format-Age $Newest.LastWriteTime)) 'Green' }
    else { Write-DeskRow $Label "Quiet (nothing in $($Global:JidemDeskDays) days)" 'DarkGray' }
}

function Write-DeskToday($Recent) {
    $midnight = (Get-Date).Date
    $today = @($Recent | Where-Object { $_.LastWriteTime -ge $midnight }).Count
    Write-Host 'TODAY' -ForegroundColor Yellow
    Write-DeskRow 'Location' (Get-JidemLocation).Display
    Write-DeskRow 'Modified' ("{0} file(s)" -f $today) $(if ($today) { 'Green' } else { 'DarkGray' })
    if ($g = Get-JidemGit) {
        Write-DeskRow 'Git' ("{0} [{1}]  {2} change(s)" -f (Split-Path $g.Root -Leaf), $g.Branch, $g.Changes.Count) $(if ($g.Changes.Count) { 'Yellow' } else { 'Gray' })
    }
    Write-Host ''
}

function Write-DeskAcademic($Recent) {
    Write-Host 'ACADEMIA' -ForegroundColor Yellow
    $inbox = Get-JidemDeskPlace 'inbox'
    if ($inbox) {
        $n = @(Get-ChildItem -LiteralPath $inbox -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.Name.StartsWith('.') }).Count
        Write-DeskRow 'Inbox' $(if ($n) { "$n waiting" } else { 'empty' }) $(if ($n) { 'Yellow' } else { 'Green' })
    }
    foreach ($a in $Global:JidemDeskAreas) {
        $path = Get-JidemDeskPlace $a
        if (-not $path) { continue }
        $label = $a.Substring(0, 1).ToUpper() + $a.Substring(1)
        Write-DeskActivity $label (Get-JidemNewestIn $Recent $path)
    }
    Write-Host ''

    if (Get-Command Get-JidemProjects -ErrorAction SilentlyContinue) {
        Write-Host 'DEVELOPMENT' -ForegroundColor Yellow
        $projects = @(Get-JidemProjects | Where-Object { $_.Exists -and $_.Group -ne 'ACADEMIC' } | Select-Object -First 6)
        if (-not $projects.Count) { Write-Host '  (no projects)' -ForegroundColor DarkGray }
        foreach ($p in $projects) {
            $newest = Get-JidemNewestIn $Recent $p.Path
            $git = Get-JidemProjectGit $p.Path
            $extra = ''
            if ($git -and $git.Changes) { $extra = "   $($git.Changes) change(s)" }
            if ($newest) { Write-DeskRow $p.Name ("Active ({0}){1}" -f (Format-Age $newest.LastWriteTime), $extra) 'Green' }
            else { Write-DeskRow $p.Name ("Quiet{0}" -f $extra) 'DarkGray' }
        }
        Write-Host ''
    }
}

function Write-DeskTeaching($Recent) {
    Write-Host 'TEACHING' -ForegroundColor Yellow
    $course = $Global:JidemCurrentCourse
    if ($course) {
        $folder = ''
        if (Get-Command Find-JidemCourse -ErrorAction SilentlyContinue) {
            $hit = @(Find-JidemCourse $course)
            if ($hit.Count) { $folder = "   (folder: TA\$($hit[0].Name))" } else { $folder = '   (no folder yet: coursenew)' }
        }
        Write-DeskRow 'Current course' ($course + $folder)
    }
    if (Get-Command Get-JidemCourseFolders -ErrorAction SilentlyContinue) {
        Write-DeskRow 'Course folders' ("{0}" -f @(Get-JidemCourseFolders).Count)
    }
    $ta = Get-JidemDeskPlace 'ta'
    if ($ta) { Write-DeskActivity 'TA work' (Get-JidemNewestIn $Recent $ta) }
    Write-Host ''

    Write-Host 'SHARED BRIDGE' -ForegroundColor Yellow
    $shared = Get-JidemDeskPlace 'shared'
    if ($shared) {
        $items = @(Get-JidemFiles $shared | Sort-Object LastWriteTime -Descending)
        if ($items.Count) { Write-DeskRow 'Files' ("{0}   newest: {1} ({2})" -f $items.Count, $items[0].Name, (Format-Age $items[0].LastWriteTime)) }
        else { Write-DeskRow 'Files' 'empty' 'DarkGray' }
    }
    else { Write-DeskRow 'Files' 'Shared folder not found' 'DarkGray' }
    Write-Host ''
}

# ---------- Command ----------

function dashboard {
    param([switch]$NoMenu)
    $since = (Get-Date).AddDays(-$Global:JidemDeskDays)
    $recent = @(Get-JidemRecent -Since $since -Top 5000)

    $title = switch ($Global:JidemAccount) {
        'JIDEM' { 'JIDEM ACADEMIC DESK' }
        'MAKIN' { 'MAKIN TEACHING DESK' }
        default { "$($Global:JidemAccount) DESK" }
    }
    Write-JidemBanner $title

    Write-DeskToday $recent
    if ($Global:JidemAccount -eq 'JIDEM') { Write-DeskAcademic $recent }
    elseif ($Global:JidemAccount -eq 'MAKIN') { Write-DeskTeaching $recent }

    $wanted = if ($Global:JidemAccount -eq 'MAKIN') { $Global:JidemDeskActionsMakin } else { $Global:JidemDeskActionsJidem }
    $actions = @($wanted | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue })

    Write-Host 'QUICK ACTIONS' -ForegroundColor Yellow
    for ($i = 0; $i -lt $actions.Count; $i++) { Write-Host ('  [{0}] {1}' -f ($i + 1), $actions[$i]) }
    Write-Host ''
    Write-JidemFooter

    if ($NoMenu -or -not $actions.Count) { return }
    $choice = Read-Host 'Choose a number or name (Enter to close)'
    if ([string]::IsNullOrWhiteSpace($choice)) { return }
    $choice = $choice.Trim()
    $n = 0
    $command = $null
    if ([int]::TryParse($choice, [ref]$n)) { if ($n -ge 1 -and $n -le $actions.Count) { $command = $actions[$n - 1] } }
    elseif ($actions -contains $choice) { $command = $choice }
    if (-not $command) { Write-Host "'$choice' is not on the list." -ForegroundColor Yellow; return }
    & $command
}

Set-Alias desk dashboard -Scope Global

if ($Global:JidemDashboardOnStart) { dashboard -NoMenu }