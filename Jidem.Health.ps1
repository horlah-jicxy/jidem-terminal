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
#               git, VS Code, the Shared bridge, and when you last made a backup
#   validate    check every folder the commands point at (places, projects, writing roots)
#               and list the ones that do not exist, with the command to create them
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
              'health', 'validate', 'backup')
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
    if ($Global:JidemFiles -or $Global:JidemHealthFiles.ContainsKey($acct)) { Add-HealthRow 'OK' 'Account' "$acct   ($HOME)" }
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
