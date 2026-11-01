# Standard keys and single-press activation 0.6.26–0.6.27 — October 29, 2026

The menus now use the keys NVDA users expect, and activation takes one press.

## Keys (game focused, on a menu screen)

| Key | Action |
| --- | --- |
| Down / Up arrow | next / previous item (repeat when held) |
| Tab | next item |
| Home / End | first / last item |
| Enter, Space | activate (never repeats when held) |
| A–Z | next item starting with that letter, wrapping; silent if none |
| Escape | not taken — the game's own Back key |
| Shift+Tab | not taken — Steam's overlay shortcut (found live) |
| F2 / F3 / F4 | still next / previous / activate |

## How it works

- The game only passes its own script shortcuts (F2–F4) to the mod, and
  ignores injected keys. The companion (`-MenuKeys`, new `MenuKeys.cs`)
  registers the keys above as hotkeys only while Warhammer2.exe is the
  foreground window AND the mod's `reader-state.tsv` heartbeat is fresh
  (rewritten every second, under 3 s old) and reports the frontend. Otherwise
  the keys are released to the game and other programs.
- Each press is appended (ring of 16, atomic replace) to `keys.tsv`:
  `WH2KEYS1 <companion id> <game session> <UI generation>` then `<seq> <action>`.
- The mod polls it every 100 ms with a frontend `real_timer` (no lease needed),
  and runs the same handlers as F2/F3/F4 (`source=keys`). Events for another
  session or UI generation are skipped; when a new companion appears, its
  backlog is skipped (the companion announces itself with an empty file at
  start, so the first real press counts). At most eight events per tick;
  sequences are consumed before acting and never replayed.
- Activation is a single press. `confirm-activations.flag` beside the log
  restores press-twice-within-four-seconds for every action. All safety checks
  (fresh capture, identity, ancestors, state, one click call site) are unchanged.
  The automation client's `-DoubleConfirm` accepts `input-sent` on the first
  request.
- Packaging: `MenuKeys.cs` ships in the NVDA package, is in the install and
  uninstall allowlists, and `Start Pilot.cmd` starts the companion with
  `-MenuKeys`. Player README rewritten around the keys.

## Tests

- Harness 362 scenarios: single press (menu, lord, automation, Start Campaign
  still blocked); key channel (backlog skip, next/previous/Home/End, letters
  with wrap and no-match, other session/generation ignored, bad actions
  rejected, companion restart, eight-per-tick bound, Enter activation, reader
  state follows the screen). Legacy scenarios run with the confirm flag.
- `tools/live/Send-Keys.ps1` injects key presses; the companion's hotkeys
  receive them (the game itself does not).

## Live results

0.6.26: Down → "Main menu. New Campaign, button, 1 of 22"; Up/Home/End/Tab/
letters correct (Q → Quest Battle → Quick Battle → Quit; Z silent; G →
Graphics); Enter on New Campaign → "Select Campaign…"; C, Enter → Continue →
Select Lord; T jumps between Tyrion, Teclis, Tretch Craventail and the
intro notice; Enter chose Teclis ("Teclis chosen." → "Teclis is now selected.")
and Tyrion back; no errors. Shift+Tab opened Steam's overlay (the owner closed
it with Shift+Tab, which the companion also sent as "previous") — so 0.6.27
leaves Shift+Tab to Steam.

0.6.27: Down/Tab/End/Home correct; fresh-launch automation regression (49
entries, wrap, refresh, Start Campaign blocked; Teclis/Tyrion selection with
single-press acknowledgements; 133 announcements in the conventional format);
graceful shutdowns.

Not verified: physical key presses on the owner's/friend's keyboard (injected
presses were used), Escape after the companion's keys (injected Escape never
reaches the game), audible completion.

Evidence: `work/live-0.6.26-keys` (keys.tsv, speech), `work/live-0.6.27-keys`,
`work/live-0.6.27-regression`. Package `outputs/warhammer2-windows-0.6.27-nvda-automation-preview.zip`.
