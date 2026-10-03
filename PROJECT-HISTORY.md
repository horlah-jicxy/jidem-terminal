# JIDEM TERMINAL - Project History and Learning Record

Compiled 2 October 2026, at the end of the first build (v1.0.0 frozen, v1.1.0 added).
Sources: the working session itself (every command, every error you pasted, every fix).
Dates are US Pacific time. All of it was built over two calendar days: 1-2 October 2026.

This file is the story of how the workspace got to where it is, what it now does, and
what the mistakes along the way taught. A user manual comes next; this is its background.

---

## 1. The short version

You started with one working PowerShell file (`JidemCommands.ps1`) and an idea: an
"academic terminal" layer on top of Windows, spread across two administrator accounts that
had grown cluttered. In two days it became:

- 13 new command files plus your original, about 3,150 lines of PowerShell
- about 74 documented commands, identical in both accounts, each one aware of which
  account it is running in
- a safety layer (`health`, `validate`, `backup`, `repair`) so the system checks itself
- a frozen written contract (`ARCHITECTURE.md`) so it stays stable
- a migration of old coursework and abstracts into the new structure
- a hardened, private dissertation repo with sensitive data removed from its history
- one writing environment (VS Code) with a tested timer, and a word count shared
  between both accounts
- a written writing-practice protocol (`WRITING-PRACTICE.md`)

Nothing was deleted from your machine on your behalf at any point. The system only reads,
previews, or creates; you do the moving and the deleting.

---

## 2. What you were trying to achieve

Your goals, in your own order of priority:

1. **A stable academic career.** Work organised so it holds up to future scrutiny
   (job market, publications), and a clear record of how your writing is produced.
2. **Less reliance on AI for writing.** Go back to drafting rough text and editing it
   yourself; rebuild the skill; keep an honest record.
3. **One organised workspace first, free time second.** Finance trackers and automations
   are deliberately parked until the structure and the writing habit are steady.
4. **Two accounts, one system.** JIDEM = intellectual production. MAKIN = UC Merced
   teaching and institutional work. `Shared` is the only bridge between them.
5. **A migration audit** of old material scattered across Downloads, OneDrive, Zotero and
   other places, done without deleting anything blind.

---

## 3. The design decisions that shaped everything

| Decision | Why it mattered |
|---|---|
| Build alongside `JidemCommands.ps1`, never edit it | Your working tool was never at risk. |
| Separate private repo (`jidem-terminal`) | The tooling has its own history, apart from your research. |
| Account detected from the profile folder name | The same files run in both accounts; each command knows where it is. |
| Table-driven (jump commands, pinned projects, help, expected files) | Adding a folder or command is one line of data, not new code. |
| Reports are read-only; creators never overwrite; `-WhatIf` everywhere | The system cannot surprise you. |
| `repair` previews by default and backs up before applying | Fixes are visible before they happen. |
| ASCII-only files, no profile line inside command files | Both rules came from real failures (see section 6). |
| `Shared` is the only bridge, kept empty between handoffs | Keeps the two workspaces separate and keeps sensitive data out of a place every account can read. |
| `health` must pass in both accounts after any change | One command proves the whole system still works. |

---

## 4. How it grew

### Day 1 - Thursday 1 October: foundation (7 am to evening)

- You shared the vision (navigation, observe, create, academic, development) and your
  existing library. Decision: build on it, in its own repo, without touching it.
- You explained the real goal: merge two administrator accounts into one system. The
  account-aware design (JIDEM vs MAKIN, `Shared` as the bridge) came from that.
- **Phase 1 - Core:** `status`, `jwhere`, `workspace`, `recent`, `today`, `tree`/`map`, `size`.
- **Phase 2 - Navigation:** a table of jump commands (about 20 per account), `places`.
- **Phase 3 - Projects:** `projects`, `openproject`, `projectinfo`, `projectnew`; pinned
  projects (Academic-papers, Teaching-Toolkit, Personal-Editor, Python, R, Experiments).
- **Phase 4 - Git (read-only):** `gitstatus`, `gitchanges`, `gitlog`, `gitbranch`, `gitroot`.
- **Phase 5 - Academia:** one-screen summaries per area (dissertation, research, writing,
  fieldwork, publications, papers, analysis, datasets).
- **Phase 6 - Teaching (MAKIN):** `teach`, `course`, `coursenew` (creates a course folder
  under `TA`), current course ANTH 005.
- **Phase 7 (evening) - Writing and VS Code bridge:** `openvscode`, `edit`, `jwrite`, `focus`.
- **Phase 8 - Search:** `findfile`, `findtext`, `search`, scoped by path, command name or
  folder name; reads text inside `.docx` files.

### Day 2 - Friday 2 October: safety, structure and the writing environment

- **Phase 9 - Maintenance:** report-only `inbox`, `duplicates`, `empty`, `cleanup`.
- **Phase 10 - Dashboard:** `dashboard` / `desk` (an academic desk for JIDEM, a teaching
  desk for MAKIN) with a quick-action menu.
- **Catching MAKIN up** so both accounts were on the same page.
- **Phase 11 - Safety layer:** `health`, `validate`, `backup`, then `repair` (preview by
  default; `-Apply` backs up first).
- **Phase 12 - Help:** `jhelp`, a table-driven help system.
- **Repo sync** (your files and the repo made identical), then the **architecture freeze**
  (`ARCHITECTURE.md`, v1.0.0), verification of both accounts independently, backups
  confirmed, obsolete scripts quarantined (not deleted) in `PowerShell\_obsolete\`.
- **Migration audit.** You described the old structure and where old material lived. The
  plan: copy first, verify, never delete blind. Zoom recordings, sound recordings,
  Taguette, IRB and consent forms stayed exactly where they were.
- **Writing practice protocol** (`WRITING-PRACTICE.md`): daily 30-45 minute draft block,
  an edit day, a weekly cold write, reading, feedback, and rules for AI use.
- **Coursework and abstracts moved** (14 files, checksums identical) into
  `Academia\Coursework`, `Publications` and `Writing`, plus a `coursework` command.
- **Dissertation repo (dissertation-moral-vocabulary):** `.gitignore` hardened, the
  Facebook corpus removed from the entire git history on all four branches (it had also
  hidden under a second path after a folder reorganisation), JIDEM named as owner.
- **Interview folders** (`C:\Houston_Project`, `interview_data`) were readable and
  modifiable by every account on the PC. Permissions tightened to administrators only,
  with the original permissions saved for undo.
- **VS Code:** MAKIN trimmed from 15 extensions to 11 (five removed, the writing timer added), Settings Sync turned off so the
  two accounts stop overwriting each other, LTeX swapped to the maintained version and set
  to check on request, so drafting is not interrupted by underlines.
- **Writing Timer 1.6.0:** session mode (Draft / Edit / Cold-write), typed-versus-pasted
  tally, an AI-use note at the end of each session, local dates that stay correct when
  you travel across time zones, and a commit message that defaults to your session note.
- **Shared word count (v1.1.0):** `syncwords` and `wordsum` add each timed session (words
  and minutes only, never text or file names) to one CSV in `Shared`, so a day's total
  covers writing in both accounts. Confirmed working in both accounts, with MAKIN's first
  session counted next to JIDEM's.

- **Sorting loose files (v1.2.0):** `sortdownloads` and `sortundo` file a loose pile (Downloads)
  into `Documents\Archive` by type and year without reading inside any file. It is the one
  command that moves files, so it was added as a deliberate, documented amendment to the
  "nothing moves" rule: preview first, y/n, never overwrites or deletes, skips research-sensitive
  names, and is reversible from a manifest.

- **Computer audit (v1.2.0):** `auditpc` maps where files actually live (profile, OneDrive,
  Documents, `C:\`) with counts, sizes, ages and a suggestion per folder, never opening a
  file. It is the report that decides what to migrate, sort or leave, one folder at a time.

---

## 5. What exists now

### Command files (each in both the repo and `$HOME\PowerShell`)

| File | Phase | Purpose |
|---|---|---|
| `JidemCommands.ps1` | legacy | Your original library, kept verbatim |
| `Jidem.Core.ps1` | 1 | status, jwhere, workspace, recent, today, tree, size |
| `Jidem.Navigation.ps1` | 2 | jump-command table, `places` |
| `Jidem.Projects.ps1` | 3 | projects, openproject, projectinfo, projectnew |
| `Jidem.Git.ps1` | 4 | read-only git reports |
| `Jidem.Academia.ps1` | 5 | area summaries (JIDEM) |
| `Jidem.Teaching.ps1` | 6 | teach, course, coursenew, area summaries (MAKIN) |
| `Jidem.Writing.ps1` | 7 | openvscode, edit, jwrite, focus |
| `Jidem.Search.ps1` | 8 | findfile, findtext, search |
| `Jidem.Maintenance.ps1` | 9 | inbox, duplicates, empty, cleanup |
| `Jidem.Dashboard.ps1` | 10 | dashboard, desk (loads last) |
| `Jidem.Health.ps1` | 11 | health, validate, backup, repair |
| `Jidem.Help.ps1` | 12 | jhelp |
| `Jidem.WritingLog.ps1` | v1.1.0 | syncwords, wordsum, logwords, countwords |
| `Jidem.Sort.ps1` | v1.2.0 | sortdownloads, sortundo (the one command that moves files) |
| `Jidem.Audit.ps1` | v1.2.0 | auditpc (report-only map of where files live) |

Documents: `README.md`, `ARCHITECTURE.md` (the frozen contract), `WRITING-PRACTICE.md`,
and this file.

### Outside the terminal

- Writing Timer 1.6.0 (in the `Academic-papers` repo, `resources/vscode-writing-timer`)
- Academia structure in JIDEM; UC-Merced structure in MAKIN
- A hardened `.gitignore` and a clean history in the dissertation repo

---

## 6. The learning curve: every kind of error, and what it taught

Around 40 of your pasted messages contained an error. They fall into a small number of causes,
and almost every one taught a habit. That is the useful finding: the mistakes were not
random, they were the same few things in different clothes.

### A. Wrong window or wrong account (about 7 times)

Commands such as `today`, `status`, `coursenew` "not recognized" in MAKIN; a copy step
run in MAKIN when it needed JIDEM; a `cd` to a path that exists only in the other account.

- **Cause:** two accounts look almost identical, and each has its own `PowerShell` folder.
- **Lesson:** read the prompt first. `PS C:\Users\jidem>` or `PS C:\Users\makin>` tells you
  which account the next command will touch.
- **What got built:** every command checks the account and says "assigned to the X account".

### B. Saved the file, but PowerShell was never told (about 10 times)

`today`, `status`, `olaces`/`places`, `projects`, `gitstatus`, `coursenew`, `jhelp` not
recognized after the code had been pasted.

- **Cause:** a command only exists after (1) the file is saved in `$HOME\PowerShell`, (2)
  the profile has a line that loads it, and (3) the profile is reloaded (`. $PROFILE`).
  Any one of the three missing gives the same message.
- **Lesson:** the three-part check: `Test-Path` the file, `Select-String` the profile for
  its name, then `. $PROFILE`.
- **What got built:** `health` and `repair`, which run those checks for you.

### C. Windows blocked the downloaded file (once, but it came back)

"File cannot be loaded ... is not digitally signed."

- **Cause:** files downloaded from a browser carry a hidden "from the internet" tag; the
  execution policy refuses unsigned scripts with that tag.
- **Lesson:** `Unblock-File` on the file. Files typed into Notepad on your own computer
  do not have the tag.
- **What got built:** `health` checks for blocked files; `repair` unblocks them.

### D. Invisible characters broke the script (parse errors)

Arrows, box-drawing characters and em dashes turned into garbage characters and the parser
failed with "Unexpected token".

- **Cause:** PowerShell 5.1 reads files by a different text encoding than the one they
  were written in.
- **Lesson / rule:** all command files are ASCII-only.
- **What got built:** the ASCII-only invariant in `ARCHITECTURE.md`, and a syntax check in
  `health`.

### E. "Call depth overflow"

`. $PROFILE` failed with a stack-depth error after the profile loading line for
`Jidem.Navigation.ps1` ended up at the bottom of that same file.

- **Cause:** the file loaded itself over and over until PowerShell gave up.
- **Lesson:** profile load lines belong in the profile only, never inside a command file.
- **What got built:** `health` detects it; it is now an invariant.

### F. Typing the wrong kind of thing (about 6 times)

- Typing a **file name** as a command (`Jidem.Maintenance.ps1`) - files are loaded by the
  profile; you type the commands inside them.
- Typing a **path** as a command (`\Github\dissertation-moral-vocabulary`) - use `cd`.
- Typing a **quoted string** on its own (`".\\powershell\jidem.navigation.ps1"`) - it just
  prints back; use `notepad` or `code` to open it.
- `pull` instead of `git pull`; `olaces` for `places`; `-SSHA` as if it were a parameter.
- Pasting a whole block of old console output (prompts, banners, results) back into the
  window: PowerShell runs every line. `PS C:\...>` at the start of a line runs the alias for
  `Get-Process`, and any line that happens to match a real command (`Teaching`, `(empty)`)
  runs it. Harmless here because those commands only read, but it is why read-only design
  matters.
- **Lesson:** a command line is `command arguments`. Strings and paths alone do nothing.
- **What got built:** `findfile`/`findtext` accept a scope word (a folder name or jump
  name) after the search term, which is what `-SSHA` was reaching for.

### G. Git surprises (about 4 times)

- `git status` in a folder that is not a repository.
- `houston_preliminary.xlsx` staged for commit in the dissertation clone - a near miss.
  Committing it would have published interview-derived data, and the planned
  `reset --hard` would then have deleted the file from disk.
- A scrub that removed `facebook_corpus.csv` from the root but missed a second path
  (`01_data/social_media/`) created by a later folder reorganisation. A verification
  step caught it before anything was pushed.
- **Lessons:** read `git status` before every commit or reset; git remembers files at
  every path they ever had; verify a history rewrite before the force-push.
- **What got built:** the `.gitignore` now ignores `houston_*`, spreadsheets, recordings,
  Taguette databases and the Facebook corpus.

### H. Things that looked like errors but were not

- The writing timer's "The tracker isn't counting this file" box is a question, not a
  fault: it offers to start counting a file.
- `Copy-Item : ... already exists` on `Publications` and `Writing` during the move; the
  files were still copied (checksums matched).
- "Loading personal and system profiles took 610ms" is just PowerShell's startup timing.
- **Lesson:** read the message; "error" is not always "something broke".

### I. VS Code and the grammar checker

- LTeX reported "Could not run ltex-ls with Java". The log showed the engine was found
  but timed out starting (16 seconds), not that Java was missing.
- **Fix:** the maintained extension (`ltex-plus`), a current Java, and a manual-check
  setting so drafting is not interrupted.

---

### Mistakes on my side (worth recording, because they shaped the process)

You asked for the full record; these were the assistant's errors, and each one changed
how the work was done:

1. **Code was not in the message.** For two phases the instructions said "paste the code
   above" when no code was in the text you saw. After that, all code was included in the
   message itself.
2. **A guessed filename** (`Jidem.Core (1).ps1`) sent you hunting for a file that was
   never there. After that, the whole file was provided instead.
3. **A multi-line `if / elseif / else`** pasted into the console splits at each line, so
   the patch silently did not run. After that, one-line commands were used.
4. **Non-ASCII characters in the first files** caused the parse errors (D above).
5. **A stray `+` in `Write-Host`**, a variable called `$all` that collided with `-All`
   (PowerShell variable names ignore case), and `@args` used where `@opts` was meant.
6. **A first-pass scrub that missed a second file path** (G above), and a preview table
   that printed empty during a `-WhatIf` test. Both were caught by testing before you ran
   them.
7. **A tag recommendation** that would have pointed `v1.0.0` at the wrong commit. It was
   corrected before you ran it.

The pattern: each of these was found by verifying (`health`, a re-check, a test), not by
luck. That habit is part of the system now.

---

## 7. Habits this process produced

1. Read the prompt: which account am I in?
2. Three checks when a command is "not recognized": file exists, profile line exists,
   profile reloaded.
3. `health` after any change, in both accounts.
4. `-WhatIf` before anything that writes.
5. Copy, verify, then delete (by you, through the Recycle Bin), never move blind.
6. `git status` before every commit, and especially before any reset.
7. Check history, not just the current files, when removing something from git.
8. Sensitive material (interviews, consent forms, recordings, Taguette) stays out of
   git, out of `Shared`, and on approved storage.
9. Draft first, edit second: a checker that nags during drafting costs more than it helps.
10. Run `syncwords` at the end of a writing day in each account.

---

## 8. What is still open

- Commit the Writing Timer 1.6.0 files on `Academic-papers` `main`.
- Confirm a clone of the dissertation repo exists in JIDEM and is up to date.
- Tag `v1.0.0` (the commit that froze `ARCHITECTURE.md`) and `v1.1.0` (latest).
- Delete the leftover `Writing` folder in `Shared` (keep `writing-log.csv`).
- Remove the five-minute test session from the timer log and the shared CSV, and delete
  `draft_timer_test.md`.
- Keep or delete the temporary backup and rescue folders after a few days.
- Check that the interview data copy in UC Merced Box is current (git does not hold it).
- Parked on purpose: finance tracker and automations, until organisation and the daily
  drafting habit are steady.
- Next document: the user manual.
