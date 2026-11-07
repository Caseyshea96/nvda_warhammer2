---
name: warhammer2-nvda-mod-dev
description: Develop-and-test loop for the NVDA accessibility mod for Total War Warhammer II in this repo (C:\Dev\jaws_warhammer2). Use for any change to diagnostics/*.lua, companion/, packaging/ or tools/live/, and for live testing in the game (menus, Select Lord, campaign map) - change, harness, build, install, live-test, document, push.
---

# Warhammer II NVDA mod: develop-and-test loop

`CLAUDE.md` is the source of truth for facts that change: accepted build and
rollback, latest docs, blocked actions, conventions. Read it first, then the
latest `docs/<AREA>_<version>.md` for the area. This skill is the procedure.

Loop: **orient → change → harness → bump → build → install → live-test →
clean up → document → push → report**

## 0. Before editing
- All work is on the owner's Windows PC. If it cannot be reached, say so; never simulate a run.
- `git status` first. Codex or another session may edit this repo: commit only your files; never stash, reset or switch branches.
- A shared notes folder named in the task: read sibling notes first, leave hand-overs there.
- An earlier attempt failed: reproduce it once and compare with a passing run in `work/live-<ver>-<topic>/` before changing code.

## 1. Rules for the runtime (each one cost a failed live run)
- Never call `string.find` (WH2 breaks `string.sub` after it). Use `starts_with` / `string.sub` / `match`.
- One repeating `real_timer` per module. Never register a timer (real or game) from inside a timer callback.
- Campaign model reads and game orders run only in the game-timer job queue (`model_call` in `diagnostics/campaign_readonly.lua`; one `cm:repeat_callback` registered at the first tick). From the reader's timer the game ignored orders, and model reads preceded freezes. UI clicks stay on the reader's timer.
- `tests/check_graphics_preview.py` rejects the text `cm:` in the campaign module (comments too); use `campaign_game()`.
- Exactly one `SimulateLClick` call site per module. Keep the guards: fresh HUD identity, path plus ancestor IDs, leaf ID, state. Widen activation only by the specific new type.
- Ask first ("…? Press Enter again to confirm.") for End Turn, Quit, Exit, Load, Abandon, Recruit, Build, Start Campaign and moves.
- Speech: NVDA order `name, role, value, states, N of M`; short; no engine words.
- Blocked actions: only what `CLAUDE.md` allows (currently: movement yes, attacks no).

## 2. Harness
- `local/tools/lua-5.1.5-windows/lua5.1.exe tests/graphics_preview_harness.lua` (frontend) and `tests/campaign_readonly_harness.lua` (campaign). Add a scenario for every new behaviour.
- In the campaign harness `cm` throws by default. A model test sets `cm` (and `effect`) before `begin()`; without `cm.repeat_callback` model jobs run at once; give it one to test the queue.
- Edit Lua with the Edit tool or a Python script saved to a file: bash heredocs and `sed` have mangled quotes and backslashes here.

## 3. Version bump (7 files)
`git grep -n "0\.6\.<old>" -- diagnostics tests tools packaging` and change only the live strings:
`diagnostics/graphics_preview.lua` (log header, status, ready message), `diagnostics/campaign_readonly.lua` (`local version`),
`tools/package-pilot.py`, `tests/campaign_readonly_client_tests.ps1`, `tools/live/Campaign-ReadOnly.ps1`,
`tests/graphics_preview_harness.lua` (`ready_text`), `packaging/interactive/GRAPHICS_PREVIEW.txt` (ready line).
Leave version mentions in comments and history alone.

## 4. Build and check
- `powershell -File tools/build-graphics-preview-windows.ps1` — needs every `PASS:` line and the ZIP path at the end. On failure do not install (the old ZIP is still there; `Install-Build` now refuses a ZIP older than the sources).
- `py -3 -X utf8 tests/check_installer.py --package artifacts/warhammer2-windows-<ver>-nvda-automation-preview.zip`
- Each build gives the pack a new hash: after rebuilding, reinstall before testing or sending.

## 5. Live test (player path; the friend's way)
```
tools/live/Install-Build.ps1 -Version <ver> -Upgrade
tools/live/Test-PlayerLaunch.ps1 -Evidence work/live-<ver>-<topic> -SkipIntro   # prints GAME=<pid>
tools/live/Start-Companion.ps1  -Evidence work/live-<ver>-<topic>
tools/live/Read-Speech.ps1 -Since <launch time> -Wait ' ready\.' -Seconds 180   # menus
tools/live/Reach-Campaign.ps1 -GamePid <pid>       # or: Continue Campaign + wait for the map
tools/live/Drive-Keys.ps1 -GamePid <pid> -Keys 'F6' # keys, then what was said
tools/live/Check-Reader.ps1 -GamePid <pid>          # when nothing is said
tools/live/Capture-Screen.ps1 -Path <png>           # look at the screen
tools/live/Stop-Session.ps1 -Evidence work/live-<ver>-<topic>   # ALWAYS, also after failures
```
- `-SkipIntro` saves about 3 minutes of intro movies. Test with the movies only when the startup itself is under test.
- Before loading or starting a campaign where something could be saved, copy `%APPDATA%\The Creative Assembly\Warhammer2\save_games` and `advice_history` into the evidence folder. Do not end turns (autosave) unless that is the test; tell the owner if you did.
- Speech: `Read-Speech -Since` only; the trace keeps old sessions, and unfiltered waits matched old lines. Logs in `%LOCALAPPDATA%\WarhammerAccess`: `native-ui-campaign-discovery.jsonl` (kinds such as `activation-dispatch`, `order-run`, `model-stalled`, `command-error`), `native-ui-graphics-preview.log`, `bridge.jsonl`.
- Injected keys reach only the companion (and only while the reader is alive), never the game: game shortcuts such as Shift+F2/F3 cannot be injected.
- Mouse stand-in: `Click-Screen.ps1 -X -Y` uses physical pixels = Capture-Screen pixels × 2. Prefer keys. Never click Start Campaign or the intro-notice confirm.
- Developer lease path (`Start-Session -Direct`, automation channel, `Campaign-ReadOnly.ps1`) only for what needs it; see `CLAUDE.md`.
- Run commands from PowerShell/Bash outside the sandbox when reading the game process, logs or saves. Foreground `sleep` is blocked: wait with a loop on a condition.

### Freeze / silent reader (open problem, frequent)
After camera or selection changes (campaign load, a list-row click, an army entering a settlement) either the game stops responding, or it keeps running while the mod's timers stop. 0.6.66 does it too.
- Detect with `Check-Reader.ps1`: `READER=silent` (heartbeat over 3 s old). A still screenshot proves nothing.
- `RESPONDING=False` for over 2 minutes, or silent for over a minute: copy the logs into the evidence folder, `Stop-Session`, relaunch. Do not retry the same step blindly. Before blaming your change, compare once with the previous build (install its ZIP without `-Upgrade`).
- Likely cause on this PC: Intel iGPU driver timeouts (`docs/FREEZE_INVESTIGATION_2026-11-03.md`). Run `tools/live/Monitor-Game.ps1 -GamePid <pid> -Out <evidence>/monitor.csv` hidden during a run, and after a freeze look for a new `WATCHDOG-<date>-<time>.dmp` in Windows Error Reporting events (LiveKernelEvent 141).
- Since 0.6.73 the companion says "The game is not responding." after 5 s of stall (game in front) and "The game is responding again."; transitions must write the screen `loading` to reader-state (else a false "busy"). Test with `tools/live/Pause-Game.ps1 -GamePid <pid> -Seconds 8`.
- During a stall the companion keeps its keys for 15 s (they wait in keys.tsv); after that it releases them and keys go to the game.

## 6. Document and ship
1. `docs/<AREA>_<ver>.md`: keys, what is read, guards, live evidence (folders), what is not verified, known problems.
2. `CLAUDE.md`: the "Current state" line, the rollback, any new rule or unblock (with date and owner's words).
3. Player-facing change: `packaging/interactive/GRAPHICS_PREVIEW.txt` (the ZIP's README).
4. Before committing, run `powershell -File tools/New-DayBranch.ps1`: it puts you on today's `<first name>_MMDDYY` branch (Casey_110726, Lucas_110726; see CLAUDE.md). Commit there and push it after the live test (every version pushed); the pre-push check refuses a branch with someone else's name. `dev` and `main` change only when the owner says so. Send the ZIP with SendUserFile.
5. Players update from the latest GitHub release ("Warhammer NVDA Update" shortcut, `packaging/pilot/Update.ps1`). Publishing is public: run `powershell -File tools/Publish-Release.ps1 -Version <ver> -NotesFile <notes.md>` (or `-Notes "<one line>"`) only when the owner says this version should go out (it uploads the ZIP and .sha256; Update.ps1 refuses a ZIP without a matching checksum).
6. Leave 0.6.x installed as tested; no owned game or companion running; flags you set (e.g. `campaign-reader-off.flag`) removed.

## 7. Report
Version and commit, what works with live evidence, what is not verified (friend's PC, physical keys), freezes seen, whether saves changed, and the one decision needed from the owner.
