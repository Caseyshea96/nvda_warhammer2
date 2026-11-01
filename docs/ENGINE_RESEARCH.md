# WH2 engine/UI research continuation

Date: 2026-10-25. Research only; no runtime changes or new installer. Findings apply to extracted local WH2 scripts, not WH3. The last reported Windows evidence remains 0.2.3; 0.2.4's tail-call hypothesis has no reported runtime result.

## Findings from shipped source

1. `lib_common.lua:1395`, output_uicomponent, uses pcall around a closure that reads uic:Id(). This contradicts the broad hypothesis that any UI call inside pcall is unsupported. It does not rule out a problem with our particular call shape or stale handles.
2. `lib_core.lua:1526`, event_callback, builds a callback list and invokes callback(context) directly. No coroutine wrapper appears in this dispatcher. Debug/performance mode introduces an additional monitoring wrapper; ordinary dispatch does not. Do not invent a coroutine/native-thread explanation without runtime evidence.
3. `lib_core.lua:221`, get_ui_root, returns the cached root. ui_created at line 279 converts context.component with UIComponent, sets readiness, then invokes registered creation callbacks. ui_destroyed at line 317 resets readiness and root before its callbacks. The API explicitly advises clients to use core's creation callbacks rather than registering their own UICreated event listener, so initialization happens in the right order.
4. `lib_common.lua:738`, is_uicomponent, checks whether tostring(obj) begins with "UIComponent ". It is a type-shape heuristic, not a native-lifetime validation. The inspection function explicitly handles a component that appears valid but fails on Id.
5. `lib_common.lua:1429` uses zero-based child enumeration: ChildCount, Find(i), UIComponent(address), then child:Id(). Our index/conversion sequence broadly matches this. Indexing is not yet an evidenced cause of failure.
6. output_uicomponent_on_click at line 1448 inspects UIComponent(context.component) on ComponentLClickUp. A mouse-event component is therefore a useful independent comparison with core's cached root. Prefer a hover event or other read-only sample where possible; do not synthesize a click to obtain a sample.
7. print_all_uicomponent_children is recursive and explicitly documented as verbose and potentially slow. Do not invoke it on the entire root as an initial diagnostic. Limit the experiment to root and a few immediate children.
8. CA inspection logs to out.ui, described as the Lua - UI console spool. Our bridge file does not automatically capture this stream. Reuse the inspection approach, but explicitly write our own bounded diagnostic file or ModLog records rather than assuming the player will find developer-console output.

## Independent modding reference

The WH2 Modding Devtool Console author documents runtime Lua execution under pcall, component/path inspection and a watched input file. This provides another reference against treating pcall as generally unusable. It does not prove our build's native methods behave correctly.

Source: https://steamcommunity.com/workshop/filedetails/?id=1574469690

The fetched Workshop page also displays removed/incompatible banners and older update information. Those can be ambiguous in Steam's unauthenticated markup, so current availability/compatibility is not verified. Do not make this tool an installation dependency or claim it will solve the issue. The mod's campaign menu-bar UI also does not establish accessible frontend operation.

Other source repositories reviewed as references:
- https://github.com/mklabs/twmods
- https://github.com/Shazbot/Warhammer-Mods

These are reference leads, not audited drop-in replacements. Searches did not establish a documented WH2 native-UI tail-call bug. Absence of search results does not disprove one; it means 0.2.4 must remain explicitly experimental.

## Revised diagnostic specification

Run only in the frontend, no model changes, no simulated clicks, no keyboard injection, no global companion hotkeys. Preserve existing speech for a single concise completion/failure announcement; write every observation to disk so speech coalescing cannot erase it.

Record build/diagnostic revision, event source (shortcut, UI-created callback, actual mouse-component event), core:is_ui_created(), root type and string representation. Obtain a fresh root per run. Bound capture frequency and total file size.

For root Id and ChildCount, log a START stage before the call and its result type/value or error after it. Compare:
- Inline native call with local assignment, protected once at the diagnostic-operation boundary.
- Non-tail adapter, also protected once.
- Existing generic reader, retaining raw values before defaults.
- If those differ, nested protection and tail-return variants as separate labelled experiments, not automatic fallbacks.

Then independently read root Visible/IsInteractive/GetStateText/Address. Do not let a failed GetStateText mask ChildCount. Address is opaque and may validly be userdata; record its representation instead of applying a text-field contract. Never treat invalid ChildCount as a genuine zero.

Only if ChildCount is a finite nonnegative integer, sample at most eight immediate children. Record Find's address type, conversion result and child Id, each separately. Stop at failed conversion rather than traversing guessed values. Repeat the same small property set on one component obtained from an actual UI event to distinguish cached-root problems from all-component problems.

Decision table:

| Observation | Next investigation |
|---|---|
| core reports not ready | Initialization/lifecycle; defer through core callbacks |
| inline root reads good, wrapper bad | Isolate wrapper argument/return shape |
| inline and wrapped root bad, event component good | Cached root and root lifetime/context |
| root good, Find/conversion bad | Child address conversion and mutation during traversal |
| all native objects bad | Runtime/build/mod conflicts and binding context; no screen-reader setting changes |
| reads good, labels empty | Menu-specific hierarchy/label adapters, not transport |
| records complete but speech incomplete | Companion coalescing/screen-reader interruption |

Acceptance before expanding again: actual main-menu item names, expected types and positive child counts, followed by a separately authorized harmless menu/submenu/back test. Passing mock tests alone does not satisfy this gate.
