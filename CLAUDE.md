# JAWS/NVDA accessibility for Total War: Warhammer II

Screen-reader access mod. The in-game Lua script writes speech requests to a
bridge file; the PowerShell companion forwards them to NVDA/JAWS.

## Where things are

- `diagnostics/graphics_preview.lua` — the current runtime. The build packs it
  as `script/_lib/mod/jaws_access.lua`, so in-game errors that name
  `jaws_access.lua:<line>` refer to this file.
- `mod/script/_lib/mod/jaws_access.lua` — older interactive pilot source.
- `companion/` — Companion.ps1 (speech bridge), Automation.ps1 (test channel).
- `packaging/pilot/` — Install.ps1 / Uninstall.ps1 shipped in the ZIP.
- `tests/` — Lua harnesses and Python/PowerShell checks.
- `local/tools/` — Lua 5.1.5, RPFM 4.5.4, NVDA controller client (git-ignored).
- `work/` — live-test evidence, candidate sources, pre-install backups
  (git-ignored; contains game-derived files — never commit).
- `outputs/` — packaged ZIPs, test reports, `failed-candidates/` (git-ignored).

`work/` and `outputs/` were copied from the earlier Codex workspace
`C:\Users\shea9\Documents\Codex\2026-10-26\resume-working-on-this-2\`, which is
left intact. Paths like `work/live-0.6.17-lord-discovery` in the docs resolve here.

## Current state — read before working

- `docs/AUTOMATION_SESSION.md` — full session history and current stop point.
- `docs/FIRST_TRIAL_0_6_60.md` — latest: first outside trial fixes (main menu on other PCs, Continue Campaign, launch without TW Mod Manager, HUD reading on by default; accepted 0.6.60) 0.6.61: "ready" waits for the menu after the intro movies; 0.6.62: Select Lord without exact layout checks; 0.6.63: the installer upgrades in place (trial 2 ran the old build) and "ready" says the version.
- `docs/SETTLEMENTS_0_6_43.md` — provinces, settlement panel, building and recruiting by keyboard, intro check box, player guide, armies read, silent-reader fix, document reading order and province/unit figures (accepted 0.6.59).
- `docs/CAMPAIGN_BUTTONS_0_6_39.md` — HUD buttons, End Turn, first turn by keyboard (0.6.38–0.6.42).
- `docs/CAMPAIGN_DISCOVERY_0_6_31.md` — owner-requested stop; candidate offline checks passed, live gates pending.
- `docs/CAMPAIGN_DISCOVERY_0_6_30.md` — latest live result: partial campaign capture; 0.6.28 restored.
- `docs/START_CAMPAIGN_0_6_28.md` — accepted confirmed Start Campaign checkpoint.
- `docs/STANDARD_KEYS_0_6_27.md` — standard keys, single press.
- `docs/SPEECH_CONVENTIONS_0_6_25.md` — NVDA-style speech.
- `docs/LORD_SELECT_0_6_23_TEST.md` — lord selection.
- `docs/LORD_REFRESH_0_6_21_TEST.md` — automatic refresh.
- `docs/LORD_READER_0_6_18_TEST.md` — the confirmed `string.find` root cause.
- `docs/FRONTEND_AUTOMATION.md` — the opt-in automation channel protocol.

Accepted installed build/rollback: **0.6.28**. Candidate **0.6.31** is in source
and packaging, unpromoted. The owner requested a stopping point: 402 Lua scenarios
and package/client checks pass, but no 0.6.31 live campaign has run. All owned
test processes and flags are absent. Campaign scheduler availability, HUD gating
and fresh capture still require live verification. See the 0.6.31 handoff.
Previous 0.6.30 captured early with read/type issues; 0.6.15–0.6.17 are failed
candidates. Preserve existing rollback archives and do not auto-start another
campaign under the earlier consumed one-campaign approval.

**Never register a `real_timer` from inside a timer callback** (it froze the game's timers); use one repeating timer.

**Never call `string.find` in the runtime.** In WH2 the plain form returns nil
for a match and then makes `string.sub` return numbers (confirmed live). Use
`starts_with` / `string.sub`.

## Building and testing

- Python: use the `py` launcher (`py -3`). Bare `python` on this machine is the
  Microsoft Store stub and fails. Build scripts auto-detect Python when
  `-Python` is omitted.
- Build the current runtime:
  `powershell -File tools/build-graphics-preview-windows.ps1`
  (runs `tests/check_graphics_preview.py`, packs, round-trips, packages to ZIP).
- Lua tests run on `local/tools/lua-5.1.5-windows`. Stock Lua is not the game
  engine: WH2 uses single-precision numbers and may differ in string behaviour.
  A fixture pass is not live proof.
- Read desktop logs and game processes outside the sandbox; sandboxed reads can
  show stale files and miss the game process.

Owner goal: a playable keyboard prototype a blind friend can try, then use his
feedback on controls. Prefer keyboard routes over moving the mouse pointer.

## Speech and input conventions

Follow NVDA conventions (JAWS later): `name, role, value, states, N of M`; the
screen name once on arrival; short messages; no engine words or developer
detail in speech. See docs/SPEECH_CONVENTIONS_0_6_25.md. Keys: arrows/Tab/Home/End/Enter/Space/
letters via the companion (`-MenuKeys`); Escape and Shift+Tab (Steam overlay)
are never taken. Activation is one press; Start Campaign always asks first.
See docs/STANDARD_KEYS_0_6_27.md.

## Live test scripts (`tools/live/`)

Each takes `-Version 0.6.x` and/or `-Evidence work/live-<version>-<topic>`:
`Install-Build` (backup + install + hash check; `-Upgrade` installs over the old build like a player) → `Start-Session -Direct`
(lease, companion, launch with TWMM's mod list) → `Wait-Game` (records owned
PID, waits for endpoint) → `Capture-Screen` (confirm main menu) → `Reach-Lord`
→ `Capture-Screen` (confirm Select Lord) → `Test-LordReader` → `Test-LordSelect`
→ `Test-Speech` → `Stop-Session`
(revoke lease, copy evidence, close only owned processes).
Campaign tests: `Start-Session -Direct -CampaignDiscovery` (backs up saves),
`Test-StartCampaign`, then `Campaign-ReadOnly.ps1 -Action Status|Capture`.
The Codex app may work in this repo in parallel; check `git status` first.
`Start-Session -StringFindProbe` runs the string.find probe (separate launch).
`Start-Session -Direct` skips the three startup movies by default: it writes
`work/skip-intro/test_mods.txt` that also loads `jaws_skip_intro.pack` (empty
`movies/startup_movie_01-03.ca_vp8`, built by `Build-SkipIntro.ps1`). The game
folder and TWMM's profile are untouched; `-WithIntro` plays them. Without the
skip the endpoint reports ready while the movies are still playing (menu ~8 s
later), so always confirm the main menu on screen. The spoken "ready" waits
for the menu (since 0.6.61: the key timer does not tick during movies). `Watch-Startup.ps1` records
startup screenshots.
`Flyover-Run.ps1` (one timed campaign start + screenshot) and `Zoom-Stress.ps1` (repeated
camera jumps, checks the reader keeps ticking) test the silent-reader fix;
`campaign-reader-off.flag` in %LOCALAPPDATA%\JawsWarhammer2 switches the campaign reader off for comparisons.
`tests/replay_capture.lua <work/.../native-ui-campaign-discovery.jsonl> [run] [next-run]`
replays a recorded campaign screen through the reader offline and prints every item as
spoken (no run: lists runs); use it to check reading changes against real captures.
Player-mode checks (no lease, like the friend): `Test-PlayerLaunch.ps1 -Evidence ...` runs the installed
companion's launch alone (game starts with `nvda_mods.txt`, no TW Mod Manager); then start the companion
with `-MenuKeys` and drive with Send-Keys. Developer verify mode turns HUD reading on itself; players get
it on by default since 0.6.60. Main-menu and Select Lord checks must not depend on this PC's exact screen.
`Click-Screen -X -Y [-MoveOnly]` stands in for a user's mouse (physical pixels =
Capture-Screen pixels x2). Never click Start Campaign or the intro-content
notice's confirm button, which overlaps it.
The owner approved direct launch (`-Direct`) instead of clicking PLAY in TWMM.

## Driving the game

- Injected keystrokes do **not** reach the game, but they do reach the companion's
  menu keys: `tools/live/Send-Keys.ps1 -Keys Down,Enter,T` (click the game's
  title bar first so it has focus). For scripted checks, use the opt-in
  automation channel (`Automation.ps1 -Action
  Enable/Status/Next/Previous/Discover/Activate/Disable`), not key injection.
- Check the screen with `tools/live/Capture-Screen.ps1` and read the PNG when
  no computer-use tool is available; use computer use (if present) only to
  verify the screen and operate Steam / TW Mod Manager.
- Logs: `%LOCALAPPDATA%\JawsWarhammer2\native-ui-graphics-preview.log`,
  `native-ui-lord-discovery.jsonl`, `bridge.jsonl`.

## Autonomous build, launch, and testing workflow

### Default launch configuration

Steam launches Warhammer II through **TW Mod Manager (Early Access)** by
default. This is the required launch method for automated testing.

- Do not use "Play Game (Skip Launcher)" unless explicitly requested.
- Do not repeatedly change Steam launch preferences.
- Do not recreate or modify the mod profile unless verification fails.
- Use the existing working mod configuration whenever possible.

### Mod Manager procedure

1. Wait for TW Mod Manager to appear.
2. Identify the installed `jaws_access.pack`.
3. Verify the current mod is enabled.
4. Verify that exactly one valid accessibility mod is activated.
5. If a stale entry is marked "Missing," remove only that profile reference
   after confirming the valid entry.
6. Preserve DirectX 11.
7. Click the green PLAY button once.
8. After the splash screens an intro video plays; Escape skips it when the
   game accepts input (injected Escape has not worked reliably).
9. Wait for the actual game process and main menu. UI readiness alone does not
   prove the video ended.

Do not confuse closing the launcher with successfully launching the game.

### Autonomous development loop

When autonomous testing is authorized:

1. Inspect the relevant source files.
2. Implement the required changes.
3. Build the updated project and verify the build succeeded.
4. Stop the game when necessary.
5. Install the updated accessibility components (keep a pre-install backup).
6. Enable an automation lease with the game closed.
7. Launch through Steam and TW Mod Manager.
8. Navigate to the relevant test screen.
9. Test functionality; capture logs and diagnostic evidence under `work/`.
10. Identify failures and make corrections.
11. Repeat until tests pass or a genuine blocker is identified.

Do not request approval between ordinary development iterations within the
authorized scope.

### Reliability and recovery

- Prefer detecting windows and processes over fixed delays.
- Verify each major transition before continuing.
- Never repeatedly click a control without checking the resulting state.
- If the same launch step fails twice, investigate rather than retrying blindly.
- Preserve the last known working build (0.6.63; before it 0.6.62) as the rollback.
- Do not delete game saves or unrelated configuration files.
- Distinguish launcher failures, mod-loading failures, game crashes, and
  accessibility integration failures.
- Never claim successful testing without verifying actual game behavior. A
  build, an acknowledgement, a native click return or NVDA code 0 alone is not
  proof.
- After every session: disable the lease, close owned game/companion processes
  (verify PID plus executable path before stopping), leave NVDA untouched.

### Blocked actions

Ending a turn makes the game autosave (save_games); tell the owner.
Lord selection and Start Campaign (always confirmed) are unblocked (owner,
October 29). Before a live campaign start, back up save_games and
advice_history. Campaign HUD buttons and tabs are allowed (End Turn/Quit/Exit/Load confirmed).
Changing settings, map/army orders, gameplay and co-op
stay blocked unless the owner explicitly unblocks them.

### Completion criteria

A test cycle is complete only when:

1. The updated build was installed successfully.
2. Warhammer II launched with the correct accessibility mod.
3. The expected game screen was reached.
4. The intended accessibility behavior was tested.
5. Results and any remaining issues were documented in `docs/`.
