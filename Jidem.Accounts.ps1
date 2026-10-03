# ==============================================================================
# Jidem.Accounts.ps1 - v1.3.0 account awareness and cross-account handoff (both accounts)
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE AFTER Jidem.Help.ps1 and
# BEFORE Jidem.Dashboard.ps1 (the dashboard must stay the last line):
#     . "$HOME\PowerShell\Jidem.Accounts.ps1"
#
# 1. THE PROMPT. Your prompt always shows which account this window is, in colour:
#        [JIDEM] C:\Users\jidem\Documents>
#        [MAKIN] C:\Users\makin>
#    If the current folder is inside the OTHER account's profile (for example you cd into
#    C:\Users\jidem while signed in as makin), it adds a red warning. The window title shows
#    the account too. This removes the commonest mistake of the build: not knowing which
#    account a window belongs to.
#
# 2. HANDOFF. Moves a folder or file between the two accounts without remembering eight steps.
#        handoff send    <folder|file> [-Name label] [-IncludeData] [-Apply] [-Yes]
#        handoff receive <label> [-To <folder>] [-Apply] [-Yes] [-Keep] [-Force]
#                         (without -To it lands in Documents\Incoming\<label>)
#        handoff status
#        handoff clear   <label> [-Yes]
#    A handoff lives in  C:\Users\Public\Documents\Shared\_handoff-private  , a folder that only the
#    jidem and makin accounts (and SYSTEM) can open, checked every time. It is temporary: after the
#    receiver has verified the copy it is removed.
#
# What it never does:
#   - It never changes or deletes your ORIGINALS. The sender keeps the original; removing it is yours.
#   - It never overwrites a file at the destination (an existing file is skipped and reported).
#   - It never carries research-sensitive names (interview, Zoom, transcript, consent, IRB ...) or
#     personal finance/identity names, and from folders it leaves databases, rosters and grade files
#     behind unless you add -IncludeData. Naming one file explicitly bypasses the data check only.
#   - Preview first: send and receive only act with -Apply, and ask y/n unless you add -Yes.
#   - It reads names, sizes and dates only; the copy itself is a plain file copy.
# ==============================================================================

foreach ($need in 'Write-JidemBanner', 'Write-JidemFooter') {
    if (-not (Get-Command $need -ErrorAction SilentlyContinue)) {
        Write-Host 'Jidem.Accounts.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
        return
    }
}

$Global:JidemHandoffRoot     = 'C:\Users\Public\Documents\Shared\_handoff-private'
$Global:JidemHandoffAccounts = @('jidem', 'makin')
$Global:JidemHandoffSkipAcl  = $false     # tests only: skip the permission check

# Names that are never carried (same lists the sorter and the audit use, when loaded).
if (-not $Global:JidemSortKeep)     { $Global:JidemSortKeep     = 'zoom|interview|transcript|consent|\birb\b|participant|fieldnote|taguette|houston|recording|pdfgear' }
if (-not $Global:JidemAuditPrivate) { $Global:JidemAuditPrivate = '\bchase\b|\bbank|\btax(es)?\b|\birs\b|\bw-?2\b|1099|passport|\bvisa\b|\bi-?20\b|\bssn\b|social security|medical|insurance|payroll|paystub|mortgage|immigration' }
$Global:JidemHandoffDirs = '[\\/](\.git|node_modules|__pycache__|\.venv|venv|\.ipynb_checkpoints)([\\/]|$)'
$Global:JidemHandoffData = '\.(db|sqlite3?|mdb|accdb)$|roster|grade|student'

# ---------- 1. The prompt ----------

function prompt {
    try {
        $acct = [string]$Global:JidemAccount
        $loc = $executionContext.SessionState.Path.CurrentLocation.Path
        if (-not $acct) { return ('PS ' + $loc + '> ') }
        $color = switch ($acct) { 'JIDEM' { 'Cyan' } 'MAKIN' { 'Magenta' } default { 'Gray' } }
        Write-Host ('[' + $acct + '] ') -NoNewline -ForegroundColor $color
        Write-Host $loc -NoNewline
        foreach ($other in @('jidem', 'makin')) {
            if ($other -ne $acct.ToLower() -and $loc -like ('C:\Users\' + $other + '*')) {
                Write-Host ('  !! in ' + $other + "'s folder, but this window is " + $acct) -NoNewline -ForegroundColor Red
            }
        }
        try { $Host.UI.RawUI.WindowTitle = ('[' + $acct + '] ' + $loc) } catch { }
        return '> '
    } catch {
        return 'PS> '
    }
}

# ---------- 2. Handoff helpers ----------

function Format-JidemHandoffSize([double]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N1} GB' -f ($Bytes / 1GB)) }
    '{0:N1} MB' -f ($Bytes / 1MB)
}

function Test-JidemHandoffAcl([string]$Dir) {
    if ($Global:JidemHandoffSkipAcl) { return $true }
    try {
        $bad = @((Get-Acl -LiteralPath $Dir).Access | Where-Object { $_.IdentityReference.Value -match '(^|\\)(Users|Everyone|Authenticated Users|INTERACTIVE|Guests)$' })
        return ($bad.Count -eq 0)
    } catch { return $false }
}

function Initialize-JidemHandoffRoot {
    $root = $Global:JidemHandoffRoot
    $parent = Split-Path $root -Parent
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        Write-Host ('The Shared folder was not found: ' + $parent) -ForegroundColor Yellow
        return $false
    }
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        if (-not $Global:JidemHandoffSkipAcl) {
            $args2 = @($root, '/inheritance:r')
            foreach ($a in $Global:JidemHandoffAccounts) { $args2 += '/grant'; $args2 += ($a + ':(OI)(CI)F') }
            $args2 += '/grant'; $args2 += 'SYSTEM:(OI)(CI)F'
            & icacls @args2 | Out-Null
        }
    }
    if (-not (Test-JidemHandoffAcl $root)) {
        Write-Host 'The handoff folder is NOT private (other accounts could read it). Nothing was copied.' -ForegroundColor Red
        Write-Host ('Fix it, or delete the folder and run the command again: ' + $root) -ForegroundColor Yellow
        return $false
    }
    $true
}

function Get-JidemHandoffList {
    $root = $Global:JidemHandoffRoot
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return @() }
    @(Get-ChildItem -LiteralPath $root -Filter '*.manifest.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
        try { $m = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json; $m | Add-Member -NotePropertyName ManifestPath -NotePropertyValue $_.FullName -Force -PassThru } catch { }
    })
}

function Get-JidemHandoffRel([string]$Base, [string]$Full) {
    $b = $Base.TrimEnd('\', '/')
    if ($Full.Length -gt $b.Length -and $Full.StartsWith($b, [StringComparison]::OrdinalIgnoreCase)) { return $Full.Substring($b.Length).TrimStart('\', '/') }
    Split-Path $Full -Leaf
}

# ---------- handoff ----------

function handoff {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Position = 0)][string]$Action = '',
        [Parameter(Position = 1)][string]$Target = '',
        [string]$To = '',
        [string]$Name = '',
        [switch]$Apply,
        [switch]$Yes,
        [switch]$IncludeData,
        [switch]$Keep,
        [switch]$Force
    )
    $acct = [string]$Global:JidemAccount
    $root = $Global:JidemHandoffRoot

    switch ($Action.ToLower()) {

        'send' {
            if (-not $Target -or -not (Test-Path -LiteralPath $Target)) {
                Write-Host 'Usage: handoff send <folder or file> [-Name label] [-IncludeData] [-Apply]' -ForegroundColor Yellow
                Write-Host '  e.g. handoff send "$HOME\Documents\Some Folder"' -ForegroundColor DarkGray
                return
            }
            $item = Get-Item -LiteralPath $Target -Force
            $full = $item.FullName.TrimEnd('\', '/')
            $docs = Join-Path $HOME 'Documents'
            foreach ($r in @($HOME.TrimEnd('\', '/'), $docs, [IO.Path]::GetPathRoot($full).TrimEnd('\', '/'), 'C:\Users\Public\Documents\Shared', $root)) {
                if ($r -and ($full -ieq $r)) { Write-Host ('Refusing to send ' + $full + ' (a root, your Documents, or the Shared bridge itself).') -ForegroundColor Yellow; return }
            }
            if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { Write-Host 'That is inside the handoff folder already.' -ForegroundColor Yellow; return }
            $label = if ($Name) { $Name } else { $item.Name }
            $label = ($label -replace '[^A-Za-z0-9._ -]', '_').Trim()
            if (-not $label) { Write-Host 'Choose a label with -Name.' -ForegroundColor Yellow; return }
            if ($item.Name -match $Global:JidemSortKeep) {
                Write-Host ('Refusing: "' + $item.Name + '" has a research-sensitive name (interview, Zoom, consent, IRB ...). It stays where it is.') -ForegroundColor Red
                return
            }

            $skip = [ordered]@{ 'build/cache folders' = 0; 'research-sensitive names' = 0; 'finance/identity names' = 0; 'databases, rosters, grades' = 0 }
            $plan = New-Object System.Collections.ArrayList
            if ($item.PSIsContainer) {
                $base = $full
                foreach ($f in @(Get-ChildItem -LiteralPath $full -Recurse -File -Force -ErrorAction SilentlyContinue)) {
                    $rel = Get-JidemHandoffRel $base $f.FullName
                    if (('\' + $rel) -match $Global:JidemHandoffDirs) { $skip['build/cache folders']++; continue }
                    if ($rel -match $Global:JidemSortKeep) { $skip['research-sensitive names']++; continue }
                    if ($rel -match $Global:JidemAuditPrivate) { $skip['finance/identity names']++; continue }
                    if (-not $IncludeData -and $f.Name -match $Global:JidemHandoffData) { $skip['databases, rosters, grades']++; continue }
                    [void]$plan.Add([pscustomobject]@{ Full = $f.FullName; Rel = $rel; Size = $f.Length })
                }
            } else {
                $base = Split-Path $full -Parent
                if ($item.Name -match $Global:JidemAuditPrivate) { Write-Host 'Refusing: that file name looks like personal finance or identity material.' -ForegroundColor Red; return }
                [void]$plan.Add([pscustomobject]@{ Full = $full; Rel = $item.Name; Size = $item.Length })
            }
            $bytes = ($plan | Measure-Object Size -Sum).Sum; if (-not $bytes) { $bytes = 0 }

            Write-JidemBanner ('HANDOFF SEND (' + $(if ($Apply) { 'APPLY' } else { 'PREVIEW' }) + ')')
            Write-Host ('From:    ' + $acct + '   ' + $full)
            Write-Host ('Label:   ' + $label)
            Write-Host ('Carries: {0:N0} file(s), {1}' -f $plan.Count, (Format-JidemHandoffSize $bytes)) -ForegroundColor Cyan
            $anySkip = $false
            foreach ($k in $skip.Keys) { if ($skip[$k] -gt 0) { $anySkip = $true } }
            if ($anySkip) {
                Write-Host 'Leaving behind:' -ForegroundColor Yellow
                foreach ($k in $skip.Keys) { if ($skip[$k] -gt 0) { Write-Host ('  {0,-28}{1,6:N0}' -f $k, $skip[$k]) } }
                if ($skip['databases, rosters, grades'] -gt 0) { Write-Host '  (add -IncludeData to carry databases, rosters and grade files; the handoff folder is private, but think first)' -ForegroundColor DarkGray }
            }
            Write-Host 'Your original is not touched.' -ForegroundColor DarkGray
            Write-Host ''
            if ($plan.Count -eq 0) { Write-Host 'Nothing to send.' -ForegroundColor Yellow; Write-JidemFooter; return }
            if (-not $Apply) {
                Write-Host 'Preview only. Nothing was copied. Add -Apply to send it.' -ForegroundColor Green
                Write-JidemFooter; return
            }
            if (-not (Initialize-JidemHandoffRoot)) { return }
            $payload = Join-Path $root $label
            if ((Test-Path -LiteralPath $payload) -or (Test-Path -LiteralPath ($payload + '.manifest.json'))) {
                Write-Host ('A handoff called "' + $label + '" is already waiting. Receive it, or clear it with: handoff clear "' + $label + '"') -ForegroundColor Yellow
                return
            }
            if (-not $Yes -and -not $WhatIfPreference) {
                $ans = Read-Host ('Copy {0:N0} file(s) into the private handoff folder? (y/n)' -f $plan.Count)
                if ($ans -notmatch '^(y|yes)$') { Write-Host 'Cancelled. Nothing was copied.' -ForegroundColor Yellow; return }
            }
            $done = 0; $failed = 0; $doneBytes = 0.0; $entries = New-Object System.Collections.ArrayList
            foreach ($p in $plan) {
                $dst = Join-Path $payload $p.Rel
                if ($PSCmdlet.ShouldProcess($p.Full, 'copy to handoff')) {
                    try {
                        $dd = Split-Path $dst -Parent
                        if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory -Path $dd -Force -ErrorAction Stop | Out-Null }
                        Copy-Item -LiteralPath $p.Full -Destination $dst -ErrorAction Stop
                        $done++; $doneBytes += $p.Size
                        [void]$entries.Add([pscustomobject]@{ Rel = $p.Rel; Size = $p.Size })
                    } catch { $failed++ }
                }
            }
            if ($done -gt 0) {
                $m = [pscustomobject]@{ Label = $label; From = $acct; Created = (Get-Date).ToString('s'); SourcePath = $full; Files = $done; Bytes = $doneBytes; Entries = @($entries) }
                $m | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath ($payload + '.manifest.json') -Encoding UTF8
            }
            Write-Host ('Sent {0:N0} file(s), {1:N0} failed.' -f $done, $failed) -ForegroundColor $(if ($failed) { 'Yellow' } else { 'Green' })
            if ($done -gt 0) {
                $other = if ($acct -eq 'JIDEM') { 'MAKIN' } else { 'JIDEM' }
                Write-Host ('Next, in the ' + $other + ' account:') -ForegroundColor Cyan
                Write-Host ('  handoff receive "' + $label + '"') -ForegroundColor White
                Write-Host '  (preview first, then add -Apply. It lands in Documents\Incoming unless you add -To "folder".)' -ForegroundColor DarkGray
            }
            Write-JidemFooter
        }

        'receive' {
            if (-not $Target) {
                Write-Host 'Usage: handoff receive <label> [-To <folder>] [-Apply]' -ForegroundColor Yellow
                handoff status
                return
            }
            $m = Get-JidemHandoffList | Where-Object { $_.Label -ieq $Target } | Select-Object -First 1
            if (-not $m) { Write-Host ('No handoff called "' + $Target + '" is waiting. Try: handoff status') -ForegroundColor Yellow; return }
            if ($m.From -ieq $acct -and -not $Force) {
                Write-Host ('This handoff was sent from ' + $m.From + ' and you are ' + $acct + '. Switch to the other account to receive it (or add -Force if you really mean it).') -ForegroundColor Red
                return
            }
            $defaultTo = $false
            if (-not $To) { $To = Join-Path (Join-Path (Join-Path $HOME 'Documents') 'Incoming') $m.Label; $defaultTo = $true }
            $destFull = [IO.Path]::GetFullPath($To).TrimEnd('\', '/')
            $docs = Join-Path $HOME 'Documents'
            foreach ($r in @($HOME.TrimEnd('\', '/'), $docs, [IO.Path]::GetPathRoot($destFull).TrimEnd('\', '/'))) {
                if ($r -and ($destFull -ieq $r)) { Write-Host ('Choose a specific folder, not ' + $destFull + '.') -ForegroundColor Yellow; return }
            }
            if ($destFull.StartsWith('C:\Users\Public\Documents\Shared', [StringComparison]::OrdinalIgnoreCase)) { Write-Host 'The destination cannot be inside Shared.' -ForegroundColor Yellow; return }
            if (-not (Test-JidemHandoffAcl $root)) { Write-Host 'The handoff folder is NOT private. Receiving is blocked until it is fixed.' -ForegroundColor Red; return }
            $payload = Join-Path $root $m.Label
            $entries = @($m.Entries)
            $willCopy = New-Object System.Collections.ArrayList; $exists = 0; $missing = 0
            foreach ($e in $entries) {
                $src = Join-Path $payload $e.Rel
                if (-not (Test-Path -LiteralPath $src)) { $missing++; continue }
                $dst = Join-Path $destFull $e.Rel
                if (Test-Path -LiteralPath $dst) { $exists++; continue }
                [void]$willCopy.Add([pscustomobject]@{ Src = $src; Dst = $dst; Size = $e.Size })
            }
            Write-JidemBanner ('HANDOFF RECEIVE (' + $(if ($Apply) { 'APPLY' } else { 'PREVIEW' }) + ')')
            Write-Host ('Label:    ' + $m.Label + '   sent by ' + $m.From + ' on ' + $m.Created)
            Write-Host ('To:       ' + $destFull + $(if ($defaultTo) { '   (default; use -To "folder" to choose another)' } else { '' }))
            Write-Host ('Copies:   {0:N0} of {1:N0} file(s), {2}' -f $willCopy.Count, $entries.Count, (Format-JidemHandoffSize (($willCopy | Measure-Object Size -Sum).Sum))) -ForegroundColor Cyan
            if ($exists)  { Write-Host ('Skipped:  {0:N0} already exist there (never overwritten)' -f $exists) -ForegroundColor Yellow }
            if ($missing) { Write-Host ('Problem:  {0:N0} file(s) listed but missing from the handoff' -f $missing) -ForegroundColor Red }
            Write-Host ''
            if (-not $Apply) { Write-Host 'Preview only. Nothing was copied. Add -Apply to receive it.' -ForegroundColor Green; Write-JidemFooter; return }
            if ($willCopy.Count -eq 0 -and $exists -eq 0) { Write-Host 'Nothing to receive.' -ForegroundColor Yellow; Write-JidemFooter; return }
            if (-not $Yes -and -not $WhatIfPreference) {
                $ans = Read-Host ('Copy {0:N0} file(s) into this folder? (y/n)' -f $willCopy.Count)
                if ($ans -notmatch '^(y|yes)$') { Write-Host 'Cancelled. Nothing was copied.' -ForegroundColor Yellow; return }
            }
            $ok = 0; $failed = 0
            foreach ($w in $willCopy) {
                if ($PSCmdlet.ShouldProcess($w.Src, 'copy to ' + $w.Dst)) {
                    try {
                        $dd = Split-Path $w.Dst -Parent
                        if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory -Path $dd -Force -ErrorAction Stop | Out-Null }
                        Copy-Item -LiteralPath $w.Src -Destination $w.Dst -ErrorAction Stop
                        $ok++
                    } catch { $failed++ }
                }
            }
            # verify: every file copied must exist at the destination with the same size
            $bad = 0
            foreach ($w in $willCopy) {
                if (Test-Path -LiteralPath $w.Dst) { if ((Get-Item -LiteralPath $w.Dst).Length -ne $w.Size) { $bad++ } } else { $bad++ }
            }
            Write-Host ('Copied {0:N0}, failed {1:N0}, verified OK: {2}' -f $ok, $failed, $(if ($bad -eq 0 -and $failed -eq 0) { 'yes' } else { 'NO (' + $bad + ' differ)' })) -ForegroundColor $(if ($bad -eq 0 -and $failed -eq 0) { 'Green' } else { 'Red' })
            $clean = ($bad -eq 0 -and $failed -eq 0 -and $exists -eq 0 -and $missing -eq 0 -and -not $Keep -and -not $WhatIfPreference)
            if ($clean) {
                try {
                    Remove-Item -LiteralPath $payload -Recurse -Force -ErrorAction Stop
                    Remove-Item -LiteralPath $m.ManifestPath -Force -ErrorAction Stop
                    Write-Host 'Handoff verified and removed from Shared.' -ForegroundColor Green
                    if (@(Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue).Count -eq 0) { Remove-Item -LiteralPath $root -Force -ErrorAction SilentlyContinue }
                } catch { Write-Host ('Copied fine, but could not remove the handoff: ' + $_.Exception.Message) -ForegroundColor Yellow }
            } else {
                Write-Host ('The handoff was kept. When you are satisfied: handoff clear "' + $m.Label + '"') -ForegroundColor Yellow
            }
            Write-Host 'The sender account still has its original.' -ForegroundColor DarkGray
            Write-JidemFooter
        }

        'status' {
            $list = @(Get-JidemHandoffList)
            Write-Host ('Handoff folder: ' + $root) -ForegroundColor DarkGray
            if (Test-Path -LiteralPath $root -PathType Container) {
                if (Test-JidemHandoffAcl $root) { Write-Host 'Permissions: private (only jidem, makin, SYSTEM)' -ForegroundColor Green }
                else { Write-Host 'Permissions: NOT private. Do not use it until fixed.' -ForegroundColor Red }
            } else { Write-Host 'Nothing is waiting (no handoff folder).' -ForegroundColor Green }
            foreach ($m in $list) {
                $age = ((Get-Date) - [datetime]$m.Created)
                $ageText = if ($age.TotalHours -lt 24) { ('{0:N0}h' -f $age.TotalHours) } else { ('{0:N0}d' -f $age.TotalDays) }
                Write-Host ('  {0,-24} from {1,-6} {2,6:N0} file(s) {3,10}   {4} old' -f $m.Label, $m.From, $m.Files, (Format-JidemHandoffSize $m.Bytes), $ageText)
            }
            if ($list.Count -gt 0) { Write-Host 'Handoffs are meant to be short-lived. Receive or clear them.' -ForegroundColor DarkGray }
        }

        'clear' {
            if (-not $Target) { Write-Host 'Usage: handoff clear <label>' -ForegroundColor Yellow; handoff status; return }
            $m = Get-JidemHandoffList | Where-Object { $_.Label -ieq $Target } | Select-Object -First 1
            if (-not $m) { Write-Host ('No handoff called "' + $Target + '".') -ForegroundColor Yellow; return }
            if (-not $Yes -and -not $WhatIfPreference) {
                $ans = Read-Host ('Remove the temporary handoff copy "' + $m.Label + '" ({0:N0} file(s))? Originals are not touched. (y/n)' -f $m.Files)
                if ($ans -notmatch '^(y|yes)$') { Write-Host 'Cancelled.' -ForegroundColor Yellow; return }
            }
            if ($PSCmdlet.ShouldProcess($m.Label, 'remove handoff')) {
                Remove-Item -LiteralPath (Join-Path $root $m.Label) -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $m.ManifestPath -Force -ErrorAction SilentlyContinue
                Write-Host 'Removed.' -ForegroundColor Green
                if (@(Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue).Count -eq 0) { Remove-Item -LiteralPath $root -Force -ErrorAction SilentlyContinue }
            }
        }

        default {
            Write-Host 'handoff: move a folder or file between the two accounts, privately.' -ForegroundColor Cyan
            Write-Host '  handoff send <folder|file> [-Name label] [-IncludeData] [-Apply]'
            Write-Host '  handoff receive <label> [-To <folder>] [-Apply]'
            Write-Host '  handoff status'
            Write-Host '  handoff clear <label>'
            Write-Host 'Preview first; add -Apply to act. Originals are never changed.' -ForegroundColor DarkGray
        }
    }
}

if (Get-Command Add-JidemHelp -ErrorAction SilentlyContinue) {
    Add-JidemHelp 'System' @('handoff') 'ANY' 'Move a folder or file between the two accounts through a private temporary folder: send in one account, receive in the other. Preview first; verifies the copy; cleans up.' @('handoff send "$HOME\Documents\Some Folder"', 'handoff send "$HOME\Documents\Some Folder" -Apply', 'handoff receive "Some Folder"', 'handoff receive "Some Folder" -To "$HOME\Documents\UC-Merced\Teaching" -Apply', 'handoff status', 'handoff clear "Some Folder"') 'Never changes originals, never overwrites, never carries research-sensitive or finance/identity names, leaves databases/rosters/grades behind unless -IncludeData. The temporary folder is private to the jidem and makin accounts and is checked every time.'
}
