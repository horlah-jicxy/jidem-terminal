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
