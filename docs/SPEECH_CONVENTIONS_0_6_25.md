# NVDA-style speech 0.6.24–0.6.25 — October 29, 2026

The owner asked for the mod to follow normal screen reader conventions, NVDA
first. This step changes speech only; keys (F2/F3/F4) and the
double-F4 activation are unchanged and are the next steps.

## Format

- Items: `name, role, value, states, N of M`, then a description if any —
  NVDA's order. Examples (live):
  - "Main menu. New Campaign, button, 1 of 22"
  - "Select Campaign. The Eye of the Vortex, radio button, checked, 1 of 17"
  - "Enable campaign introduction, check box, checked, 4 of 49, Start the campaign with …"
  - "Campaign difficulty, combo box, Normal, 33 of 49"
  - "Teclis, radio button, not checked, 14 of 49"
- The screen name is spoken once on arrival ("Main menu.", "Select Campaign.",
  "Select Lord.", "Graphics.", "Advanced graphics."), not on every item.
- Roles: button, radio button (campaigns, lords), check box, combo box (graphics
  dropdowns, difficulties), slider, tab (Movie/Map), heading (`tx_*` titles,
  effect group titles). Plain text has no role.
- States: `inactive`/not interactive → "unavailable"; radio/check box →
  "checked"/"not checked"; tabs → "selected". Engine words (active, NewState,
  read only) are never spoken. Graphics check boxes whose checked state is not
  established say "state unknown".
- Lord setup: the intro check box is one entry (label + state + description);
  the "Campaign"/"Battle" labels that repeated the difficulty combo boxes are
  gone. 49 entries live (was 53).
- Browsing Lord setup reads the whole bounded screen at once, so "N of M" is
  final from the first item (no "Still reading"), and a lord can be chosen
  immediately. Developer Discover still pages and says "Screen read again."
- Messages are short: "Not supported yet.", "The screen changed. Press F2 and
  try again.", "Teclis is now selected.", "Confirmation timed out.". F4 on
  plain text is silent. Developer details (node counts, log hints, "No game
  action was sent") go to the log only.
- Startup: "Warhammer accessibility ready. F2 and F3 move, F4 activates."

## Fixes found while testing

- A watched field longer than 1000 bytes looked changed on every key press
  (truncated capture vs full live text), re-reading until the 2 MiB discovery
  log budget failed. Comparison now uses the same truncation, and the log
  restarts when a new read begins past 1 MiB.
- A resting mouse puts the portrait under it in the `hover` state; that lord
  was dropped from the list and could not be chosen (seen live in 0.6.24).
  `hover` now counts as choosable. Every refused selection logs
  `activation.lord_blocked` with its reason.

## Tests

- Harness: 357 scenarios; 105 speech assertions converted, plus exact
  announcements for each screen/role, no engine words, no duplicates, limited
  capture, hover, refresh loop. Mutations of the log rollover and earlier
  guards fail the harness.
- `tools/live/Test-Speech.ps1` checks everything sent to NVDA in a session.

## Live result (0.6.25)

Reader regression (49 entries, wrap, refresh, Start Campaign blocked, two menu
clicks); Teclis selected and confirmed, re-select refused, Tyrion selected and
confirmed with the mouse resting on Tyrion's portrait; 133 item announcements
all in the new format; graceful shutdown. Audible completion not assessed.

Evidence: `work/live-0.6.24-speech` (hover failure), `work/live-0.6.25-speech`
(pass, `spoken.txt`). Package: `outputs/warhammer2-windows-0.6.25-nvda-automation-preview.zip`.
