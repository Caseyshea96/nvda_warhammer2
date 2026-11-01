# Warhammer II NVDA accessibility

A keyboard and NVDA screen-reader prototype for Total War: WARHAMMER II, built
so a blind player can try the game and give feedback on the controls.

**Current build: 0.6.65.** Menus (New Campaign, Continue Campaign, Select
Campaign including Mortal Empires), Select Lord as a sequence of choices (race,
lord, campaign setup with difficulty lists), confirmed Start Campaign, and
campaign-map reading (HUD, provinces, settlements, building and recruiting,
End Turn) have passed live testing on this PC. Moving armies and battles are
not supported yet; battles are planned as auto resolve.

The game-side Lua script writes speech requests to a bridge file; the Windows
companion (PowerShell and C#) forwards them to NVDA and passes the menu keys
back to the game. See [the latest trial notes](docs/TRIAL_3_0_6_64.md) and
[CLAUDE.md](CLAUDE.md) for the current state and how to build and test.

Build: `powershell -File tools/build-graphics-preview-windows.ps1` (runs the
checks, packs `warhammer_access.pack`, packages the ZIP). Build artifacts are
excluded from Git.

## Project documents

- [Implementation plan](IMPLEMENTATION_PLAN.md)
- [Current progress history](docs/CURRENT_PROGRESS.md)
- [Speech conventions](docs/SPEECH_CONVENTIONS_0_6_25.md) and [standard keys](docs/STANDARD_KEYS_0_6_27.md)
- [Engine research](docs/ENGINE_RESEARCH.md)
- [Local environment and pack inspection](docs/ENVIRONMENT.md)
- [RPFM setup](docs/RPFM_SETUP.md)
- [Transport specification](protocol/README.md)

Sources: `diagnostics/` (game-side Lua: `graphics_preview.lua` is the runtime,
`campaign_readonly.lua` the campaign reader), `companion/` (Windows PowerShell
and C#), `packaging/pilot/` (installer), `tests/`, and `tools/`. Proprietary
game extracts and downloaded tools stay under ignored `local/`; release
packages under ignored `artifacts/`.
