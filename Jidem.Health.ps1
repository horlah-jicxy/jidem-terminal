# ==============================================================================
# Jidem.Health.ps1 - Phase 11 safety layer
#
# Needs Jidem.Core.ps1 loaded first. Add to $PROFILE after the other Jidem lines
# (before Jidem.Dashboard.ps1, which must stay last):
#     . "$HOME\PowerShell\Jidem.Health.ps1"
#
# Commands:
#   health      check the whole setup and report OK / WARN / FAIL for each part:
#               PowerShell and execution policy, profile and its load order, every command
#               file (exists, parses, no stray characters, not blocked), expected commands,
#               git, VS Code, the Shared bridge, and when you last made a backup, and any disconnected sessions
#   validate    check every folder the commands point at (places, projects, writing roots)
#               and list the ones that do not exist, with the command to create them
#   repair      PREVIEW safe fixes (unblock files, create missing folders); -Apply does them after a backup
#   backup      copy your command files and profile into a new dated folder under
#               $HOME\PowerShell\backups (never overwrites or deletes; -WhatIf previews)
#
# Nothing here changes your profile or command files. health and validate only read.
# ==============================================================================

if (-not (Get-Command Get-JidemFiles -ErrorAction SilentlyContinue)) {
    Write-Host 'Jidem.Health.ps1 needs Jidem.Core.ps1 loaded first.' -ForegroundColor Yellow
    return
}

# Command files each account is expected to have and load.
$Global:JidemHealthFiles = @{
    JIDEM = @('JidemCommands.ps1', 'Jidem.Core.ps1', 'Jidem.Navigation.ps1', 'Jidem.Projects.ps1', 'Jidem.Git.ps1',
              'Jidem.Academia.ps1', 'Jidem.Writing.ps1', 'Jidem.Search.ps1', 'Jidem.Maintenance.ps1', 'Jidem.Health.ps1', 'Jidem.Dashboard.ps1')
    MAKIN = @('JidemCommands.ps1', 'Jidem.Core.ps1', 'Jidem.Navigation.ps1', 'Jidem.Git.ps1', 'Jidem.Search.ps1',
              'Jidem.Maintenance.ps1', 'Jidem.Writing.ps1', 'Jidem.Teaching.ps1', 'Jidem.Health.ps1', 'Jidem.Dashboard.ps1')
}

# Commands each account should have after loading.
$Global:JidemHealthCommands = @{
    ALL   = @('status', 'jwhere', 'workspace', 'recent', 'today', 'tree', 'size', 'places', 'gitstatus', 'gitchanges', 'gitlog',
              'gitbranch', 'findfile', 'findtext', 'search', 'cleanup', 'duplicates', 'empty', 'dashboard', 'edit', 'openvscode',
              'health', 'validate', 'backup', 'repair')
    JIDEM = @('projects', 'openproject', 'projectinfo', 'projectnew', 'dissertation', 'research', 'writing', 'papers', 'jwrite', 'focus', 'inbox')
    MAKIN = @('teach', 'course', 'coursenew', 'ta', 'courses')
}

# Files that must be loaded before a given file.
$Global:JidemHealthNeeds = @{
    'Jidem.Navigation.ps1'  = @('Jidem.Core.ps1')
    'Jidem.Projects.ps1'    = @('Jidem.Core.ps1', 'Jidem.Navigation.ps1')
    'Jidem.Git.ps1'         = @('Jidem.Core.ps1')
    'Jidem.Academia.ps1'    = @('Jidem.Core.ps1', 'Jidem.Navigation.ps1')
    'Jidem.Writing.ps1'     = @('Jidem.Core.ps1')
    'Jidem.Search.ps1'      = @('Jidem.Core.ps1')
    'Jidem.Maintenance.ps1' = @('Jidem.Core.ps1', 'Jidem.Navigation.ps1', 'Jidem.Search.ps1')
    'Jidem.Teaching.ps1'    = @('Jidem.Core.ps1', 'Jidem.Navigation.ps1')
    'Jidem.Health.ps1'      = @('Jidem.Core.ps1')
    'Jidem.Dashboard.ps1'   = @('Jidem.Core.ps1', 'Jidem.Navigation.ps1')
}

# ---------- Helpers ----------

function Get-JidemLoadPosition($Loaded, [string]$Name) {
    for ($i = 0; $i -lt $Loaded.Count; $i++) { if ($Loaded[$i] -ieq $Name) { return $i } }
    -1
}

function Test-JidemFileHealth([string]$Path) {
    # Returns @{ Status; Detail } for one command file.
    if (-not (Test-Path -LiteralPath $Path)) { return @{ Status = 'FAIL'; Detail = 'file not found' } }
    $size = (Get-Item -LiteralPath $Path).Length
    if ($size -eq 0) { return @{ Status = 'FAIL'; Detail = 'file is empty (paste did not save?)' } }

    $problems = @(); $worst = 'OK'
    $tokens = $null; $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errs)
    if ($errs -and $errs.Count) {
        $problems += "syntax error at line $($errs[0].Extent.StartLineNumber): $($errs[0].Message)"
        $worst = 'FAIL'
    }
    if (Select-String -LiteralPath $Path -Pattern '^\s*\.\s+"\$HOME\\PowerShell\\Jidem' -Quiet) {
        $problems += 'contains a profile load line (belongs only in the profile)'
        $worst = 'FAIL'
    }
    $bad = $false
    foreach ($b in [System.IO.File]::ReadAllBytes($Path)) { if ($b -gt 127) { $bad = $true; break } }
    if ($bad) { $problems += 'non-ASCII characters (can break Windows PowerShell 5.1)'; if ($worst -ne 'FAIL') { $worst = 'WARN' } }
    if (Get-Item -LiteralPath $Path -Stream Zone.Identifier -ErrorAction SilentlyContinue) {
        $problems += 'blocked: run Unblock-File'
        if ($worst -ne 'FAIL') { $worst = 'WARN' }
    }
    if ($problems.Count) { return @{ Status = $worst; Detail = ($problems -join '; ') } }
    @{ Status = 'OK'; Detail = ('{0:N0} bytes' -f $size) }
}

function Write-HealthRow($Row) {
    $color = switch ($Row.Status) { 'OK' { 'Green' } 'WARN' { 'Yellow' } 'FAIL' { 'Red' } default { 'DarkGray' } }
    Write-Host ('  {0,-5}' -f $Row.Status) -NoNewline -ForegroundColor $color
    Write-Host ('{0,-24}' -f $Row.Area) -NoNewline
    Write-Host $Row.Detail -ForegroundColor DarkGray
}

# ---------- Commands ----------

function health {
    $acct = $Global:JidemAccount
    $dir = Join-Path $HOME 'PowerShell'
    $rows = New-Object System.Collections.ArrayList
    function Add-HealthRow([string]$Status, [string]$Area, [string]$Detail) {
        [void]$rows.Add([pscustomobject]@{ Status = $Status; Area = $Area; Detail = $Detail })
    }

    # --- PowerShell, policy, account ---
    Add-HealthRow 'OK' 'PowerShell' "$($PSVersionTable.PSVersion)"
    $policy = [string](Get-ExecutionPolicy)
    if ($policy -eq 'Restricted') { Add-HealthRow 'FAIL' 'Execution policy' 'Restricted: scripts cannot run' }
    elseif ($policy -eq 'AllSigned') { Add-HealthRow 'WARN' 'Execution policy' 'AllSigned: unsigned command files will not load' }
    else { Add-HealthRow 'OK' 'Execution policy' $policy }
    if ($Global:JidemHealthFiles.ContainsKey($acct)) { Add-HealthRow 'OK' 'Account' "$acct   ($HOME)" }
    else { Add-HealthRow 'WARN' 'Account' "$acct is not JIDEM or MAKIN; only generic checks apply" }

    # --- Profile and load order ---
    $ptext = ''
    if (Test-Path -LiteralPath $PROFILE) {
        Add-HealthRow 'OK' 'Profile' $PROFILE
        if ($PROFILE -match 'OneDrive') { Add-HealthRow 'INFO' 'Profile location' 'inside OneDrive (synced to the cloud; that is fine)' }
        $ptext = Get-Content -LiteralPath $PROFILE -Raw
    }
    else { Add-HealthRow 'FAIL' 'Profile' "not found: $PROFILE" }
    $loaded = @()
    foreach ($m in [regex]::Matches($ptext, '(?m)^\s*\.\s+"\$HOME\\PowerShell\\([^"\r\n]+\.ps1)"')) { $loaded += $m.Groups[1].Value }
    Add-HealthRow 'INFO' 'Files loaded by profile' ("{0}" -f $loaded.Count)

    $expected = @()
    if ($Global:JidemHealthFiles.ContainsKey($acct)) { $expected = @($Global:JidemHealthFiles[$acct]) }

    $orderProblems = @()
    foreach ($name in $loaded) {
        if ($Global:JidemHealthNeeds.ContainsKey($name)) {
            foreach ($need in $Global:JidemHealthNeeds[$name]) {
                $np = Get-JidemLoadPosition $loaded $need
                if ($np -lt 0) { $orderProblems += "$name needs $need, which the profile does not load" }
                elseif ($np -gt (Get-JidemLoadPosition $loaded $name)) { $orderProblems += "$need must load before $name" }
            }
        }
    }
    $dp = Get-JidemLoadPosition $loaded 'Jidem.Dashboard.ps1'
    if ($dp -ge 0 -and $dp -ne ($loaded.Count - 1)) { $orderProblems += 'Jidem.Dashboard.ps1 should be the last line' }
    if ($orderProblems.Count) { foreach ($p in $orderProblems) { Add-HealthRow 'FAIL' 'Profile load order' $p } }
    elseif ($loaded.Count) { Add-HealthRow 'OK' 'Profile load order' 'dependencies load before the files that need them' }
    foreach ($f in $expected) {
        if ((Get-JidemLoadPosition $loaded $f) -lt 0) { Add-HealthRow 'WARN' "Not in profile" "$f is expected for $acct but the profile does not load it" }
    }

    # --- Each command file ---
    foreach ($f in $expected) {
        $r = Test-JidemFileHealth (Join-Path $dir $f)
        Add-HealthRow $r.Status $f $r.Detail
    }

    # --- Commands actually loaded in this session ---
    $wantCmds = @($Global:JidemHealthCommands.ALL)
    if ($Global:JidemHealthCommands.ContainsKey($acct)) { $wantCmds += @($Global:JidemHealthCommands[$acct]) }
    $missing = @($wantCmds | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
    if ($missing.Count) { Add-HealthRow 'FAIL' 'Commands' ("missing in this session: " + ($missing -join ', ') + "  (reload with . `$PROFILE)") }
    else { Add-HealthRow 'OK' 'Commands' ("{0} expected commands are loaded" -f $wantCmds.Count) }

    # --- Tools and folders ---
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) { Add-HealthRow 'OK' 'Git' ((git --version 2>$null) -join ' ') } else { Add-HealthRow 'WARN' 'Git' 'not found on PATH' }
    if (Get-Command code -ErrorAction SilentlyContinue) { Add-HealthRow 'OK' 'VS Code' "'code' is on PATH" } else { Add-HealthRow 'WARN' 'VS Code' "'code' is not on PATH" }
    $rootNames = @($Global:JidemRoots.Keys)
    if ($rootNames.Count) { Add-HealthRow 'OK' 'Workspace roots' ($rootNames -join ', ') } else { Add-HealthRow 'FAIL' 'Workspace roots' 'none of the workspace folders exist' }
    $bridge = 'C:\Users\Public\Documents\Shared'
    if (Test-Path -LiteralPath $bridge) { Add-HealthRow 'OK' 'Shared bridge' $bridge } else { Add-HealthRow 'WARN' 'Shared bridge' "not found: $bridge" }

    # --- Backups ---
    $bdir = Join-Path $dir 'backups'
    $last = $null
    if (Test-Path -LiteralPath $bdir) { $last = Get-ChildItem -LiteralPath $bdir -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
    if (-not $last) { Add-HealthRow 'WARN' 'Backups' 'none yet. Run: backup' }
    elseif (((Get-Date) - $last.LastWriteTime).TotalDays -gt 30) { Add-HealthRow 'WARN' 'Backups' ("last backup {0}. Run: backup" -f (Format-Age $last.LastWriteTime)) }
    else { Add-HealthRow 'OK' 'Backups' ("last backup {0}" -f (Format-Age $last.LastWriteTime)) }

    # --- Disconnected sessions (they keep their apps running and hold memory) ---
    $sessLine = $null
    try {
        $q = @(quser 2>$null)
        $disc = @()
        foreach ($ln in $q) {
            if ($ln -match '^\s*>?(\S+)\s+(?:(\S+)\s+)?(\d+)\s+Disc\b') { $disc += [pscustomobject]@{ User = $Matches[1]; Id = [int]$Matches[3] } }
        }
        if ($q.Count -eq 0) {
            Add-HealthRow 'INFO' 'Sessions' 'could not read the session list (quser)'
        } elseif ($disc.Count -eq 0) {
            Add-HealthRow 'OK' 'Sessions' 'no disconnected sessions'
        } else {
            foreach ($d in $disc) {
                $mb = 0
                try { $mb = [int]((Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $d.Id } | Measure-Object WorkingSet -Sum).Sum / 1MB) } catch { }
                $use = if ($mb -gt 0) { (' using about {0:N1} GB' -f ($mb / 1024)) } else { '' }
                Add-HealthRow 'WARN' 'Sessions' ("{0} has a disconnected session (ID {1}){2}. Save its work, then run: logoff {1}" -f $d.User, $d.Id, $use)
            }
        }
    } catch {
        Add-HealthRow 'INFO' 'Sessions' 'could not read the session list'
    }

    # --- Print ---
    Write-JidemBanner "$acct SYSTEM HEALTH"
    foreach ($r in $rows) { Write-HealthRow $r }
    $fail = @($rows | Where-Object { $_.Status -eq 'FAIL' }).Count
    $warn = @($rows | Where-Object { $_.Status -eq 'WARN' }).Count
    Write-Host ''
    Write-Host ("  Warnings: {0}    Failures: {1}" -f $warn, $fail) -ForegroundColor $(if ($fail) { 'Red' } elseif ($warn) { 'Yellow' } else { 'Green' })
    if (-not $fail -and -not $warn) { Write-Host '  Everything looks healthy.' -ForegroundColor Green }
    Write-Host '  Read-only: nothing was changed.' -ForegroundColor DarkGray
    Write-Host ''
    Write-JidemFooter
}

function validate {
    $acct = $Global:JidemAccount
    $problems = @(); $checked = 0; $other = 0

    foreach ($p in $Global:JidemPlaces) {
        if ($p.Account -ne 'ANY' -and $p.Account -ne $acct) { $other++; continue }
        $checked++
        $found = $p.Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
        if (-not $found) { $problems += [pscustomobject]@{ What = "command '$($p.Name)'"; Path = $p.Paths[0] } }
    }
    if ($acct -eq 'JIDEM') {
        if ($Global:JidemPinnedProjects) {
            foreach ($p in $Global:JidemPinnedProjects) {
                $checked++
                if (-not (Test-Path -LiteralPath $p.Path -PathType Container)) { $problems += [pscustomobject]@{ What = "project '$($p.Name)'"; Path = $p.Path } }
            }
        }
        if ($Global:JidemWritingRoots) {
            foreach ($r in $Global:JidemWritingRoots) {
                $checked++
                if (-not (Test-Path -LiteralPath $r -PathType Container)) { $problems += [pscustomobject]@{ What = 'writing root'; Path = $r } }
            }
        }
    }
    if ($acct -eq 'MAKIN' -and (Get-Command Get-JidemCourseFolders -ErrorAction SilentlyContinue)) {
        $checked++
        if (-not (Get-Command Resolve-JidemTeachPath -ErrorAction SilentlyContinue) -or -not (Resolve-JidemTeachPath 'ta')) {
            $problems += [pscustomobject]@{ What = 'TA folder (course folders live here)'; Path = "$($Global:JidemDocs)\UC-Merced\TA" }
        }
    }

    Write-JidemBanner "$acct PATH CHECK"
    Write-Host ("  Checked {0} path(s) for {1}; skipped {2} that belong to the other account." -f $checked, $acct, $other) -ForegroundColor DarkGray
    Write-Host ''
    if (-not $problems.Count) { Write-Host '  All paths exist.' -ForegroundColor Green }
    foreach ($p in $problems) {
        Write-Host ('  MISSING  {0}' -f $p.What) -ForegroundColor Yellow
        Write-Host ("           {0}" -f $p.Path) -ForegroundColor DarkGray
        Write-Host ("           create: New-Item -ItemType Directory -Path '{0}'" -f $p.Path) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host '  Read-only: nothing was created.' -ForegroundColor DarkGray
    Write-Host ''
    Write-JidemFooter
}

function backup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    $dir = Join-Path $HOME 'PowerShell'
    $root = Join-Path $dir 'backups'
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dest = Join-Path $root $stamp
    $n = 2
    while (Test-Path -LiteralPath $dest) { $dest = Join-Path $root "$stamp-$n"; $n++ }

    $files = @(Get-ChildItem -LiteralPath $dir -Filter 'Jidem*.ps1' -File -ErrorAction SilentlyContinue)
    $hasProfile = Test-Path -LiteralPath $PROFILE
    if (-not $files.Count -and -not $hasProfile) { Write-Host 'Nothing to back up.' -ForegroundColor Yellow; return }

    if ($PSCmdlet.ShouldProcess($dest, "Copy $($files.Count) command file(s) and the profile")) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        foreach ($f in $files) { Copy-Item -LiteralPath $f.FullName -Destination $dest }
        if ($hasProfile) { Copy-Item -LiteralPath $PROFILE -Destination (Join-Path $dest 'profile.ps1') }
        Write-Host "Backed up to: $dest" -ForegroundColor Green
        Write-Host ("  {0} command file(s){1}" -f $files.Count, $(if ($hasProfile) { ' + profile.ps1' } else { '' })) -ForegroundColor DarkGray
        $all = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue).Count
        Write-Host ("  {0} backup(s) kept in {1}. Old ones are never deleted automatically." -f $all, $root) -ForegroundColor DarkGray
    }
}

# ---------- repair (safe fixes only) ----------
#   repair                          PREVIEW: list what could be fixed and what needs you. Changes nothing.
#   repair -Apply                   take a backup, then unblock blocked command files
#   repair -Apply -CreateFolders    also create the missing folders that 'validate' lists
# It never edits your profile or command files, never deletes, and never overwrites anything.
# Problems it cannot fix safely are listed under NEEDS YOU, with the exact line or step to take.

function Get-JidemMissingFolders {
    $acct = $Global:JidemAccount
    $list = @()
    foreach ($p in $Global:JidemPlaces) {
        if ($p.Account -ne 'ANY' -and $p.Account -ne $acct) { continue }
        $found = $p.Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
        if (-not $found) { $list += [pscustomobject]@{ What = "command '$($p.Name)'"; Path = $p.Paths[0] } }
    }
    if ($acct -eq 'JIDEM' -and $Global:JidemPinnedProjects) {
        foreach ($p in $Global:JidemPinnedProjects) {
            if (-not (Test-Path -LiteralPath $p.Path -PathType Container)) { $list += [pscustomobject]@{ What = "project '$($p.Name)'"; Path = $p.Path } }
        }
    }
    $seen = @{}
    foreach ($item in $list) {
        $key = $item.Path.ToLower()
        if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $item }
    }
}

function repair {
    param([switch]$Apply, [switch]$CreateFolders)
    $acct = $Global:JidemAccount
    $dir = Join-Path $HOME 'PowerShell'
    $fixes = New-Object System.Collections.ArrayList
    $needsYou = New-Object System.Collections.ArrayList
    $expected = @()
    if ($Global:JidemHealthFiles.ContainsKey($acct)) { $expected = @($Global:JidemHealthFiles[$acct]) }

    # 1. Command files: blocked ones can be unblocked; anything else needs you.
    foreach ($f in $expected) {
        $path = Join-Path $dir $f
        if (-not (Test-Path -LiteralPath $path)) {
            [void]$needsYou.Add("$f is missing from $dir. Copy it from the other account through the Shared folder, or paste it again.")
            continue
        }
        if (Get-Item -LiteralPath $path -Stream Zone.Identifier -ErrorAction SilentlyContinue) {
            [void]$fixes.Add(@{ Kind = 'unblock'; Target = $path; Label = $f; Gated = $false })
        }
        $r = Test-JidemFileHealth $path
        $rest = @($r.Detail -split '; ' | Where-Object { $_ -notmatch '^blocked' })
        if ($r.Status -ne 'OK' -and $rest.Count -and $rest[0]) { [void]$needsYou.Add("${f}: " + ($rest -join '; ')) }
    }

    # 2. Profile: report only, never edited.
    $ptext = ''
    if (Test-Path -LiteralPath $PROFILE) { $ptext = Get-Content -LiteralPath $PROFILE -Raw }
    else { [void]$needsYou.Add("Profile not found: $PROFILE") }
    $loaded = @()
    foreach ($m in [regex]::Matches($ptext, '(?m)^\s*\.\s+"\$HOME\\PowerShell\\([^"\r\n]+\.ps1)"')) { $loaded += $m.Groups[1].Value }
    foreach ($f in $expected) {
        if ((Get-JidemLoadPosition $loaded $f) -lt 0) {
            [void]$needsYou.Add('Your profile does not load ' + $f + '. Add this line to it: . "$HOME\PowerShell\' + $f + '"')
        }
    }
    foreach ($name in $loaded) {
        if ($Global:JidemHealthNeeds.ContainsKey($name)) {
            foreach ($need in $Global:JidemHealthNeeds[$name]) {
                $np = Get-JidemLoadPosition $loaded $need
                if ($np -ge 0 -and $np -gt (Get-JidemLoadPosition $loaded $name)) {
                    [void]$needsYou.Add("Profile order: move the line for $need above the line for $name.")
                }
            }
        }
    }
    $dp = Get-JidemLoadPosition $loaded 'Jidem.Dashboard.ps1'
    if ($dp -ge 0 -and $dp -ne ($loaded.Count - 1)) { [void]$needsYou.Add('Profile order: Jidem.Dashboard.ps1 should be the last line.') }

    # 3. Missing folders: created only with -CreateFolders, and only inside Documents or Public.
    foreach ($m in @(Get-JidemMissingFolders)) {
        $inside = $m.Path.StartsWith($Global:JidemDocs, [StringComparison]::OrdinalIgnoreCase) -or $m.Path.StartsWith('C:\Users\Public\', [StringComparison]::OrdinalIgnoreCase)
        if ($inside) { [void]$fixes.Add(@{ Kind = 'folder'; Target = $m.Path; Label = $m.What; Gated = $true }) }
        else { [void]$needsYou.Add("Folder for $($m.What) is outside Documents/Public; create it yourself: $($m.Path)") }
    }

    # --- Show the plan ---
    Write-JidemBanner "$acct REPAIR"
    Write-Host ($(if ($Apply) { 'APPLYING SAFE FIXES' } else { 'PREVIEW (nothing is changed; add -Apply to fix)' })) -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'CAN FIX AUTOMATICALLY' -ForegroundColor Yellow
    if (-not $fixes.Count) { Write-Host '  Nothing.' -ForegroundColor Green }
    foreach ($fx in $fixes) {
        $note = ''
        if ($fx.Gated -and -not $CreateFolders) { $note = '   (needs -CreateFolders)' }
        $verb = if ($fx.Kind -eq 'unblock') { 'unblock' } else { 'create ' }
        Write-Host ('  {0}  {1}{2}' -f $verb, $(if ($fx.Kind -eq 'unblock') { $fx.Label } else { $fx.Target }), $note)
    }
    Write-Host ''
    Write-Host 'NEEDS YOU (repair will not touch these)' -ForegroundColor Yellow
    if (-not $needsYou.Count) { Write-Host '  Nothing.' -ForegroundColor Green }
    foreach ($n in $needsYou) { Write-Host "  - $n" }
    Write-Host ''

    # --- Apply ---
    $doable = @($fixes | Where-Object { (-not $_.Gated) -or $CreateFolders })
    if ($Apply) {
        if (-not $doable.Count) { Write-Host 'No automatic fixes to apply.' -ForegroundColor Green }
        else {
            Write-Host 'Backing up first ...' -ForegroundColor DarkGray
            backup
            foreach ($fx in $doable) {
                try {
                    if ($fx.Kind -eq 'unblock') { Unblock-File -LiteralPath $fx.Target -ErrorAction Stop; Write-Host "  unblocked  $($fx.Label)" -ForegroundColor Green }
                    else { New-Item -ItemType Directory -Path $fx.Target -Force -ErrorAction Stop | Out-Null; Write-Host "  created    $($fx.Target)" -ForegroundColor Green }
                }
                catch { Write-Host "  FAILED     $($fx.Label): $($_.Exception.Message)" -ForegroundColor Red }
            }
            Write-Host ''
            Write-Host 'Now run:  . $PROFILE   and then   health' -ForegroundColor DarkGray
        }
    }
    elseif ($doable.Count) {
        $hint = 'To apply: repair -Apply'
        if (@($fixes | Where-Object { $_.Gated }).Count) { $hint += '   (add -CreateFolders to also create the folders)' }
        Write-Host $hint -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-JidemFooter
}
