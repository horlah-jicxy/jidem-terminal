# JIDEM TERMINAL  (architecture frozen at v1.0.0 - see ARCHITECTURE.md; v1.1.0 adds the shared word count, v1.2.0 adds sorting and the computer audit, v1.3.0 adds the account prompt and handoff, v1.4.0 adds `trash`)

New here? Read `USER-MANUAL.md`. For how it was built and what each mistake taught, read `PROJECT-HISTORY.md`.

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
| `Jidem.WritingLog.ps1` | v1.1.0 | both | `syncwords` `wordsum` `logwords` `countwords`: a shared daily word count (numbers only) in `Shared\writing-log.csv`. Load after Help, before Dashboard. |
| `Jidem.Sort.ps1` | v1.2.0 | both | `sortdownloads` `sortundo` `trash`: sort a loose pile (Downloads) into `Documents\Archive` by type and year. Preview first; never reads inside files; the one command that moves files. Load after Help, before Dashboard. |
| `Jidem.Audit.ps1` | v1.2.0 | both | `auditpc`: report-only map of where your files live (folders under your profile, OneDrive, Documents, C:\) with size, age, main file types and a suggestion. Never opens, moves or deletes anything; prints folder names and counts only. Load after Help, before Dashboard. |
| `Jidem.Accounts.ps1` | v1.3.0 | both | The prompt shows `[JIDEM]` or `[MAKIN]` (with a red warning if you are in the other account's folder), and `handoff send / receive / status / clear` moves folders between the accounts through a private temporary folder. Load after Help, before Dashboard. |
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
. "$HOME\PowerShell\Jidem.WritingLog.ps1"
. "$HOME\PowerShell\Jidem.Sort.ps1"
. "$HOME\PowerShell\Jidem.Audit.ps1"
. "$HOME\PowerShell\Jidem.Accounts.ps1"
. "$HOME\PowerShell\Jidem.Dashboard.ps1"
```

MAKIN: the same, without `Projects` and `Academia`, and with `Jidem.Teaching.ps1` (after Maintenance/Writing, before Health); `Jidem.WritingLog.ps1`, `Jidem.Sort.ps1`, `Jidem.Audit.ps1` and `Jidem.Accounts.ps1` go after Help in both.

## Rules the whole system follows

- Reports are read-only. `inbox`, `duplicates`, `empty`, `cleanup`, `health`, `validate` and every git command never change anything.
- Commands that create (`projectnew`, `coursenew`, `backup`, `repair -Apply`) never overwrite or delete, and most support `-WhatIf`.
- Nothing commits, stages, pulls, pushes, renames or deletes for you. `trash` is the only command that removes anything, and only to the Recycle Bin (preview first, y/n, refuses sensitive and system paths). Nothing moves files either, except `sortdownloads -Apply` (preview first, y/n, never overwrites or deletes, reversible with `sortundo`).
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

## Documentation

| File | What it is |
|---|---|
| `USER-MANUAL.md` | How to use everything: routines, the writing timer, the shared word count, safety, troubleshooting, command reference |
| `PROJECT-HISTORY.md` | How the workspace grew, what exists, and the learning record of every kind of error |
| `ARCHITECTURE.md` | The frozen contract and its invariants |
| `WRITING-PRACTICE.md` | The drafting, cold-write, feedback and AI-use routine |
