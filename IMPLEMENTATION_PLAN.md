# Warhammer II accessibility: implementation plan

## Goal

A playable keyboard prototype that a blind friend can try with NVDA, then his
feedback on the controls decides what comes next. Single-player first; co-op
later.

## Architecture

Game Lua (reads the UI, keeps the logical focus, clicks only checked
elements) → bridge file → Windows companion → NVDA Controller Client → speech
and braille. The companion's menu keys go back to the game through a small
key file polled by one repeating game timer. Speech follows NVDA conventions:
name, role, value, states, position.

## Where it stands (0.6.65)

- Menus: main menu, Select Campaign (both campaigns), Continue Campaign.
- Select Lord: race → lord → campaign setup (difficulty lists, intro check
  box, details, Start Campaign with confirmation); Backspace goes back.
- Campaign map: HUD reading, panels, provinces and settlements, building and
  recruiting, End Turn.
- One-step launch without TW Mod Manager; installer upgrades in place.

## Next

1. Trial feedback from the friend (each trial's notes in `docs/`).
2. Battles: auto resolve as the default (owner decision, November 1); needs a
   live capture of the pre-battle screen.
3. Army movement and other map orders: blocked until the owner unblocks them.
4. Load Campaign (save list), other languages (race names), document reading
   order on the Select Lord details.
5. Co-op: later, once single-player is playable.

## Rules that came from live failures

- Never call `string.find` in the runtime (WH2's string library misbehaves).
- Never register a `real_timer` from inside a timer callback; use one
  repeating timer (froze the game's timers twice).
- Never check a screen against this PC's exact layout; check identities and
  re-verify the clicked element.

History of earlier versions: [current progress](docs/CURRENT_PROGRESS.md) and
the dated notes in `docs/`.
