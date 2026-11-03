# Loading speech and notification dismissal — 0.6.72

Start Campaign, Continue Campaign and Load now write "Loading campaign.
Please wait." before the native click. Loading can stop the game's timers,
so announcing afterward can leave the player waiting in silence. Starting a
new campaign also explains that an intro movie may play. The campaign reader
already announces "Campaign map" on arrival.

Ctrl+Backspace dismisses one notification at a time while campaign reading is
active and the game is focused. Ctrl+Escape was requested as a suggestion,
but Windows refused to register it (error 1409). Ctrl+Backspace registered
successfully. Plain Escape and Steam's Shift+Tab remain available.

Supported targets are advisor Close, notification-frame Skip, and Accept in
the informational How They Play / Mission Issued! notices. Informational
titles are rechecked before Accept. Generic Close/Accept, settings, exit and
turn-ending controls are not shortcut targets. A higher panel, incomplete
capture, hidden/disabled/replaced target, or stale key generation prevents
dismissal. The shortcut cancels a pending confirmation; a successful click
requires a new capture before another dismissal can occur.

Validation: 415 frontend and 73 campaign Lua 5.1 scenarios, speech/atomic
request/client checks and package round-trip passed. The keyboard helper
compiled under Windows PowerShell 5.1. Added tests check pre-click speech on
all three loading paths, safe dismissal, repeated presses, unrelated dialogs,
changed notice titles, stale generation and unavailable targets.

Live evidence: `work/live-0.6.72-loading-dismiss`. Installed over 0.6.71,
backed up saves, launched the player path, loaded Continue Campaign. Companion
trace showed loading speech at 15:35:51 UTC and map reading at 15:36:22–24 UTC
on November 3. The reader was alive and the game responding. Ctrl+Backspace
reached keys.tsv as `dismiss`; the changing screen triggered a guarded
re-read. An actual live notification dismissal is not confirmed. NVDA was
disconnected, so this verifies speech requests, not audible output. No turn
was ended. Only the recorded test game and companion were closed afterward.

NVDA retest: `work/live-0.6.72-nvda`. After the player switched from JAWS to
NVDA, repeated Continue Campaign. NVDA was connected and returned success
for loading at 15:40:04 UTC and campaign-map speech at 15:40:37 UTC.
Ctrl+Backspace arrived as `dismiss`; NVDA received "Skip is unavailable."
The captured Skip control was inactive and a screenshot confirmed an idle
campaign map with Event Messages, rather than a dismissible notification.
The advisor was also unavailable. This verifies live key delivery and safe
refusal; actual popup dismissal remains unverified live. No turn was ended;
existing save hashes were unchanged in the first run. NVDA is left running.
The installer suite also passed after closing the first test game (an earlier
parallel installer run was correctly blocked by the running game).

Pre-install rollback: `work/preinstall-0.6.72-28d57924`.
