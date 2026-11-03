# "The game is not responding." — 0.6.73 (November 3, 2026)

Owner request (Nov 3, after the freeze investigation): "Yes, add it" — tell
the player when the game stalls, instead of silence.

## What the player hears

- **"The game is not responding."** when the mod's heartbeat (`reader-state.tsv`,
  rewritten about once a second) is more than 5 s old while the game window
  is in front. Said once per stall, queued (does not cut off speech).
- **"The game is responding again."** when the heartbeat is fresh again.
- Nothing when the game is not in front, while a campaign loads, during the
  intro movies, for a heartbeat this companion never saw fresh (an old
  session), or for a heartbeat over 10 minutes old.
- Wording (owner, Nov 3: "game is not responding is more accurate"): the
  first build said "The game is busy."; the live runs below used that text.
- Player guide (`GRAPHICS_PREVIEW.txt`, Shift+F3 entry): wait for "The game
  is responding again." before pressing more keys.

## How

- Companion (`Watch-GameStall`, every 100 ms tick with the menu keys on):
  reads the heartbeat age; remembers the screen of the last fresh heartbeat.
  Gaps up to ~2.4 s are normal after camera jumps (Nov 3 monitor), so 5 s.
- The mod marks transitions with the screen field `loading`:
  - menus: before the Start Campaign / Continue Campaign / Load click, when
    the menu UI is torn down (rebuilt menu clears it), and during the intro
    movies (cleared at the first key tick, which comes after the movies);
  - campaign: when the campaign UI is torn down (quit, load, exit).
- Keys still work with `loading` (the companion checks only the reader flag).

## Tests

- `tests/companion_stall_tests.ps1` (in the build): busy after 5 s once,
  back once, a second stall again; unfocused, loading/movies, old heartbeat,
  over 10 minutes, busy-then-loading stay quiet.
- Harness: 416 frontend (loading before the Continue click and after, movies,
  teardown/rebuild), 74 campaign (teardown says loading, also on later ticks).
- `tools/live/Pause-Game.ps1 -GamePid N -Seconds S` pauses the owned game
  process to simulate a stall (always resumes).

## Live (this PC, player path, installed 0.6.73 over 0.6.70)

`work/live-0.6.73-busy`: Continue Campaign: "Loading campaign. Please wait."
→ 47 s → "Campaign map", no false "busy". F6, then a 9 s pause: "The game is
busy." 4 s into it, "The game is responding again." on resume, reader alive.
About 2 minutes later, moving through the Game Menu, the game froze for good
(reader silent 3+ minutes, game frames identical, Windows still "responding",
one core busy, no GPU timeout report): the companion said "The game is not responding."
(it had also stalled briefly 4 s before: busy, back, busy). The earlier pause
may have contributed; killed after 3 minutes (`campaign-freeze.jsonl`).

`work/live-0.6.73-busy-2` (fresh, no pause): the same Game Menu steps read
fine (Resume … Support, reader alive). Quit → "Quit? Press Enter again to
confirm." → the game's own dialog ("If you quit now you will lose all unsaved
progress") → Accept: the reader state went `loading`, then the menu said
"Warhammer accessibility 0.6.73 ready." with no false "busy".

`work/live-0.6.73-not-responding` (rebuilt with the new wording): Continue
Campaign, F6, an 8 s pause: "The game is not responding." 4 s in, "The game
is responding again." on resume, reader alive.

No turn ended, nothing saved: save files unchanged. NVDA was not running
(speech checked in the trace, not heard).

## Not verified

- A real (GPU) freeze with the new notice; physical keys; the friend's PC.
- Exit to Windows and Load from the campaign (same teardown path as Quit).
- When a hung window turns into Windows' "not responding" ghost window, the
  foreground check may fail; the notice comes at 5 s, usually before that.

## Noticed, not changed

The campaign Game Menu reads each button twice ("Resume, button" then
"Resume Game"; "Save, button" then "Save") — the label text is a separate
item, as "Exit to Windows" was before 0.6.71.

## Published

Owner's go-ahead (Nov 3): release **v0.6.73**
(https://github.com/Caseyshea96/nvda_warhammer2/releases/tag/v0.6.73, ZIP +
`.sha256`; it also carries 0.6.71 and 0.6.72). The downloaded ZIP matches the
local build; the installed Update shortcut script says "Version 0.6.73 is
installed; the newest release is 0.6.73. Nothing to update."
