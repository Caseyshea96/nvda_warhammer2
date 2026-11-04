# Attacks and auto-resolve battles — 0.6.74 (November 3, 2026)

Owner (Nov 3): "go ahead and do all this" — attacks and auto-resolve battles,
each step asking first, plus the smaller fixes (Game Menu double reading;
check Exit to Windows, Load from the campaign, Ctrl+Backspace live). Attacks
are now unblocked (CLAUDE.md); fighting a battle yourself and declaring war
stay blocked.

## What the player does and hears

1. **F7** lists enemies at war as well as places: settlements ("Glittering
   Tower, button, Cult of Excess, at war, this turn") and the 5 nearest enemy
   armies in the field ("Malus's army, button, Har Ganeth, at war, 7 units,
   this turn"; armies inside a settlement are attacked through it).
2. **Enter**: "Attack Glittering Tower with Tyrion? Press Enter again to
   confirm." Enter: "Attacking Glittering Tower." — the game's own orders, as
   its scripts give them: `attack_region(lord, region, true)` for a
   settlement, `attack(lord, enemy, true)` for an army (game-timer job queue).
   No "arrived"/"stopped" when he reaches the target (the battle screen is
   read instead); "stopped on the way" when he falls short.
3. **Pre-battle screen** (the game hides its HUD for it; the reader now reads
   battle panels with the HUD hidden): "Screen updated. Glittering Tower",
   "Turns remaining until settlement surrenders, 10", "Casualties, Low",
   "Battle Result, Decisive Victory", the buttons, both armies' units
   ("Spear Infantry, list item, 30 soldiers").
   - Fight Battle and Scout terrain (loads the battle map): "Fighting the
     battle yourself is not supported. Choose Auto-resolve." / "Scouting the
     battle map is not supported. …"
   - Auto-resolve, Break Siege, Encircle, Quick Save: ask first.
4. **Results**: "Decisive Victory, heading", "Your side, deployed 116, lost 14,
   remaining 102, enemy captured 15", "Enemy side, …", each unit "Spearmen,
   list item, Spear Infantry, 22 soldiers, kills 13" (lost units "disbanded").
   Accept asks first.
5. **Settlement Captured**: one button per choice: "Occupy, button, Conquest
   penalty -10, Province instability -3, You occupy the settlement and all
   captives are killed.", "Loot & Occupy", "Sack", "Raze". Enter twice clicks
   the card's own button.

## Other changes

- Game Menu: each button once ("Resume Game, button" … "Exit to Main Menu,
  button"); the label child named `string` folds into any `button_*`.
- Reading: a label ending in a colon takes its value ("Battle Result,
  Decisive Victory"); a bare number named by its tooltip ("Turns remaining
  …, 10"); `dy_rank` reads "Rank, 2"; a unit card's "Health" bar no longer
  takes the soldier count ("Hit Points: 1017/1017" bars keep their text).
- F6 from a lord standing in a minor settlement (Glittering Tower) announces
  the province capital (Lothern): the Provinces list row selects the capital.
- Ctrl+Backspace: the advisor and the tutorial highlight above a "Mission
  Issued!" notice no longer block dismissing it.
- Campaign Load Game: each save is one list item with the game's reason when
  it cannot be loaded ("You are missing the following mods: …").
- Log: `signature-change` (what keeps a screen from settling, first 40) and
  `hud-unavailable` (why the HUD cannot be read, with the root layers).
- `tests/replay_capture.lua` rebuilds a hidden HUD (`layout`) so battle
  captures replay.

## Live (this PC, player path, Continue Campaign on the Eataine save)

- `work/live-0.6.74-attack`, `-attack-2`: the order worked (Tyrion marched,
  pre-battle opened) but the screen was not read (HUD hidden → reader idle).
- `work/live-0.6.74-attack-3`: the screen read; Auto-resolve → Decisive
  Victory; Accept → Settlement Captured (captures replayed offline).
- `work/live-0.6.74-battle`: attack → read → Auto-resolve → results → Accept
  → Occupy → "Talisman Gained"; income 1901 → 1940.
- `work/live-0.6.74-final`: Fight Battle and Scout terrain refused; the whole
  battle again; after the talisman a real "Mission Issued!" notice:
  Ctrl+Backspace → "Notification dismissed." (the first press said "The
  screen changed. Reading it again."); again → the advisor closed.
- `work/live-0.6.74-battle-2`: F6 after the capture → "Lothern, Straits of
  Lothern." (matches the game's selection).
- `work/live-0.6.74-menu`: Exit to Windows → "Exit to Windows? Press Enter
  again to confirm." → the game's "If you quit now …" → Accept → the game
  closed; reader state `loading`, no false "not responding".
- `work/live-0.6.74-load`: Game Menu → Load → "Screen updated.
  Eataine_Auto-save, list item, selected, unavailable, Normal, turn 1, …,
  You cannot load this save game. You are missing the following mods:
  jaws_skip_intro jaws_access".

No turn ended, nothing saved: the save files are unchanged after every run
(battles do not autosave). In one run a test script of mine pressed Enter
twice on "End turn" (a failed search; the script now never presses Enter
unless the item was found): its tooltip was "Resolve or skip this
notification to end turn", and it only jumped to Tyrion's "Lord not moved"
notification; saves unchanged, treasury unchanged. A Windows Quick Settings
panel also opened once during a run and took keys (cause unknown).

## Not verified / known gaps

- A real load from the campaign Load Game: the only save predates the 0.6.65
  rename and the game refuses it (Continue Campaign still loads it). Making a
  new save to test was not done without the owner's OK.
- Attacking an army in the field (none near Tyrion in this save; harness
  only), sieges of walled cities (Break Siege / Encircle / Continue siege
  paths), captives after field battles, retreat, losing a battle.
- Declaring war (attacking a faction not at war) stays blocked: such targets
  are moves, never attacks.
- Which results row is "Your side": the first row (`row_example`) was the
  player in every run; not checked for allied battles.
- The results screen is announced twice ("Screen updated. Decisive Victory"
  twice) as it settles. The pre-battle arrival may land on a remembered unit
  instead of the title. The campaign list in Load Game reads in fragments.
- After the first battle the game's tutorial ("Select your army") makes the
  Menu unavailable until it is followed.
- Physical keys; the friend's PC.

Harness: 416 frontend, 80 campaign scenarios (+ attack orders, enemy armies
in F7, neutral targets stay moves, pre-battle refusal and Auto-resolve
confirm, hidden HUD with a battle panel, results row, unit card, capture
option click, Game Menu fold, notice under the advisor).
