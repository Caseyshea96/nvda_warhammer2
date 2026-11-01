# Lord reader 0.6.18 — live pass and root cause — October 29, 2026

0.6.18 passes the live Lord setup reader test that 0.6.15–0.6.17 failed, and the
cause of those failures is confirmed in-game.

## Root cause

WH2's `string.find` with the plain flag is broken. A live probe (opt-in flag
file, separate launch) logged:

| Call | Expected | In-game |
| --- | --- | --- |
| `string.find('lord:tree.a.b','lord:tree.',1,true)` | `1` | `nil` |
| `string.sub('abc',1,1)` afterwards | string | **number** |
| `('abc'):sub(1,1)` afterwards | string | **number** |
| `tostring('abc')` | string | string |

0.6.14 never calls `string.find`. Every failed candidate called
`s:find(prefix,1,true)` on captured text: 0.6.15/0.6.16 during traversal,
0.6.17 when announcing the first race-attribute bullet (entry 23). The call
returned the wrong answer (so 0.6.17 spoke entry 23 without its label), then
the next `:sub()` (the logger, line 327, outside navigate's pcall) indexed a
number: `attempt to index a number value`. The logger was never the cause.

**Rule: do not call `string.find` in the runtime.** Use `string.sub` prefix
checks (`starts_with` in graphics_preview.lua). `string.match`/`gsub` are
used by the proven 0.6.14 code and were not implicated.

## Changes in 0.6.18 (on top of the 0.6.17 candidate)

- Lord labels use `starts_with` (string.sub) instead of `:find`/`:sub` methods.
- Logging after `navigate`'s pcall is guarded; on failure a formatting-free
  `navigation.REPORT_FAILED` line is written and the request still completes.
  The proven logger body is unchanged (static check enforces this).
- Opt-in probe: `string-find-probe.flag` beside the log runs the four calls
  above at startup. It breaks later string calls, so use a separate launch.
- Harness: 339 scenarios (335 + simulated in-game find/sub fault, report guard,
  probe on/off). The fault scenario fails against 0.6.17 and passes on 0.6.18.

## Live result (session 1, probe off)

| Check | Result |
| --- | --- |
| Offline | 339 scenarios, speech trace, PS 5.1 atomic writes, pack round-trip, installer/tamper/uninstall/preservation |
| Install | 0.6.18 manifest and pack hash verified; backup `work/preinstall-0.6.18-0d3435a9` |
| Launch | Direct: `Warhammer2.exe` with TWMM `used_mods.txt` (only `warhammer_access.pack`) and `-dx11`, owner-approved; main menu visually confirmed, no intro video on screen |
| Route | New Campaign → Select Campaign (17) → Continue → Select Lord (Tyrion, High Elves, Eataine) visually confirmed |
| Reader | All 34 entries, labels match the expected catalog, including `Race attribute:` ×3, faction/lord effects, difficulties |
| Paging | Next fetched discovery pages itself (pages 1–5, 205 nodes, complete, 0 errors/limits) |
| Wrap | Both directions |
| Refresh | Explicit Discover reread 5 pages back to the complete 34-entry catalog |
| F4 on Start Campaign | Single request, game replied `blocked` ("read only. No game action was sent"); still on Select Lord |
| Native clicks | Exactly two (New Campaign, Continue) |
| Errors | No `ERROR` or `REPORT_FAILED` lines in the native log |
| Speech | 88 NVDA requests/returns for companion 19504, all code 0; audible completion not assessed |
| Shutdown | Native disabled acknowledgement received; game closed gracefully (no forced kill) |

Test-script notes from the run (fixed in `tools/live/`): PowerShell 5.1 empty
`$PSScriptRoot` in param defaults and unrolled-JSON arrays; Activate needs
`-ExpectedSelectedKey`. Those failures happened client-side; nothing was sent.
The run resumed mid-list, so traversal/wrap were completed across two script
invocations in the same game session. The expected catalog had "(Lord's army)";
the game text is `(` + icon markup + `Lord's army)`, which the reader renders as
"( Lord's army)" (as the harness already expected); catalog corrected.

## Probe session (session 2)

Direct launch with the flag; results as in the table above. The endpoint did
not become ready afterwards (expected: string.sub was broken). Flag removed,
game closed gracefully, companion stopped. The disabled acknowledgement for
this session is the previous status file, not a fresh one.

## Still open

Injected keyboard delivery, intro skipping, TWMM accessibility, audible
completion, automatic refresh after manual changes, gameplay and co-op.
Starting a campaign and lord/settings changes remain blocked.

Evidence: `work/live-0.6.18-lord-reader` (logs, reader-steps.json,
transitions.json, screenshots), `work/live-0.6.18-string-probe`.
Package: `outputs/warhammer2-windows-0.6.18-nvda-automation-preview.zip`
(SHA-256 9febc81966d141648517c918af459f82162d551930ef46f26ec3c2cb96bbe328).
