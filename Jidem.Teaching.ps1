# ==============================================================================
# Jidem.Teaching.ps1 - Phase 6 teaching workflow (MAKIN account)
#
# Needs Jidem.Core.ps1 and Jidem.Navigation.ps1 loaded first. Add to MAKIN's $PROFILE
# after them (do NOT load this in the JIDEM account):
#     . "$HOME\PowerShell\Jidem.Teaching.ps1"
#
# Commands:
#   teach                 go to UC-Merced and show an overview: folders, current course,
#                         recent work, and what is waiting in the Shared bridge
#   courses  ta  teaching  university  administration  admin  currentwork
#                         go there and show a summary (contents most recently active
#                         first, files modified in the last 14 days)
#   <command> -Code       also open the folder in VS Code
#   <command> -Quiet      just go there, no summary
#
# These REPLACE the plain jump commands of the same names. Read-only: nothing is
# created, changed, or deleted.
# ==============================================================================

if (-not (Get-Command Invoke-JidemGo -ErrorAction SilentlyContinue)) {
    Write-Host 'Jidem.Teaching.ps1 needs Jidem.Core.ps1 and Jidem.Navigation.ps1 loaded first.' -ForegroundColor Yellow
    return
}

# Shown at the top of 'teach'. Edit this line when the course changes.
$Global:JidemCurrentCourse = 'ANTH 005'

$Global:JidemSharedBridge = 'C:\Users\Public\Documents\Shared'

# command name -> heading shown in the summary
$Global:JidemTeachAreas = [ordered]@{
    courses        = 'COURSES'
    ta             = 'TA WORK'
    teaching       = 'TEACHING'
    university     = 'UNIVERSITY'
    administration = 'ADMINISTRATION'
    admin          = 'ADMINISTRATION'
    currentwork    = 'CURRENT WORK'
}

# ---------- Helpers ----------

function Resolve-JidemTeachPath([string]$Name) {
    $place = $Global:JidemPlaces | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $place) { return $null }
    $place.Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
}

function Show-JidemTeachArea([string]$Title, [string]$Path, [switch]$Overview) {
    Write-JidemBanner $Title

    if ($Overview) {
        Write-Host 'CURRENT COURSE' -ForegroundColor Yellow
        Write-Host "  $($Global:JidemCurrentCourse)"
        Write-Host ''
    }

    Write-Host 'LOCATION' -ForegroundColor Yellow
    Write-Host "  $((Get-JidemLocation $Path).Display)"
    Write-Host ''

    # --- Contents: subfolders, most recently active first (dot-folders hidden) ---
    $folders = @(Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue |
                 Where-Object { $Global:JidemIgnore -notcontains $_.Name -and -not $_.Name.StartsWith('.') })
    $loose = @(Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction SilentlyContinue)

    $rows = foreach ($f in $folders) {
        $files = @(Get-JidemFiles $f.FullName)
        $latest = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        [pscustomobject]@{
            Name   = $f.Name
            Files  = $files.Count
            Latest = if ($latest) { $latest.LastWriteTime } else { [datetime]::MinValue }
        }
    }
    $rows = @($rows | Sort-Object Latest -Descending)

    Write-Host 'CONTENTS' -ForegroundColor Yellow
    if (-not $rows.Count -and -not $loose.Count) { Write-Host '  (empty)' -ForegroundColor DarkGray }
    $shown = 0
    foreach ($r in $rows) {
        if ($shown -ge 12) { break }
        $age = if ($r.Latest -eq [datetime]::MinValue) { 'empty' } else { Format-Age $r.Latest }
        Write-Host ('  {0,-30}' -f $r.Name) -NoNewline -ForegroundColor Yellow
        Write-Host ('{0,5} files   {1}' -f $r.Files, $age) -ForegroundColor DarkGray
        $shown++
    }
    if ($rows.Count -gt 12) { Write-Host "  ... and $($rows.Count - 12) more folder(s)" -ForegroundColor DarkGray }
    if ($loose.Count) { Write-Host "  + $($loose.Count) file(s) directly in this folder" -ForegroundColor DarkGray }
    Write-Host ''

    # --- Recently modified files ---
    Write-Host 'MODIFIED IN THE LAST 14 DAYS' -ForegroundColor Yellow
    $recent = @(Get-JidemRecent -Since (Get-Date).AddDays(-14) -Top 5 -Path @($Path))
    if ($recent.Count) {
        foreach ($f in $recent) {
            $rel = $f.FullName.Substring($Path.Length).TrimStart('\', '/')
            Write-Host ('  {0,-9} {1}' -f (Format-Age $f.LastWriteTime), $rel)
        }
    }
    else { Write-Host '  Nothing.' -ForegroundColor DarkGray }
    Write-Host ''

    # --- Overview only: the bridge to the JIDEM account ---
    if ($Overview) {
        Write-Host 'SHARED BRIDGE' -ForegroundColor Yellow
        $bridge = $Global:JidemSharedBridge
        if (Test-Path -LiteralPath $bridge) {
            $items = @(Get-JidemFiles $bridge | Sort-Object LastWriteTime -Descending)
            if ($items.Count) {
                Write-Host "  $($items.Count) file(s) in Shared. Newest:"
                foreach ($f in ($items | Select-Object -First 3)) {
                    Write-Host ('  {0,-9} {1}' -f (Format-Age $f.LastWriteTime), $f.FullName.Substring($bridge.Length).TrimStart('\', '/'))
                }
            }
            else { Write-Host '  Empty.' -ForegroundColor DarkGray }
        }
        else { Write-Host "  Not found: $bridge" -ForegroundColor DarkGray }
        Write-Host ''
    }
    Write-JidemFooter
}

function Enter-JidemTeachArea {
    param([string]$Name, [string]$Title, [switch]$Overview, [switch]$Code, [switch]$Quiet)
    if ($Global:JidemAccount -ne 'MAKIN') {
        Write-Host "'$Name' is assigned to the MAKIN account." -ForegroundColor Yellow
        return
    }
    $path = Resolve-JidemTeachPath $Name
    if (-not $path) { Invoke-JidemGo $Name; return }   # prints the "not found" message
    Set-Location -LiteralPath $path
    if (-not $Quiet) { Show-JidemTeachArea $Title $path -Overview:$Overview }
    if ($Code) {
        if (Get-Command code -ErrorAction SilentlyContinue) { code . }
        else { Write-Host "VS Code ('code') is not on PATH." -ForegroundColor Yellow }
    }
}

# ---------- Commands ----------

function teach {
    param([switch]$Code, [switch]$Quiet)
    Enter-JidemTeachArea 'school' 'TEACHING' -Overview -Code:$Code -Quiet:$Quiet
}

foreach ($area in $Global:JidemTeachAreas.Keys) {
    $title = $Global:JidemTeachAreas[$area]
    $body = "param([switch]`$Code, [switch]`$Quiet) Enter-JidemTeachArea '$area' '$title' -Code:`$Code -Quiet:`$Quiet"
    Set-Item -Path "Function:\global:$area" -Value ([scriptblock]::Create($body))
}

Remove-Variable area, title, body -ErrorAction SilentlyContinue
