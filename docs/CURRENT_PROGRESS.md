# Current progress

## October 29 stopping point: 0.6.31 candidate ready for a live gate

The owner requested a stopping point. HUD-readiness gating, typed read diagnostics
and an explicit capture-only refresh channel are built in 0.6.31. All 402 Lua
scenarios plus client/atomic/speech/pack/installer checks pass. No live campaign
was run for this candidate. Accepted 0.6.28 is still installed with matching
runtime hashes; test processes and markers are absent. See
CAMPAIGN_DISCOVERY_0_6_31.md. Older checkpoints below are historical.


## October 29 latest: first campaign diagnostic result

One explicitly approved Tyrion campaign reached the actual map. The diagnostic
ran during the opening sequence and captured six text entries, with 70 reported
read/type issues; it did not read the later normal HUD. Campaign speech reached
NVDA, but full browsing/wrap and physical keys remain unverified. No gameplay
commands were sent. Accepted 0.6.28 is restored, all runtime hashes match, and
owned test processes/flags are closed/removed. Candidate 0.6.30 remains unpromoted.
See CAMPAIGN_DISCOVERY_0_6_30.md. Next: getter-type diagnostics and a bounded
post-cinematic refresh/readiness gate. Older sections below are historical.

## October 29 final owner-requested checkpoint

Stopped after 0.6.17 failed its live reader at the first race attribute, following
22 acknowledged entries. The full catalog, wrap and refresh checks were not
reached. 0.6.14 is restored and all 13 installed runtime payload hashes match.
Game/companion are closed and test leases removed. Candidate code and fresh
evidence are preserved; see [FINAL_LORD_READER_TEST.md](FINAL_LORD_READER_TEST.md).
Await the owner's next resume request.


## October 29: named Lord reader candidates rolled back

0.6.15 and 0.6.16 passed 343 fixtures and package/installer checks but failed
live after guarded New Campaign/Continue reached actual Select Lord. 0.6.16
completed the first 48-path page and announced Select Lord before the native
Lua error; a full reader/refresh pass was not reached. Exact cause is unproven.

The live-verified 0.6.14 installation, source, version and generic pack are
restored. Owned test processes are closed and leases revoked. Candidate code
and logs remain preserved in the task workspace. See
[LORD_READER_CANDIDATE_TEST.md](LORD_READER_CANDIDATE_TEST.md).


## Latest automation gate — October 29, 2026

The 5:45 AM continuation installed and live-tested 0.6.14. Lord setup now has
a read-only captured-text browser: five pages examined 205 index paths,
captured 131 native-visible nodes and exposed 34 text entries. Its 44,160-byte
compact log completed without errors or limits. All 34 entries, next/previous
wrap and a blocked Start Campaign request passed in the actual game. The
screen remained Select Lord. This run sent only the two existing New Campaign
and Continue clicks. The original diagnostic completed six captures with no
native errors or bounding, and stayed below its 2 MiB budget.

332 Lua scenarios, source/scanner preservation, pack round-trip, speech,
PowerShell 5.1 atomic requests and shipped installer checks pass. All 52 NVDA
requests returned code 0; full audible completion is still unassessed. The
reader is a captured snapshot and does not automatically refresh after manual
lord/settings changes. Next improve field grouping/refresh before expanding
selection actions. Lord selection, settings changes and Start Campaign remain
blocked. The test lease is disabled and owned processes are stopped. The game
window closed on Alt+F4, but its process lingered after a bounded shutdown wait;
only that verified windowless frontend process was terminated. Shutdown
reliability remains a separate gate. The 0.6.13 checkpoint below is historical.

The owner prioritized automation over feature expansion. Installed 0.6.13 now
passes live native automation: 22 main controls, both wrap directions, exact
lease/deadline values, an expired confirmation with no click, New Campaign to
Select Campaign, all 17 campaign-reader entries, and guarded Continue to Select
Lord. Exactly two positive native clicks were sent. No campaign was started.

Injected F2/F3 do not produce native ShortcutTriggered events, including with
Discord closed and game focus explicitly recovered. Automated intro skipping
has not succeeded. Steam/TW Mod Manager launches and NVDA startup speech work.

All 322 Lua scenarios, speech trace, pack round-trip, shipped-ZIP installer and
Windows PowerShell 5.1 atomic replacement checks pass. The native channel uses
real_timer single shots with RealTimeTrigger. Numeric Unix epochs round in the
game, so decimal text and an exact UTC day-relative clock enforce expiry.

The actual next screen shows Select Lord with Tyrion, High Elves and Eataine.
Its initial read-only scan reached the 200-node limit and the 2 MiB log budget;
the saved final capture is partial, with only 107 logged rows. It is not an
activation template. Next implement scoped read-only discovery or pagination.
Start Campaign and all new Select Lord actions remain blocked. Test lease is
revoked; game and owned companion are closed. NVDA remains running.

See [AUTOMATION_SESSION.md](AUTOMATION_SESSION.md) for current evidence, test
lease cleanup, scheduled continuations and the next live gate. Earlier release
notes below describe historical checkpoints and may mention superseded installs.

## Implemented

- Keyboard-only, read-only native UI diagnostic with a one-shot bounded visible-tree capture, raw return types and per-method errors; frontend-only logging preserves evidence across campaign/battle loading.
- Windows speech companion with the official NVDA Controller Client backend, plus installer/removal scripts.
- Development control identity validation, UI readiness gates and lifecycle invalidation.
- Companion hotkeys registered while the game is foreground, with focus checks at dispatch and tested registration/release behavior. Focus detection polls every 100 ms.
- Bounded speech batches preserve errors/results and collapse consecutive focus messages. Speech completion across polls and simultaneous-source arbitration remain outstanding.

## Validation

Lua fixture tests cover native-like opaque identities, replaced controls, missing identities, lifecycle, turn checks and visibility filtering. Separate diagnostic fixtures check bounded captures and malformed returns. PowerShell tests cover transport, protocol, speech batches and hotkey policy. C# compilation targets .NET Framework 4.8 and C#5. Pack builds round-trip through RPFM. Installer fixtures run against temporary Steam-like paths with spaces and cover reruns, tampering and removal/preservation.

These checks are local simulations and packaging checks. NVDA read-only frontend browsing has run successfully in the game. Quiet-mode effectiveness, broader activation, battle and co-op paths still need runtime testing.

## Required next evidence

2026-10-28 latest: New Campaign activation PASSED in 0.6.0. The user reported
success. Native logs record its dispatch and the resulting campaign_select
panel with Select Campaign title: 167 nodes on the first capture, 168 on the
second, no native .ERROR or .bounded records. Eye of the Vortex is selected,
Mortal Empires is active, and Continue is active. The captures contain the
Vortex description and 12 listed race tooltips; these do not establish DLC
ownership. Return to main menu is also present. Escape return from this new
screen was not captured in that run.

0.6.1-nvda-campaign-preview is built and installed with a backup of 0.6.0.
It maps 17 entries: two campaign choices, Continue, the description, twelve
listed races and the Escape-return instruction. Footer support links, store
icons, empty particles, containers and duplicate labels are excluded. All
entries except Continue are read-only. Only the captured Vortex selection can
authorize Continue; Mortal Empires selection and Start Campaign remain blocked.

Continue uses the exact campaign_select/button_frame/button_next path (2/2/0).
All 107 named nodes from the actual capture retain exact fields and identities
in the fresh confirmation fingerprint. The root accepts the two observed
starting counts (5 or 6); a sixth child must be the observed hidden,
noninteractive Tooltip. Its appearance during confirmation changes the raw
root count and cancels confirmation. Sixty blank smoke leaves are excluded
from the actionable fingerprint only while they remain unnamed, text-free,
noninteractive NewState leaves. Their boolean visibility may animate. Changed
IDs/content/interactivity/children or unknown root overlays block activation.
These exceptions are based on differences between the two actual captures.

Cached campaign browsing probes root/panel identity, the optional Tooltip,
selection states, title/description, Continue state/visibility and button-frame
size before reusing the list. Changed supported states refresh the capture.
This is not general modal detection or continuous value tracking. Every F4
still re-captures and verifies all required fields, resolves the current native
path, checks visible ancestors and active state, and requires confirmation
within four seconds. There remains one native SimulateLClick dispatch site.
New Campaign now has an observed-result check for this captured screen.
Continue's next screen remains discovery; no unobserved setup IDs are invented.

251 frontend fixture scenarios passed: both actual capture variants, all 17
entries, cached wraparound/refresh, Continue confirmation, native failures,
changed identities/ancestors, selected campaign/title changes, extra panels,
purchase/download controls, duplicate IDs, particle-content rejection, clocks,
navigation/lifecycle/log failures, returned-click versus observed-result and
unknown-next-screen blocking. A test caught and fixed a particle-ID validation
hole before packaging. Existing read-only/native traversal and exact logger
checks, Lua syntax, single dispatch site, pack/source round-trip, speech trace,
ZIP payload/integrity and shipped temporary installer/tamper/uninstall/file
preservation tests passed. Existing RPFM warnings were nonfatal. Installed
version and pack hash match the package manifest. The new reader/Continue
target have not yet run live. No campaign was started during this work.

Next live test: New Campaign, browse the 17 entries, select Continue (third),
double F4, then tap F2 once on the next setup screen. Capture the native preview
log and speech trace before relaunching. Map actual faction/lord/difficulty
data from that capture. Use Escape and browse to verify return transitions.
Keep existing Quiet Mode enabled; no add-on reinstall or graphics test needed.
0.6.0 and 0.5.10 rollback ZIP hashes remain unchanged.
0.6.1 ZIP SHA256: 99FCDDDF734829E87EFD22D4DDFD90E9CB050446E8B2DF78AADB8EEAC16ABEB2.

### Earlier checkpoints (historical)

2026-10-28 latest checkpoint: the user confirmed 0.5.10 worked in windowed
mode. Native logs confirm Graphics and Advanced dispatches and observed results,
40-node/7-entry basic Graphics, 152-node/33-entry Advanced, and Escape return
to the 86-node/22-control main menu. No native .ERROR or .bounded records occur.
Speech traces include Advanced wraparound and return navigation. Graphics is
now a retained regression checkpoint; no further graphics expansion is planned.

The user requested gameplay-relevant work. 0.6.0-nvda-campaign-preview is built
and installed, with a backup of 0.5.10. It adds only the actually captured main
menu New Campaign path (2/1/0/0/0/0/1) to the native activation allowlist. The
same exact main-menu template, fresh root/path, visible ancestors, native
identities, active state and double-F4 confirmation remain required. Continue,
Load, multiplayer and Start Campaign remain blocked. Graphics/Advanced support
is preserved, and there is still one native SimulateLClick call site.

Campaign setup has not yet been captured or mapped. F2 on an unmapped frontend
screen logs the proven bounded native traversal (200 nodes, depth 20); it does
not expose background controls or authorize setup actions on an unknown panel.
Unknown screens refresh on an explicit browse key because descendants may
change without replacing their parent. After New Campaign input the log records
result_requires_mapping, never an observed campaign result based on invented IDs.

178 fixture scenarios passed, including the new captured target, bad native
reads, stale identities, hidden ancestors, inactive states, modal/template
changes, clocks, lifecycle, lost logging and non-actionable synthetic setup
discovery/refresh/return. No synthetic setup IDs are treated as game evidence.
Baseline traversal/logger preservation, Lua syntax, single dispatch site, pack
round-trip source match, speech trace, ZIP payload/integrity and shipped
temporary installation/tamper/uninstall/preservation checks passed. Existing
RPFM reserved-path warnings remain nonfatal. Installed version and pack hash
match the manifest. The new target is not yet live-tested.

Next capture: launch normally; select New Campaign with F2 and double F4;
tap F2 once on the resulting screen; send native-ui-graphics-preview.log and
speech-trace.jsonl before relaunching. Map actual campaign selection, faction,
lord and difficulty data from that evidence. Do not enable Start Campaign yet.
The log filename is retained for compatibility. 0.5.10/read-only rollbacks remain.
0.6.0 ZIP SHA256: 0CA720BB53E88325750796C4AB0981F5B70C6D698B14427984DB4442F313983F.

### Prior testing record (historical)

2026-10-28: 0.5.10 is installed. The user confirmed physical F2 speech;
the native log captures the 22-control main menu and cached navigation, and
the speech trace records New Campaign and Continue Campaign with NVDA code 0.
Computer Use F2 attempts produced no native shortcut record before that user
test. Synthetic keyboard delivery remains an automation limitation; its cause
is unproven. The live windowed-mode Advanced activation retest is still pending.

The 0.5.9 logs show the 33-entry Advanced reader working after manual entry.
The user intentionally enabled windowed mode. Comparing the 40-node basic
captures finds one difference: checkbox_windowed.CurrentState is selected
instead of active. The exact layout guard therefore incorrectly blocked Advanced.
0.5.10 permits those two observed starting states on that single basic-panel
field. Every other field and native identity remains exact. The actual raw
state stays in the confirmation fingerprint, so changing it between F4 presses
cancels activation. Advanced itself must remain active. No setting is changed.

136 Lua fixture scenarios passed, including the actual failing windowed capture,
positive opening/observed-result simulation, state-change cancellation, unknown
states, malformed reads, visibility, identity and interactivity rejection.
Preserved traversal/logger checks, single native dispatch check, pack source
round-trip, speech trace, ZIP integrity/payload hashes and temporary installation,
tamper, uninstall and unrelated-file preservation checks passed. Existing RPFM
warnings were nonfatal; extracted source matched. Installation was backed up;
the installed pack hash matches the package manifest.
0.5.10 ZIP SHA256: 13B66CFAAEEE8B002B19409D33DFEEE962088099551392125612AD3AB1A4E2AF.

Autonomous live attempts reached the main menu, but do not establish independent
launcher accessibility or automated intro skipping. The intro was gone by the
next main-menu observation; whether synthetic Escape caused it is unproven.
No supported Computer Use stop-shortcut remapping control was exposed in the
available API or documentation; the shortcut was not changed. The mod's Escape
behavior was not changed. All Advanced settings remain read-only.

The next live gate is double-F4 Advanced opening with windowed mode retained,
then 33-entry browsing and Escape return. Do not equate fixture success or NVDA
Controller Client code 0 with a completed live activation or full audible output.

### Earlier checkpoints (historical status at the time)

2026-10-28 live 0.5.8 Advanced view PASSED. The native log records one Graphics
and one Advanced dispatch, then matching activation.observed_result records.
Advanced completed 152 nodes with no .ERROR or .bounded record. Escape produced
navigation.screen_changed, followed by an 86-node/22-control main-menu capture
and forward/reverse announcements. This is the first complete Advanced native
capture; its controls can now be mapped from evidence instead of synthetic IDs.

0.5.9 adds a 33-entry read-only Advanced browser from that capture: Benchmark;
seven visible checkbox controls; eighteen visible dropdowns and selected values;
Graphics Card and Video Memory information; Accept/Cancel; Resolution/UI scale
values; Apply UI Scale. Hidden controls, label duplicates, slider subcomponents
and footer links are excluded. Inactive controls remain informative. Selected/
active native checkbox state is reported without claiming checked semantics.
Scale percentages and hardware text are read from native children; information
rows do not announce structural NewState. Values are captured entry snapshots.
An expanded dropdown observed on entry suppresses the underlying list; general
popup/modal focus and updates after outside edits remain unfinished.

All 33 Advanced entries are read-only. Benchmark, Apply, Accept, Cancel,
checkboxes, sliders and dropdowns have no native dispatch path. Only the two
previously verified view targets (Graphics and Advanced) can activate. Their
screen templates, raw-field/identity checks, fresh resolution and four-second
confirmation remain unchanged. The proven native traversal/isolated logger is
unchanged apart from its existing three metadata annotations. The source has
one native SimulateLClick call site and no coordinate/global-hotkey path.

121 fixture scenarios passed, including all 33 observed entries and their
read-only rejection, raw inactive/selected states, 152-node bounded capture,
cache behavior/wraparound, footer exclusion, hidden controls, malformed native
labels/values, captured popup suppression, reduced string library, same-root
visibility transitions and all previous activation/lifecycle/clock/read guards.
Pack extraction matched source; ZIP hashes, speech trace and shipped temporary
installer/tamper/uninstall/preservation tests passed. Existing RPFM warnings
remain nonfatal with matching round-trip source. 0.5.9 is built, not installed
or live-tested. Verified 0.5.8 and 0.5.7 ZIPs are unchanged.
0.5.9 ZIP SHA256: 312750ED6B4C918A936B39634211CB2F81386A0824BEE5C7846C14D70D19D700.
Next live check: open Graphics then Advanced, browse the expected 33 entries and
verify sample dropdown values, scales and no background duplicates. Test Escape
and main-menu browsing. Collect native preview, bridge and speech trace logs.
Full audible completion is still separate from NVDA API acceptance.


2026-10-28 verified checkpoint: 0.5.7 successfully opens Graphics, exposes
seven native basic controls with Resolution/Quality values, excludes footer
links, and returns to the 22-control main menu after Escape. The user confirmed
success. The exact cached-Graphics-to-main probe branch was not separately
captured in the latest return run; that branch remains fixture-tested. Full
speech completion remains distinct from successful Controller Client returns.
The isolated plain logger remains in use; string.match exists in the actual
host, so its absence was an offline reproducer, not the established live cause.

0.5.8 is built as the next view/discovery preview, not installed or live-tested.
It adds one allowlisted target: button_advanced_options at the captured path
options_graphics/basic_options/button_advanced_options (zero-based 2/1/3).
Graphics from the exact main menu is still enabled. The 40-node basic Graphics
field template is independently verified, and every F4 re-captures, compares
identities/raw fields, re-resolves every visible ancestor and checks the active
leaf. Pending confirmation includes target identity and expires after four
seconds; navigation, state changes, errors, lifecycle and clocks cancel it.
Both targets use one native SimulateLClick dispatch site. No settings writes,
checkbox/dropdown activation, Accept, Cancel, Recommended or gameplay are enabled.

After native dispatch the result is unconfirmed until a later capture sees
basic Graphics or the Advanced panel, respectively. Matching native results
are logged; a returned click alone is never a success claim. Known child-panel
visibility flags are checked before using cached navigation, so collapsing
Advanced without replacing the root/panel can refresh the basic control list.

Advanced's visible descendants have not been observed in-game. F2 after opening
it performs bounded discovery (200 nodes, depth 20) and announces captured data;
it deliberately does not invent a control list or expose background footers.
Visible Advanced detection is a read-only observation, not a general modal-focus
detector. Truncation is logged and cannot enable setting actions. The next native
capture is required before mapping the actual Advanced controls.

115 fixture scenarios passed: all previous main-menu/basic-reader checks plus
Advanced confirmations, raw read/identity failures, duplicated IDs, layout/popup
changes, lifecycle, log loss, observed-result versus no-result cases, unchanged
root/panel identities with visibility changes, and bounded oversized discovery.
Synthetic Advanced descendants are fixture data only and are not assumed to
match the game. Lua syntax, preserved traversal/isolated logger, pack source
round-trip, ZIP payload hashes, speech trace and shipped temporary installer/
tamper/uninstall/preservation tests passed. Existing RPFM reserved-path warnings
remain nonfatal; extraction hash matched. Verified 0.5.7 and read-only 0.5.3 ZIPs
are unchanged. 0.5.8 ZIP SHA256: 659E5B3EA5A01A31D7437844B2EE30B1A341BDC593DE416FD4D7D622869E1C4D.
Next live test: open Graphics, select Advanced, double F4, then F2 once for the
native discovery capture. Test Escape and F2/F3 afterward. Collect native preview,
bridge and speech trace logs; confirm whether Advanced opened. Map controls only
after actual visible-panel evidence arrives.


2026-10-28 live 0.5.6 Graphics activation PASSED. The tester reported it worked.
The native log records a single activation.dispatch/activation.returned pair.
The next native capture finds root child2 Id options_graphics, with basic_options,
seven basic controls and their value/label children. This is observed native
screen-transition evidence in addition to the user report. Escape return and
full audible completion remain separate live checks.

The post-activation capture visited 40 nodes. Its three navigable entries were
Total War Academy, Patch Notes and Quit, all footer controls. The scanner did
not miss the Graphics data: the old main-menu ID classifier excluded checkbox,
dropdown and new button IDs. Observed Resolution was 1280x720 and Quality Low.
The Advanced panel and dropdown popups were hidden. CurrentState active on the
windowed checkbox does not establish whether it is checked.

0.5.7 adds a separate read-only Graphics scope using the captured basic panel
paths and native label/value fields. It exposes seven controls: Run in window,
Accept changes, Cancel changes, Advanced, Recommended, Resolution and Quality.
It removes the footer from Graphics navigation, marks settings read-only, and
reports checkbox checked state as unavailable. Unsupported advanced/popup or
unknown top-level panels do not fall back to unrelated footer entries.

A bounded fresh root/panel identity probe detects panel replacement before
reusing a cached list, so Escape can restore main-menu browsing without a
UI-created event. This probe is fixture-tested, not live-verified. Settings
values are entry snapshots; no settings edits, apply/cancel/recommend actions,
dropdown expansion or Advanced activation are enabled. F4 still only opens
Graphics from the exact verified main menu. General modal detection is unfinished.
The proven traversal and plain logger are preserved with their existing three
metadata annotations; native read order is unchanged inside that traversal.

76 fixture scenarios passed, covering the captured 40-node Graphics page,
seven-control labels/value reporting, exclusion of footers, forward/reverse
wraparound, disabled/hidden/malformed fields, read-only F4 rejection, new-panel
and Escape-like root replacement without callbacks, reduced string library,
plus all previous main-menu activation guards. Pack extraction matched source,
ZIP payload checks, speech trace and shipped temporary installer/tamper/
uninstall/preservation tests passed. Working 0.5.6 and read-only 0.5.3 ZIPs
remain unchanged. 0.5.7 is built, not installed or live-tested.
ZIP SHA256: 2ABCE1436A4A1C74382EED4AA9EAD90697E69FACD52A241407DCB41B9B80278E.
Next test: open Graphics, verify seven scoped controls and values; use Escape,
then verify main-menu F2/F3. Collect native preview, bridge and speech trace logs.


2026-10-28 subsequent 0.5.5 live result: raw shortcut and navigation records
confirm script_F2 was received. Cached state was false and runs was zero. The
last record is capture.ENTER, before any native UI read. The input-delivery
hypothesis is ruled out for that F2 event. No menu speech was generated.

0.5.6 removes metadata bookkeeping from log(), restoring that function exactly
to the proven diagnostic implementation. observe() stores flat native results;
metadata is interpreted after traversal. capture_tree differs from the proven
function only in control-path annotation, node-count recording and explicit
classification-error invalidation. Shortcut trace/error reporting remains.
Setup-stage markers and string.match/string.find availability are logged.
The log cap now includes the header and conservatively accounts for CRLF.

An offline comparison reproduced the exact old stopping point by making
string.match unavailable: 0.5.5's logger fails after capture.ENTER, then its
navigation error handler fails in the same logger. Under that same reduced
library fixture, 0.5.6 navigates successfully. This is a concrete reproduction,
not confirmation that the game's string.match is absent; the next startup log
will record its type. The cause in the live host is still not fully established.

65 fixture scenarios pass, including reduced string-library navigation,
confirmation, strict screen layout, native identities, failed reads, lifecycle,
clock boundaries, log loss/cap and error recovery. Plain logger source equality
is checked. Pack extraction and ZIP hashes passed, as did speech trace and
shipped temporary installer/tamper/uninstall/preservation tests. The original
0.5.3 read-only ZIP remains unchanged. 0.5.6 is built, not installed/live-tested.
ZIP SHA256: F35BB65D472A595F2C633A2930A2222167D3B838373256969F2F7D934A340B3B.
Next test: F2 once, wait, F3 once. Stop before F4 unless real controls are spoken.
Collect native-ui-graphics-preview.log and bridge.jsonl, including on silence.


2026-10-28 live 0.5.4 regression: the manifest/receipt and bridge startup
confirm 0.5.4. The native preview log contains only the header and UI-created
record, with no capture entry. Four F4 callbacks produced the no-selection
message. NVDA accepted those requests. The logs cannot distinguish absent or
remapped F2/F3 events from a navigation exception before the first scan log.
Do not attribute the failure to NVDA, shortcut interception or native scanning
without further evidence. The failed run was preserved under this chat's work/.

0.5.5 is built as a diagnostic update, not a proven runtime fix. It separates
F2/F3 navigation and F4 activation listeners, caches the delivered shortcut
string per handler, logs up to 64 raw ShortcutTriggered names, accepted
navigation events, cached-state types, capture entry and completion/error
markers. The browse branch is protected and reports navigation exceptions.
The Graphics activation boundary and exact capture_tree function are unchanged.

64 Lua fixture scenarios passed, including raw unknown/remapped events, trace
limits, first-input lifecycle order and recovery from a navigation exception.
Pack extraction matched source; ZIP hashes and speech trace fixtures passed.
The working 0.5.3 rollback ZIP is unchanged. 0.5.5 is not installed or live-tested.
First retest F2 once, then F3 once; do not use F4 unless controls are announced.
Collect native-ui-graphics-preview.log and bridge.jsonl even when silent.
0.5.5 ZIP SHA256: F8C1B96B01830AFB9BE303DFB9E41A55A8583A56CDD4C9A52BD33EE24ED5A5E3.


0.5.4-nvda-graphics-preview is built and packaged, not installed or live-tested.
It is a separate frontend source, diagnostics/graphics_preview.lua, rather than
the failed generalized navigator. capture_tree is checked for exact source
identity with the successful diagnostic. Metadata collection and activation
sit outside that function, and F2/F3 retain direct cached diagnostic browsing.

Activation is limited to the verified Graphics path and label. Every F4 obtains
a new bounded capture, checks the captured 86-node main-menu field template,
compares every raw field and opaque identity against the browse snapshot,
then resolves and re-reads the Graphics ancestry from a fresh root. The second
F4 must arrive within four seconds, with validation completed before expiry.
Navigation, unreadable or changed UI, lifecycle/panel events, clock anomalies,
missing selection and failed/full diagnostics block or cancel activation.
Selection and confirmation are consumed before the single SimulateLClick call.
The speech result states only that input was sent, never that Graphics opened.

The exact-screen template intentionally blocks differing menu configurations,
including unrelated state changes. It is not a verified general modal API.
No campaign/battle, other menu control, coordinate input or shortcut dispatch
is available. 0.5.3 and 0.4.3 rollback ZIP hashes remain unchanged.

Validation passed: Lua syntax, unchanged capture_tree source, 60 fixture
scenarios reconstructed from the actual 86-node capture (cached 22-control
navigation/wraparound, only Graphics dispatch, confirmation boundaries,
identity replacement, failed/function/nil reads, disabled/hidden ancestry,
preexisting/new panels, lifecycle and context changes, log loss/cap, native
click exceptions and no unobserved-success claim). Pack extraction matched the
Lua source hash; ZIP payload hashes and shipped installer tests passed,
including tampering, nondefault paths, reruns, uninstall and unrelated-file
preservation. Speech trace fixtures passed. The bundled Lua 5.1 DLL executes
the fixtures. RPFM emitted its existing reserved-path warnings; round-trip
verification still passed.

Build: tools/build-graphics-preview-windows.ps1 -Python <python.exe>.
Package mode: tools/package-pilot.py --graphics-preview.
ZIP SHA256: 19E8D1CECB41ABEA995DE4F2AF81FF7B599F42B3C6D9E4229C4B363B535EFCB9.

Next live test: install 0.5.4, verify F2/F3 still find real controls, then choose
Graphics and tap F4 twice within four seconds. Verify whether Graphics opens;
use Escape to return and browse again. Collect native-ui-graphics-preview.log,
bridge.jsonl and speech-trace.jsonl, plus audible/visual observations. The exact
cause of the old generalized scanner failure remains unknown.


0.5.3 live read-only test PASSED UI discovery and navigation: the diagnostic
visited 86 nodes, classified 22 controls, completed both capture and comparison,
and logged no .ERROR records. Bridge records confirm F2/F3 movement and both
wraparound directions (New Campaign to Quit and Quit to New Campaign), plus
inactive Continue and Load Campaign states. The receipt confirms installed
0.5.3-nvda-scanner-compare. Audible completion has not been explicitly assessed.

All 32 preview-reader comparisons on the root and first child returned valid
values, including those inside the additional protected wrapper. The final
inline/adapter/tail/nested root reads also agreed. This does not reproduce the
full preview scanner failure and does not establish its root cause. It is
evidence against treating the reader or protected wrapper alone as the cause;
call ordering, full traversal/classification and execution context still differ.

Keep 0.5.3 as the currently working read-only installation. F4 remains disabled;
no activation was tested. Next engineering step: retain the proven scanner and
introduce identity/path capture and fresh validation incrementally for Graphics,
with raw native-read evidence, rather than another uninstrumented reader change.


Latest live 0.5.2 result FAILED. Both manifest and bridge hello confirm 0.5.2.
It again scanned seven nodes then one, with function-valued native reads and no
menu controls. The proposed reader-layer change did not resolve the failure.
Do not attribute the regression to protected calls or tail calls as established
fact. The supplied native-ui-diagnostic.log is still from the 0.4.3 run.

0.5.3-nvda-scanner-compare is a separate read-only investigation build. Its
baseline capture_tree is checked for exact equality with diagnostics/native_ui_diagnostic.lua.
After baseline traversal it compares the 0.5.2 reader on the same root and first
child, direct and inside an additional protected action wrapper, then repeats
the diagnostic root sample. It writes native-ui-scanner-compare.log. F4 is unbound;
no click/shortcut dispatch exists. F2/F3 navigate the captured baseline controls.
The original 0.4.3 ZIP remains unchanged. Initial build status was untested;
the later live result above confirms installation and read-only success.

Validation: Lua syntax and comparison harness passed, including malformed
function returns, one-shot capture, error retention, F4 rejection and baseline
traversal preservation. Pack round-trip hashes, ZIP integrity and shipped ZIP
temporary installer/tamper/uninstaller/preservation tests passed. Lua execution
uses the bundled Lua 5.1 DLL. Build: tools/build-scanner-compare-windows.ps1 -Python
<python.exe>. Package mode: tools/package-pilot.py --scanner-compare.
RPFM emitted its existing reserved-path warnings; round-trip hash matched.
0.5.3 ZIP SHA256: 0E33CDDDDD3F2B43C8563A64E506B4B006F1568636E662A0B0130570B1CF1F57.
The requested 0.5.3 capture has now been collected and passed as described above.


2026-10-26 subsequent live 0.5.1 test FAILED: the fresh frontend bridge contains
58 records, no Controls entries, an initial seven-node traversal followed by
one-node traversals, and invalid function values from scalar native reads.
F4 reported no selection; no activation was reached. The submitted
native-ui-diagnostic.log identifies 0.4.3 and is historical evidence, not a
0.5.1 capture. Speech trace records successful NVDA API returns and repeated
interrupting speech requests; audible completion was not assessed by the user.

0.5.2 is a candidate correction: assign each native result directly inside the
protected callback instead of returning it through a separate reader closure.
The exact live cause remains unproven. It also corrects the obsolete Shift-F4
guidance to the game's Escape key and includes its version in frontend hello.
The Graphics-only activation boundary and unchanged 0.4.3 rollback remain.
Validation: Lua syntax and 227 fixture records passed in normal and host-pcall
modes, including function-valued required-read failures. The bundled Lua EXE
could not launch (Windows error 623); fixtures used the same bundled Lua 5.1 DLL
through a temporary ctypes runner. Speech tracing, pack source/extraction hash
comparison, ZIP integrity and temporary installation/uninstallation tests passed.
RPFM emitted its existing dependencies_manager_v2 reserved-path warning;
extracted Lua still matched the source. The 0.4.3 fallback ZIP SHA256 remains
A04A0351386B15C99715F16F9841E96550EDD2318453CAD179AB7D9A34941AA9.
0.5.2 ZIP SHA256: 6CAA7B005382608E2550729DE6FE148FB61495FF1FA2067CB0606A880A71BB46.
0.5.2 is built, not installed or tested in-game. Retest F2/F3 first; do not infer
live correctness from fixtures.


0.5.0 live regression: F2/F3 repeatedly reported no Controls entries after scanning only one UI node; the first recorded read issue was `GetStateText returned userdata`. Graphics activation was not reached. The root cause is not yet proven: the first-error-only report concealed the ChildCount failure details.

0.5.1 replaces the argument-taking reader table with zero-argument captured-component closures matching the successful diagnostic pattern, traverses children before classification, and retains multiple distinct native read errors. Normal and host-pcall fixtures pass, including malformed root text with readable children. The pack roundtrip and installer tests pass. The 0.5.1 preview was installed after backing up 0.5.0 and its logs under `local/scanner-regression-7563aaef130c4f6787eb8679a0c5f7af`. Retest is pending: keyboard automation did not advance the Steam launch-options dialog. No live scanner-fix or activation success is claimed. Installed ZIP SHA256: `15ce79c177812660962d7c4383a0fab538b596eee2420dcaffbdefd0a1a96f12`.

After the activation review and the user's request to continue development, a separate `0.5.0-nvda-preview` ZIP was built. It contains the Graphics-only game-side activation prototype, explicitly selects NVDA, excludes Native.cs/HotkeyPolicy.cs, and enables speech tracing. It has not been installed or live-tested. The unchanged 0.4.3 diagnostic ZIP remains the fallback. The earlier requirement to wait before packaging is superseded for this development preview; audible completion and frontend modal behavior remain live acceptance requirements.

The activation prototype now rejects failed required reads, including failures shared by both the browse and activation snapshots, requires the observed `active` state, validates ancestor visibility, and blocks activation whenever a tracked panel is open. Fixtures exercise these cases in normal Lua and the host-pcall variant. Frontend modal events have not been established by a live capture; campaign-named mock events do not prove frontend coverage. Do not test activation with an open modal. `tools/build-interactive-windows.ps1 -Python <python.exe>` builds and roundtrip-verifies the pack, then packages it. Windows installer fixtures passed against the ZIP, covering tampering, repeat installation, rollback, and preservation of unrelated files.

2026-10-26 live 0.4.3 result: the diagnostic and quiet-mode add-on were installed, NVDA restarted, and the game loaded with only warhammer_access enabled. The new capture completed 86 nodes and 22 controls; bridge records show full names and forward/reverse navigation. The tester heard diagnostic speech but reports each control utterance stops after “Controls.” This does not pass speech usability. Three startup watchdog recoveries were observed; the ten-minute menu stability test was not completed because Computer Use was stopped with Escape. Do not infer that quiet mode fixes the freezes or that controller API acceptance proves audible completion.

An unreleased companion `-TraceSpeech` option now records UTC timestamps, process/request IDs, full requested text, NVDA return codes, and explicit companion stop requests in bounded local `speech-trace.jsonl` files. It is off by default, has fixture coverage, and is not installed in the 0.4.3 package. A zero return code records API acceptance only, not spoken completion. Use this to distinguish rapid replacement requests from an interruption outside the companion if the single-tap test still truncates speech. The tester's single-tap-and-wait result is pending.

A subsequent direct Controller Client probe ran with NVDA process 14288 present and Warhammer II closed. The sandboxed connection returned RPC error 1722; the approved unsandboxed call returned 0 for both connection and a single complete speech request with interruption disabled, without a braille call. Audible completion is awaiting tester confirmation. This is an out-of-game comparison, not proof of speech behavior while the game is focused.

The first 0.3.0 Windows capture proved that the root is valid: Id and ChildCount returned the same correct values through inline, adapter, tail and nested calls; Address returned opaque userdata. This disproves the earlier protected-call/tail-call hypotheses. The diagnostic itself then stopped before `child0.Find.START` in its unprotected bounded-loop setup, while F2 key repeat started five captures and prevented the hover capture.

The 0.3.1 run established successful root-child conversion for `layout`, `watermark_square`, `main`, `sp_frame`, and hidden `browser`; all read methods returned consistent types and opaque addresses. Its hover event identified only the broad `main` container and the user rejected mouse-dependent testing.

The 0.3.2 keyboard-only run completed all 86 visible-tree nodes without error. It identified labeled wrappers for New, Continue, Load and Multiplayer Campaign; battle modes; graphics, sound, controls, game settings, brightness, credits and support; plus Total War Academy, Patch Notes and Quit. The screen-reader transcript confirms startup speech and the one-shot F2 capture. No further mouse/event-component evidence is required.

The 0.3.3 diagnostic stopped immediately after reading the root ChildCount, before its first child lookup. The 0.3.4 diagnostic moves classification after child traversal, isolates it behind its own protected call, and uses the exact control IDs established by the successful 0.3.2 capture. On its first F2 it performs the bounded tree capture and speaks the first known button; subsequent F2/F3 presses browse next/previous controls. It has no F4 handler, mouse dependency, activation, or game-command path. Diagnostic mode does not load the native mouse/hotkey assembly.

The 0.3.4 Windows result completed all 86 visible nodes, classified 22 controls, logged `capture.COMPLETE`, and spoke New Campaign, Continue Campaign, Load Campaign, Multiplayer Campaign, and Movie Viewer in order. No capture or classification error appeared. This validates the game-side read-only traversal and classification path. The screen-reader transcript also announced “left mouse button” twice, but the diagnostic contains no mouse action path and its launcher does not load the pointer/hotkey assembly, so that phrase cannot be attributed to a diagnostic mouse action.

The 0.4.2 NVDA test passed end to end: the game captured 86 visible nodes and 22 controls without errors; bridge sequences were consecutive; the tester confirmed NVDA spoke all 22 controls and reverse wraparound worked. NVDA's log nevertheless recorded recurring sub-second watchdog recoveries and UI Automation errors also seen before the diagnostic was installed.

The next package is 0.4.3-nvda-diagnostic. It adds a minimal, separately removable NVDA app module using documented per-application sleep mode for Warhammer2.exe. The add-on contains no gestures or input APIs. The test must prove controller speech continues while native game events and watchdog recoveries are suppressed. F2/F3 remain the only diagnostic keys; no mouse interaction, F4 handler, activation, or game command is included.

The unreleased interactive source has been narrowed in preparation for the following gate. Frontend activation is allowlisted only to the captured WH2 1.12.1 ancestry `main / banner_clip / fe_banner / menu / options_frame / holder / button_graphics` at its captured zero-based indexes, with the spoken label `Graphics`. Campaign, battle, shortcuts, dialogs, duplicate IDs elsewhere, and every other frontend control are blocked. Activation requires the same component address, label, tooltip, state, visibility and UI generation plus a second F4 within four seconds. Navigation, panel changes, UI recreation, errors and expiry clear the confirmation. The former unconfirmed Shift+F4 Escape path is disabled. These changes have fixture coverage but are not included in 0.4.3 and must not be packaged until the quiet-mode runtime test passes.

The development navigator removes the failing `math.*` bounds, derives labels from visible button descendants, excludes duplicate `button_txt`/title/icon presentation nodes, and explicitly reports that map targets are not keyboard accessible. Live activation remains deferred until the 0.4.3 quiet-mode test. Additional activation fixtures verify that a backward system-clock change and browsing away then back require a fresh confirmation. Unreadable-panel guidance now points to the game's Escape key.

The diagnostic package is not playable. 0.2.5-dev is a development build, not a verified replacement. Prior pcall/tail-call explanations remain hypotheses. See ENGINE_RESEARCH.md for the decision table.

Proprietary game extracts, screen-reader installers, downloaded developer tools, local captures and ZIP/pack artifacts are intentionally not committed. No license is assigned to third-party material.
