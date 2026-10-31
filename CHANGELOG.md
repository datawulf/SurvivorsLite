# Changelog

Every version passed the test harness (`tests/run.py`) before release. What has been
seen working in the real game is listed in [the feature status](README.md#feature-status).

## 1.9.0 - 2026-10-31

- Run stats on the screen: the character pane's numbers in a small panel you can move.
  The pane's twelve (Health, Damage, Haste, Crit, Crit Dmg, Armor, Area, Targets, Echo,
  Speed, Regen, Pickup) always show, the rest of its run stats (Lifesteal, Lives, Vs
  Elites...) once something raised them. A number that just changed shows green when it
  went up and red when it went down for 5 seconds. Point at a row for what it means and
  what your worn gear adds. `/slite stats raised|all|off`.

## 1.8.1 - 2026-10-31

- Minimap pins and lair distances in zones without a map, like Naxxramas. There the game
  gives no map position, so the run line's world position of your hero places the pins
  and measures the distances. They move when the line comes rather than every frame.
- Indoors the minimap shows less ground (300 yd across at the widest zoom instead of
  467). The pins now use the indoor scale while you stand indoors.
- A zone whose lines carry no map coordinates no longer reuses the last zone's map scale.
- Tested against the addon API of web build `fe298f333712`.

## 1.8.0 - 2026-10-30

- Picked jewelry under the floating action bar: the amulet, rings and trinkets you picked
  this run, with their quality, cooldowns and tooltips. `/slite jewelry on/off`.
- Skill circles of area skills (a radius or a cone) grow by your Area stat again, on top of
  the tooltip's yards, so the circle matches the area the skill hits. A targeting reach
  ("12 yd range", "within 30 yd") keeps its tooltip's yards. A skill whose tooltip moves
  with Area at the same rank is noticed and used as shown. "Grow with your Area stat" turns
  it off.
- Unique icons: every guardian's lair is a dragon head in a color of its own (red, blue,
  green, bronze, purple) on its minimap pin, its status line and its guardian's plate,
  with an edge in that color. Chests on the minimap are small treasure chests.
- Checked against web build `019734ed2f34`: the addon API is unchanged.

## 1.7.1 - 2026-10-29

- Stops the error window in Alterac Valley: "QuestTimerFrame:SetPoint(): Couldn't find
  region named 'MinimapCluster'". The error comes from the game's own layout pass, which
  cannot find the minimap frame by name there. SurvivorsLite catches only that error and
  still places the chat dock and bags that the failed pass skipped.
- Checked against the new web build `d2233962924f`: the addon API is unchanged.

## 1.7.0 - 2026-10-29

- Each guardian's lair gets a mark of its own (star, circle, diamond, triangle, moon,
  square). The same mark is on its minimap pin, its status line and its guardian's plate.
- The lair that comes back first stands out: a bigger pin with a gold glow and a
  countdown under it, and a gold "next 0:45  86 yd" line in the status list.
- Lines of sleeping guardians show how far away they are.

## 1.6.0 - 2026-10-29

- Your absorb shield on the hero health bar: a pale blue segment after your health, a
  bright tick when health and shield pass your maximum and the amount after your health
  ("300 +400"). `/slite shield on/off`.

## 1.5.0 - 2026-10-29

- Leash bar over your character while a guardian chases you: how far you are from its
  lair against how far it follows ("Mother Fang  32 / 40 yd"), green to red, with a
  "gives up soon" warning.
- The leash is learned two ways: it grows while a guardian keeps chasing you farther out
  and it is set where a guardian gives up and goes back to sleep.

## 1.4.0 - 2026-10-29

- Circles on the ground: the camera's distance and angle are read through saved view 5
  (`SaveView(5)` and the `cameraDistanceD` and `cameraPitchD` settings) and every circle is
  drawn in perspective on flat ground. Falls back to flat circles when the client does not
  give live values. Field of view setting and `/slite camera`.
- Skill circles now use exactly the yards in each skill's own tooltip. 1.3 had decided once
  for all skills whether tooltips include Area and added Area on top for skills that do not
  use it.
- Removed the plate shrinking trick from 1.2. It does not stop plates jumping in this client.

## 1.3.0 - 2026-10-29

- Skill circles: tick any run skill with a reach (Eviscerate, Blade Flurry...) and it gets
  a circle in its own color. The reach is read from the skill's tooltip, so it grows with
  ranks, upgrades and Area. `/slite skills` and `/slite skill <name>`.

## 1.2.0 - 2026-10-29

- Gear buttons on the minimap and on the action bar open the options, and a chat line at
  login says so.
- Plain enemies get a thin 40x3 health bar with no name or level.
- Smaller boss and guardian bars with your debuffs under them and absolute health again.
- Same-named units are matched by health, so an elite pack mob named like a guardian is
  not marked. Elites are no longer marked unless "Mark elites" is on.
- Smaller hero bar. Buff uptime under each timed buff.
- Compact floating action bar made of the game's buttons, with cooldown seconds and the
  talents' clocks over it.
- Status list with one line each: bosses, every guardian (asleep, awake or "back in 0:45")
  and the next boss. Lines near you are bright.
- Minimap pins for lairs and chests. Leash rings around held lairs and a leash distance on
  awake guardians' lines, starting at 40 yd.

## 1.1.0 - 2026-10-29

- Options window: `/slite` or the SurvivorsLite button in the game menu.
- Range circle (8 yd by default), an optional second circle and a pickup radius circle,
  growing with Area. One size calibration for your zoom.

## 1.0.0 - 2026-10-29

- First release as a light replacement for SurvivorsDragonUi.
- Hero bar under your character: level, health, experience, lives, cooldowns, buffs and
  debuffs.
- Plates for the final boss, bosses, guardians and elites with health in percent and as a
  number. "ENRAGED" on enraged bosses.
- Party plates with class colors, level and an arrow. Party frames with health, level,
  damage per second and revive progress.
- Boss countdown, "Name is down!" warning and a red screen edge at low health.
