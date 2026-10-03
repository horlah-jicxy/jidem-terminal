# JIDEM TERMINAL - User Manual

Version: terminal v1.2.0 (architecture frozen at v1.0.0, amended at v1.1.0 and v1.2.0), Writing Timer 1.6.0.
Written 2 October 2026. For the story of how this was built, and the mistakes that shaped it,
see `PROJECT-HISTORY.md`. For the technical contract, see `ARCHITECTURE.md`.

This manual is for you. It assumes you are comfortable opening PowerShell and VS Code, and
nothing else. Every command is real and every habit in it comes from something that went
wrong once during the build.

---

## Contents

1. What this is, in one page
2. Your first five minutes
3. How the system works (the one idea that explains most problems)
4. Daily, weekly and monthly routines
5. Writing: the timer, Save & Push, and the shared word count
6. Moving files: between the accounts, and sorting loose files
7. Protecting sensitive material
8. Git habits
9. Command reference
10. When something breaks
11. Changing and extending things
12. Backup and recovery
13. Glossary
14. Version notes

---

## 1. What this is, in one page

JIDEM TERMINAL is a set of PowerShell commands that sit on top of Windows PowerShell 5.1
(not PowerShell 7) and make your two administrator accounts behave like one organised
workspace. It does not replace anything. It reads your folders, summarises them, takes you
to them, and checks that its own setup is sound.

| Account | Job | Typical folders |
|---|---|---|
| **JIDEM** | Intellectual production: dissertation, papers, research, writing, development | `Academia`, `GitHub`, `Development` |
| **MAKIN** | Teaching and institutional work at UC Merced | `UC-Merced`, `Writing-Notes` |
| **Shared** | The only bridge. Both accounts can open it. | `C:\Users\Public\Documents\Shared` |

The same command files are installed in both accounts. Each command works out which
account it is running in (from the profile folder name) and either does its job or tells
you which account it belongs to ("assigned to the MAKIN account").

Five rules the whole system obeys. They are why you can trust it:

1. **Reports never change anything.** They only read.
2. **Commands that create things never overwrite**, and most support `-WhatIf` (preview).
3. **Nothing commits, pulls, pushes, renames or deletes for you.** You do those. Nothing moves files either, with one deliberate exception: `sortdownloads -Apply` (section 6.2), which previews first, asks y/n, never overwrites or deletes, and can be undone.
4. **`repair` previews by default**, backs up before it applies, and never edits your
   profile or your code.
5. **`health` must pass in both accounts after any change.**

---

## 2. Your first five minutes

Open PowerShell. Look at the prompt, because it tells you which account you are in:

- `PS C:\Users\jidem>` means JIDEM.
- `PS C:\Users\makin>` means MAKIN.

Then, in either account:

```powershell
desk          # your desk: today's activity, areas, quick-action menu
status        # one-screen overview
jhelp         # every command available in this account
health        # is the whole setup sound?
```

If a command says "not recognized", go straight to section 10 (the three-part check).

---

## 3. How the system works

One idea explains most of what can go wrong.

A command exists in a PowerShell window only when **all three** of these are true:

1. The **file** that defines it is saved in `$HOME\PowerShell\` (for example
   `Jidem.Core.ps1`).
2. Your **profile** (`$PROFILE`) has a line that loads that file.
3. The profile has been **reloaded** in this window (`. $PROFILE`).

If any one is missing, you get "The term '...' is not recognized". It looks the same every
time, which is why it caught you about ten times during the build.

You never type a file name. You type the commands inside the files. `Jidem.Core.ps1` is a
file; `status` is the command.

### Load order (matters)

Core first. Dashboard last. The writing-log, sort and audit files go after Help and before Dashboard.

JIDEM profile, in order: `JidemCommands`, `Jidem.Core`, `Jidem.Navigation`,
`Jidem.Projects`, `Jidem.Git`, `Jidem.Academia`, `Jidem.Writing`, `Jidem.Search`,
`Jidem.Maintenance`, `Jidem.Health`, `Jidem.Help`, `Jidem.WritingLog`, `Jidem.Sort`, `Jidem.Audit`, `Jidem.Dashboard`.

MAKIN profile, in order: `JidemCommands`, `Jidem.Core`, `Jidem.Navigation`, `Jidem.Git`,
`Jidem.Search`, `Jidem.Maintenance`, `Jidem.Writing`, `Jidem.Teaching`, `Jidem.Health`,
`Jidem.Help`, `Jidem.WritingLog`, `Jidem.Sort`, `Jidem.Audit`, `Jidem.Dashboard`.

Each line looks like `. "$HOME\PowerShell\Jidem.Core.ps1"` (a dot, a space, then the path).
That line belongs only in the profile, never inside a command file. (Putting it inside a
command file makes the file load itself forever and gives "call depth overflow".)

### Two Documents folders

- `C:\Users\<name>\Documents` is the new structure. It is a plain local folder and is **not**
  synced by OneDrive.
- `C:\Users\<name>\OneDrive\Documents` is where Windows keeps old material, and it is
  cloud-synced.

Files you create in the first folder have no cloud copy. The dissertation is protected by
GitHub. Anything else important needs its own backup (section 12).

---

## 4. Daily, weekly and monthly routines

### A writing day (JIDEM or MAKIN)

1. `desk` to see where you are.
2. Open VS Code in the folder you are writing in (`dissertation -Code`, `jwrite`, or open
   `Writing-Notes` in MAKIN).
3. Press **Ctrl+Alt+W**, choose 30 or 45 minutes, choose **Draft**. Write. Do not fix
   spelling, "i", spacing or capitals while drafting.
4. Stop the timer. Add a one-line note. Answer the AI-use question honestly.
5. Run `syncwords` (this adds the session to the shared count).
6. When the draft should be saved to GitHub, use the **Save & Push** button or task.
7. Edit on a separate pass: run **LTeX: Check Current Document**, fix the flags, and use
   **Edit** mode on the timer for that session.

### A teaching day (MAKIN)

```powershell
teach                        # overview: current course, recent work, Shared bridge
course ANTH                  # go to a course folder (partial names work)
coursenew "IH 211" -WhatIf   # preview a new course folder, then run without -WhatIf
```

### End of a writing day

```powershell
syncwords
wordsum
```

Do this in each account you wrote in.

### Weekly

- `cleanup -Quick` for a clutter report; `inbox` (JIDEM) to see what is waiting.
- `backup`, then `health`, in each account.
- A weekly cold write (300 words, no AI, no notes) if you are following
  `WRITING-PRACTICE.md`.

### Monthly or after a big change

- `sortdownloads` (preview, then `-Apply`) to file the Downloads pile (section 6.2).
- `duplicates` for wasted space (reports only; you decide).
- Check that the interview data copy in UC Merced Box is current.
- Delete temporary `_rescue_*` and `_backup-*` folders you no longer need (through the
  Recycle Bin, yourself).

---

## 5. Writing: the timer, Save & Push, and the shared word count

### 5.1 The Writing Timer (VS Code extension, v1.6.0)

Installed in both accounts. It lives in the `Academic-papers` repo under
`resources/vscode-writing-timer/` (source and the `.vsix` installer).

**Start a session**

- Press **Ctrl+Alt+W**, or click the status-bar item ("Start writing").
- It picks the file you were last in (or the only visible one, or asks you).
- Choose the length: 25, 30, 45, 50, 90 minutes, or open-ended.
- Choose the mode: **Draft**, **Edit / revise**, or **Cold-write (no AI, no notes)**.
- If the file is in the paper repo but the tracker is not counting it, you are asked to
  **Track this file** (its words go into your daily count and streak) or **Time it without
  tracking**. Use "without tracking" for tests and scratch files.

**While it runs**

- The status bar shows time and net words in the current file (`+N words`).
- Click it for a menu: **Pause**, **Stop & record**, **Keep writing**.
- After `idleMinutes` (default 5) with no typing or cursor movement it auto-pauses. The
  idle stretch is not counted. Typing in the file resumes it.
- If VS Code reloads or closes mid-session, the session returns **paused** at your last
  keystroke and asks **Resume** or **Stop & record**. Nothing is lost.

**Stop a session**

1. Optional one-line note ("what did you work on?").
2. "Did AI help with this session?" - None, Brainstorming or outlining, Feedback or edits
   on my draft, Drafted with AI help, or Skip.
3. The tracker records your words and active minutes.
4. A message shows the result. If you pasted large blocks it also shows "typed about N
   words; pasted M in K blocks".
5. A **Save & Push** button runs the workspace's Save & Push task.

**What it records** (one line per session in `.writing-sessions.jsonl`, at the root of the
tracker's repo, or beside the file if there is no tracker): start, end, active and wall
minutes, net words, mode, estimated typed words, pasted words and blocks, largest paste,
deleted characters, local date, UTC offset, time zone, pauses, the AI-use choice, and your
note. It never records what you wrote.

**Settings** (VS Code Settings, search "writingTimer"):

| Setting | Default | Meaning |
|---|---|---|
| `writingTimer.idleMinutes` | 5 | Auto-pause after this many idle minutes (0 = off). |
| `writingTimer.pasteWordThreshold` | 15 | One insertion of this many words or more counts as a paste. |
| `writingTimer.warnWhenUntracked` | true | Show the "words won't reach the tracker" dialog. Turn off for `Writing-Notes`. |

**Honest limits (read these)**

- "Typed words" is an **estimate** (typed characters divided by 6).
- Pastes smaller than the threshold, and short inline completions, count as typing.
- A file rewritten on disk by another tool (for example an AI agent) shows up as a large
  block.
- "Net words" goes **down** when you delete. Edit sessions can be zero or negative; that is
  why Edit mode exists.
- The record is for you. It supports your own discipline. It is not proof to anyone else.
- `.writing-sessions.jsonl` is tracked in the paper repo, so your notes and AI-use choices
  are committed when you push.

### 5.2 Save & Push (`resources/scripts/save_and_push.ps1`)

Run it from the VS Code button after a session, or from Tasks: Run Task: Save & Push. It:

1. Checks your citations (warns, never blocks).
2. Lists every change (new, edited, deleted) in colour.
3. Warns about files over 10 MB, files whose names look like research data
   (transcript, interview, consent, participant, recordings), and 5 or more deletions.
4. Asks `y` to push or `n` to cancel (cancelling commits nothing).
5. Asks for a short note. The default is your last session note if that session ended in
   the last 3 hours, otherwise `writing <date>`. A leftover template such as
   `Draft: <what you worked on>` is replaced by the default.
6. Commits and pushes.

### 5.3 The shared word count

One CSV, readable from both accounts:
`C:\Users\Public\Documents\Shared\writing-log.csv`
Columns: `Date, Time, Account, Words, Minutes, Note, SessionStart, Source, Mode`.

It holds **numbers only**. `syncwords` never copies file names or session notes. It is the
one deliberate exception to "Shared stays empty", because nothing sensitive can be in it.

| Command | What it does |
|---|---|
| `syncwords` | Reads this account's `.writing-sessions.jsonl` files and adds sessions not yet in the log. Safe to run any number of times. |
| `syncwords -WhatIf` | Shows what it would add and writes nothing. |
| `syncwords -Since 2026-09-01` | Only sessions on or after that date. |
| `syncwords -Root "C:\path"` | Search a different folder for session logs. |
| `wordsum` | Today, the last 7 days (`-Days 14` for more), per account, and your streak. |
| `logwords 450 40 -Note "ch2"` | Add one line by hand, for writing the timer did not see. |
| `countwords .\draft.md` | Count the words in a `.md`, `.txt` or `.tex` file. |

Folders `syncwords` searches by default (5 levels deep):

- JIDEM: `Documents\GitHub` and `Documents\Academia`.
- MAKIN: `Documents\Writing-Notes` and `Documents\UC-Merced`.

How the totals work:

- **Draft, Cold-write and manual** entries count as words and minutes.
- **Edit** sessions count as **minutes only** (shown as "edit N min").
- A day counts if it has at least one word logged. The streak is consecutive such days,
  counting back from today (or from yesterday if you have not written yet today).
- Days use the **local date stored by timer 1.6 and later**, so a day stays the day you
  wrote it after you travel (for example to Houston). Sessions from timer 1.5 and earlier
  have no stored date and are read as Pacific time (offset -420, set in
  `$Global:JidemLegacyUtcOffset`).
- Keep **Windows time zone set automatically** when you travel.

Fixing a wrong entry:

- Open the CSV in Notepad and delete the row. **If it came from the timer, also delete
  that session's line from `.writing-sessions.jsonl` first**, or the next `syncwords`
  adds it back.
- If a command says the log "has the older column layout", rename the file to
  `writing-log-old.csv` in File Explorer and run the command again. Nothing is written
  until you do.

---

## 6. Moving files: between the accounts, and sorting loose files

`Shared` is a bridge, not a place to keep things. It is readable by every account on the
PC, so **no sensitive material ever goes in it** (see section 7).

### 6.1 Between the two accounts

The pattern, every time:

1. In the sending account, copy the files into a temporary folder inside `Shared`.
2. In the receiving account, copy them out into place.
3. `Unblock-File` anything that came through (downloaded or handed-over files can carry the
   "from the internet" tag).
4. Verify (open a few; compare checksums if it matters).
5. Delete the temporary folder from `Shared`, through File Explorer.
6. Originals are removed only by you, through the Recycle Bin, after you have verified.

Example check that copies are identical:

```powershell
Get-FileHash "C:\path\to\original" ; Get-FileHash "C:\path\to\copy"
```

Leave `writing-log.csv` in `Shared`. It is meant to be there.

### 6.2 Sorting a loose pile (Downloads, Desktop)

`sortdownloads` files the loose items in your Downloads folder into
`Documents\Archive\Downloads\<Category>\<Year>\`, so nothing sits unfiled. It works **without
ever reading inside a file**: it looks only at names, extensions, sizes and dates, and the
preview prints counts, not file names. Neither you nor Claude has to open anything.

Use it in this order:

```powershell
sortdownloads                     # PREVIEW: counts by category, and what it will leave alone
sortdownloads -ShowNames          # optional: the same, with names, on your own screen
sortdownloads -Apply              # does it, after asking y/n
sortundo                          # lists past sorts
sortundo sort-<stamp>.csv -Apply  # puts one sort back where it was
```

Categories: Documents, PDFs, Spreadsheets, Slides, Images, Compressed, Installers,
CodeData, Other, and Folders (whole folders move intact into `Folders\<year>`, never
emptied out). The year is when the file arrived (the later of its created and modified dates).

What it **leaves alone** (always counted in the preview):

- anything that arrived or changed in the last 14 days (`-Days` changes this; `-Days 0` means everything)
- partial downloads (`.crdownload`, `.tmp`, `.part`)
- OneDrive cloud-only placeholders (moving them would download them)
- audio and video, because they can be recordings (add `-IncludeMedia` once you have checked)
- any name matching `$Global:JidemSortKeep`: interview, Zoom, transcript, consent, IRB,
  participant, fieldnote, Taguette, Houston, recording. Edit that list in `Jidem.Sort.ps1`
  to add more. Those items stay exactly where they are.
- hidden folders (names starting with a dot)

Safety:

- It never overwrites (a name clash becomes `name (2).ext`) and never deletes.
- Every move is written to a manifest in `$HOME\PowerShell\sort-logs`, which `sortundo` uses.
  `sortundo` skips anything that has moved again or whose original name is now taken.
- It refuses to sort your home folder, `Documents`, a drive root, or `Shared`.
- `-WhatIf` with `-Apply` lists each move and does none.
- The archive is in the local `Documents` folder, which OneDrive does **not** back up
  (section 3). Include `Documents\Archive` in your own backup.

Other loose piles (the Desktop, for example) use the same command:
`sortdownloads -Path "$HOME\Desktop"`. Old **folders with their own structure** (project
trees, phone-sync folders) are not flattened by this command; migrate those by copying,
checking, then removing the originals yourself (section 6.1).

### 6.3 Mapping the whole computer (`auditpc`)

Before moving any old folder, find out what is where. `auditpc` is a **report**: it
changes nothing, opens nothing, and prints folder names and counts only (never file
names).

```powershell
auditpc            # scan and print the map (can take a few minutes)
auditpc -Csv       # also save it to $HOME\PowerShell\audit-logs for later
auditpc -Top 60 -MinMB 0     # show more, including small folders
```

It looks at the top-level folders under your profile, OneDrive, `OneDrive\Documents`,
`Documents` and the root of `C:\`, and prints for each: number of files, size, newest and
oldest dates, the two main file types, and a **suggestion**:

| Label | Meaning | What you do |
|---|---|---|
| `FILED` | Already inside your Documents workspace | Nothing |
| `MIGRATE?` | Mostly documents, PDFs, sheets or slides | Copy into the workspace, check, then remove the original yourself, one folder at a time |
| `SORT-PILE` | Loose files (Downloads, Desktop, or loose files at a root) | `sortdownloads -Path <folder>`, preview first |
| `LEAVE-APP` | Program data or caches (Anaconda, Zotero, whisper, node_modules, hidden folders) | Leave alone |
| `LEAVE-SENS` | A research-sensitive name (interview, Zoom, consent, IRB, Houston ...) | Leave exactly where it is; never moved, never put in `Shared` |
| `LEAVE-PRIVATE` | A personal finance, identity or health name (bank, Chase, tax, passport, visa, insurance ...) | Keep out of the academic workspace; file it yourself in a private place |
| `REVIEW-MEDIA` | Mostly audio or video, which could be recordings | Check by hand before filing anything |
| `PHOTOS` | Mostly pictures | Leave, or archive by hand |
| `CLEAN?` | Mostly installers and archives | Look through them yourself; remove by hand if they are not needed |
| `PROJECT` | Mostly code or data | Leave in place, or migrate by hand |
| `EMPTY` | No files | Delete it yourself if you like |

Honest limits: the suggestion comes from names and file types only, so it is a guess. A
folder counts at most 20,000 files (shown as `20,000+`). Folders that are program data or
that have a research-sensitive name are listed but never scanned. Copying a folder into the
workspace is always done by you, as with the coursework: copy, verify, delete the original
through the Recycle Bin yourself.

---

## 7. Protecting sensitive material

Applies to interviews, transcripts, recordings, consent forms, Taguette databases, and
anything derived from them (for example `houston_preliminary.xlsx`).

- **Never put it in `Shared`.** Every account on the PC can read that folder.
- **Never put it in git.** The dissertation repo's `.gitignore` excludes `interview_data/`,
  `transcripts/`, `houston_*`, `*.xlsx`, `*.xls`, audio and video files, Taguette `*.tdb`,
  `*.docx` and `facebook_corpus.csv`. Before any commit or reset, read `git status`.
- **Keep an approved copy** on UC Merced Box. Git does not hold the data, and an
  untracked local copy has no backup.
- **Check your IRB protocol** before choosing any other storage. De-identification helps
  but does not by itself settle where data may live.
- **Folder permissions.** `C:\Houston_Project` and `...\interview_data` were restricted to
  administrators only. Check with `icacls "<folder>"`. It should list only
  `BUILTIN\Administrators` and `NT AUTHORITY\SYSTEM`. Both your accounts are administrators,
  so they can still reach it; non-administrator accounts cannot.
- **If something sensitive was committed**, tell Claude before pushing anything else.
  Removing it from history needs a careful rewrite and a verification pass (the Facebook
  corpus was removed this way, and it also lived under a second path).
- **Zoom recordings** stay on the local drive where they are. Nothing in this system moves
  them.

---

## 8. Git habits

The git commands in this system only read (`gitstatus`, `gitchanges`, `gitlog`,
`gitbranch`, `gitroot`). Changing git is always your action, and these habits keep it safe:

1. **`git status` before every commit and before any reset.** Know what is staged.
2. A file that is staged but not yet committed is **deleted from disk** by
   `git reset --hard`. Unstage it first (`git restore --staged <file>`).
3. Git remembers a file at **every path it ever had**. Removing a file from history means
   checking each path, then verifying.
4. `git fetch` is always safe. `git pull` merges, so look at `git status` first.
5. In JIDEM, `Academic-papers` is the one working clone. Do not keep a second, drifting
   copy in MAKIN.
6. Never `git add -A` over a folder that might hold sensitive files. Save & Push lists
   every change before committing.

---

## 9. Command reference

Generated from the help table (`jhelp`), so it matches what the commands themselves say.
"Both accounts" commands run in either; the others print "assigned to the X account" in the
wrong one.

### Core

**`status`** (both accounts)  
One screen: where you are, your workspace folders, the last 7 days of work, and git state.

```powershell
status
```

**`jwhere`** (both accounts)  
Where you are: an arrow path, which workspace area it belongs to, and git.

```powershell
jwhere
```
Note: Named jwhere because 'where' is a built-in PowerShell alias for Where-Object.

**`workspace`** (both accounts)  
Every workspace root and its subfolders, with file counts and last activity.

```powershell
workspace
```

**`recent`** (both accounts)  
Recently modified files across your workspace, newest first.

```powershell
recent [-Days 14] [-Top 20] [-Extension md,docx] [-Path <folder>]
recent -Days 3 -Extension docx
```

**`today`** (both accounts)  
Files modified since midnight.

```powershell
today [-Top 50] [-Extension md]
```

**`tree` / `map`** (both accounts)  
A folder tree with file counts, skipping .git, node_modules and similar.

```powershell
tree [-Depth 2] [-Files] [-Path <folder>]
tree -Files -Depth 1
```
Note: map is an alias for tree.

**`size`** (both accounts)  
Biggest subfolders (with percentage), or biggest files with -Files.

```powershell
size [-Top 15] [-Files] [-Path <folder>]
```

### Navigation

**`places`** (both accounts)  
Lists every jump command for this account and whether its folder exists.

```powershell
places [-All]
```
Note: -All also shows the other account's commands.

**`jidem` / `shared` / `archive` / `reference`** (both accounts)  
Jump to Documents (jidem), the Shared bridge, the archive, or the reference folder.

```powershell
jidem
shared
```
Note: shared is C:\Users\Public\Documents\Shared, the one folder both accounts can open.

**`academia` / `coursework` / `development` / `personaleditor` / `pythonwork` / `rwork` / `experiments` / `teachingtoolkit` / `github` / `archives`** (JIDEM only)  
Jump to a JIDEM folder.

```powershell
academia
development
github
```
Note: In the MAKIN account these print 'assigned to the JIDEM account'.

**`makin` / `school` / `makinarchive`** (MAKIN only)  
Jump to a MAKIN folder (makin = Documents, school = UC-Merced).

```powershell
school
```
Note: In the JIDEM account these print 'assigned to the MAKIN account'.

### Academic workflow

**`dissertation` / `research` / `writing` / `fieldwork` / `publications` / `analysis` / `datasets` / `papers`** (JIDEM only)  
Go to the folder AND show a summary: contents (most recently active first), files changed in the last 14 days, git state.

```powershell
dissertation [-Code] [-Quiet]
papers
research -Quiet
```
Note: -Code also opens VS Code; -Quiet just jumps. dissertation = Academic-papers\projects\dissertation (falls back to Academia\Dissertation); papers = Academic-papers\projects.

### Projects

**`projects`** (JIDEM only)  
A numbered list of your projects with git branch and uncommitted changes.

```powershell
projects
```

**`openproject`** (JIDEM only)  
Go to a project and open it in VS Code.

```powershell
openproject
openproject 3
openproject paper -NoCode
```
Note: Takes a number or part of a name. -NoCode skips VS Code.

**`projectinfo`** (JIDEM only)  
Summary of a project folder: git, file counts, newest files, VS Code.

```powershell
projectinfo [path]
```

**`projectnew`** (JIDEM only)  
Creates Documents\Development\<name> with a README.md.

```powershell
projectnew "My Project" [-Git] [-WhatIf]
```
Note: Never overwrites. -Git also runs git init. -WhatIf previews.

### Git

**`gitstatus`** (both accounts)  
Repository, branch, sync with upstream (as of last fetch), state, last commit.

```powershell
gitstatus
```
Note: All git commands only read. Nothing commits, stages, pulls, pushes or switches branches.

**`gitchanges`** (both accounts)  
Changed files grouped as staged, modified, untracked, conflicts.

```powershell
gitchanges [-Stat]
```

**`gitlog`** (both accounts)  
Recent commits, one line each.

```powershell
gitlog [-Count 10]
```

**`gitbranch`** (both accounts)  
Current branch, upstream, and branches sorted by recent activity.

```powershell
gitbranch [-All]
```
Note: -All adds remote branches.

**`gitroot`** (both accounts)  
Prints the repository root folder.

```powershell
gitroot [-Go]
```
Note: -Go moves you there.

### Writing and VS Code

**`openvscode`** (both accounts)  
Open a folder (default: here) or a file in VS Code.

```powershell
openvscode [path]
```

**`edit`** (both accounts)  
Open a file in VS Code by path or by part of its name, searching under the current folder.

```powershell
edit <file>
edit abstract
```
Note: If several files match, it lists them newest first and asks you to be more specific.

**`jwrite`** (JIDEM only)  
Go to a writing project and open it in VS Code.

```powershell
jwrite [project] [-NoCode]
jwrite ssha -NoCode
```
Note: Named jwrite because 'write' is a built-in alias. With no name it uses the pinned project (set JidemWritingProject in Jidem.Writing.ps1) or the most recently edited one.

**`focus`** (JIDEM only)  
One-screen status of a writing project: location, editor, git, last edited files.

```powershell
focus [project] [-Code]
```
Note: Opens nothing unless you add -Code. Git counts only changes inside that project.

**`syncwords`** (both accounts)  
Add your Writing Timer sessions to the shared word log (words and minutes only), once each.

```powershell
syncwords
syncwords -WhatIf
syncwords -Since 2026-09-01
```
Note: Reads .writing-sessions.jsonl in this account's writing folders and appends to Shared\writing-log.csv. Never copies notes or file names. Safe to run repeatedly.

**`wordsum`** (both accounts)  
Words written today and over the last days, both accounts, plus your streak. Edit sessions show as minutes only.

```powershell
wordsum
wordsum -Days 14
```
Note: Report only.

**`logwords`** (both accounts)  
Add one line by hand: words, minutes, optional note, for writing the timer did not see.

```powershell
logwords 450 40
logwords 300 -Note "notes"
logwords 450 40 -WhatIf
```
Note: Appends to Shared\writing-log.csv. Never edits or deletes. -WhatIf previews.

**`countwords`** (both accounts)  
Count the words in a .md, .txt or .tex file.

```powershell
countwords .\draft.md
```
Note: Report only.

### Search

**`findfile`** (both accounts)  
Find files by NAME (wildcards * ? allowed).

```powershell
findfile <name> [where]
findfile abstract
findfile "*.docx" SSHA
```
Note: [where] = a folder path, a jump-command name (dissertation, papers), or a folder name (SSHA). Skips dot-folders and Archive folders unless you add -IncludeHidden / -IncludeArchive.

**`findtext`** (both accounts)  
Find text INSIDE files, including Word .docx files.

```powershell
findtext <text> [where]
findtext masculinity SSHA
findtext "heal.*" -Regex
```
Note: Switches: -Here (current folder only), -Regex, -NoDocx, -Top <n>, -IncludeHidden, -IncludeArchive. Reads .md .txt .csv .py .r .rmd .qmd .tex .bib .html .xml .yaml .yml and .docx.

**`search`** (both accounts)  
File names and text matches together on one screen.

```powershell
search <text> [where]
search healing papers
```
Note: Same switches as findtext.

### Maintenance

**`inbox`** (JIDEM only)  
Go to the inbox and report what is waiting, how old it is, and a guessed category for each item.

```powershell
inbox [-Quiet]
```
Note: Report only: nothing is moved. The category is a guess from file names and types.

**`duplicates`** (both accounts)  
Files with identical content (same size and SHA-256), biggest wasted space first.

```powershell
duplicates [where] [-MinKB 1] [-Top 15]
```
Note: Report only: nothing is deleted.

**`empty`** (both accounts)  
Empty folders and zero-byte files.

```powershell
empty [where]
```
Note: Empty folders may be intentional scaffolding. Report only.

**`cleanup`** (both accounts)  
One-screen clutter report: inbox, stale areas, empty items, duplicates.

```powershell
cleanup [-Quick] [-StaleDays 90]
```
Note: -Quick skips the duplicate check, which can be slow. Report only.

**`sortdownloads`** (both accounts)  
Sort a loose pile (Downloads by default) into Documents\Archive by file type and arrival year. Preview first; counts only, never reads inside files.

```powershell
sortdownloads
sortdownloads -Days 30 -ShowNames
sortdownloads -Apply
sortdownloads -Path "$HOME\Desktop"
```
Note: The one command that moves files. Preview unless -Apply, then asks y/n. Never overwrites or deletes. Leaves recent files, partial downloads, cloud-only files, audio/video (unless -IncludeMedia) and names matching $Global:JidemSortKeep (interview, Zoom, transcript, consent, IRB ...). Folders move intact. Writes a manifest to $HOME\PowerShell\sort-logs.

**`sortundo`** (both accounts)  
List past sorts, or put the files from one sort back where they were.

```powershell
sortundo
sortundo sort-20261002-101500-123.csv -Apply
```
Note: Preview unless -Apply. Skips anything that has moved again or whose original name is now taken.

**`auditpc`** (both accounts)  
Map where your files live: every top-level folder under your profile, OneDrive, Documents and C:\ with file count, size, age, main file types and a suggestion (migrate, sort, leave, review).

```powershell
auditpc
auditpc -Csv
auditpc -Root "D:\Old" -Top 20
```
Note: Report only: never opens, moves, copies or deletes anything, and prints folder names and counts, never file names. Program data and research-sensitive folders are listed but not scanned.

### Teaching

**`teach`** (MAKIN only)  
Go to UC-Merced and show the teaching overview: current course, contents, recent work, Shared bridge.

```powershell
teach [-Code] [-Quiet]
```
Note: Edit the current course in Jidem.Teaching.ps1 ($Global:JidemCurrentCourse).

**`course`** (MAKIN only)  
List your course folders, or go to one (partial names work).

```powershell
course
course 211
course ANTH -Code
```
Note: Course folders live in UC-Merced\TA.

**`coursenew`** (MAKIN only)  
Create a course folder in TA with Syllabus, Materials, Assignments, Attendance, Grades, Reports.

```powershell
coursenew "IH 211" [-Term "Fall 2024"] [-WhatIf]
```
Note: Spaces become hyphens; -Term is appended after an underscore. Never overwrites.

**`courses` / `ta` / `teaching` / `university` / `administration` / `admin` / `currentwork`** (MAKIN only)  
Go to the folder and show a summary: contents, files changed in the last 14 days.

```powershell
ta [-Code] [-Quiet]
administration
```

### System

**`health`** (both accounts)  
Checks the whole setup: PowerShell, profile and its load order, every command file, expected commands, git, VS Code, folders, backups.

```powershell
health
```
Note: Read-only. Shows OK / WARN / FAIL.

**`validate`** (both accounts)  
Lists any folder your commands point at that does not exist, with the command to create it.

```powershell
validate
```
Note: Read-only.

**`backup`** (both accounts)  
Copies your command files and profile into a new dated folder under $HOME\PowerShell\backups.

```powershell
backup [-WhatIf]
```
Note: Never overwrites or deletes.

**`repair`** (both accounts)  
Preview, then apply, safe fixes: unblock downloaded files, create missing folders.

```powershell
repair
repair -Apply
repair -Apply -CreateFolders
```
Note: Preview by default. -Apply backs up first. Never edits your profile or code.

**`dashboard` / `desk`** (both accounts)  
Your desk: JIDEM academic desk or MAKIN teaching desk, with a numbered quick-action menu.

```powershell
dashboard [-NoMenu]
```

**`jhelp`** (both accounts)  
This help.

```powershell
jhelp
jhelp git
jhelp findtext
jhelp -All
```


### Jump commands

JIDEM:

| Command | Takes you to |
|---|---|
| `academia` | Academic workspace |
| `inbox` | Unsorted incoming items |
| `research` | Research projects |
| `dissertation` | Dissertation |
| `writing` | Manuscripts and drafts |
| `fieldwork` | Fieldwork |
| `publications` | Published and submitted work |
| `coursework` | Courses I have taken (IH 210, 213, 250) |
| `papers` | Papers and projects (Academic-papers repo) |
| `analysis` | Analysis |
| `datasets` | Data |
| `archives` | Academic archive |
| `development` | Development root |
| `personaleditor` | Personal Editor |
| `pythonwork` | Python |
| `rwork` | R |
| `experiments` | Experiments |
| `teachingtoolkit` | Teaching Toolkit |
| `github` | GitHub repositories |

MAKIN:

| Command | Takes you to |
|---|---|
| `makin` | MAKIN Documents |
| `school` | UC Merced root |
| `courses` | Courses |
| `ta` | TA work |
| `teaching` | Teaching |
| `university` | University |
| `administration` | Administration |
| `admin` | Administration (short name) |
| `currentwork` | Current work |
| `makinarchive` | MAKIN archive |

Both accounts:

| Command | Takes you to |
|---|---|
| `jidem` | Documents |
| `shared` | Bridge between accounts |
| `archive` | Archive |
| `reference` | Reference material |

`places` shows every jump command for the account you are in and whether each folder exists.

### The desk quick actions

`desk` ends with a numbered menu. JIDEM: `dissertation`, `research`, `writing`, `papers`,
`projects`, `inbox`, `recent`, `syncwords`, `wordsum`, `status`. MAKIN: `teach`, `course`,
`ta`, `shared`, `today`, `syncwords`, `wordsum`, `status`. Type the number or the name.

---

## 10. When something breaks

Start with these three, in this order:

```powershell
health      # parses every file, names the line of any syntax error, checks load order
validate    # folders your commands point at that do not exist
repair      # PREVIEW of safe fixes; repair -Apply backs up first, then applies
```

### "The term '...' is not recognized"

The three-part check:

```powershell
Test-Path "$HOME\PowerShell\<file>.ps1"            # 1. is the file there?
Select-String -Path $PROFILE -Pattern "<file>"     # 2. does the profile load it?
. $PROFILE                                         # 3. reload, then try again
```

Also check the prompt. You may be in the wrong account.

### Symptom guide

| What you see | Usual cause | What to do |
|---|---|---|
| "not recognized" for a command | File missing, profile line missing, or not reloaded | The three-part check above. |
| "not recognized" for a **file name** | You typed a file name | Type the commands inside it. Files load through the profile. |
| "assigned to the X account" | Right command, wrong account | Switch accounts. |
| "File ... cannot be loaded ... not digitally signed" | Downloaded file is blocked | `Unblock-File "<path>"`, or `repair -Apply`. |
| Parse error with strange characters (like an arrow turned into garbage) | Non-ASCII in a file | Keep command files ASCII-only. `health` finds the line. |
| "call depth overflow" on `. $PROFILE` | A profile load line is inside a command file | Delete that line from the command file. |
| A flood of errors after pasting a block (`Get-Process : A positional parameter...`, banner lines "not recognized") | Console output was pasted INTO PowerShell; it runs every line, and `PS` at the start of a prompt is the alias for `Get-Process` | Nothing is harmed (check for stray command names that ran). Paste only a command line, never prompts or results. `cls` clears the screen. |
| A quoted path just prints back | A string by itself is not a command | Use `notepad "<path>"` or `code "<path>"`. |
| `pull` not recognized | It is a git subcommand | `git pull`. |
| `fatal: not a git repository` | Plain `git` in a folder with no repo | `gitroot`, or go to the repo first. |
| `Copy-Item : An item ... already exists` on a folder | The folder is already there | Check the files arrived (hashes). Usually harmless. |
| `where`, `write` or `r` behaves oddly | They are built-in PowerShell aliases | The commands were named `jwhere` and `jwrite` for this reason. |
| "The tracker isn't counting this file" | Not an error: a question | Choose Track, or Time it without tracking. |
| `sortdownloads` says nothing to sort | Everything is recent, sensitive-named, media or cloud-only | Check the "left where they are" counts; use `-Days`, `-ShowNames` or `-IncludeMedia` after checking. |
| `auditpc` takes a long time | Large drive; it counts files | Let it finish, or scan one place: `auditpc -Root "C:\Github"`. |
| `syncwords` says 0 session log files | No timed session in this account's folders yet | Write one timed session, then run it again. |
| "writing-log.csv has the older column layout" | The first version of the file | Rename it to `writing-log-old.csv` and rerun. |
| LTeX "could not run ltex-ls with Java" | Slow Java start or an old LTeX fork | Use `ltex-plus`, update Java, restart VS Code fully. |
| `Loading personal and system profiles took 610ms` | Normal startup timing | Nothing. |

### Things that trip PowerShell

- A PowerShell variable name is **not case sensitive** (`$all` and `-All` collide).
- `data` is a reserved word. Arguments such as `'@{u}'` need quoting when passed to native
  commands.
- Do not paste a multi-line `if / elseif / else` into the console. Each line is run
  separately. Use a script file or a one-line form.

---

## 11. Changing and extending things

Table changes are always safe and need no new code.

| To change | Edit |
|---|---|
| A jump command or folder | The table in `Jidem.Navigation.ps1` (one `New-JidemPlace` line each) |
| Pinned projects (JIDEM) | `$Global:JidemPinnedProjects` in `Jidem.Projects.ps1` |
| The pinned writing project | `$Global:JidemWritingProject` in `Jidem.Writing.ps1` |
| Current course (MAKIN) | `$Global:JidemCurrentCourse` in `Jidem.Teaching.ps1` |
| Areas on the JIDEM desk | `$Global:JidemDeskAreas` in `Jidem.Dashboard.ps1` |
| Desk quick actions | `$Global:JidemDeskActionsJidem` / `...Makin` in `Jidem.Dashboard.ps1` |
| Show the desk at startup | `$Global:JidemDashboardOnStart = $true` in `Jidem.Dashboard.ps1` |
| Folders `syncwords` searches | `$Global:JidemWritingRoots` in `Jidem.WritingLog.ps1` |
| Document a new command | One `Add-JidemHelp` line in `Jidem.Help.ps1` |

After any edit: `. $PROFILE`, then `health`. Keep the repo copy in step, so a rebuild is
possible (see section 12).

Adding **new files or new behaviour** is a version change (v1.1.0 style, additive). Read
`ARCHITECTURE.md` first; its invariants are the rules that kept this stable.

---

## 12. Backup and recovery

Three layers:

1. **`backup`** (per account): copies the command files and profile into a new dated
   folder under `$HOME\PowerShell\backups`. Never overwrites or deletes.
2. **The `jidem-terminal` repo** (GitHub, private): the command files, the documentation
   and the architecture contract.
3. **Your academic files** are not in that repo. The dissertation analysis and
   `Academic-papers` are in their own private GitHub repos. Everything else under
   `C:\Users\<name>\Documents` has **no cloud copy** and needs its own backup (an external
   drive or another service). Interview data belongs on UC Merced Box.

To recover a broken setup:

1. `health`, then `repair` (preview), then `repair -Apply` if the fixes look right.
2. Restore from `$HOME\PowerShell\backups\<date-time>`.
3. Or copy the files from the repo, `Unblock-File` them, and `. $PROFILE`.

Temporary `_obsolete` folders (old scripts) and `_rescue_*` / `_backup-*` folders were
created for safety. They are safe to delete once you are sure you do not need them, through
the Recycle Bin, yourself.

---

## 13. Glossary

- **Account:** a Windows user (JIDEM or MAKIN). Each has its own home folder and profile.
- **Profile (`$PROFILE`):** the PowerShell script that runs when a window opens. It loads the files.
- **Dot-source:** the `. "path"` line that loads a file into the current window.
- **Jump command:** a command that takes you to a folder (`dissertation`, `ta`, ...).
- **Table-driven:** behaviour held in a table you edit, not in code.
- **`-WhatIf`:** preview: show what would happen and change nothing.
- **Read-only / report-only:** only reads; changes nothing.
- **Shared:** `C:\Users\Public\Documents\Shared`, the bridge folder.
- **Tracker (`writing_tracker.ps1`):** counts words in the files on its active list.
- **Session log (`.writing-sessions.jsonl`):** the timer's one-line-per-session record.
- **Draft / Edit / Cold-write:** the three session modes of the timer.
- **Quarantine (`_obsolete`):** old files moved aside, not deleted.
- **Invariant:** a rule that must stay true (see `ARCHITECTURE.md`).

---

## 14. Version notes

| Version | What it is |
|---|---|
| v1.0.0 | The frozen architecture: Phases 1 to 12 and `repair`. |
| v1.1.0 | Additive: `Jidem.WritingLog.ps1` (`syncwords`, `wordsum`, `logwords`, `countwords`), `coursework` jump command, desk actions for `syncwords` and `wordsum`. |
| v1.2.0 | `Jidem.Sort.ps1` (`sortdownloads`, `sortundo`): the one command that moves files, narrowly amended into the contract. `Jidem.Audit.ps1` (`auditpc`): report-only map of where files live. |
| Writing Timer 1.6.0 | Session modes, typed-versus-pasted tally, AI-use note, local dates and offsets, 30/45-minute presets, Ctrl+Alt+W, `warnWhenUntracked`. Save & Push now defaults to your last session note. |

Still open at the time of writing: committing the timer 1.6.0 files on `Academic-papers`
`main`, tagging `v1.0.0` (the commit that froze `ARCHITECTURE.md`) and `v1.1.0`, and
removing the leftover test session. See the end of `PROJECT-HISTORY.md`.
