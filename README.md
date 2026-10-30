# SurvivorsLite

A small, fast HUD addon for [Azeroth Survivors](https://wow.aethus.pl), written as a light
replacement for SurvivorsDragonUi. Tested against the client's addon API of web build
`019734ed2f34` (2026-10-30).

- Download: [latest release](https://github.com/datawulf/SurvivorsLite/releases/latest)
- Documentation: [datawulf.github.io/SurvivorsLite](https://datawulf.github.io/SurvivorsLite/)
- Changes: [CHANGELOG.md](CHANGELOG.md)
- Support the work: [Ko-fi](https://ko-fi.com/munkrej)

Fan made and not affiliated with the makers of Azeroth Survivors or with Blizzard
Entertainment.

## What it shows

- Hero bar under your character: level, health (green to red), experience line and
  extra lives. Your absorb shield sits on the health bar as a pale segment after your
  health, with a bright tick at the end when health and shield pass your maximum, and
  its amount after your health ("489 +120"), from the shield the run reports. Under it
  your buffs and debuffs with time left and stacks, and for timed buffs how much of this
  run they were up. A buff that ran out stays dimmed with its uptime.
- A class colored ring around your character, drawn above the 3D world so you can see
  where you stand under tree tops.
- Name plates:
  - Final boss (skull, magenta), bosses (skull, orange) and guardians (star, gold, dimmed
    while asleep) get a bar with health in percent and as a number, "ENRAGED" when a
    boss enrages, and your debuffs on them with stacks and time left.
  - A plate is matched to the run's unit list by name and, where several units share a
    name (an elite pack mob named like a guardian), by health, so only the real one is
    marked. Elites can be marked too (off by default).
  - Plain enemies get a thin bar of their own health and nothing else (or no plate, or
    the game's plate).
  - Party members get a class colored plate with their level and a big arrow.
- Party frames: class colored health, level, damage per second, DOWN or revive
  progress, faded when out of range. Click a row to target.
- Every guardian's lair has a look of its own, by its place in the run's lair line: a
  dragon head in a color of its own (red, blue, green, bronze, purple). The same icon and
  color are on its minimap pin, its line in the status list and its guardian's plate, so
  you can tell the guardians apart at a glance.
- Boss status list, one short line each: bosses alive with their health, every
  guardian's lair (asleep with how far it is, awake with how far you are from its lair
  against its leash, or when it comes back) and the next boss. The lair that comes back
  first says "next" in gold with its countdown and how far it is. Lines whose unit has
  its plate up near you are bright.
- Minimap: every guardian's lair under its dragon head with an edge in its color (dim
  while it refills, "!" while its guardian is awake, kept on the edge when off the map), a
  ring at the leash radius around each held lair, and the run's chests as small treasure
  chests. The lair that comes back first is bigger,
  glows gold and counts down under its pin, so you can head there before it fills.
- Leash bar over your character while a guardian chases you: how far you have led it from
  its lair against how far it will follow ("Mother Fang  32 / 40 yd"), green, orange, then
  red, with "gives up soon" before it turns back home.
- A compact floating action bar made of the game's own buttons: the six spells, the
  racial and the character and talent buttons, with seconds left on each cooldown and
  the talents' clocks (Cheat Death, heals, demon summons) over it. Under it the jewelry
  you picked this run (amulet, rings, trinkets) with its quality, its cooldown and its
  tooltip under the mouse.
- Skill circles: tick any of your run skills (Eviscerate, Blade Flurry...) and a circle in
  its own color shows its reach around you. The reach is read from the skill's own
  tooltip ("8 yd radius", "12 yd range", "within 12 yd"), so it follows ranks and upgrades
  by itself. An area (a radius or a cone) also grows by your Area stat, which the tooltip
  does not count; a targeting reach ("12 yd range", "within 30 yd") stays as shown. If a
  skill's tooltip turns out to count Area already, the addon notices when Area changes and
  uses that skill's yards as shown. Picks are remembered by skill name.
- Range circles around your character: a blue one at a radius you pick (8 yd by
  default), an optional orange second one and an optional gold one at your pickup
  radius. The blue and orange circles can grow with your Area stat.
- Circles lie on the ground in perspective when the client gives the camera's distance
  and angle (see below), and follow your zoom and camera angle; otherwise they are flat on
  the screen and need one size calibration.
- Warnings over your character: the next boss in the last 10 seconds before it comes,
  and "Name is down!" when a party member falls. A red pulsing screen edge under 35
  percent health.
- An options window with every setting, changed live.

## Install

Download `SurvivorsLite-<version>.zip` from the
[latest release](https://github.com/datawulf/SurvivorsLite/releases/latest). The zip holds
one folder named `SurvivorsLite`, which is what the game's installer wants. GitHub's
"Download ZIP" of the source does not install.

In the browser game: Options, AddOns, Install, then pick the zip. It loads on your next
run. Remove SurvivorsDragonUi on the same page so the two do not both run. A new version
installs over the old one and keeps your settings.

In the Windows build: unzip so the game's AddOns folder holds `SurvivorsLite\`.

## Feature status

Every feature passes the test harness, which runs the addon against the game's own addon
API in a mock of the 1.12 client. Not every one has been seen in the real game yet.
Tried one of them? Tell how it went with a
[feature check](https://github.com/datawulf/SurvivorsLite/issues/new?template=feature_check.md).

Seen working in game (player screenshots and reports):

- Hero bar under your character: level, health and experience line.
- Buff and debuff icons with time left and buff uptime.
- The class colored ring around your character.
- Boss and guardian plates with health bars.
- Thin health bars for plain enemies.
- The boss status list.
- The range circle and skill circles, flat on the screen.

Not confirmed in game yet:

- The guardians' reset range (leash): the leash bar over you, learning the real distance,
  leash rings on the minimap and leash distances in the status list.
- Circles on the ground from the live camera. The client may not give live values to
  saved views; then the circles stay flat (`/slite camera` tells).
- Skill circles following each skill's tooltip yards (ranks and upgrades).
- Minimap pins for lairs and chests.
- Guardian looks and the next respawn pin and line.
- The shield on the health bar.
- The floating action bar with cooldown seconds and talent clocks.
- The gear buttons on the minimap and the action bar.
- Debuff icons and absolute health on boss and guardian plates.
- Matching same-named units by health, so only the real guardian is marked.
- Party frames and party member plates.
- The boss countdown, the "Name is down!" warning and the low health screen edge.
- The fix for the Alterac Valley error window (1.7.1).
- The picked jewelry row under the action bar (1.8.0).
- Area skills growing by your Area stat on top of their tooltip (1.8.0). If an area skill
  still hits farther than its circle, the game may count the enemy's body size too.
- The dragon head and chest icons on the minimap (1.8.0).

Tried and not possible from an addon: see [Limits](#limits).

## Options

`/slite` (or `/sl`), the gear on the minimap's edge, the gear at the end of the floating
action bar, or the SurvivorsLite button in the game menu (Esc) open the options window.
Esc closes it. Point at a setting for what it does. "Move frames" lets you drag the hero
bar, action bar, party frames, status list and the circles' center.

## Circles on the ground

The client has no addon call for the camera, but 1.12's saved views carry it: `SaveView(5)`
writes the camera's distance and pitch into the `cameraDistanceD` and `cameraPitchD`
settings. The addon reads them twice a second (ten times a second right after the camera
moved or the wheel zoomed) while a circle shows, and projects every dot of every circle
onto flat ground around your feet. View 5's own values are put back at logout. The options
window shows what it reads under Camera, and `/slite camera` says it in chat.

- If it says "Waiting for the camera" after you zoomed or turned the camera, this client
  does not write live values into saved views, and the circles stay flat.
- Field of view sets how wide the camera sees. Match it once: turn on Pickup radius and
  change Field of view until experience starts flying to you as it touches the gold
  circle. After that the circles are right at every zoom and angle.
- The ground is taken as flat at your feet, so on slopes and hills the circles drift.

## Flat circles

Without the live camera the circles are drawn flat on the screen around your character
and need one calibration for the zoom you play at:

1. Zoom out the way you play and open `/slite`.
2. Turn on Pickup radius (it shows once a run sends your stats).
3. Change Size per yard until experience starts flying to you as it touches the gold
   circle. The blue circle is then right too.
4. If your camera looks in from the side instead of straight down, lower Height until
   the circles lie flat on the ground.
5. Move frames, then drag the small "You" box onto your feet if the circles sit off
   center. Lock frames when done.

Zooming in or out later makes the circles wrong until you change Size per yard again.

## The guardians' leash

The leash is how far from its lair you can lead a guardian before it gives up and goes
home. The client does not say, so it starts at the setting (40 yd) with a "?" after it and
is learned in play, both ways:

- While a guardian keeps chasing you, the farthest you stood from its lair counts as a
  distance it holds at (once it is still awake two seconds later, since the run's line
  lags). The leash grows to it.
- When an awake guardian falls back asleep alive while you live, where you stood is where
  it gave up. The addon says so in chat and the "?" goes away.

The distance is measured from you to the lair, through your map position and the lair's,
so it needs the run's lair line and a zone map. Moving the leash slider or
`/slite leash N` forgets what play taught.

## Commands

`/slite help` lists every command with its current state.

| Command | Effect |
| --- | --- |
| `/slite` / `options` | open or close the options window |
| `/slite unlock` / `lock` | drag the hero bar, action bar, party frames, status list and the circles' center |
| `/slite hero on/off` | hero bar with your health and auras |
| `/slite shield on/off` | your shield on the health bar |
| `/slite uptime on/off` | buff uptime under the aura icons |
| `/slite ring on/off` | ring around your character |
| `/slite lowhp on/off` | red screen edge at low health |
| `/slite bar on/off` | floating action bar (off puts the game's bar back) |
| `/slite barscale 0.5-1.5` | size of the floating action bar |
| `/slite jewelry on/off` | your picked jewelry under the action bar |
| `/slite cds on/off` | cooldown numbers and talent clocks |
| `/slite buffs timed/all/off` | which buffs to show |
| `/slite plates on/off` | boss and guardian plates |
| `/slite mobs bars/hide/show` | plain enemies: small bars, hidden or the game's plates |
| `/slite elites on/off` | mark elites too |
| `/slite debuffs on/off` | your debuffs on boss and guardian plates |
| `/slite autoplates on/off` | turn enemy plates on by itself |
| `/slite allies on/off` | party member plates, turns friendly plates on in a party |
| `/slite party on/off` | party frames |
| `/slite threats on/off` | boss status list |
| `/slite lairs on/off` / `chests on/off` | lairs and chests on the minimap |
| `/slite leashring on/off` | leash rings on the minimap |
| `/slite leash 10-150` | the guardians' leash radius in yards |
| `/slite leashbar on/off` | the leash bar over your character |
| `/slite mapbutton on/off` | the gear on the minimap |
| `/slite alerts on/off` | boss countdown and ally down warnings |
| `/slite skills` | your skills with a reach and their yards now |
| `/slite skill <name>` | a circle at that skill's reach on or off, e.g. `skill blade flurry` |
| `/slite range 8` / `range on/off` | range circle radius in yards (1-60), or turn it on/off |
| `/slite range2 30` / `range2 on/off` | second range circle |
| `/slite pickup on/off` | circle at your pickup radius |
| `/slite area on/off` | grow the range circles and area skill circles with your Area stat |
| `/slite ground on/off` | circles on the ground from the live camera |
| `/slite fov 30-100` | the camera's field of view for ground circles |
| `/slite camera` | what the ground circles read from the camera |
| `/slite zoom 5-60` | circle size per yard, matched to your camera zoom |
| `/slite tilt 0.3-1` | circle height for a camera that looks in from the side |
| `/slite scale 0.6-2` | size of the hero bar, party frames and list |
| `/slite perf` | measures this addon's own Lua time for 10 seconds |
| `/slite reset` | default settings and positions |

## Why it is fast

- No per-frame work. One OnUpdate drives a few tickers (0.1 to 1 s) that sleep when
  there is nothing to count down.
- Name plates: the world's frames are only listed when their count grows. A plate is
  classified when it shows, its name or its match changes. Plain enemies' thin bars are
  the game's own health bar made small, so they run no addon code. Only the marked few
  listen to their health.
- The run's addon lines only set dirty flags; rebuilds run at most 3 to 5 times a second.
- Text is only set when the shown value changes. Circles and minimap rings only move
  their dots when a radius, the zoom or the screen changes. The options window is built
  the first time it opens and runs nothing while closed.

In the test harness (300 plates, 10 health changes per frame, unit and stat lines at 10
per second, timed with a high resolution clock) it measured about 3.5 ms of Lua per
second, 0.06 ms per frame. Use `/slite perf` in game for the real number.

## Limits

- Trees still draw over the world. The client gives addons no access to the 3D scene.
- Name plates jump apart in crowds: the client places them with a solver of its own and
  an addon only sees where it put them, so they cannot be made to overlap. Plain enemies
  hidden (`/slite mobs hide`) is the way to keep crowds calm.
- Ground circles assume flat ground and that the camera orbits a point 1.5 yd above your
  feet, and they lag the camera's own smoothing by up to half a second.
- Plain enemy bars and hidden plates change the client's own plate parts. If the client
  ever lays its plates out again, they show as the game's plates.
- Minimap pins assume 1.12's minimap scale (466.67 yd across at zoom 0, outdoors) and that
  the run's lair and chest map coordinates are those of your zone's map.
- Skill circles need the skill's tooltip to name its reach in yards; a skill without
  one (a buff, a self heal) is not offered. Which skills Area grows is read from the kind
  of reach the tooltip names, not from the game's own rules, which addons cannot see.
- The leash is learned from the run's sleep state, so a guardian that falls asleep for
  another reason teaches a wrong value; the slider replaces it.
- In Alterac Valley the game's own layout pass cannot find `MinimapCluster` and used to
  pop up an error window ("QuestTimerFrame:SetPoint(): Couldn't find region named
  'MinimapCluster'"). SurvivorsLite catches only that error and still places the chat
  dock and bags; the quest timer and durability frames, which a run does not use, keep
  their last place.

## Development

The game's addon API (AZS_*) is Lua inside the client build and belongs to the game, so
it is not in this repository. Fetch it once, then run the tests:

```bash
pip install lupa
python tools/fetch_api.py
python tests/run.py
python build.py
```

- `tools/fetch_api.py` downloads the current web build (about 90 MB) and writes
  `tests/azs_api.lua`: the API and the character pane's stats parser. `--wasm FILE` uses a
  `wenilla_bg.wasm` you already have. Run it again when the game updates.
- `tests/run.py` lints for Lua 5.0 (no `#`, `%`, `select`, varargs, `string.match`) and
  ASCII, then plays through a run in a strict mock of the 1.12 frame API
  (`tests/mock.lua`, `tests/scenario.lua`).
- `build.py` writes `dist/SurvivorsLite-<version>.zip` with the version from the `.toc`.
- The addon is plain 1.12 Lua: `this`, `event` and `arg1` globals, `table.getn`,
  `math.mod`. `SurvivorsLite/core.lua` holds the module loader, settings, tickers and
  slash commands; each other file is one feature.
- The documentation site is `docs/`, published by GitHub Pages from the `main` branch.

## Support

SurvivorsLite is free. If it helps your runs, you can
[buy me a coffee on Ko-fi](https://ko-fi.com/munkrej). Bugs and ideas go to the
[issues](https://github.com/datawulf/SurvivorsLite/issues).

## License

[MIT](LICENSE).
