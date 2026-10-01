# JIDEM TERMINAL

Command layer for the two Windows accounts (JIDEM and MAKIN).

| File | Role |
|---|---|
| `JidemCommands.ps1` | Your working navigation file, kept exactly as is. Not edited by this project. |
| `Jidem.Core.ps1` | Phase 1 core control. Account-aware: scans the JIDEM or MAKIN workspace depending on `$HOME`. |
| `Jidem.Navigation.ps1` | Phase 2 navigation. One table of jump commands per account; `places` lists them. |

`$PROFILE` (both accounts):

```powershell
. "$HOME\PowerShell\JidemCommands.ps1"
. "$HOME\PowerShell\Jidem.Core.ps1"
. "$HOME\PowerShell\Jidem.Navigation.ps1"
```

Phase 1 commands: `status`, `jwhere` (not `where`, a built-in alias), `workspace`, `recent`, `today`, `tree` (alias `map`), `size`.
Each later phase is added as its own file (`Jidem.Projects.ps1`, `Jidem.Git.ps1`, ...) loaded after these.
