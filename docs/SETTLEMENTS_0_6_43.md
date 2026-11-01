# Settlements by keyboard 0.6.43 — October 29, 2026

Owner's choice after the first playable turn: settlements (army movement
later). Still no map or army orders.

## What changed

- **Province rows** (`row_entry_<province>` in the Provinces tab) are one
  item each, NVDA style: "Straits of Lothern, list item, 520, Contested
  province, Public Order: Neutral, Building upgrades available, 70 of 83".
  The row's parts (`region_name`, `income`, `mon`, `icon_public_order`,
  `upgradable`) are folded into it. Enter clicks the row: the game zooms to
  the province and opens its settlement panel.
- **Buildings** (the element inside each `building_slot_N`, and the upgrade
  chain in `construction_popup` → `slot_parent`) are buttons named from the
  game's own text: `effect.get_localised_string('building_culture_variants_name_'
  .. key)` (the call the game's UI library uses), falling back to the key.
  Empty slots are "Construction slot". Value = settlement name; states:
  built / locked / not owned / "Population surplus cost N[, not enough]" /
  "Building upgrades available"; units the building recruits are read last
  ("Units: Spearmen, Archers"). Settlement names (`dy_province`), list titles
  and the settlement panel title are headings; sort buttons are buttons.
- **Build asks first**: an available upgrade in the popup says "Build Lothern
  (Elven Village)? Press Enter again to confirm."; locked ones say "… is
  unavailable." Abandon / disband / raze / demolish / dismantle buttons also
  ask first (the popup has "Click to abandon this settlement").
- **After every click the reader re-reads once** (2 s later), so changes
  deeper than the panel watch (the Provinces list) are announced. If nothing
  changed it stays quiet on the same item; if something closed it says
  "Screen updated." and stays put. New items are found by element IDs and
  names, not child positions, so a panel added at the root no longer makes
  every item "new"; the reader starts at the first new heading, then text.
- Activation still checks HUD identity, path + ancestor IDs, leaf ID and
  state (now also refusing `not_owned`); one `SimulateLClick` call site.
- Harness: 45 campaign scenarios (+3: rows and settlement panel, popup with
  build confirmation / locked / abandon, missing game text).

## Live (0.6.43, intro box unchecked, everything after Start Campaign by keys)

P → "Provinces, tab" → Enter → "Provinces activated." "Screen updated."
"Provinces, heading, 46 of 83". Down/letters read all 11 rows (above).
S → Straits of Lothern → Enter → the game zoomed and opened the settlement
panel; "Screen updated." "Lothern, heading". Slots: "Lothern (Elven Hamlet),
button, Lothern, Building upgrades available", "Straits of Lothern, button,
Lothern", "Militia Camp, button, Lothern", "Construction slot, button,
Lothern, locked" (×2), then Tower of Lysean / Glittering Tower buildings.
Enter on Lothern (Elven Hamlet) opened its upgrade chain: "Lothern (Elven
Hamlet), button, built, …, Units: Spearmen, Archers"; "Lothern (Elven
Village), button, Population surplus cost 1"; Town / City / Spired Citadel
"locked, … not enough". Enter → "Build Lothern (Elven Village)? Press Enter
again to confirm." → Enter → "Lothern (Elven Village) activated." The game
started the upgrade: treasury 6000 → 4000, growth target 600 → 200, the slot
now reads "Lothern (Elven Village), button, Lothern, Construction turns
left". Four native clicks in total (tab, row, building, build). No turn
ended, no saves written. Evidence: `work/live-0.6.43-settlements-2`
(discovery logs, screenshots). Discovery of the IDs: `work/live-0.6.42-provinces-2`.

The 0.6.42 campaign-start stall did not recur: both runs passed the flyover
to the HUD (~100 s). The intro check box was already unchecked on Select
Lord in both runs, so no click was needed.

## Known gaps (next)

- Reading order is breadth-first: the three settlement headings come before
  all buildings (each building names its settlement), the Other Provinces sort
  buttons sit between the Lothern row and the other rows, and the minimap's
  settlement icons ("Settlement: Lothern Owner: Eataine") come before rows.
- After opening the upgrade popup the reader starts at its Abandon button
  (safe: it asks first); after building it starts at the new growth value.
  Better: start at the popup's first building / the changed slot.
- Money cost is only in the game's hover tooltip; only the population
  surplus cost is read. "Construction turns left" lacks the number.
- Recruiting not tested live: Recruit Lord / Recruit Hero are ordinary
  buttons in the HUD (already activatable); their panels are unread.
- A list opened by the mouse deeper than three levels is not announced
  automatically (Shift+F3 re-reads); keyboard clicks re-read.
- Physical keys still unverified (injected keys reach only the companion).

## 0.6.44–0.6.45 (in progress, installed, not yet accepted)

- 0.6.44: popup/build focus prefers heading → building/row → text; "under
  construction, N turns left"; each settlement's buildings follow its heading;
  minimap icons last; buttons with "recruit" in the ID ask first. Live: the
  reader's timer event was lost mid-scan after selecting a province (silent,
  no error) — the same cause as the 0.6.42 "flyover stall".
- 0.6.45: a watchdog timer re-arms the reader when ticks stop; Shift+F3 also
  re-arms. Harness 47. Live: Provinces → row → settlement panel announced;
  new building order confirmed. Not yet heard: focus after opening the
  upgrade popup, build focus, turns-left number, Recruit Hero panel.
  Evidence: work/live-0.6.44-settlements, work/live-0.6.45-settlements.
  Accepted rollback stays 0.6.43.

### Blocker found (0.6.45 live, October 29 evening)

The building upgrade popup (`construction_popup`) is hover-bound: the game
closes it as soon as the mouse pointer is not over the building or popup.
The mod's click opens it, but it closes at once unless the pointer happens
to be there. In the 0.6.43 run the pointer was by chance over the popup
area (a map hover tooltip at that spot is visible in its screenshot), which
is why building worked; in three 0.6.45 attempts it did not open by keyboard.
A real test mouse click on the slot opened it; moving the pointer away
closed it (screenshots in `work/live-0.6.45-settlements-3`). In one session
a ChatGPT/Codex always-on-top, click-through overlay (0,0–467,1080) was also
on screen and real clicks did nothing; without it they worked.
Options: the companion moves the pointer onto the building when it is
activated (needs the element's screen position: Position()/Bounds() plus the
game window's client rectangle); or find another construction path.

## 0.6.46–0.6.49: building and recruiting by keyboard (accepted 0.6.49)

- **Upgrade list (0.6.46–0.6.47).** Because the popup closes when the pointer
  is not over it (owner preferred not to move the mouse), Enter on a building
  clicks it and reads the popup's options in the same moment, then offers them
  as a list: "Upgrades for Lothern (Elven Hamlet), 5 options." then "Lothern
  (Elven Village), button, Population surplus cost 1, 2 of 6" … "Close
  upgrades". Arrows/Home/End/letters move in the list; Enter on an option asks
  "Build …? Press Enter again to confirm."; the second Enter reopens the popup
  and clicks that option in one step (the option and its state are re-checked
  first). Re-reads behind the list stay quiet (0.6.47 fix: the first try
  closed the list on the post-click re-read).
- **Timers (0.6.48).** Live 0.6.47: both the reader timer and the watchdog
  stopped together after a province zoom. Game events that happen anyway
  (panels opening/closing, clicks, mouse-over, settlement/character selection,
  any shortcut) now restart them after 3 s without a tick; Shift+F3 too.
- **Recruit Lord (0.6.49).** Lord types (Legendary Lords / Prince / Princess)
  are tabs; candidates (`general_candidate_N_`) are list items: "Cavill, list
  item, Prince, Fay, rank 1, upkeep 213, cost 825"; an unavailable one says
  why ("unavailable, influence 30, … Cannot recruit Lord. You have
  insufficient influence."). `button_raise` is "Recruit, button" and asks
  first. Recruit Hero opens and reads ("No characters currently available."
  in Lothern on turn 1).
- Harness: 50 campaign scenarios.

Live (pointer left on the title bar, everything after Start Campaign by keys):
0.6.48 — P → Provinces → S → Straits of Lothern → L → Lothern (Elven Hamlet)
→ "Upgrades for Lothern (Elven Hamlet), 5 options." → Enter, Enter →
"Building Lothern (Elven Village)." Treasury 6000 → 4000; "Screen updated."
"Lothern (Elven Village), button, Lothern, under construction, 3 turns left".
0.6.49 — R → Recruit Lord → "Legendary Lords, tab, selected" → Prince tab →
"Cavill, list item, …, cost 825" → Enter (selected) → R → "Recruit, button"
→ Enter → "Recruit? Press Enter again to confirm." → Enter → "Recruit
activated." Treasury 6000 → 5175, income 1901 → 1658, Cavill's army appeared
at Lothern; "Screen updated." "Cavill Prince". No army orders, no turn ended,
no saves. Evidence: `work/live-0.6.48-upgrades`, `work/live-0.6.49-recruit`.

Still open: after recruiting, the game selects the new army (army orders stay
blocked); the built building in the upgrade list shows a stray "Population
surplus cost 8"; the Other Provinces sort buttons and minimap icons; physical
keys unverified.

## 0.6.50–0.6.51: intro check box by keyboard; player guide (accepted 0.6.51)

- Select Lord: "Enable campaign introduction, check box" toggles with Enter
  (same identity checks as lord portraits): "Enable campaign introduction,
  checked" / "not checked". The reader returns to the check box afterwards, so
  Enter again or an arrow continues from it (0.6.50 lost the place).
  Live 0.6.51: Enter → checked (screenshot), Enter → not checked, Down →
  "Race Attributes, heading, 5 of 49". Evidence: `work/live-0.6.51-prelude`.
- The ZIP's README.txt (`packaging/interactive/GRAPHICS_PREVIEW.txt`) is now a
  player guide for the first outside tester: install, keys, starting a
  campaign (uncheck the introduction), campaign map keys (Shift+F2 for HUD
  reading), things to try (provinces, build, recruit, skip, end turn), what is
  not supported, and what to send back.

## 0.6.52–0.6.55: armies read (no orders); timer restart fixed (accepted 0.6.55)

Owner's answer "continue with whatever you think" was not taken as an unblock
of army orders; this adds reading and selection only.
- Lords & Heroes rows (`character_row_N`): "Tyrion, list item, Legendary Lord,
  116 soldiers, faction leader, rank 1"; Enter selects the lord (the game zooms
  to him and opens his army panel).
- Army panel: the lord's name is a heading; unit cards (`LandUnit N`,
  `NavalUnit N`) follow it as read-only items: "Spearmen, list item, Spear
  Infantry, strength 30[, rank N]". Group members (buildings, unit cards) are
  now placed after their heading even when they come first in the tree.
- Timer restart: os.time() is useless in the game's single-precision numbers
  (steps of ~2 minutes), so the 0.6.48 event restart could almost never fire.
  It now uses os.clock() (logged `"os_clock":true`), falling back to "two
  events with no tick between".
- Harness: 51 campaign scenarios (+ units-before-heading order).

Live: 0.6.54 — the reader stopped again right after selecting Tyrion (zoom),
all timers silent; a hover and a click did not restart it (the os.time bug).
0.6.55 — Lords & Heroes → Tyrion → "Screen updated." "Tyrion, heading", then
the seven units in order, "Unit count, 7/20". No timer loss in that run, so
the restart path is verified by the harness only. Evidence:
`work/live-0.6.51-armies` (IDs), `work/live-0.6.54-armies`,
`work/live-0.6.55-armies`.

Open: why the game drops all of the mod's timer events after some zoom-to
actions (about 1 in 3 runs) is unknown. A blind player who sits still has no
event to restart it except a game shortcut (Shift+F3, physical keys only);
whether ShortcutTriggered still arrives in that state is unverified.

## 0.6.56–0.6.58: the silent reader (accepted 0.6.58)

Symptom: after some camera jumps (Enter on a province or lord row) and during
some opening flyovers, the reader went silent for good. In the flyover case the
game's own flyover froze on one frame too (game responding, CPU busy), so the
game's script timers stopped together with the mod's.

Findings:
- Not the log budget, not a Lua error (none logged), not window focus (focusing
  or clicking the game did not resume it).
- With the campaign reader switched off (test-only `campaign-reader-off.flag`
  in %LOCALAPPDATA%\WarhammerAccess), 4 of 4 campaign starts finished the
  flyover (`work/flyover-compare/off-1..4`). With the reader on, about 2 of 18
  earlier starts froze. Suggestive, not conclusive on its own.
- The reader re-registered its next single-shot `real_timer` from inside the
  timer callback, every tick. The game's own campaign scripts never use
  `real_timer` (they use model callbacks). Likely cause: registering a timer
  while the game is dispatching timers occasionally wipes the timer list,
  which also stops the game's scripted flyover camera.

Fix (0.6.57): the game offers `real_timer.register_repeating` (logged
`"timer":"repeating"`), so one 100 ms repeating timer and one 3 s watchdog are
registered once at start; nothing is registered from inside a callback (slow
work runs every tenth tick). Recovery paths (watchdog, game events, Shift+F3)
restart it only when ticks have stopped. Single-shot remains as a fallback.
0.6.58: the developer log restarts at 1 MiB like the player log (the 2 MiB cap
would otherwise stop long test sessions).

Live: 0.6.57 — two fresh sessions, two flyovers and 20 camera jumps
(`tools/live/Zoom-Stress.ps1`), no silence, no restart needed
(`work/live-0.6.57-timer`, `work/live-0.6.57-timer-2`). The old build went
silent after roughly one jump in five to eight. 0.6.58 — flyover plus two jumps
(`work/live-0.6.58-check`). Harness: 52 campaign scenarios (+ repeating timer
registered once, never from a callback).

Still possible but not seen since: if it ever happens, Shift+F3 (physical key)
restarts the reader; the friend's guide asks him to report it.

## 0.6.59: reading order and figures (accepted 0.6.59)

Found with a new offline replay, `tests/replay_capture.lua <discovery.jsonl>
[run] [next-run]`: it rebuilds a recorded screen from the discovery log, runs
the reader on it (stock Lua, file access stubbed) and prints every item as
spoken; with a second run it swaps the screen and prints what the re-read
announces. Every capture from 0.6.48–0.6.58 was replayed.

- **Document order.** Items are read in tree order (each panel's title, text
  and buttons together) instead of breadth-first. A title is read before the
  elements beside it ("Your Provinces" sits after its rows in the tree;
  "Recruit Lord" sits in a title plaque after its list). Group rules
  (buildings after their settlement, units after the army heading, minimap
  last) still apply.
- **Arrival** starts at the title of the top-most open panel ("Campaign map,
  53 items." "How They Play, heading, 44 of 53"), else at the first item.
- **Province figures** are one item each: "Growth, 0/600 (+20)", "Turns until
  surplus point, 30", "Population Surplus, 1", "Income, 520", "Public order,
  0 (-1), Neutral", "Untainted, 100%". Section titles (`header_frame`) are
  headings with their explanation as the description; "Left-click to open
  Help pages." is dropped.
- **Tax Province** is "check box, checked/not checked", read only (toggling
  taxes is not unblocked).
- **Unit stats were mispaired** (0.6.49 live said "Leadership, 36" where the
  screen showed 80, because a bare number joined the item before it). Each
  stat (`dynamic_stats/statN`: name, number, modifier icons) is now one item:
  "Armour, 80, Shielded, …, How resistant a unit is …". Upkeep reads "Upkeep, 213".
- A button's own label element is not a second item (no more "Txt, button" /
  "Recruit" after "Recruit, button"); "Raise army||…" descriptions read
  "Raise army. …". A sentence tooltip on a text item is its description
  ("Armoured & Shielded, …, Armoured units can block …").
- Harness: 53 campaign scenarios (+ the above with IDs from the captures).

Live (0.6.59, `work/live-0.6.59-order`, everything after Start Campaign by
keys): arrival "How They Play, heading, 44 of 53" → Down reads Eataine, the
body, Accept. Provinces → "Provinces, heading" → "Your Provinces, heading",
three sort buttons, "Straits of Lothern, list item, …". Enter → "Straits of
Lothern, heading". G → the figures above, exactly as listed. Recruit Lord →
"Recruit Lord, heading, 6 of 118", "Recruit, button"; stats matched the
screenshot (Armour 80, Leadership 80, Speed 36, Melee Attack 60, Melee Defence
60, Weapon Strength 400, Charge Bonus 30). Lords & Heroes → "Lords & Heroes,
heading" → Tyrion → "Tyrion, heading", units. No orders, no turn ended, no saves.

Still open: "Unresolved events, 1" sits apart from "You have an unresolved
event!"; long names on some HUD buttons (Sword of Khaine); physical keys
unverified.

