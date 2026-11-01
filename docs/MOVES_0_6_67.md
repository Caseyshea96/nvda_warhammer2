# Lords, settlements and moving armies 0.6.67 — November 1, 2026

Owner request (Nov 1): "a button that I can toggle between cities and
generals like pressing F6 … for movement a list would work best … within
one turn: the settlement". This unblocks army **movement**. Attacks stay
blocked (enemy settlements are listed, Enter says "Attacking is not
supported yet."); battles are to be auto resolved (owner decision).

## Keys (campaign map, HUD reading on)

- **F6** switches between a lord and his settlement. From a settlement (or
  nothing) it selects the nearest lord with an army, else the faction leader;
  from a lord, the settlement he stands in, else the nearest one you own.
  It clicks the row in the game's own Lords & Heroes or Provinces list
  (opening the tab first), so the game's selection and panels follow; the
  HUD reader then re-reads ("Screen updated." "Tyrion, heading", units).
  Spoken first: "Tyrion, 7 units, 100 percent movement." / "Lothern, Eataine."
- **Shift+F6** selects the next lord.
- **F7** lists places the selected lord can move to: the 15 nearest
  settlements, those reachable this turn first (the game's own
  `character_can_reach_settlement`), each "Name, button, owner, this turn /
  more than a turn, N of M", then "Close". Arrows, Home/End and letters move;
  Backspace closes. Enter asks first ("Move Tyrion to Lothern? Press Enter
  again to confirm."), the second Enter gives the order.
- Your own settlement: `join_garrison` (enters it). Anywhere else: `move_to`
  on the settlement's spot; if the army has not moved after 3 s, one retry
  2 units outside it, on the side the lord comes from (live: the ruins'
  own spot did nothing, the retry worked).
- The army is watched once a second: "Tyrion arrived at Lothern." /
  "Tyrion stopped on the way to Caledor's Repose, no movement left." /
  "Tyrion did not move."
- Refused: multiplayer ("Not available in multiplayer."), not your turn
  ("Wait for your turn."), no lord selected ("Select a lord first: press F6.").
- Companion: F6, Shift+F6, F7 are new menu keys (actions `lords`,
  `nextlord`, `moves`); only while the reader is on, like the others.

## How orders and model reads run (found live)

1. Model reads and `move_to` called from the reader's timer (`real_timer`):
   the order was accepted but the army never moved ("Lord not moved").
2. `CampaignUI.TriggerCampaignScriptEvent` + a `UITriggerScriptEvent`
   listener: the event never arrived (logged nothing).
3. Inside a game-timer callback (`cm:callback`): **the order is carried out**
   (Tyrion entered Lothern).
4. But registering a game timer from inside the reader's timer callback was
   followed by a freeze, and reading the model from the reader's timer
   during a selection or a march was followed by a "not responding" hang.
   So: **one repeating game timer** (`cm:repeat_callback`, 0.2 s), registered
   once at the first tick, runs a queue of jobs. The reader's timer only
   queues jobs and does UI clicks; all model reads and orders run in the
   jobs. Jobs not run within 3 s are dropped: "The game is busy. Try again."
   (`model-stalled` in the log). Without the game timer (tests) jobs run at once.
5. `tests/check_graphics_preview.py` still forbids the text `cm:` in the
   campaign module; model access goes only through `campaign_game()`.

Logged: `model-pump`, `game-api` (which commands exist: `move_to`,
`join_garrison`, `attack_region`, `attack` yes; `select_character` no),
`move-order`, `lord-state`, `order-run`, `move-watch`, `command-error`.

## Live results (this PC, player path, NVDA not running)

Continue Campaign (pre-rename Eataine save, turn 1). Final build, run
`work/live-0.6.67-moves-11`: F6 → "Tyrion, 7 units, 100 percent movement." →
army panel read; F7 → "Move Tyrion, 100 percent movement, 2 of 15 places this
turn. Lothern, button, yours, this turn, 1 of 16"; Enter, Enter → "Moving to
Lothern." → "Tyrion arrived at Lothern." Run `-12` (same code plus a fallback
that never fired, since removed): F7 → C → Caledor's Repose (ruins) → "Moving
toward Caledor's Repose." → retry outside → "Tyrion stopped on the way to
Caledor's Repose, no movement left." (Correction: F6 lord → settlement was
**not** verified in 0.6.67, and it was broken: see 0.6.68.)
No turn was ended, nothing was saved; the save files are unchanged.

## The freeze / silent reader (not caused by 0.6.67; open)

In 7 of 12 runs today the reader stopped: either the game window went "not
responding" (runs 6, 7, 10; minutes, killed) or the game kept running and only
the mod's timers stopped (runs 8, 9, 11; reader heartbeat dead, restart by a
game event did not help; in run 12 it stalled a few seconds and recovered).
Triggers were camera/selection moments: campaign load, the Lords/Provinces row
click, an army entering a settlement. **0.6.66 did the same** with only HUD
navigation (`work/live-0.6.66-select-check`), so this is the old silent-reader
problem (0.6.44–0.6.58 docs: "after some zoom-to actions, about 1 in 3 runs"),
much more frequent on this PC today. During a stall the companion releases its
keys (heartbeat older than 3 s), so a key pressed then goes to the game (seen:
a second F6 was lost). The game-timer queue reports "The game is busy" if its
jobs wait 3 s. Next: find what stops the game's script timers (both
`real_timer` and model timers stall together).

## Test tooling

- `Test-PlayerLaunch.ps1 -SkipIntro` adds the empty-movies pack to the
  player launch (ready in ~25 s instead of ~3 min of movies).
- `Send-Keys.ps1` knows F6, ShiftF6, F7.
- Harness: 55 campaign scenarios (+2: F6/F7/moves with direct model access;
  the game-timer job queue, one repeating timer, stall message).

## 0.6.68 — review fixes and one-step updates (November 1, 2026)

Code review of 0.6.67 (10 findings), all fixed:
- **F6 lord → settlement was broken live** ("Could not find Lothern in the
  Provinces list."): province rows sit inside sections of the list
  (`list_box` → section → `list_box` → `row_entry_<province>`), not directly
  in it. The row is now found by its ID anywhere in the panel; the harness
  fixture has the real nesting. Live: "Lothern, Straits of Lothern.", the
  settlement panel read, F6 again → "Tyrion, 7 units, 100 percent movement."
  (`work/live-0.6.68-moves-2`).
- Lord rows: full name first; a first name only when exactly one row has it;
  otherwise "More than one lord is called X. Choose him in the Lords &
  Heroes list." (no wrong selection).
- F7 uses the selected lord, else the last lord selected (the game may select
  the settlement after he joins its garrison).
- F4 in the move list goes through the same guard as Enter (an error no
  longer stops the reader).
- A stopped reader also quiets the game-timer job pump.
- A full job queue (16) says "The game is busy. Try again."
- F7 reads only positions for all regions; names/owners for the nearest 15.
- `Read-Speech` skips older lines by comparing timestamps as text.
- Harness: a real error inside a command ("Could not do that.", logged).
- Diagnostic probes (`game-api`, `lord-state`) only with the developer flag.

Keys during a stall: live, the reader's timer stalled after a camera change,
the companion (3 s heartbeat limit) released its keys and two Enters went to
the game (harmless that time: no turn ended, saves unchanged). The companion
now keeps its keys for stalls up to **15 s**; keys pressed meanwhile wait in
keys.tsv and run when the reader resumes. Map controls (Shift+F2) and
leaving the game still release them at once. In the last run the reader
stopped for good ~20 s after the army arrived (the open freeze problem): F6
and F7 were held and never ran.

**One-step update.** The installer now closes the running helper itself
(instead of refusing) and makes a second desktop shortcut, "Warhammer NVDA
Update" (`Update.cmd` → `Update.ps1`). It finds the newest
`warhammer2-windows-<version>-nvda-automation-preview.zip` (also "… (1).zip")
in Downloads (the real Downloads folder) or on the Desktop, says "Updating
from version A to B.", unpacks it to a temporary folder, runs its installer
(every file checked against its manifest) and deletes the temporary folder.
No newer ZIP: "Version A is installed; the newest download is B. Nothing to
update." No ZIP: "No update found. Save the new ZIP …". `Update.cmd` is one
line on purpose (the update replaces it while cmd runs it). Updating from
0.6.67 or earlier still uses the ZIP's Install.cmd once. Live: 0.6.67 →
0.6.68 "Upgraded from version 0.6.67 to 0.6.68.", both shortcuts made;
Update with the helper running → "Closing the accessibility helper." and the
helper gone; no-argument run found an old 0.6.63 ZIP on the Desktop and said
nothing to update (`work/live-0.6.68-update`). Installer checks cover the
update (no ZIP, already current, older install updated) and closing a real
running helper.
