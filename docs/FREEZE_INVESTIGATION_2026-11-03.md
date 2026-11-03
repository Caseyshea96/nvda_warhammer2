# Freeze / silent reader investigation — November 3, 2026

Owner request: "investigate freezes". No code change; installed build 0.6.70
(source is 0.6.72, pulled from GitHub, not built on this PC).

## Finding: the freezes line up with graphics-driver timeouts on this PC

Windows recorded `LiveKernelEvent 141` reports (a GPU engine stopped
responding and was reset) with dump files named by their local time. On
November 1 the dumps fall inside the freeze runs:

| Run (Nov 1, local time) | Result | GPU timeout dump |
|---|---|---|
| live-0.6.67-moves .. moves-5 (16:01–16:36) | fine | none |
| live-0.6.67-moves-6 (16:38–16:42) | game not responding | none |
| live-0.6.67-moves-7 (16:45–16:48) | game not responding | none |
| live-0.6.67-moves-8 (16:54–17:01) | reader stalled at campaign load | **16:56** |
| live-0.6.67-moves-9 (17:02–17:06) | freeze | none |
| live-0.6.67-moves-10 (17:11–17:12) | game not responding | none |
| live-0.6.66-select-check (17:15–17:21) | freeze (old build) | **17:17** |
| live-0.6.67-reader-off (17:22–17:28) | **campaign reader switched off**; from ~17:26 the screen changed only every ~25 s (pairs 3 s apart identical) | **17:24** |
| live-0.6.67-moves-11 (17:29–17:36) | reader silent | **17:34** |
| live-0.6.67-moves-12 (17:40–17:45) | stalled a few seconds, recovered | **17:44** |
| live-0.6.68-moves-2 (18:32–18:35) | reader stopped | **18:34** |

Other dumps: Oct 29 15:31, Oct 30 09:02, Nov 1 12:55. None on Nov 3.
Six of the problem runs have a dump inside them, none of the five clean runs
before them do, and the run **with the campaign reader switched off** (no
mod code on the campaign map at all) slowed to one frame per ~25 s with a
dump. Runs 6, 7, 9 and 10 have no dump; Windows does not keep a dump for
every timeout, so they are probably the same thing.

How that explains both symptoms: the game's script timers (`real_timer`
and `cm:repeat_callback`) tick on the game's main loop. When the GPU hangs
or crawls, the main loop waits on it, so the mod's heartbeat stops ("silent
reader") or, when the wait is over ~5 s, Windows marks the window "not
responding". Both stall together, as seen before.

## The PC

Intel Core i7-1065G7 laptop (15 W; CPU and GPU share the power budget),
Intel Iris Plus integrated graphics, driver 27.20.100.9510 from April 2021.
The game already ran at the lowest presets, windowed at 1280×720.

## Live runs today (player path, Continue Campaign, installed 0.6.70)

`tools/live/Monitor-Game.ps1` sampled every second: reader heartbeat age,
game CPU, the game's GPU 3D use, CPU performance (percent of base clock).

| | `work/live-0.6.70-freeze-1` (old settings) | `work/live-0.6.70-freeze-2` (lower settings) |
|---|---|---|
| Keys | 23 F6/Shift+F6, F7 and a march to Caledor's Repose | 57 F6/Shift+F6, F7 and the same march |
| Longest reader gap on the map | 2.4 s | 1.3 s |
| Game GPU 3D use (median) | 96 % | 90 % |
| CPU clock (median, % of base) | 64 % | 88 % |
| Freeze / silent reader | none | none |

On the campaign map the game keeps the integrated GPU nearly saturated the
whole time, and the CPU runs well below its base clock because the GPU takes
the power budget. Lower settings gave the CPU back about a third of its
clock. Neither run froze, so today's runs do not reproduce Nov 1 (which had
an hour of back-to-back sessions).

## Settings changed on this PC (owner, Nov 3: "you can put the graphics settings even lower")

`%APPDATA%\The Creative Assembly\Warhammer2\scripts\preferences.script.txt`:
`gfx_resolution_scale` 1 → 0.5, `gfx_vsync` false → true, `gfx_distortion`,
`gfx_sharpening`, `gfx_blood_effects` true → false. The original is in
`work/live-0.6.70-freeze-2/preferences-before.script.txt`.

## Conclusions

- The freezes on this PC are most likely the laptop's graphics (driver
  timeouts under constant full GPU load), not the mod: they happen with the
  campaign reader off, and with 0.6.66. The friend's PC may not have them.
- The mod cannot stop a GPU hang. It can make one less confusing for a blind
  player (not built): the companion could say "The game is busy." when the
  heartbeat stops for a few seconds and "Ready." when it comes back.
- Worth doing on this PC (owner): update the Intel graphics driver (Intel's
  current driver for Iris Plus is much newer than April 2021); keep the
  laptop plugged in and cool during tests; leave a minute between sessions.

## Not verified

- Whether the lower settings or a driver update prevent the freezes: today
  had no freezes on either setting.
- Whether the four problem runs without a dump were GPU timeouts.
- The friend's PC (graphics hardware unknown).

## Later the same day (0.6.73)

The companion now says "The game is busy." during a stall
(`docs/BUSY_NOTICE_0_6_73.md`). In `work/live-0.6.73-busy` the game froze
for good while moving through the campaign Game Menu, about 2 minutes after
a 9 s test pause of the process: frames identical, Windows "responding", one
core busy, reader silent 3+ minutes, **no GPU timeout report** this time. The
same steps in a fresh session (`work/live-0.6.73-busy-2`) worked. So not
every freeze leaves a driver report; the pause may have contributed.
