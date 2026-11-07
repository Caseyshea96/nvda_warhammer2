# Review fixes — 0.6.75 (November 7, 2026)

Owner (Nov 7): "thoroughly review the entire codebase before next test run",
then "Fix all 13". A high-effort review of the shipped code (both Lua readers,
the companion, the installer/updater) found 13 issues; all are handled.

## Fixes

1. **Pre-battle allow-list.** On `popup_pre_battle` only `button_autoresolve`,
   `button_retreat`, `button_surround`, `button_continue_siege`, `button_save`
   and `button_info` are pressed; any other button (Fight Battle, Scout
   terrain, an unknown sally-out on a defender's or siege panel) says "<name>
   is not supported. Choose Auto-resolve." Before, only two known IDs were
   refused, so another manual-battle button could have started a real-time
   battle.
2. **Keys never released by a file collision.** The companion reads
   `reader-state.tsv` once per tick with full sharing; a locked or half-written
   read keeps the last good contents instead of releasing every hotkey for a
   tick (keys pressed then went to the game).
3. **NVDA reconnects by itself** every 5 s after an error (NVDA restarted or
   started after the helper) and says "Speech reconnected." Before, speech
   stopped until the on-screen reconnect button was pressed.
4. **Results rows.** The reader asks the game (pending battle, in a
   game-timer job when the pre-battle or results panel opens) whether the
   player attacked. Then "Your side … / Enemy side …" (live: the first row is
   the player's when attacking); otherwise "Side 1 … / Side 2 …", since the
   row order when defending is unverified.
5. **Attack watch.** Only a battle panel opening ends it quietly; an attack
   that stops short says "stopped on the way to X, …" or "Tyrion stopped next
   to X; no battle started."
6. **No false "The game is not responding."** on relaunch: a heartbeat
   written before the running game started (a crash, then a relaunch from the
   helper) is not a stall.
7. **keys.tsv writes** retry the replace a few times, and a key whose write
   still failed is written on the next tick (never lost).
8. **Capture options** are pressable only once their own `option_button` is
   found (else "Not supported yet.", no click on the card).
9. **Moving to another faction's settlement (not at war)**: verified live,
   no change needed: no war or trespass prompt; the game ignores the order
   and the player hears "Tyrion did not move." (`work/live-0.6.75-neutral`).
10. **F6 names what the game selected**: the settlement comes from the game's
    SettlementSelected event (its own choice for the province row); the
    target's name only if no event comes within two seconds.
11. **Menu 'loading' state** clears if the menu keeps ticking ~10 s after a
    Start/Continue/Load click (no load happened), so a later menu stall is
    still announced.
12. One read of `reader-state.tsv` per tick (was two).
13. `MenuKeys.GameFocused()` caches the answer per foreground process ID
    instead of building a Process object several times a second.

The campaign module is at Lua 5.1's limit of 200 locals in one chunk: new
state lives in one table (`battle_state`).

## Tests

Harness: 416 frontend (+ loading cleared when the menu keeps running), 82
campaign (+ unknown pre-battle button refused, results rows numbered or named
from the game's sides, attack watch quiet only with a battle panel and "stopped
next to … no battle started" without, capture option without its button, F6
from the event and the two-second fallback). Companion: stall tests (+
earlier-run heartbeat, locked and half-written file keep the keys, old
heartbeat and map controls release them, NVDA reconnect every 5 s).

## Live (this PC, player path, installed 0.6.75 over 0.6.74)

- `work/live-0.6.75-battle`: F6 → "Lothern, Straits of Lothern."; then a
  **real freeze** right after an F6 camera jump (game not responding, reader
  silent, ~3 cores busy, no GPU report): the companion said "The game is not
  responding." 6 s in. Killed after 2.5 minutes (`campaign-freeze.jsonl`,
  `freeze.png`).
- `work/live-0.6.75-battle-2`: attack Glittering Tower → Fight Battle refused
  → Auto-resolve → log `battle-sides player_attacker:true` (pre-battle and
  results) → "Your side, deployed 116, lost 14, remaining 102, enemy captured
  15", "Enemy side, …" → Accept → Occupy → "Talisman Gained".
- `work/live-0.6.75-neutral`: F7 → "Vaul's Anvil, button, Caledor, more than a
  turn" → Enter twice → "Moving toward Vaul's Anvil." → "Tyrion did not move."
  (both move orders ignored; no dialog on screen).
- companion.log over all three runs: no sharing violations; the reconnect
  logs "The RPC server is unavailable" every 30 s (NVDA not running here).

No turn ended; save files unchanged.

## Not verified

- NVDA reconnect with a real NVDA (not running on this PC; unit-tested).
- A defender's pre-battle panel and its button IDs (the allow-list refuses
  unknown ones); results-row order when defending (rows are numbered then).
- Keys colliding with a write in practice (no collisions logged in these runs).

## Published

Owner's go-ahead (Nov 7): release **v0.6.75** from the `dev` branch
(https://github.com/Caseyshea96/nvda_warhammer2/releases/tag/v0.6.75, ZIP +
`.sha256`, tagged at d9f849d). The downloaded ZIP matches the local build; the
installed Update shortcut script says "Version 0.6.75 is installed; the newest
release is 0.6.75. Nothing to update." `main` stays at 0.6.74.
