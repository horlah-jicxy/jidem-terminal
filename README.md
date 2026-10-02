# JIDEM TERMINAL  (architecture frozen at v1.0.0 - see ARCHITECTURE.md)

A personal command layer on top of Windows PowerShell 5.1 for two accounts that each have one job:

- **JIDEM** - intellectual production: Academia, Dissertation, Papers, Research, Writing, Development, GitHub.
- **MAKIN** - institutional operations: UC-Merced, Courses/TA, Teaching, University, Administration.
- **Shared** (`C:\Users\Public\Documents\Shared`) - the one folder both accounts can open; the deliberate bridge between them.

The accounts are kept separate on purpose. The same files work in both; each command checks which account it is
running in (from the profile folder name) and either does its job or says which account owns it.

## Files (one per phase; the first four rows are the foundation)

| File | Phase | Account | What it adds |
|---|---|---|---|
| `JidemCommands.ps1` | - | both | Original jump commands with account guards (kept as it was) |
| `Jidem.Core.ps1` | 1 | both | `status` `jwhere` `workspace` `recent` `today` `tree`/`map` `size`, plus the helpers everything else uses |
| `Jidem.Navigation.ps1` | 2 | both | Table of jump commands per account; `places` |
| `Jidem.Projects.ps1` | 3 | JIDEM | `projects` `openproject` `projectinfo` `projectnew` |
| `Jidem.Git.ps1` | 4 | both | Read-only: `gitstatus` `gitchanges` `gitlog` `gitbranch` `gitroot` |
| `Jidem.Academia.ps1` | 5 | JIDEM | `dissertation` `research` `writing` `fieldwork` `publications` `analysis` `datasets` `papers` show a summary |
| `Jidem.Teaching.ps1` | 6 | MAKIN | `teach` `course` `coursenew` + summaries for `ta` `courses` `teaching` `university` `administration` `currentwork` |
| `Jidem.Writing.ps1` | 7 | both | `openvscode` `edit`; JIDEM: `jwrite` `focus` |
| `Jidem.Search.ps1` | 8 | both | `findfile` `findtext` (incl. Word) `search` |
| `Jidem.Maintenance.ps1` | 9 | both | Report-only: `inbox` (JIDEM) `duplicates` `empty` `cleanup` |
| `Jidem.Health.ps1` | 11 | both | `health` `validate` `backup` `repair` |
| `Jidem.Help.ps1` | 12 | both | `jhelp`, `jhelp <command>`, `jhelp <group>`, `jhelp -All` |
| `Jidem.Dashboard.ps1` | 10 | both | `dashboard` / `desk`: JIDEM academic desk, MAKIN teaching desk. **Load last.** |

## Profile (`$PROFILE`, in OneDrive\Documents\WindowsPowerShell)

Load order matters. Core first; Dashboard last. Files go in `$HOME\PowerShell\`.

JIDEM:
```powershell
. "$HOME\PowerShell\JidemCommands.ps1"
. "$HOME\PowerShell\Jidem.Core.ps1"
. "$HOME\PowerShell\Jidem.Navigation.ps1"
. "$HOME\PowerShell\Jidem.Projects.ps1"
. "$HOME\PowerShell\Jidem.Git.ps1"
. "$HOME\PowerShell\Jidem.Academia.ps1"
. "$HOME\PowerShell\Jidem.Writing.ps1"
. "$HOME\PowerShell\Jidem.Search.ps1"
. "$HOME\PowerShell\Jidem.Maintenance.ps1"
. "$HOME\PowerShell\Jidem.Health.ps1"
. "$HOME\PowerShell\Jidem.Help.ps1"
. "$HOME\PowerShell\Jidem.Dashboard.ps1"
```

MAKIN: the same, without `Projects` and `Academia`, and with `Jidem.Teaching.ps1` (after Maintenance/Writing, before Health).

## Rules the whole system follows

- Reports are read-only. `inbox`, `duplicates`, `empty`, `cleanup`, `health`, `validate` and every git command never change anything.
- Commands that create (`projectnew`, `coursenew`, `backup`, `repair -Apply`) never overwrite or delete, and most support `-WhatIf`.
- Nothing commits, stages, pulls, pushes, moves, renames or deletes for you.
- `repair` is preview-only until `-Apply`; it backs up first and never edits your profile or code.
- Command files are plain ASCII (non-ASCII breaks Windows PowerShell 5.1 when a file has no BOM).
- A command file never contains a profile load line; those belong only in `$PROFILE`.

## Everyday use

```powershell
dashboard        # your desk
status           # quick overview
jhelp            # every command; jhelp <command> for details
health           # is the setup sound?
backup           # dated copy of command files + profile
```

## Changing things

| To change | Edit |
|---|---|
| A jump command or folder | the table in `Jidem.Navigation.ps1` (one line each) |
| Pinned projects | `$Global:JidemPinnedProjects` in `Jidem.Projects.ps1` |
| Pin the writing project | `$Global:JidemWritingProject` in `Jidem.Writing.ps1` (e.g. `'dissertation'`) |
| Current course (MAKIN) | `$Global:JidemCurrentCourse` in `Jidem.Teaching.ps1` |
| Areas on the JIDEM desk | `$Global:JidemDeskAreas` in `Jidem.Dashboard.ps1` |
| Show the desk at startup | `$Global:JidemDashboardOnStart = $true` in `Jidem.Dashboard.ps1` |
| Document a new command | one `Add-JidemHelp` line in `Jidem.Help.ps1` |

After any edit: `. $PROFILE`, then `health`.

## When something breaks

1. `health` - it parses every file and names the line of any syntax error, empty file, blocked download, stray character or wrong load order.
2. `validate` - lists folders the commands point at that do not exist.
3. `repair` - previews safe fixes; `repair -Apply` unblocks downloaded files (and `-CreateFolders` creates missing folders).
4. Restore from `$HOME\PowerShell\backups\<date-time>`, or from this repository.

Moving files between the accounts: copy them into a temporary folder inside `Shared`, copy them out as the other
account, `Unblock-File` them, then delete the temporary folder.

## Backups

Two layers: `backup` (local dated copies per account) and this repository (`horlah-jicxy/jidem-terminal`, private).
Your actual academic files are not in this repository and should have their own backup (OneDrive, external drive).
