# SurvivorsLite

A small, fast HUD addon for [Azeroth Survivors](https://wow.aethus.pl), written as a light
replacement for SurvivorsDragonUi. Built on the game's official addon API and tested against
web build `f3a3d645a1ed` (2026-11-05).

- Download: [latest release](https://github.com/datawulf/SurvivorsLite/releases/latest)
- Documentation: [datawulf.github.io/SurvivorsLite](https://datawulf.github.io/SurvivorsLite/)
- Changes: [CHANGELOG.md](CHANGELOG.md)
- Support the work: [Ko-fi](https://ko-fi.com/punkware)

Fan made and not affiliated with the makers of Azeroth Survivors or with Blizzard
Entertainment.

## What it shows

- Hero bar under your character: level, health (green to red), experience line and
  extra lives. Your absorb shield sits on the health bar as a pale segment after your
  health, with a bright tick at the end when health and shield pass your maximum, and
  its amount after your health ("489 +120"), from the shield the run reports. Under it
  your buffs and debuffs with time left and stacks, and for timed buffs how much of this
  run they were up. A buff that ran out stays dimmed with its uptime.
- A class colored ring on your feet, drawn above the 3D world so you can see where you
  stand under tree tops. The game itself says where your feet are on screen, so the ring,
  the hero bar and the warnings follow you.
- Name plates:
  - Final boss (skull, magenta), bosses (skull, orange) and guardians (their lair's dragon
    head, dimmed while asleep) get a bar of the addon's own over the exact unit's head, with
    health in percent and as a number, "ENRAGED" when a boss enrages, and your debuffs on
    them with stacks and time left. These do not jump apart in crowds and do not need name
    plates. Elites can be marked too (off by default).
  - Plain enemies get a thin bar of their own health and nothing else (or no plate, or
    the game's plate).
  - Party members get a class colored plate with their level and a big arrow.
- Run stats: the character pane's numbers in a small panel you can move. The pane's
  twelve (Health, Damage, Haste, Crit, Crit Dmg, Armor, Area, Targets, Echo, Speed,
  Regen, Pickup) always show, the rest of its run stats (Lifesteal, Lives, Vs Elites...)
  once something raised them, or all of them. A number that just changed is green when
  it went up and red when it went down for 5 seconds, so you see what a pick did. Point
  at a row for what it means and what your worn gear adds.
- Party frames: class colored health, level, damage per second, "DOWN 34 yd" or revive
  progress, faded when out of range. Click a row to target. A friend who is down also gets
  a marker on the spot, seen through walls, and a minimap pin that points the way.
- Damage meter: your damage by source as bars with the source's own icon, its damage per
  second and its share, the longest bar the top one's. Tabs switch to the party's heroes
  (class colors, your own name in gold, their best spells on mouse over), the last boss
  fight and your healing. Bars glide to their new length. Point at a row for the totals.
  Reset counts from now on without touching the game's numbers, and All goes back to the
  whole run. `/slite rows 3-15` sets how many rows show, `/slite window 5-120` makes damage
  per second cover the last seconds.
- This addon's boss bars replace the game's at the top: a boss or an awake guardian has its
  bar at the top of the screen for the whole fight, a sleeping guardian over the unit. The game's meter and lair flag can be hidden too (off by default). All come back at logout. Its
  character and party frames are hidden while the hero bar and party rows show. The run stats, action bar, jewelry and meter stay
  over the level-up cards.
- Every guardian's lair has a look of its own, by its place in the run's lair line: a
  dragon head in a color of its own (red, blue, green, bronze, purple), drawn for this
  addon on a transparent background. The same look is on its minimap pin, its line in the
  status list and its guardian's plate, so you can tell the guardians apart at a glance.
- Boss status list, one short line each: bosses alive with their health, every
  guardian's lair (asleep with how far it is, awake with how far you are from its lair
  against its leash, or when it comes back) and the next boss. The lair that comes back
  first says "next" in gold with its countdown and how far it is. Lines whose unit has
  its plate up near you are bright.
- Minimap: every guardian's lair as its dragon head in its color (grey while it refills,
  "!" while its guardian is awake, kept on the edge when off the map), a
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
- Circles lie on the ground where the game itself puts them, at any zoom and angle (see
  below). Without anything to measure from they are flat on the screen and need one size
  calibration.
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

In the Windows and Linux builds: unzip so `benilla-config/AddOns/SurvivorsLite/` sits next to
the game's executable.

## Feature status

Every feature passes the test harness, which runs the addon against the game's own addon
API in a mock of the 1.12 client. Not every one has been seen in the real game yet.
Tried one of them? Tell how it went with a
[feature check](https://github.com/datawulf/SurvivorsLite/issues/new?template=feature_check.md).

Seen working in game (player screenshots and reports):

- Hero bar under your character: level, health and experience line.
- Buff and debuff icons with time left and buff uptime.
- The class colored ring around your character.
- Thin health bars for plain enemies.
- The boss status list.
- The range circle and skill circles, flat on the screen.
- Each meter row's sum, rate and share (1.11.1).
- Hiding the game's character frame and getting it back (1.11.1).
- Engaged bosses and guardians with their bar at the top for the whole fight (1.11.2).
- One damage meter row per spell, procs on a blue row of their own (1.11.2).

New in 1.11.0 on the game's official API, not confirmed in game yet:

- Circles on the ground and the ring, hero bar and warnings on your feet. `/slite world`
  says what they measure from.
- Boss plates over the exact unit, with name plates off too. The guardian's plate was seen
  working this way in game, and so were the old plates on the client's name plates.
- Minimap pins and lair distances from your live position on every map.
- The damage meter from the meter API: every source's icon, Reset and `/slite window`.
- The run stats, action bar, jewelry and meter over the level-up cards.
- Hiding the game's meter, boss bars and lair flag, and getting them back at logout.
- "DOWN 34 yd" on party rows, the marker on the spot and the minimap pin.
- New in 1.11.1: hiding the game's party frames and no black bar on the level-up cards.
- New in 1.11.2: boss skulls and awake guardian pins moving on the minimap.

Not confirmed in game yet:

- The guardians' reset range (leash): the leash bar over you, learning the real distance,
  leash rings on the minimap and leash distances in the status list.
- Skill circles following each skill's tooltip yards (ranks and upgrades).
- Minimap pins for lairs and chests.
- Guardian looks and the next respawn pin and line.
- The shield on the health bar.
- The floating action bar with cooldown seconds and talent clocks.
- The gear buttons on the minimap and the action bar.
- Debuff icons and absolute health on boss and guardian plates.
- Party frames and party member plates.
- The boss countdown, the "Name is down!" warning and the low health screen edge.
- The fix for the Alterac Valley error window (1.7.1).
- The picked jewelry row under the action bar (1.8.0).
- Area skills growing by your Area stat on top of their tooltip (1.8.0). If an area skill
  still hits farther than its circle, the game may count the enemy's body size too.
- The indoor minimap scale (1.8.1).
- The run stats panel (1.9.0).
- The transparent dragon head and chest icons and the smaller boss skull (1.10.0).

Tried and not possible from an addon: see [Limits](#limits).

## Options

`/slite` (or `/sl`), the gear on the minimap's edge, the gear at the end of the floating
action bar, or the SurvivorsLite button in the game menu (Esc) open the options window.
Esc closes it. Point at a setting for what it does. "Move frames" lets you drag the hero
bar, action bar, party frames, status list and, for flat circles, their center.

## Circles on the ground

The game's world anchors put any place in the world through the camera, and your position
says where you stand. They have no handle on your own hero, so the addon takes one anchor
that stays put (a lair, a chest or the place an enemy fell) and adds the yards to your feet.
Your feet are projected every frame, and while a circle shows four more points around them
give the ground's perspective. There is nothing to calibrate and no lag. The options window
shows what it measures from under Placement, and `/slite world` says it in chat.

- The game says nothing about the ground's height, so the ground is taken as flat at your
  feet. On slopes and hills the circles drift.
- Until there is a lair, a chest or a fallen enemy to measure from, the circles are flat.
- `/slite ground off` keeps them flat for good.

## Flat circles

Without the game's projection the circles are drawn flat on the screen around your
character and need one calibration for the zoom you play at:

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

The distance is measured from your live position to the lair, on every map. Moving the
leash slider or `/slite leash N` forgets what play taught.

## Commands

`/slite help` lists every command with its current state.

| Command | Effect |
| --- | --- |
| `/slite` / `options` | open or close the options window |
| `/slite unlock` / `lock` | drag the hero bar, action bar, party frames, status list, run stats, damage meter and the circles' center |
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
| `/slite stats raised/all/off` | run stats panel: the pane's twelve and raised run stats, every stat, or none |
| `/slite plates on/off` | boss and guardian plates |
| `/slite mobs bars/hide/show` | plain enemies: small bars, hidden or the game's plates |
| `/slite elites on/off` | mark elites too |
| `/slite debuffs on/off` | your debuffs on boss and guardian plates |
| `/slite autoplates on/off` | turn enemy plates on by itself |
| `/slite allies on/off` | party member plates, turns friendly plates on in a party |
| `/slite party on/off` | party frames |
| `/slite downmark on/off` | marker and minimap pin on a party member who is down |
| `/slite meter on/off` | damage meter |
| `/slite rows 3-15` | rows in the damage meter |
| `/slite window 0-120` | seconds the meter's damage per second covers, 0 for the whole run |
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
| `/slite ground on/off` | circles on the ground and your ring on your feet, projected by the game |
| `/slite world` | what the ground circles measure from |
| `/slite zoom 5-60` | flat circle size per yard, matched to your camera zoom |
| `/slite tilt 0.3-1` | flat circle height for a camera that looks in from the side |
| `/slite overcards on/off` | run stats, action bar, jewelry and meter over the level-up cards |
| `/slite hidemeter on/off` | hide the game's meter while this addon's shows |
| `/slite hidebosses on/off` | replace the game's boss bars with this addon's (on by default) |
| `/slite hideflag on/off` | hide the game's lair flag while this addon's pins show |
| `/slite hideplayer on/off` | hide the game's character frame while the hero bar shows (on by default) |
| `/slite hideparty on/off` | hide the game's party frames while the party rows show (on by default) |
| `/slite scale 0.6-2` | size of the hero bar, party frames and list |
| `/slite perf` | measures this addon's own Lua time for 10 seconds |
| `/slite reset` | default settings and positions |

## Why it is fast

- Almost no per-frame work. One OnUpdate drives a few tickers (0.1 to 1 s) that sleep when
  there is nothing to count down. Each frame only your feet and the few boss and guardian
  plates go through the game's camera, as it asks for, and the four ground points while a
  circle shows.
- Name plates: the world's frames are only listed when their count grows. A plate is
  classified when it shows or its name changes. Plain enemies' thin bars are the game's own
  health bar made small, so they run no addon code.
- The meter reads the game's counters at most three times a second and only when they
  moved.
- The run's addon lines only set dirty flags; rebuilds run at most 3 to 5 times a second.
- Text is only set when the shown value changes. Circles and minimap rings only move
  their dots when a radius, the view or the screen changes. The options window is built
  the first time it opens and runs nothing while closed.

In the test harness (300 plates, 10 health changes per frame, unit, stat and meter lines at
10 per second and a circle on the ground) it measured about 9 ms of Lua per second, 0.15 ms
per frame, with a rough clock and with the game's native calls played by Lua stand-ins. Use
`/slite perf` in game for the real number.

## Limits

- Trees still draw over the world. The client gives addons no access to the 3D scene.
- The client's name plates jump apart in crowds: it places them with a solver of its own
  and an addon only sees where it put them. That still goes for the plain enemies' thin
  bars. Plain enemies hidden (`/slite mobs hide`) is the way to keep crowds calm.
- Plain enemies' bars and plates of party members who are up stay on the client's plates:
  the game gives no anchor on a friend who is up and no health of a plain enemy.
- While a boss or guardian lives, the client's plates with its name stay hidden, so an elite
  named like a guardian shows no thin bar until that guardian is dead.
- Boss and guardian health moves 5 times a second, with the run's unit line.
- Ground circles assume flat ground at your feet.
- Plain enemy bars and hidden plates change the client's own plate parts. If the client
  ever lays its plates out again, they show as the game's plates.
- Minimap pins assume 1.12's minimap scale (466.67 yd across at zoom 0 outdoors, 300
  indoors). Where both minimap zoom settings match, telling indoors from outdoors takes one
  zoom step and back, once per place.
- The row of level-up cards is wide. The run stats and meter start out past it, but in a
  nearly square window they still overlap a card's edge a little, and a click there goes to
  the panel. `/slite overcards off` or dragging them helps.
- While frames are kept over the cards the client also draws the target's health bars over
  the dimmed screen. That comes with `overcards` and goes when it is off.
- Hiding parts of the game's HUD is saved by the game, so the addon puts them back at
  logout. If the game crashes they stay hidden until the next run with the addon or the
  game's options (the lair flag has no check box there).
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
it is not in this repository. Fetch it once, then run the tests. Position, world anchors and
the meter API are native client code: `tests/mock.lua` plays them from the game's addon doc,
so the harness cannot prove those parts against the real client.

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
- `tools/make_media.py` draws the addon's own textures into `SurvivorsLite/media` as BLP
  files with 8 bits of alpha, like the game's own interface art: the lair's dragon head
  (grey, tinted in each lair's color), the chest and the meter's bar. The client loads an
  addon's textures only as BLP; TGA and PNG files show nothing there.
- The addon is plain 1.12 Lua: `this`, `event` and `arg1` globals, `table.getn`,
  `math.mod`. `SurvivorsLite/core.lua` holds the module loader, settings, tickers and
  slash commands; each other file is one feature.
- The documentation site is `docs/`, published by GitHub Pages from the `main` branch.

## Support

SurvivorsLite is free. If it helps your runs, you can
[buy me a coffee on Ko-fi](https://ko-fi.com/punkware). Bugs and ideas go to the
[issues](https://github.com/datawulf/SurvivorsLite/issues).

## License

[MIT](LICENSE).
