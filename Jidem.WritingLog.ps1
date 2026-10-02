# ==============================================================================
# Jidem.WritingLog.ps1 - v1.1.0 shared daily word count (both accounts)
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE AFTER Jidem.Help.ps1 and
# BEFORE Jidem.Dashboard.ps1 (the dashboard must stay the last line):
#     . "$HOME\PowerShell\Jidem.WritingLog.ps1"
#
# Commands:
#   syncwords [-Root <folder>...] [-Since yyyy-MM-dd] [-WhatIf]
#                      read the Writing Timer session logs (.writing-sessions.jsonl) in this
#                      account's writing folders and ADD any sessions not yet in the shared log
#   wordsum [-Days 7]  report-only: today, the last days and your streak, both accounts
#   logwords <words> [<minutes>] [-Note "text"] [-WhatIf]
#                      add one line by hand (for writing the timer did not see)
#   countwords <file>  report-only: count the words in a .md / .txt / .tex file
#
# The log is one CSV in the Shared bridge:  C:\Users\Public\Documents\Shared\writing-log.csv
#   columns: Date, Time, Account, Words, Minutes, Note, SessionStart, Source, Mode
# It holds NUMBERS ONLY. syncwords never copies file names, session notes or text. It is the one
# deliberate exception to "Shared stays empty" because nothing sensitive can be in it.
#
# Commands here only ever APPEND lines. Nothing overwrites, edits or deletes the log or the
# timer's own files, and nothing runs on its own. To fix a wrong line, edit the CSV in Notepad.
# Running syncwords twice never duplicates: each timer session is added once (by its start time).
#
# Days use the LOCAL date stored by Writing Timer 1.6+ (localDate, utcOffsetMinutes), so a day
# stays the day you wrote it even after you travel. Older sessions (timer 1.5 and earlier) have no
# stored date and are read as the offset in $Global:JidemLegacyUtcOffset (-420 = US Pacific, summer).
# ==============================================================================

foreach ($need in 'Write-JidemBanner', 'Write-JidemFooter') {
    if (-not (Get-Command $need -ErrorAction SilentlyContinue)) {
        Write-Host 'Jidem.WritingLog.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
        return
    }
}

$Global:JidemWritingLog     = 'C:\Users\Public\Documents\Shared\writing-log.csv'
$Global:JidemWritingColumns = @('Date', 'Time', 'Account', 'Words', 'Minutes', 'Note', 'SessionStart', 'Source', 'Mode')
$Global:JidemLegacyUtcOffset = -420

# Folders syncwords searches (to 5 levels deep) for Writing Timer session logs.
$Global:JidemWritingRoots = switch ($Global:JidemAccount) {
    'JIDEM' { @("$HOME\Documents\GitHub", "$HOME\Documents\Academia") }
    'MAKIN' { @("$HOME\Documents\Writing-Notes", "$HOME\Documents\UC-Merced") }
    default { @("$HOME\Documents") }
}

# ---------- Helpers ----------

function Get-JidemWordRows {
    if (-not (Test-Path -LiteralPath $Global:JidemWritingLog)) { return @() }
    @(Import-Csv -LiteralPath $Global:JidemWritingLog |
        Where-Object { $_.Date -match '^\d{4}-\d{2}-\d{2}$' -and $_.Words -match '^\d+$' })
}

function New-JidemWordRow($Date, $Time, [int]$Words, [int]$Minutes, [string]$Note, [string]$SessionStart, [string]$Source, [string]$Mode) {
    [pscustomobject]([ordered]@{
        Date         = $Date
        Time         = $Time
        Account      = $Global:JidemAccount
        Words        = $Words
        Minutes      = $Minutes
        Note         = $Note
        SessionStart = $SessionStart
        Source       = $Source
        Mode         = $Mode
    })
}

# True when the log does not exist yet, or already has this version's column layout.
function Test-JidemWordLogReady {
    $log = $Global:JidemWritingLog
    if (-not (Test-Path -LiteralPath $log)) { return $true }
    $first = Get-Content -LiteralPath $log -TotalCount 1
    $want = (($Global:JidemWritingColumns | ForEach-Object { '"' + $_ + '"' }) -join ',')
    if ($first -eq $want) { return $true }
    Write-Host 'writing-log.csv has the older column layout (from the first version of this file).' -ForegroundColor Yellow
    Write-Host 'In File Explorer, rename it to writing-log-old.csv, then run the command again. Nothing was written.' -ForegroundColor Yellow
    Write-Host ('Folder: ' + (Split-Path $log -Parent)) -ForegroundColor DarkGray
    $false
}

function Add-JidemWordRows([object[]]$Rows) {
    if (-not (Test-JidemWordLogReady)) { return $false }
    try {
        $Rows | Export-Csv -LiteralPath $Global:JidemWritingLog -Append -NoTypeInformation -Encoding ASCII -ErrorAction Stop
        return $true
    } catch {
        Write-Host ('Could not write to the log: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Host 'If the file is open in Excel, close it. If it says access denied, tell Claude.' -ForegroundColor Yellow
        return $false
    }
}

function ConvertTo-JidemUtc($Value) {
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    try { return ([datetimeoffset]::Parse([string]$Value, [cultureinfo]::InvariantCulture)).UtcDateTime } catch { return $null }
}

# ---------- Commands ----------

function countwords {
    param([Parameter(Mandatory = $true, Position = 0)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Host ('No such file: ' + $Path) -ForegroundColor Yellow
        return
    }
    $ext = [IO.Path]::GetExtension($Path).ToLower()
    if (@('.md', '.txt', '.tex') -notcontains $ext) {
        Write-Host 'countwords reads plain text only (.md .txt .tex). For Word files use the count shown in Word.' -ForegroundColor Yellow
        return
    }
    $text = Get-Content -LiteralPath $Path -Raw
    if (-not $text) { $text = '' }
    $n = ([regex]::Matches($text, '\S+')).Count
    Write-Host ('{0:N0} words in {1}' -f $n, (Split-Path $Path -Leaf))
}

function logwords {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Position = 0)][int]$Words = 0,
        [Parameter(Position = 1)][int]$Minutes = 0,
        [string]$Note = ''
    )
    if ($Words -lt 1 -or $Words -gt 100000 -or $Minutes -lt 0 -or $Minutes -gt 720) {
        Write-Host 'Usage: logwords <words> [<minutes>] [-Note "what it was"] [-WhatIf]' -ForegroundColor Yellow
        Write-Host '  e.g. logwords 450 40 -Note "ch2 draft"' -ForegroundColor DarkGray
        Write-Host '  For timed sessions use syncwords instead; logwords is for writing the timer did not see.' -ForegroundColor DarkGray
        return
    }
    $log = $Global:JidemWritingLog
    $dir = Split-Path $log -Parent
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        Write-Host ('The Shared folder was not found: ' + $dir) -ForegroundColor Yellow
        return
    }
    $now = Get-Date
    $clean = ($Note -replace '[^\x20-\x7E]', ' ').Trim()
    if ($clean.Length -gt 80) { $clean = $clean.Substring(0, 80) }
    $row = New-JidemWordRow $now.ToString('yyyy-MM-dd') $now.ToString('HH:mm') $Words $Minutes $clean '' 'manual' ''
    if ($PSCmdlet.ShouldProcess($log, ('append ' + $Words + ' words'))) {
        if (-not (Add-JidemWordRows @($row))) { return }
        $todayKey = $now.ToString('yyyy-MM-dd')
        $sum = (Get-JidemWordRows | Where-Object { $_.Date -eq $todayKey -and $_.Mode -ne 'Edit' } | ForEach-Object { [int]$_.Words } | Measure-Object -Sum).Sum
        Write-Host ('Logged {0:N0} words ({1} min) as {2}.' -f $Words, $Minutes, $Global:JidemAccount) -ForegroundColor Green
        Write-Host ('Today so far, both accounts: {0:N0} words.' -f $sum) -ForegroundColor Cyan
    }
}

function syncwords {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string[]]$Root,
        [string]$Since = ''
    )
    $roots = if ($Root) { $Root } else { $Global:JidemWritingRoots }
    $sinceDate = $null
    if ($Since) {
        try { $sinceDate = [datetime]::ParseExact($Since, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture) }
        catch { Write-Host 'Use -Since yyyy-MM-dd, for example -Since 2026-09-01' -ForegroundColor Yellow; return }
    }
    $log = $Global:JidemWritingLog
    $dir = Split-Path $log -Parent
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        Write-Host ('The Shared folder was not found: ' + $dir) -ForegroundColor Yellow
        return
    }
    if (-not (Test-JidemWordLogReady)) { return }

    $known = @{}
    foreach ($r in Get-JidemWordRows) {
        if ($r.SessionStart) { $known[($r.Account + '|' + $r.SessionStart)] = $true }
    }

    $files = @()
    foreach ($rt in $roots) {
        if (Test-Path -LiteralPath $rt -PathType Container) {
            $files += @(Get-ChildItem -LiteralPath $rt -Recurse -Depth 5 -Force -File -Filter '.writing-sessions.jsonl' -ErrorAction SilentlyContinue)
        }
    }

    $new = New-Object System.Collections.ArrayList
    $seen = 0
    foreach ($f in $files) {
        foreach ($line in @(Get-Content -LiteralPath $f.FullName)) {
            if (-not $line -or -not $line.Trim()) { continue }
            try { $s = $line | ConvertFrom-Json } catch { continue }
            if (-not $s.start) { continue }
            $startUtc = ConvertTo-JidemUtc $s.start
            if (-not $startUtc) { continue }
            $seen++
            $off = $Global:JidemLegacyUtcOffset
            if ($null -ne $s.utcOffsetMinutes -and ([string]$s.utcOffsetMinutes) -ne '') { $off = [int]$s.utcOffsetMinutes }
            $local = $startUtc.AddMinutes($off)
            $date = if ($s.localDate) { [string]$s.localDate } else { $local.ToString('yyyy-MM-dd') }
            if ($sinceDate -and ([datetime]::ParseExact($date, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)) -lt $sinceDate) { continue }
            $words = [math]::Max(0, [int]$s.words)
            $mins = [int][math]::Round([double]$s.activeMinutes)
            if ($words -eq 0 -and $mins -eq 0) { continue }
            $stamp = $startUtc.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
            $key = $Global:JidemAccount + '|' + $stamp
            if ($known.ContainsKey($key)) { continue }
            $known[$key] = $true
            $mode = if ($s.mode) { [string]$s.mode } else { '' }
            [void]$new.Add((New-JidemWordRow $date $local.ToString('HH:mm') $words $mins '' $stamp 'timer' $mode))
        }
    }

    Write-Host ('{0}: {1} session log file(s), {2} session(s) read, {3} new.' -f $Global:JidemAccount, $files.Count, $seen, $new.Count) -ForegroundColor Cyan
    if ($new.Count -eq 0) {
        if ($files.Count -eq 0) { Write-Host ('No .writing-sessions.jsonl found under: ' + ($roots -join ', ')) -ForegroundColor Yellow }
        else { Write-Host 'Nothing new to add. The shared log is up to date.' -ForegroundColor Green }
        return
    }
    if ($WhatIfPreference) {
        foreach ($n in $new) {
            Write-Host ('  {0} {1}  {2,6:N0} words  {3,4} min  {4}' -f $n.Date, $n.Time, $n.Words, $n.Minutes, $n.Mode)
        }
    }
    if ($PSCmdlet.ShouldProcess($log, ('append ' + $new.Count + ' session(s)'))) {
        if (Add-JidemWordRows $new.ToArray()) {
            Write-Host ('Added {0} session(s) to the shared log.' -f $new.Count) -ForegroundColor Green
            Write-Host 'Run wordsum to see the totals.' -ForegroundColor DarkGray
        }
    }
}

function wordsum {
    param([int]$Days = 7)
    if ($Days -lt 1) { $Days = 1 }
    Write-JidemBanner 'WORDS WRITTEN'
    $rows = Get-JidemWordRows
    if ($rows.Count -eq 0) {
        Write-Host 'No entries yet. Run syncwords to add your timed sessions, or logwords for one by hand.' -ForegroundColor Yellow
        Write-Host ('Log file: ' + $Global:JidemWritingLog) -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    # Words and minutes count writing (Draft, Cold-write, manual). Edit sessions count as edit minutes only.
    $byDay = @{}
    foreach ($r in $rows) {
        if (-not $byDay.ContainsKey($r.Date)) {
            $byDay[$r.Date] = [pscustomobject]@{ Words = 0; Minutes = 0; EditMin = 0; Sessions = 0; Acct = @{} }
        }
        $day = $byDay[$r.Date]
        $mins = 0
        if ($r.Minutes -match '^\d+$') { $mins = [int]$r.Minutes }
        $day.Sessions += 1
        if ($r.Mode -eq 'Edit') {
            $day.EditMin += $mins
        } else {
            $day.Words   += [int]$r.Words
            $day.Minutes += $mins
            $who = [string]$r.Account
            if (-not $day.Acct.ContainsKey($who)) { $day.Acct[$who] = 0 }
            $day.Acct[$who] += [int]$r.Words
        }
    }

    $today = (Get-Date).Date
    $todayKey = $today.ToString('yyyy-MM-dd')

    if ($byDay.ContainsKey($todayKey) -and $byDay[$todayKey].Words -gt 0) {
        $t = $byDay[$todayKey]
        Write-Host ('Today: {0:N0} words, {1} min writing, {2} session(s)' -f $t.Words, $t.Minutes, $t.Sessions) -ForegroundColor Green
        foreach ($k in ($t.Acct.Keys | Sort-Object)) {
            Write-Host ('  {0,-8} {1,7:N0}' -f $k, $t.Acct[$k])
        }
        if ($t.EditMin -gt 0) { Write-Host ('  plus {0} min editing' -f $t.EditMin) -ForegroundColor DarkGray }
    } else {
        Write-Host 'Today: no writing logged yet.' -ForegroundColor Yellow
        if ($byDay.ContainsKey($todayKey) -and $byDay[$todayKey].EditMin -gt 0) {
            Write-Host ('  ({0} min editing logged)' -f $byDay[$todayKey].EditMin) -ForegroundColor DarkGray
        }
    }
    Write-Host ''

    Write-Host ('Last {0} days' -f $Days) -ForegroundColor Cyan
    for ($i = 0; $i -lt $Days; $i++) {
        $key = $today.AddDays(-$i).ToString('yyyy-MM-dd')
        if ($byDay.ContainsKey($key)) {
            $x = $byDay[$key]
            $who = (($x.Acct.Keys | Sort-Object) | ForEach-Object { '{0} {1:N0}' -f $_, $x.Acct[$_] }) -join ', '
            $edit = if ($x.EditMin -gt 0) { ('  edit {0} min' -f $x.EditMin) } else { '' }
            Write-Host ('  {0}  {1,7:N0} words  {2,4} min   {3}{4}' -f $key, $x.Words, $x.Minutes, $who, $edit)
        } else {
            Write-Host ('  {0}        -' -f $key) -ForegroundColor DarkGray
        }
    }
    Write-Host ''

    $cursor = $today
    if (-not ($byDay.ContainsKey($todayKey) -and $byDay[$todayKey].Words -gt 0)) { $cursor = $today.AddDays(-1) }
    $streak = 0
    while ($byDay.ContainsKey($cursor.ToString('yyyy-MM-dd')) -and $byDay[$cursor.ToString('yyyy-MM-dd')].Words -gt 0) {
        $streak++
        $cursor = $cursor.AddDays(-1)
    }
    $total = ($byDay.Values | ForEach-Object { $_.Words } | Measure-Object -Sum).Sum
    Write-Host ('Streak: {0} day(s) in a row.   All time: {1:N0} words over {2} day(s).' -f $streak, $total, $byDay.Count)
    Write-Host ''
    Write-JidemFooter
}

if (Get-Command Add-JidemHelp -ErrorAction SilentlyContinue) {
    Add-JidemHelp 'Writing and VS Code' @('syncwords') 'ANY' 'Add your Writing Timer sessions to the shared word log (words and minutes only), once each.' @('syncwords', 'syncwords -WhatIf', 'syncwords -Since 2026-09-01') 'Reads .writing-sessions.jsonl in this account''s writing folders and appends to Shared\writing-log.csv. Never copies notes or file names. Safe to run repeatedly.'
    Add-JidemHelp 'Writing and VS Code' @('wordsum') 'ANY' 'Words written today and over the last days, both accounts, plus your streak. Edit sessions show as minutes only.' @('wordsum', 'wordsum -Days 14') 'Report only.'
    Add-JidemHelp 'Writing and VS Code' @('logwords') 'ANY' 'Add one line by hand: words, minutes, optional note, for writing the timer did not see.' @('logwords 450 40', 'logwords 300 -Note "notes"', 'logwords 450 40 -WhatIf') 'Appends to Shared\writing-log.csv. Never edits or deletes. -WhatIf previews.'
    Add-JidemHelp 'Writing and VS Code' @('countwords') 'ANY' 'Count the words in a .md, .txt or .tex file.' @('countwords .\draft.md') 'Report only.'
}
