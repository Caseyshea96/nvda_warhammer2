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
Caledor's Repose, no movement left." F6 lord → settlement was verified
earlier (`-moves-4`/`-9`, older order code, same selection code).
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
