# JIDEM TERMINAL - Architecture (FROZEN at v1.0.0; amended at v1.1.0 and v1.2.0, see section 8)

This document is the contract. Day-to-day work happens *inside* it; changing the contract itself is a deliberate,
rare act (see "Changing the contract").

## 1. Accounts

| Account | Job | Home |
|---|---|---|
| JIDEM | Intellectual production | `C:\Users\jidem` |
| MAKIN | Institutional operations | `C:\Users\makin` |
| Shared | The only bridge between them | `C:\Users\Public\Documents\Shared` (kept EMPTY between handoffs; the one standing exception is `writing-log.csv`, numbers only) |

Accounts never read each other's profiles. The account is derived from the profile folder name (`$HOME` leaf, upper-cased).

## 2. Workspace folders (under each account's `Documents`)

JIDEM
```
Academia\   00_INBOX  Research  Writing  Fieldwork  Publications  Analysis  Data  Archives   (Dissertation = legacy, empty)
Development\  Personal-Editor  Python  R  Experiments
GitHub\     Academic-papers\projects\{dissertation, independent-study, LSA_Paper, notes, SSHA, SWAA}   teaching-toolkit-v43
Archive\    Reference\
```
MAKIN
```
UC-Merced\  Administration  Courses  Teaching  University  TA\<COURSE>[_<Term>]\{Syllabus, Materials, Assignments, Attendance, Grades, Reports}
Current-Work\   Archive\   Reference\
```
Course folders live in `TA\` (not `Courses\`). Past courses are added with `coursenew "IH 211" -Term "Fall 2024"`.

## 3. Command files (in `$HOME\PowerShell\`) and load order

```
1  JidemCommands.ps1       legacy base (original jump commands; superseded by Navigation, kept loaded)
2  Jidem.Core.ps1          helpers + status/jwhere/workspace/recent/today/tree/size
3  Jidem.Navigation.ps1    jump-command table, places
4  Jidem.Projects.ps1      JIDEM only
5  Jidem.Git.ps1
6  Jidem.Academia.ps1      JIDEM only
7  Jidem.Writing.ps1
8  Jidem.Search.ps1
9  Jidem.Maintenance.ps1   needs Search
10 Jidem.Teaching.ps1      MAKIN only (after Navigation)
11 Jidem.Health.ps1
12 Jidem.Help.ps1
13 Jidem.WritingLog.ps1    v1.1.0, after Help (syncwords, wordsum, logwords, countwords)
14 Jidem.Sort.ps1          v1.2.0, after Help (sortdownloads, sortundo)
15 Jidem.Audit.ps1         v1.2.0, after Help (auditpc, report-only)
16 Jidem.Dashboard.ps1     ALWAYS LAST
```
Naming: `Jidem.<Area>.ps1`; globals `$Global:Jidem*`; helper functions `*-Jidem*`. Core loads before everything but the legacy base.

## 4. Invariants (never broken, even by "small" additions)

1. Reports are read-only (inbox, duplicates, empty, cleanup, health, validate, all git commands).
2. Nothing commits, stages, pulls, pushes, renames or deletes on the user's behalf. Nothing MOVES files either, with ONE deliberate exception (v1.2.0): `sortdownloads -Apply`, which previews first, asks y/n, never overwrites or deletes, skips research-sensitive names, and writes a manifest that `sortundo` can reverse.
3. Anything that creates never overwrites, and supports `-WhatIf` where it can (projectnew, coursenew, backup).
4. `repair` previews by default; `-Apply` backs up first; it never edits the profile or command files.
5. Command files are ASCII only, parse cleanly, and contain no profile load line (those live only in `$PROFILE`).
6. Each command checks its account and says which account owns it when run in the other.
7. `health` must pass (0 warnings, 0 failures) in both accounts after any change.

## 5. What may change without touching the contract

- Data in tables: jump commands (Navigation), pinned projects, desk areas, current course, pinned writing project, help text.
- Bug fixes inside a function that keep its name, parameters and behaviour.
- New commands added as NEW lines in an existing area file (and one `Add-JidemHelp` entry).

## 6. Changing the contract (new file, renamed folder, new account rule, changed load order)

1. Say what changes and why. 2. Change it in the repo clone. 3. Update this file and bump the version tag
(v1.1.0 for additive, v2.0.0 for breaking). 4. `. $PROFILE`, `health`, `backup` in BOTH accounts.
5. Push and tag.

## 7. Known, accepted oddities

- `JidemCommands.ps1` duplicates jump commands that Navigation redefines; it is kept as the legacy base.
- `ACADEMIC` is tried as a fallback root alongside `Academia`.
- `Academia\Dissertation` is empty; the real dissertation project is `GitHub\Academic-papers\projects\dissertation`.
- Windows PowerShell 5.1 only; no PowerShell 7 features.

## 8. Amendments since v1.0.0

| Version | Change | Why it stays inside the contract |
|---|---|---|
| v1.1.0 | `Jidem.WritingLog.ps1`; `coursework` jump command; desk actions for `syncwords` and `wordsum`; `writing-log.csv` in Shared (numbers only) | Additive. Only appends to one CSV; never overwrites, edits or deletes. |
| v1.2.0 | `Jidem.Sort.ps1` (`sortdownloads`, `sortundo`) | A deliberate, narrow amendment of invariant 2. Moves files only on `-Apply` after a preview and a y/n, within the user's own Documents, and is reversible from its manifest. It never reads inside a file. |
| v1.2.0 | `Jidem.Audit.ps1` (`auditpc`) | Additive and report-only: reads names, sizes and dates, never opens, moves, copies or deletes anything. |
