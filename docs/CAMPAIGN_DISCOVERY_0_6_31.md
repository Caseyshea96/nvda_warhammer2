# 0.6.31 stopping checkpoint — October 29, 2026

Stopped at the owner's request. **0.6.28 remains installed and accepted.**
Candidate 0.6.31 is built, packaged and tested offline; it has not been installed
or run in a live campaign. No game was launched during this continuation.

## Candidate changes

- Wait for a visible root HUD `layout`, no visible cinematic bars/loading screen,
  and two consistent root/layout identity samples before reading text. The game's
  own campaign UI library identifies `layout` as its HUD container. This gate
  has fixture coverage; its actual campaign behavior still needs verification.
- Scope capture to HUD/dialog UI. Explicitly log exclusions of root world-space
  labels/path icons and visual-only layers. This is not complete world discovery.
- Log each failed/incorrectly typed getter with method, path, expected/actual
  type, protected-call success and bounded error text. Count each issue once;
  nil/unexpected returns still mark capture limited, rather than being hidden.
- Log explicit node/child/depth/queue/entry budget reasons.
- Add a capture-only diagnostic request/status channel, independent of menu keys.
  `tools/live/Campaign-ReadOnly.ps1` supports Status and Capture only. It cannot
  start a campaign, select anything, activate UI or send game orders.
- Bind requests to the flag owner, game session, generation, unique token and
  UTC expiry. Reject stale/replayed/invalid requests; never retry automatically.
- Limit to three capture attempts, sixteen consumed request tokens, 180 readiness
  checks per attempt, 1,800 timer ticks, existing per-capture traversal limits
  and the shared 2 MiB log budget. Lease removal cancels the module.
- Preserve fresh root/layout checks for browsing and invalidate replaced UI.
  Scoped snapshot text is not automatically refreshed after every field change;
  an explicit Capture request creates the new snapshot.

The diagnostic uses `real_timer`/RealTimeTrigger so request polling is independent
of the campaign model callback path. **Campaign availability/liveness of that
native API is not yet live-proven.** Missing scheduler support reports an error
and stops; it must not be claimed as fixed by fixtures. The unsupported generic
`get_tm`/Timers path was not reintroduced.

## Verification completed

- 370 existing frontend scenarios and 32 campaign diagnostic scenarios: **402 Lua
  scenarios passed**. Checks cover early HUD/cinematic gating, scope exclusions,
  typed native failures, request owner/session/generation/expiry/replay guards,
  explicit fresh capture, caps, root/layout replacement and zero game clicks.
- PowerShell 5.1 mock-endpoint client tests passed: capture-only schema, fresh
  matching status, exact acknowledgement, invalid data and timeout without retry.
- Atomic create/replace tests passed for both clients on PowerShell 5.1.
- Speech checks, both-module pack round-trip, package hashes and shipped ZIP
  installer/tamper/uninstall/unrelated-file preservation checks passed.
- Accepted installed 0.6.28: all fourteen runtime payload hashes match. Game and
  companion counts are zero. Automation lease, campaign flag and request absent.

Candidate ZIP SHA-256:
`48e03f9037989b14e0e5d19d59678755f516b122594bfc1ab788968f833b1ce6`.

## Resume point

Do not promote 0.6.31 until a new approved live test verifies post-cinematic HUD
readiness, actual getter types, capture completion, the capture-only refresh
and native cursor checks. Physical-key delivery and full audible completion
remain separate acceptance gates. Campaign-map activation/gameplay/co-op stay
blocked. The previous one-campaign authorization was consumed by the 0.6.30
test; this continuation did not start another or assume new approval.

For an approved test, use the existing backed-up Start-Session flow with
-CampaignDiscovery. Once the campaign module is running, these are read-only:

    powershell.exe -File tools/live/Campaign-ReadOnly.ps1 -Action Status
    powershell.exe -File tools/live/Campaign-ReadOnly.ps1 -Action Capture

Capture acknowledges acceptance, not completion. Read Status until a fresh run
reaches ready or limited; inspect the log on error/timeout. The mode-verify
native cursor test is explicitly not a physical-key test. Stop-Session preserves
status/evidence and removes only its matching owned capture request and flag.

Source, fixtures and helper scripts remain in the repository. The tested
ZIP/checksum are in artifacts/ and outputs/. Verification snapshot is
work/checkpoint-0.6.31/final-checkpoint.json. Candidate changes are uncommitted;
previous work and rollback archives are preserved. No new continuation schedule
was created, and no more testing is planned until the owner resumes.
