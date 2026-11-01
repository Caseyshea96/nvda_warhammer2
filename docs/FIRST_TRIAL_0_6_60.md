# First outside trial fixes 0.6.60 — October 30, 2026

Feedback from trial run 1 on the owner's friend's PC (0.6.59):

1. New Campaign said "Could not verify this screen. Press F2 and try again."
2. Continue Campaign said "Not supported yet." (Enter and Space alike.)
3. TW Mod Manager is hard to use with NVDA to start the game with the mod.

## Causes

- **Main menu / Select Campaign activation compared the whole screen with a
  recording from this PC**: exact node counts (main menu 86/87, Select
  Campaign 167/168) and every label, tooltip and state. Any other PC (DLC,
  saves, news banner, version, language) fails, so New Campaign was refused.
  Select Campaign was also classified "not supported" unless the root had
  exactly the children and particle effects seen here.
- Continue Campaign (`button_start_campaign`) was not an allowed target.
- The companion's launch used `steam://rungameid/594570`, which opens TW Mod
  Manager.

## Changes

- **Identity check instead of a recording** (`activate_player_target` in
  `diagnostics/graphics_preview.lua`): on the main menu and Select Campaign the
  selected element is clicked when its ID is allowed (`button_new_campaign`,
  `button_start_campaign` = Continue Campaign, `button_graphics`,
  `button_next` = Continue) and, read again at the press, it is the same
  element: same IDs and addresses on its path, every read on the path
  successful, visible, same label and tooltip, interactive and `active`; no
  visible or unreadable extra root panel (a dialog); and nothing read on the
  screen changed between the selection read and the press read (a DLC purchase
  panel appearing, a changed selection or title cancels). Not compared:
  visibility of unnamed particle effects, the tooltip/news layers' contents.
  A lookalike element elsewhere is never the target (the selected path is).
  Mortal Empires selected (remembered by the game) may continue.
- Select Campaign is supported unless a visible extra panel is on top.
- Continue Campaign loads the latest save; "Continue Campaign is unavailable."
  when there is none. Load Campaign stays "Not supported yet." (its save list
  is not read).
- **Campaign HUD reading starts on for players** once the map is read
  (`"source":"player-default"`); Shift+F2 still switches to map controls and a
  player's choice is kept. Before, a player had to know Shift+F2 before any key
  read the HUD (developer verify mode had hidden this in every live test).
- **One-step launch without TW Mod Manager** (`Launch-Game` in
  `companion/Companion.ps1`, used by the desktop shortcut / Start Pilot.cmd):
  writes `%LOCALAPPDATA%\WarhammerAccess\nvda_mods.txt` (`add_working_directory
  "<game>/data"; mod "warhammer_access.pack";`) and starts `Warhammer2.exe` with it
  and `; -dx11`, the command line TW Mod Manager's Play uses. Says "Starting
  Warhammer with the accessibility mod. The intro movies play first; Escape
  skips them." Needs Steam running and the installed pack; otherwise it falls
  back to Steam and says to tick warhammer_access in the Mod Manager. Only the
  accessibility mod is loaded this way. The launch button is "Launch game".
  As before, the game is launched only after NVDA speech is confirmed.
- Player guide and installer messages updated.
- Harness: 383 frontend scenarios (old exact-template expectations changed to
  "allowed on another PC, blocked when it changes between presses"; + other-PC
  main menu, Continue Campaign active/unavailable, Load Campaign, replaced
  element), 53 campaign scenarios (+ player default reading).
- `tools/live/Test-PlayerLaunch.ps1` runs the installed companion's
  Launch-Game alone (speech stubbed) when NVDA is not running.

## Live (0.6.60, player mode: no test lease, real menu keys)

NVDA was not running on this PC. Start Pilot.cmd (the desktop shortcut's
command) correctly refused to launch without speech ("The RPC server is
unavailable"). Test-PlayerLaunch then ran the installed Launch-Game: the game
started as `Warhammer2.exe "...\nvda_mods.txt" ; -dx11`, no TW Mod Manager
window; main menu after ~170 s (intro movies). Evidence:
`work/live-0.6.60-trial`, `work/live-0.6.60-trial-2`.

- Main menu → Down, Down → "Continue Campaign, button, 2 of 22" → Enter →
  "Continue Campaign activated." → the latest autosave loaded → "Campaign map,
  45 items." "Event Messages, heading".
- Relaunch → Down, Enter → "New Campaign activated." → "Select Campaign. The
  Eye of the Vortex, radio button, checked, 1 of 17" → Continue → "Select
  Lord" → Start Campaign (asked first) → ~5 min later (intro movie + flyover)
  "Campaign map, 53 items." "How They Play, heading, 44 of 53" with HUD reading
  already on → Down read the dialog → A → "Accept activated." "Mission
  Issued!, heading". No turn ended; save count unchanged (2).

## Still open

- ~~"Warhammer accessibility ready" is spoken while the intro movies still play.~~
  Fixed in 0.6.61 (below).
- The friend's PC is untested: these checks are tolerant by design, but his
  menu's IDs/paths have not been seen. If anything fails, his
  `native-ui-graphics-preview.log` shows the reason (`activation.player_target`).
- Steam not running falls back to TW Mod Manager.
- Physical keys (Shift+F2/F3, Escape) unverified by automation.

## 0.6.61: "ready" waits for the main menu

The startup message was spoken when the script loaded, during the copyright
splash, up to three minutes before the menu (the long intro cinematic plays on
some launches and not others).

Probe (`work/live-0.6.61-startup`, `-startup-2`): during the movies the menu
tree is already built and reports itself visible, so the screen cannot tell
them apart. The key timer, though, does not tick at all while a movie plays
(none for the whole cinematic) and ticks about ten times a second on the menu;
the first ticks came between the last movie frame and the menu.

Change (`announce_ready` / `ready_tick` in `diagnostics/graphics_preview.lua`):
the message is spoken after 15 key-timer ticks with no gap of two seconds or
more between them (about 1.5 s of menu). A pause restarts the count; a key
press before then counts as ready (no late message); with no key timer it is
spoken at load, as before. Logged as `startup.ready`. Harness: 388 frontend
scenarios (+ not at load, 15 ticks, pause restarts, one-second steps, clock
failure, no timer).

Live, player path (companion started with the desktop shortcut's arguments,
NVDA running, intro movies on; `work/live-0.6.61-ready`, `-ready-2`,
speech-trace.jsonl):

- Short intro: logo movie on screen 16:32:28, menu by 16:32:32, "ready"
  16:32:32.8. Down, Down: "Main menu. New Campaign, button, 1 of 22",
  "Continue Campaign, button, 2 of 22".
- Long cinematic: cinematic on screen 16:36:28, menu fading in 16:36:33,
  "ready" 16:36:34.8 (three minutes after launch). Down: "Main menu. New
  Campaign, button, 1 of 22".

Not changed: the automation endpoint still reports ready during the movies
(test scripts must still confirm the menu on screen).

## 0.6.62: Select Lord without this PC's exact layout

Select Lord (`lord_context` in `diagnostics/graphics_preview.lua`) still had
the exact-layout checks that broke the main menu on the friend's PC: root 5–8
children, exactly one hidden `browser` layer, no other extra layer even hidden,
and the `sp_grand_campaign` panel with exactly 6 children. Any difference (no
news browser, a hidden DLC layer, an extra panel child) would leave Select Lord
unread and Start Campaign unusable.

Now: root `root` and visible with 3–32 children; extra root layers (index 4
on) may be anything hidden, or a visible `Tooltip`/`tooltip_*`; a visible
other layer (a dialog, or the web browser shown on top) or an unreadable one
blocks, as before; the panel must be `sp_grand_campaign`, visible, with at
least one child. Unchanged: the panel is root child 2 (from the game's layout
files, as for every frontend screen), reading must complete without errors to
choose, and every activation re-resolves its path by ID and checks state.
Rejections are still logged as `lord.context_reject`.

Harness 394 frontend scenarios (+ no browser layer, hidden extra layers and a
second browser, an extra hidden panel child — each reads and starts after the
confirmation; a visible dialog layer and an unreadable layer block; a dialog
appearing after the first Start Campaign press stops the start).

Live (player path, NVDA, `work/live-0.6.62-lord`): ready 16:50:19 after the
movies → Down, Enter: "New Campaign activated." → "Select Campaign. The Eye of
the Vortex…" → Continue → "Select Lord. Select Lord, heading, 1 of 49", "Start
Campaign, button, 2 of 49", "Selected lord: Tyrion, 3 of 49", the introduction
check box (on screen: unchecked) → Enter on Start Campaign: "Start the campaign
as Tyrion, High Elves, Eataine? Press Enter again to start." → Down cancelled
it. No campaign started; dispatches were New Campaign and Continue only.

## 0.6.63: trial run 2 — the update never installed

Trial run 2 on the friend's PC (given 0.6.62) reported the trial-1 messages
word for word: New Campaign "Could not verify this screen. Press F2 and try
again.", Continue Campaign "Not supported yet." Neither can come from 0.6.60
or later: on the main menu Enter goes to `activate_player_target`, which never
says "Could not verify", and Continue Campaign is an allowed target. His game
was still running 0.6.59.

Cause: `packaging/pilot/Install.ps1` refused to replace any `warhammer_access.pack`
whose checksum differed from the new one ("A different warhammer_access.pack
exists…"), and any App file that differed. Every earlier version differs, so
installing a new ZIP over the old one always failed and left the old build in
place; the guide said "INSTALL (once)" and did not say to uninstall first.
Live tests here never saw it because `Install-Build.ps1` uninstalls first.

Changes:

- The installer upgrades its own earlier install in place: the old pack must
  match `receipt.json` (same game folder), each old App file must match the
  old `App\manifest.json`. A pack or file it did not install, or one changed
  since, is still refused (message says what to do). The new pack is copied
  beside the old one, verified, then swapped. It prints "Upgraded from version
  X to Y." (or "Installed version Y.").
- The spoken ready message carries the version: "Warhammer accessibility
  0.6.63 ready. Arrow keys move, Enter activates." so a tester can tell which
  build runs. Guide: "INSTALL OR UPDATE", correct shortcut name ("Warhammer
  NVDA Pilot"), ask to mention the number in feedback.
- `tests/check_installer.py`: upgrade over a faked older install (pack and
  companion replaced, no leftover `.new`, receipt updated, other packs kept);
  a receipt for another game folder and a hand-edited old companion are
  refused with the old pack kept.
- `tools/live/Install-Build.ps1 -Upgrade` runs the shipped installer the
  player's way (no uninstall, game folder auto-detected).

Live (`work/live-0.6.63-upgrade`): `Install-Build -Version 0.6.63 -Upgrade`
over the installed 0.6.62 in Program Files: "Upgraded from version 0.6.62 to
0.6.63.", pack hash checked, backup `work/preinstall-0.6.63-a65cdddb`. Then the
player launch (`Test-PlayerLaunch`, NVDA not running so speech from
speech-trace.jsonl; game `Warhammer2.exe nvda_mods.txt ; -dx11`): "Warhammer
accessibility 0.6.63 ready. Arrow keys move, Enter activates." ~95 s after
launch with the menu on screen → Down: "Main menu. New Campaign, button, 1 of
22" → Enter: "New Campaign activated." → Down: "Select Campaign. The Eye of
the Vortex, radio button, checked, 1 of 17". Owned game and companion closed.

For the friend: run the 0.6.63 ZIP's Install.cmd (it replaces 0.6.59 in place;
no uninstall needed), then the desktop shortcut. "ready" should say 0.6.63.

Still per-PC: the named-field labels ("Selected lord:", "Race:", "Faction:",
difficulties) and the start prompt's names use fixed paths; if a PC's layout
shifts them, items are still read but without those prefixes, and the prompt
says "Start the campaign?" without names.
