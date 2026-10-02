# JIDEM TERMINAL

Command layer for the two Windows accounts (JIDEM and MAKIN).

| File | Role |
|---|---|
| `JidemCommands.ps1` | Your working navigation file, kept exactly as is. Not edited by this project. |
| `Jidem.Core.ps1` | Phase 1 core control. Account-aware: scans the JIDEM or MAKIN workspace depending on `$HOME`. |
| `Jidem.Navigation.ps1` | Phase 2 navigation. One table of jump commands per account; `places` lists them. |
| `Jidem.Projects.ps1` | Phase 3 projects: `projects`, `openproject`, `projectinfo`, `projectnew`. |
| `Jidem.Git.ps1` | Phase 4 read-only git: `gitstatus`, `gitchanges`, `gitlog`, `gitbranch`, `gitroot`. |
| `Jidem.Academia.ps1` | Phase 5 academic workflow (JIDEM): `dissertation`, `research`, `writing`, `fieldwork`, `publications`, `analysis`, `datasets` now show a summary; `-Code` opens VS Code, `-Quiet` just jumps. Load last. |
| `Jidem.Teaching.ps1` | Phase 6 teaching workflow (MAKIN): `teach` overview plus summaries for `courses`, `ta`, `teaching`, `university`, `administration`, `currentwork`. Load last, MAKIN only. |
| `Jidem.Writing.ps1` | Phase 7 writing + VS Code: `openvscode`, `edit`, `jwrite` (not `write`: built-in alias), `focus`. |
| `Jidem.Search.ps1` | Phase 8 search: `findfile`, `findtext` (incl. Word .docx), `search`. Works in both accounts. |
| `Jidem.Maintenance.ps1` | Phase 9 maintenance (report-only): `inbox`, `duplicates`, `empty`, `cleanup`. Load after Search. |
| `Jidem.Dashboard.ps1` | Phase 10 dashboard: `dashboard` / `desk` (JIDEM academic desk, MAKIN teaching desk) with a quick-action menu. Load LAST. |

`$PROFILE` (both accounts):

```powershell
. "$HOME\PowerShell\JidemCommands.ps1"
. "$HOME\PowerShell\Jidem.Core.ps1"
. "$HOME\PowerShell\Jidem.Navigation.ps1"
. "$HOME\PowerShell\Jidem.Projects.ps1"
. "$HOME\PowerShell\Jidem.Git.ps1"
. "$HOME\PowerShell\Jidem.Academia.ps1"   # JIDEM account only
```

Phase 1 commands: `status`, `jwhere` (not `where`, a built-in alias), `workspace`, `recent`, `today`, `tree` (alias `map`), `size`.
Each later phase is added as its own file (`Jidem.Projects.ps1`, `Jidem.Git.ps1`, ...) loaded after these.
