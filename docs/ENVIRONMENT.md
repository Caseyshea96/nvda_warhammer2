# Installed environment

Verified from local files, 2026-10-24.

- Game: Steam app 594570, Total War: WARHAMMER II.
- Steam manifest state: installed (`StateFlags=4`), build `13784690`.
- Directory: `/home/casey/.local/share/Steam/steamapps/common/Total War WARHAMMER II`.
- `Warhammer2.exe`: Windows x86-64 PE executable, confirmed present.
- Steam compatibility selection: `proton_experimental`. This identifies the selected channel, not a tested runtime version.
- Host: Fedora 44 x86-64, glibc 2.43.
- Game launch and co-op connectivity have not been tested by the agent.

## Initial input findings

The installed `data/text/default_keys.xml` defines hidden script shortcuts `script_F2`, `script_F3`, `script_F4`, and Shift/Ctrl variants. Its shortcut assignments route these to the root component. This is evidence for investigating native script input before building a companion-to-game command channel; it does not yet prove event delivery or freedom from screen-reader key conflicts.

The file also maps next/previous selection to the battle card manager and cancel-order to `button_halt`. These are candidates for normal game command routes. No key bindings have been changed.

## RPFM compatibility

The official 5.2.0 Linux archive passed its published SHA-256 check, but its binaries require `GLIBC_2.44`. The system has not been upgraded to accommodate them. Official **4.5.4** also passed its published checksum and its CLI runs successfully. It is now pinned in the setup script and release metadata. `tools/rpfm.sh` selects WH2 and keeps configuration under ignored `local/rpfm-config`. GUI runtime dependencies are not yet verified.

## Initial pack inspection

RPFM successfully indexed `data.pack` and extracted its scripts under ignored `local/inspection/base`. This is base-pack source evidence; inspect overrides in other packs before treating it as the final effective script set.

- `script/_lib/lib_mod_loader.lua`: common mods at `script/_lib/mod/`; campaign mods at `script/campaign/mod/` and the campaign-specific mod directory; battle mods at `script/battle/mod/`; frontend mods at `script/frontend/mod/`.
- Campaign loading is registered on `NewSession`, with named mod functions executed on `FirstTickAfterWorldCreated`. Battle/frontend paths load directly in their respective branches. Startup code must respect this distinction.
- `ModLog` uses `io.open`, writes newline-delimited text, flushes, and closes. This supports the proposed file transport approach, but actual permissions, working directory, and latency remain runtime checks.
- `script/events.lua` defines `ShortcutTriggered`; campaign scripts demonstrate listeners for it.
- Several shipped campaign scripts call `CampaignUI.TriggerCampaignScriptEvent`, establishing concrete WH2 examples to inspect before custom synchronized commands.

All installed top-level `.pack` files were indexed: `lib_mod_loader.lua`, `lib_core.lua`, `events.lua`, and `all_scripted.lua` were found only in `data.pack`. The audit result is stored locally in `local/inspection/loader-pack-locations.json`. This resolves overrides for these four files, not every campaign script.

A read-only probe pack (since removed) was built and copied to `data/`, holding one script. Lua 5.1.5 syntax checks, engine-mock tests, and RPFM pack round-trip checks passed. In-game tests are pending; see [the procedure](PROBE_TEST.md).

No vanilla packs or Steam settings were modified. The only deployment change was that diagnostic probe pack; it was not enabled by the agent.
