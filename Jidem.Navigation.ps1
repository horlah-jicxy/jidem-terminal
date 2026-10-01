# ==============================================================================
# Jidem.Navigation.ps1 - Phase 2 navigation (account-aware, table-driven)
#
# Loads AFTER Jidem.Core.ps1. Add to $PROFILE:
#     . "$HOME\PowerShell\JidemCommands.ps1"
#     . "$HOME\PowerShell\Jidem.Core.ps1"
#     . "$HOME\PowerShell\Jidem.Navigation.ps1"
#
# Every jump command comes from one table below. To add a command, add one line.
# A command with several candidate folders jumps to the first one that exists.
# Commands never create folders; if one is missing they tell you the command to run.
#
# Extra command: places  (lists every command and whether its folder exists)
# Note: 'data' is a reserved word in PowerShell, so that command is named 'datasets'.
# ==============================================================================

if (-not $Global:JidemDocs)   { $Global:JidemDocs = Join-Path $HOME 'Documents' }
if (-not $Global:JidemAccount) { $Global:JidemAccount = (Split-Path $HOME -Leaf).ToUpper() }

$d = $Global:JidemDocs
$sharedBridge = 'C:\Users\Public\Documents\Shared'

function New-JidemPlace([string]$Name, [string]$Account, [string[]]$Paths, [string]$Note) {
    [pscustomobject]@{ Name = $Name; Account = $Account; Paths = $Paths; Note = $Note }
}

# Academic folders may live under Academia or ACADEMIC; both are tried.
function Get-JidemAcademic([string]$Sub) {
    $docs = $Global:JidemDocs
    if ($Sub) { @("$docs\Academia\$Sub", "$docs\ACADEMIC\$Sub") } else { @("$docs\Academia", "$docs\ACADEMIC") }
}

# Account: JIDEM, MAKIN, or ANY (works in both).
$Global:JidemPlaces = @(
    # --- Everywhere ---
    New-JidemPlace 'jidem'          'ANY'   @("$d")                                  'Documents'
    New-JidemPlace 'shared'         'ANY'   @($sharedBridge)                         'Bridge between accounts'
    New-JidemPlace 'archive'        'ANY'   @("$d\Archive")                          'Archive'
    New-JidemPlace 'reference'      'ANY'   @("$d\Reference")                        'Reference material'

    # --- JIDEM: academia ---
    New-JidemPlace 'academia'       'JIDEM' (Get-JidemAcademic '')                   'Academic workspace'
    New-JidemPlace 'inbox'          'JIDEM' (Get-JidemAcademic '00_INBOX')           'Unsorted incoming items'
    New-JidemPlace 'research'       'JIDEM' (Get-JidemAcademic 'Research')           'Research projects'
    New-JidemPlace 'dissertation'   'JIDEM' (Get-JidemAcademic 'Dissertation')       'Dissertation'
    New-JidemPlace 'writing'        'JIDEM' (Get-JidemAcademic 'Writing')            'Manuscripts and drafts'
    New-JidemPlace 'fieldwork'      'JIDEM' (Get-JidemAcademic 'Fieldwork')          'Fieldwork'
    New-JidemPlace 'publications'   'JIDEM' (Get-JidemAcademic 'Publications')       'Published and submitted work'
    New-JidemPlace 'analysis'       'JIDEM' (Get-JidemAcademic 'Analysis')           'Analysis'
    New-JidemPlace 'datasets'       'JIDEM' (Get-JidemAcademic 'Data')               'Data'
    New-JidemPlace 'archives'       'JIDEM' (Get-JidemAcademic 'Archives')           'Academic archive'

    # --- JIDEM: development ---
    New-JidemPlace 'development'    'JIDEM' @("$d\Development")                      'Development root'
    New-JidemPlace 'personaleditor' 'JIDEM' @("$d\Development\Personal-Editor")      'Personal Editor'
    New-JidemPlace 'pythonwork'     'JIDEM' @("$d\Development\Python")               'Python'
    New-JidemPlace 'rwork'          'JIDEM' @("$d\Development\R")                    'R'
    New-JidemPlace 'experiments'    'JIDEM' @("$d\Development\Experiments")          'Experiments'
    New-JidemPlace 'teachingtoolkit' 'JIDEM' @("$d\GitHub\teaching-toolkit-v43", "$d\Development\Teaching-Toolkit") 'Teaching Toolkit'
    New-JidemPlace 'github'         'JIDEM' @("$d\GitHub")                           'GitHub repositories'

    # --- MAKIN: UC Merced ---
    New-JidemPlace 'school'         'MAKIN' @("$d\UC-Merced")                        'UC Merced root'
    New-JidemPlace 'courses'        'MAKIN' @("$d\UC-Merced\Courses")                'Courses'
    New-JidemPlace 'ta'             'MAKIN' @("$d\UC-Merced\TA")                     'TA work'
    New-JidemPlace 'teaching'       'MAKIN' @("$d\UC-Merced\Teaching")               'Teaching'
    New-JidemPlace 'university'     'MAKIN' @("$d\UC-Merced\University")            'University'
    New-JidemPlace 'administration' 'MAKIN' @("$d\UC-Merced\Administration")        'Administration'
    New-JidemPlace 'admin'          'MAKIN' @("$d\UC-Merced\Administration")        'Administration (short name)'
    New-JidemPlace 'currentwork'    'MAKIN' @("$d\Current-Work")                     'Current work'
    New-JidemPlace 'makinarchive'   'MAKIN' @("$d\Archive")                          'MAKIN archive'
)

function Invoke-JidemGo([string]$Name) {
    $place = $Global:JidemPlaces | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $place) { Write-Host "Unknown place: $Name" -ForegroundColor Yellow; return }
    if ($place.Account -ne 'ANY' -and $place.Account -ne $Global:JidemAccount) {
        Write-Host "'$Name' is assigned to the $($place.Account) account." -ForegroundColor Yellow
        return
    }
    $target = $place.Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
    if ($target) { Set-Location -LiteralPath $target; return }
    Write-Host "'$Name' folder not found:" -ForegroundColor Yellow
    foreach ($p in $place.Paths) { Write-Host "  $p" }
    Write-Host "Create it with: New-Item -ItemType Directory -Path '$($place.Paths[0])'"
}

foreach ($place in $Global:JidemPlaces) {
    Set-Item -Path "Function:\global:$($place.Name)" -Value ([scriptblock]::Create("Invoke-JidemGo '$($place.Name)'"))
}

function places {
    # places [-All]   list jump commands for this account (-All includes the other account's)
    param([switch]$All)
    $labels = [ordered]@{ JIDEM = 'JIDEM'; MAKIN = 'MAKIN'; ANY = 'EVERYWHERE' }
    $ok = 0; $missing = 0
    Write-Host ''
    foreach ($acct in $labels.Keys) {
        if (-not $All -and $acct -ne 'ANY' -and $acct -ne $Global:JidemAccount) { continue }
        Write-Host $labels[$acct] -ForegroundColor Cyan
        foreach ($p in ($Global:JidemPlaces | Where-Object { $_.Account -eq $acct })) {
            $found = $p.Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
            if ($found) {
                $ok++
                Write-Host ('  {0,-16}' -f $p.Name) -NoNewline -ForegroundColor Green
                Write-Host $found
            }
            else {
                $missing++
                Write-Host ('  {0,-16}' -f $p.Name) -NoNewline -ForegroundColor DarkGray
                Write-Host ('MISSING  ' + $p.Paths[0]) -ForegroundColor DarkGray
            }
        }
        Write-Host ''
    }
    Write-Host ("{0} ready, {1} missing" -f $ok, $missing) -ForegroundColor DarkGray
}

Remove-Variable d, sharedBridge, place -ErrorAction SilentlyContinue
