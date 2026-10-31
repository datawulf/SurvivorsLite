-- Drives SurvivorsLite through a run: login, plates appear, the run's addon lines arrive,
-- a party forms, an ally goes down, settings change. Returns a list of failures.

local fails = {}
local function expect(cond, msg)
    if not cond then table.insert(fails, msg) end
end
local function chatHas(pattern)
    for i = 1, table.getn(MOCK.chat) do
        if string.find(MOCK.chat[i], pattern) then return true end
    end
end

-- The skills' tooltips as the client writes them: a range on the right in color, a radius
-- line, and a racial with no reach.
MOCK.tips[1] = { { "Eviscerate", "|cffffffff12 yd range|r" }, { "Rank 3" }, { "Strikes an enemy within 12 yd for 300." } }
MOCK.tips[2] = { { "Blade Flurry" }, { "8 yd radius" }, { "Hits every enemy within 8 yd of you for 120." } }
MOCK.tips[12] = { { "Blood Fury" }, { "Increases all your damage by 25% for 10 sec." } }

MOCK.event("ADDON_LOADED", "SurvivorsLite")
MOCK.event("PLAYER_LOGIN")
expect(SurvivorsLite.db ~= nil, "settings did not load")
MOCK.addon("AZSSPELLS", "eviscerate,6762,3,5,5;blade_flurry,13877,2,8,8")

-- 300 plain enemies, a boss, a guardian, an elite, our summons, a party member. Plate health
-- matches the run's unit line: Hogger 50000/80000, Mother Fang 9000/10000.
local plain = {}
for i = 1, 300 do table.insert(plain, MOCK.plate("Defias Thug", 1, 0, 0, 100)) end
local boss = MOCK.plate("Hogger", 1, 0, 0, 62)
local guardian = MOCK.plate("Mother Fang", 1, 0, 0, 90)
local elite = MOCK.plate("Kobold Geomancer", 1, 0, 0, 62)
local treant = MOCK.plate("Treant", 0, 1, 0, 100)
local ally = MOCK.plate("Ayla", 0, 0, 1, 100)

MOCK.units.party1 = { name = "Ayla", class = "MAGE", level = 14, hp = 900, hpm = 1000, near = true }
MOCK.event("PLAYER_ENTERING_WORLD")
MOCK.event("PARTY_MEMBERS_CHANGED")
expect(MOCK.enemyPlates, "enemy plates were not turned on")
expect(MOCK.friendPlates, "friendly plates were not turned on in a party")
expect(chatHas("gear button opens the options"), "no login hint about the options")

MOCK.addon("AZSRUN", "ph=playing;t=100;sl=0")
MOCK.addon("AZSZONE", "len=900")
MOCK.addon("AZSBOSSES", "1,107,Hogger,0,due;2,600,Edwin VanCleef,1,due")
MOCK.addon("AZSUNITS", "boss,11,Hogger,50000,80000,1;guardian,12,Mother Fang,9000,10000,0;elite,13,Kobold Geomancer,500,800,0")
MOCK.addon("AZSDEBUFFS", "11,172,3,18,110,0,,Spell_Shadow_AbominationExplosion,Corruption;11,980,1,24,120,0,,Spell_Shadow_CurseOfSargeras,Curse of Agony")
MOCK.addon("AZSTIMERS", "Cheat Death,Ability_Rogue_CheatDeath,cooldown,130,60;Pact,Spell_Shadow_SummonImp,summon,99,20")
MOCK.addon("AZSPARTY", "Ayla,mage,100000,1234,0.5,Fireball,200")
MOCK.addon("AZS", "hp=2000;dmg=1.2;cd=0.9;crit=0.1;cm=1.5;liv=2;area=1.25;pick=12")
MOCK.event("PLAYER_AURAS_CHANGED")

MOCK.run(120, 60)

local function overlay(p)
    for i = 1, table.getn(p._children) do
        local c = p._children[i]
        if c ~= p.mockBar then return c end
    end
end
local function fill(o)
    for i = 1, table.getn(o._children) do
        if o._children[i]._type == "StatusBar" then return o._children[i] end
    end
end
local function texts(f)
    local out = {}
    for i = 1, table.getn(f._regions) do
        local r = f._regions[i]
        if r._type == "FontString" and r._text then out[r._text] = true end
    end
    return out
end

expect(boss._alpha == 1, "boss plate hidden")
local bo = overlay(boss)
expect(bo and bo._shown, "boss has no overlay")
expect(bo.icon._w == 12 and bo.icon._h == 12, "boss skull not the smaller size: " .. tostring(bo.icon._w))
expect(boss.mockBar._alpha == 0, "boss stock bar still visible")
expect(guardian._alpha == 1 and overlay(guardian) and overlay(guardian)._shown, "guardian not highlighted")
expect(not (overlay(elite) and overlay(elite)._shown), "elite marked while elites are off")
expect(SurvivorsLite.nearby["Hogger"] and SurvivorsLite.nearby["Mother Fang"], "marked plates not listed as near")

-- Plain enemies: the client's bar, small, nothing else.
local p1 = plain[1]
expect(p1._alpha == 1 and p1.mockBar._alpha == 1 and p1.mockBar._w == 40 and p1.mockBar._h == 3, "plain enemy has no small bar")
expect(p1.mockName._alpha == 0, "plain enemy still shows its name")
expect(p1._w == 128 and p1.mockBar._point[1] == "CENTER", "plain plate resized or bar not centered")
expect(treant._alpha == 0, "own summons not hidden")
expect(ally._alpha == 1 and overlay(ally), "ally not highlighted")

-- Boss health moves live through the stock bar; the absolute value comes from the run.
boss.mockBar:SetValue(40)
local bf = fill(bo)
expect(math.abs(bf._value - 0.4) < 0.001, "boss overlay fill did not follow: " .. tostring(bf._value))
local bt = texts(bf)
expect(bt["40%"] and bt["32K"], "boss texts wrong")

-- Your debuffs under the boss bar.
expect(bo.debuffs[1] and bo.debuffs[1]._shown and bo.debuffs[2]._shown, "no debuff icons on the boss plate")
expect(bo.debuffs[1] and bo.debuffs[1].tex._tex == "Interface\\Icons\\Spell_Shadow_AbominationExplosion", "debuff icon texture")
expect(bo.debuffs[1] and bo.debuffs[1].count._text == "3", "debuff stacks")
expect(overlay(guardian).debuffCount == 0, "guardian shows the boss's debuffs")
MOCK.addon("AZSDEBUFFS", "12,172,1,18,110,0,,Spell_Shadow_AbominationExplosion,Corruption")
MOCK.run(30, 60)
expect(bo.debuffs[1] and not bo.debuffs[1]._shown and overlay(guardian).debuffs[1] and overlay(guardian).debuffs[1]._shown, "debuffs did not move to the guardian")

-- Two plates named like a guardian: only the one whose health fits it is marked.
local kt1 = MOCK.plate("Kobold Taskmaster", 1, 0, 0, 50)
local kt2 = MOCK.plate("Kobold Taskmaster", 1, 0, 0, 100)
MOCK.addon("AZSUNITS", "boss,11,Hogger,32000,80000,1;guardian,12,Mother Fang,9000,10000,0;guardian,15,Kobold Taskmaster,5000,10000,1;elite,16,Kobold Taskmaster,800,800,0")
MOCK.run(30, 60)
expect(overlay(kt1) and overlay(kt1)._shown, "real guardian not marked")
expect(not (overlay(kt2) and overlay(kt2)._shown) and kt2.mockBar._w == 40, "same named elite marked as the guardian")
expect(overlay(kt1) and texts(fill(overlay(kt1)))["5.0K"], "shared name lost the absolute health")
local slash = SlashCmdList["SURVIVORSLITE"]
slash("elites on")
MOCK.run(30, 60)
expect(overlay(kt2) and overlay(kt2)._shown and overlay(kt2)._w == 70, "elite not marked with elites on")
expect(overlay(kt1) and overlay(kt1)._w == 120, "guardian lost its style when the elite was marked")
slash("elites off")
MOCK.run(30, 60)
-- The real guardian walks out of plate range: the lone same named mob stays plain.
kt1:Hide()
MOCK.run(30, 60)
expect(not (overlay(kt2) and overlay(kt2)._shown), "a lone same named mob was marked as the far guardian")

-- A plain plate reused for a guardian, and the guardian plate reused for a plain enemy.
plain[5]:Hide()
plain[5].mockName:SetText("Mother Fang")
plain[5].mockBar:SetValue(90)
plain[5]:Show()
guardian:Hide()
guardian.mockName:SetText("Defias Thug")
guardian.mockBar:SetValue(100)
guardian:Show()
MOCK.run(30, 60)
expect(plain[5]._alpha == 1 and overlay(plain[5]) and overlay(plain[5])._shown, "reused plate did not become a guardian")
expect(not overlay(guardian)._shown and guardian.mockBar._alpha == 1 and guardian.mockBar._w == 40, "old guardian plate kept its highlight")

-- Party member goes down: alert and DOWN text.
MOCK.units.party1.hp = 0
MOCK.event("UNIT_HEALTH", "party1")
local alerted = false
for i = 1, table.getn(MOCK.frames) do
    local o = MOCK.frames[i]
    if o._type == "FontString" and o._text == "Ayla is down!" then alerted = true end
end
expect(alerted, "no ally down alert")

-- Low health edge and boss countdown.
MOCK.units.player.hp = 300
MOCK.event("UNIT_HEALTH", "player")
MOCK.run(60, 60)
local counted = false
for i = 1, table.getn(MOCK.frames) do
    local o = MOCK.frames[i]
    if o._type == "FontString" and o._text and string.find(o._text, "^Hogger  %d") then counted = true end
end
expect(counted, "no boss countdown")

-- Your shield on the health bar: 300 of 2000 health and a 400 shield.
local heroBar
for i = 1, table.getn(SurvivorsLiteHero._children) do
    local c = SurvivorsLiteHero._children[i]
    if c._type == "StatusBar" and c._h == 7 then heroBar = c end
end
local function shieldParts()
    local seg, tick, label
    for i = 1, table.getn(heroBar._children) do
        local f = heroBar._children[i]
        for j = 1, table.getn(f._regions) do
            local r = f._regions[j]
            if r._type == "Texture" and r._h == 7 then seg = r end
            if r._type == "Texture" and r._w == 2 then tick = r end
            if r._type == "FontString" then label = r end
        end
    end
    return seg, tick, label
end
MOCK.addon("AZSRUN", "ph=playing;t=110;sl=0;hp=300;hpm=2000;sh=400")
local seg, tick, label = shieldParts()
expect(seg and seg._shown and math.abs(seg._point[4] - 0.15 * 96) < 0.01 and math.abs(seg._w - 0.2 * 96) < 0.01, "shield segment: " .. tostring(seg and seg._w))
expect(tick and not tick._shown, "over-shield tick shown for a shield that fits")
expect(label and label._text == "300 |cffaee0ff+400|r", "health text with shield: " .. tostring(label and label._text))
-- A shield past your maximum fills the rest and shows the tick.
MOCK.addon("AZSRUN", "ph=playing;t=110;sl=0;hp=300;hpm=2000;sh=2000")
expect(math.abs(seg._w - 0.85 * 96) < 0.01 and tick._shown, "over-shield: " .. tostring(seg._w))
expect(label._text == "300 |cffaee0ff+2.0K|r", "over-shield text: " .. tostring(label._text))
-- Broken: gone.
MOCK.addon("AZSRUN", "ph=playing;t=110;sl=0;hp=300;hpm=2000;sh=0")
expect(not seg._shown and not tick._shown and label._text == "300", "broken shield still shows")
MOCK.addon("AZSRUN", "ph=playing;t=110;sl=0;hp=300;hpm=2000;sh=400")
SlashCmdList["SURVIVORSLITE"]("shield off")
expect(not seg._shown and label._text == "300", "shield off still shows the shield")
SlashCmdList["SURVIVORSLITE"]("shield on")
expect(seg._shown, "shield on did not show it again")
MOCK.addon("AZSRUN", "ph=playing;t=110;sl=0;hp=300;hpm=2000;sh=0")

-- ---------------------------------------------------------------- action bar

local bar = SurvivorsLiteBar
expect(ActionButton1._parent == bar and ActionButton12._parent == bar and CharacterMicroButton._parent == bar, "buttons not on the floating bar")
expect(not MainMenuBar._shown, "the client's main bar still shows")
expect(ActionButton1NormalTexture._alpha == 0, "socket art still on the buttons")
expect(bar._point[1] == "BOTTOM" and bar._scale == 0.85, "floating bar not at the bottom or not scaled")
MainMenuBar:Show()
expect(not MainMenuBar._shown, "the client's main bar came back while the bar floats")
MOCK.actions[1].start, MOCK.actions[1].dur = MOCK.now, 10
MOCK.event("ACTIONBAR_UPDATE_COOLDOWN")
MOCK.run(12, 60)
local function number(b)
    for i = 1, table.getn(b._children) do
        local t = texts(b._children[i])
        for k in pairs(t) do return k end
    end
end
expect(number(ActionButton1) == "10" or number(ActionButton1) == "9", "no cooldown number: " .. tostring(number(ActionButton1)))
local clocks = SurvivorsLiteClocks
local shownClocks = 0
for i = 1, table.getn(clocks._children) do if clocks._children[i]._shown then shownClocks = shownClocks + 1 end end
expect(shownClocks == 2, "talent clocks over the bar: " .. shownClocks)
expect(clocks._point[2] == bar, "talent clocks not over the floating bar")
slash("bar off")
expect(ActionButton1._parent == MainMenuBarArtFrame and ActionButton1._point[1] == "BOTTOMLEFT" and ActionButton1._point[4] == 8, "bar off did not put button 1 back")
expect(ActionButton2._point[2] == ActionButton1 and ActionButton12._point[4] == 280, "bar off did not put the buttons back in a row")
expect(MainMenuBar._shown and ActionButton1NormalTexture._alpha == 1 and not bar._shown, "bar off did not restore the main bar")
expect(clocks._point[2] == ActionButton1, "talent clocks not over the client's bar")
slash("bar on")
expect(ActionButton1._parent == bar and not MainMenuBar._shown, "bar on did not float again")
slash("cds off")
MOCK.run(12, 60)
expect(number(ActionButton1) == "" or number(ActionButton1) == nil, "cooldown number with cds off")
slash("cds on")

-- ---------------------------------------------------------------- buff uptime

-- Ten seconds of a run: the timed shield was up the whole time.
MOCK.addon("AZSRUN", "ph=playing;t=200;sl=0")
MOCK.run(660, 60)
local upFound
for i = 1, table.getn(MOCK.frames) do
    local o = MOCK.frames[i]
    if o.upKey == "Interface\\Icons\\Spell_Holy_PowerWordShield" and o._shown then upFound = o.up._text end
end
expect(upFound == "100%", "shield uptime: " .. tostring(upFound))
-- It runs out: it stays dimmed with its uptime.
local shield = table.remove(MOCK.buffs.HELPFUL, 2)
MOCK.event("PLAYER_AURAS_CHANGED")
MOCK.run(30, 60)
local dimmed
for i = 1, table.getn(MOCK.frames) do
    local o = MOCK.frames[i]
    if o.upKey == "Interface\\Icons\\Spell_Holy_PowerWordShield" and o._shown and o._alpha < 1 then dimmed = o.up._text end
end
expect(dimmed and dimmed ~= "", "expired buff not kept dimmed with its uptime")
table.insert(MOCK.buffs.HELPFUL, shield)
MOCK.event("PLAYER_AURAS_CHANGED")
MOCK.run(30, 60)

-- ---------------------------------------------------------------- status list and minimap

-- Lairs and a chest on a 1000 x 1000 yd map: world y = 2400 - 1000 mx, x = 1600 - 1000 my.
MOCK.mapX, MOCK.mapY = 0.40, 0.62
MOCK.addon("AZSLAIRS", "4,held,Mother Fang,12,0,1000,2000,0,0.40,0.60,1;2,empty,Kobold Taskmaster,15,45,1050,1950,0,0.45,0.55,0;3,held,Rhahk'Zor,14,0,950,2050,0,0.35,0.65,0")
MOCK.addon("AZSCHESTS", "7,1200,2300,0,0.10,0.40;8,1010,1990,0,0.41,0.59")
MOCK.addon("AZSUNITS", "boss,11,Hogger,32000,80000,1;guardian,12,Mother Fang,9000,10000,0;guardian,14,Rhahk'Zor,20000,20000,0")
MOCK.run(30, 60)
local dist = SurvivorsLite.LairDistance(AZS_LAIRS[1])
expect(dist and math.abs(dist - 20) < 0.01, "lair distance: " .. tostring(dist))
local status = SurvivorsLiteThreats
local function statusLines()
    local out = {}
    for i = 1, table.getn(status._children) do
        local r = status._children[i]
        if r._shown and r.name then out[r.name._text] = r.status._text end
    end
    return out
end
local lines = statusLines()
expect(lines["Hogger"] == "ENRAGED 40%", "boss status line: " .. tostring(lines["Hogger"]))
expect(lines["Mother Fang"] == "asleep 90%  20 yd", "guardian status line: " .. tostring(lines["Mother Fang"]))
expect(lines["Kobold Taskmaster"] and string.find(lines["Kobold Taskmaster"], "^next 0:4%d  86 yd$"), "next lair line: " .. tostring(lines["Kobold Taskmaster"]))
-- Each lair's own dragon head on its status line: Mother Fang's lair is fourth, bronze.
local function rowIcon(name)
    for i = 1, table.getn(status._children) do
        local r = status._children[i]
        if r._shown and r.name and r.name._text == name then return r.icon end
    end
end
local function same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] end
local ICON = SurvivorsLite.ICON
local LOOKS = SurvivorsLite.LAIR_LOOKS
-- The addon's own transparent dragon, whole, tinted in the lair's color (greyed when `dim`).
local function wears(tex, n, dim)
    local c = LOOKS[n].color
    local want = { c[1], c[2], c[3], 1 }
    if dim then want = { 0.25 + c[1] * 0.3, 0.25 + c[2] * 0.3, 0.25 + c[3] * 0.3, 0.85 } end
    return tex and tex._tex == SurvivorsLite.LAIR_ICON and same(tex._coords, { 0, 1, 0, 1 }) and same(tex._vc, want)
end
expect(string.find(SurvivorsLite.LAIR_ICON, "Interface\\AddOns\\SurvivorsLite\\media\\", 1, true) == 1, "lair icon is not the addon's own texture")
expect(wears(rowIcon("Mother Fang"), 4) and wears(rowIcon("Kobold Taskmaster"), 2, true) and wears(rowIcon("Rhahk'Zor"), 3), "status lines do not carry the lair looks")
expect(not same(LOOKS[4].color, LOOKS[2].color) and not same(LOOKS[2].color, LOOKS[3].color), "lairs share a color")
local hoggerIcon = rowIcon("Hogger")
expect(hoggerIcon and hoggerIcon._tex == SurvivorsLite.RAIDICONS and same(hoggerIcon._coords, ICON.skull), "boss line lost its skull")
-- Mother Fang's plate wears the bronze head and its edge takes the lair's color.
local mfIcon = overlay(plain[5]) and overlay(plain[5]).icon
expect(wears(mfIcon, 4) and mfIcon._w == 16, "guardian plate does not wear its lair's icon")
expect(same(overlay(plain[5]).edge._vc, { LOOKS[4].color[1], LOOKS[4].color[2], LOOKS[4].color[3], 1 }), "guardian plate edge not in its lair's color")
expect(lines["Edwin VanCleef"] and string.find(lines["Edwin VanCleef"], "^in "), "next boss line")

-- Pins: the lair 20 yd north is 6 units up at zoom 0 (140 units for 466.67 yd).
local function pinAt(x, y)
    for i = 1, table.getn(Minimap._children) do
        local c = Minimap._children[i]
        if c._shown and c._point and c.tex and math.abs(c._point[4] - x) < 0.1 and math.abs(c._point[5] - y) < 0.1 then return c end
    end
end
local heldPin = pinAt(0, 6)
expect(heldPin and wears(heldPin.tex, 4), "no bronze pin for the lair 20 yd north")
expect(heldPin and heldPin.edge == nil and heldPin._w == 16, "lair pin still sits on a square")
local nextPin = pinAt(15, 21)
expect(nextPin and nextPin.tip2 and string.find(nextPin.tip2, "^Back in 0:4%d, 86 yd away. Comes back first."), "next lair pin tooltip: " .. tostring(nextPin and nextPin.tip2))
expect(nextPin and wears(nextPin.tex, 2, true) and nextPin.glow._shown and nextPin._w == 20, "next lair pin not marked")
expect(nextPin and string.find(nextPin.label._text or "", "^0:4%d$"), "next lair pin has no countdown")
expect(heldPin and not heldPin.glow._shown, "a held lair glows")
local farChest, nearChest = false, nil
for i = 1, table.getn(Minimap._children) do
    local c = Minimap._children[i]
    if c._shown and c.tip == "Chest" then
        if c.tip2 == "32 yd away" then nearChest = c else farChest = true end
    end
end
expect(not farChest, "a chest 300 yd away shows on the minimap")
expect(nearChest and nearChest.tex._tex == SurvivorsLite.MEDIA .. "chest" and same(nearChest.tex._coords, { 0, 1, 0, 1 })
    and nearChest._w == 14 and pinAt(3, 9) == nearChest, "the chest 32 yd away has no chest pin")
Minimap:SetZoom(5)
MOCK.run(6, 60)
expect(pinAt(0, 21), "zoom did not scale the pins")
Minimap:SetZoom(0)
MOCK.run(6, 60)
expect(MOCK.zoom == 0 and MOCK.cvars.minimapZoom == "0" and MOCK.cvars.minimapInsideZoom == "0", "the indoor check left the zoom changed")
local ringsShown = 0
for i = 1, table.getn(Minimap._children) do
    local c = Minimap._children[i]
    if c._shown and c.dots and table.getn(c.dots) > 0 then ringsShown = ringsShown + 1 end
end
expect(ringsShown == 2, "leash rings around held lairs: " .. ringsShown)

-- The guardian wakes: the line and the bar over you show how far you are against the leash.
MOCK.addon("AZSUNITS", "boss,11,Hogger,32000,80000,1;guardian,12,Mother Fang,8000,10000,1;guardian,14,Rhahk'Zor,20000,20000,0")
MOCK.run(30, 60)
lines = statusLines()
expect(lines["Mother Fang"] == "80%  20/40 yd?", "awake guardian leash line: " .. tostring(lines["Mother Fang"]))
local leash = SurvivorsLiteLeash
expect(leash and leash._shown, "no leash bar while a guardian chases")
local function leashLabel()
    for i = 1, table.getn(MOCK.frames) do
        local o = MOCK.frames[i]
        if o._type == "FontString" and o._parent == leash and o._text then return o._text end
    end
end
expect(leashLabel() == "Mother Fang  20 / 40 yd?", "leash bar text: " .. tostring(leashLabel()))
-- You lead it 35 yd out: a warning before it gives up.
MOCK.mapY = 0.635
MOCK.run(6, 60)
local warnedText = false
for i = 1, table.getn(MOCK.frames) do
    local o = MOCK.frames[i]
    if o._type == "FontString" and o._text == "Mother Fang gives up soon" and o._shown then warnedText = true end
end
expect(warnedText, "no warning before the guardian gives up")
-- You lead it 50 yd out and it keeps chasing for three seconds: it holds at 50.
MOCK.mapY = 0.65
MOCK.run(180, 60)
expect(SurvivorsLite.db.leashHeld == 50, "leash held distance: " .. tostring(SurvivorsLite.db.leashHeld))
expect(leashLabel() == "Mother Fang  50 / 50 yd?", "leash bar after holding at 50: " .. tostring(leashLabel()))
-- You run to 60 yd and it gives up: the leash is learned there.
MOCK.mapY = 0.66
MOCK.run(6, 60)
MOCK.addon("AZSUNITS", "boss,11,Hogger,32000,80000,1;guardian,12,Mother Fang,10000,10000,0;guardian,14,Rhahk'Zor,20000,20000,0")
MOCK.run(6, 60)
expect(SurvivorsLite.db.leashLearned == 60 and chatHas("learned the guardians' leash"), "leash not learned: " .. tostring(SurvivorsLite.db.leashLearned))
local radius, confirmed = SurvivorsLite.LeashRadius()
expect(radius == 60 and confirmed, "leash radius after learning: " .. tostring(radius))
expect(not leash._shown, "leash bar stayed after the guardian went home")
-- Waking again, the bar shows the learned leash without a question mark.
MOCK.mapY = 0.62
MOCK.addon("AZSUNITS", "boss,11,Hogger,32000,80000,1;guardian,12,Mother Fang,9000,10000,1;guardian,14,Rhahk'Zor,20000,20000,0")
MOCK.run(6, 60)
expect(leashLabel() == "Mother Fang  20 / 60 yd", "leash bar with a learned leash: " .. tostring(leashLabel()))
slash("leashbar off")
expect(not leash._shown, "leashbar off left the bar")
slash("leashbar on")
MOCK.addon("AZSUNITS", "boss,11,Hogger,32000,80000,1;guardian,12,Mother Fang,9000,10000,0;guardian,14,Rhahk'Zor,20000,20000,0")
MOCK.run(6, 60)
slash("leash 45")
expect(SurvivorsLite.db.leash == 45 and SurvivorsLite.db.leashLearned == nil and SurvivorsLite.db.leashHeld == nil, "leash setting did not replace the learned one")
MOCK.mapY = 0.62

-- Naxxramas has no zone map: your map position reads 0, 0 and the lair and chest lines carry
-- no map coordinates. The run line's world position places the pins, indoors at the indoor
-- scale (140 units for 300 yd), and the status list still says how far the lairs are.
MOCK.mapX, MOCK.mapY = 0, 0
MOCK.indoors = true
MOCK.event("ZONE_CHANGED_NEW_AREA")
MOCK.addon("AZSRUN", "ph=playing;t=300;sl=0;px=980;py=2000;pz=0;pf=0")
MOCK.addon("AZSLAIRS", "4,held,Mother Fang,12,0,1000,2000,0,,,1;2,empty,Kobold Taskmaster,15,45,1050,1950,0,,,0;3,held,Rhahk'Zor,14,0,950,2050,0,,,0")
MOCK.addon("AZSCHESTS", "8,1010,1990,0,0,0")
local zoomSets, mapSets = MOCK.zoomSets, MOCK.mapSet or 0
MOCK.run(30, 60)
lines = statusLines()
expect(lines["Mother Fang"] == "asleep 90%  20 yd", "no lair distance without a zone map: " .. tostring(lines["Mother Fang"]))
local naxxPin = pinAt(0, 9.33)
expect(naxxPin and wears(naxxPin.tex, 4), "no pin 20 yd north without a zone map, at the indoor scale")
local naxxChest = pinAt(4.67, 14)
expect(naxxChest and naxxChest.tip2 == "32 yd away", "no chest pin without a zone map")
expect(MOCK.zoomSets == zoomSets + 2 and MOCK.zoom == 0 and MOCK.cvars.minimapInsideZoom == "0" and MOCK.cvars.minimapZoom == "0", "the indoor check did not step the zoom and back once: " .. (MOCK.zoomSets - zoomSets))
MOCK.addon("AZSRUN", "ph=playing;t=301;sl=0;px=990;py=2000;pz=0;pf=0")
MOCK.run(180, 60)
expect(pinAt(0, 4.67), "the pin did not follow the run line's position")
expect((MOCK.mapSet or 0) - mapSets <= 1, "the map was set to the zone every tick: " .. ((MOCK.mapSet or 0) - mapSets))
expect(MOCK.zoomSets == zoomSets + 2, "the indoor check stepped the zoom again")
-- Outdoors again, in a zone whose lines carry no usable map coordinates: the last zone's
-- map scale is not reused, the world position places the pin at the outdoor scale.
MOCK.indoors = nil
MOCK.mapX, MOCK.mapY = 0.40, 0.62
MOCK.event("ZONE_CHANGED_NEW_AREA")
MOCK.addon("AZSRUN", "ph=playing;t=302;sl=0;px=980;py=2000;pz=0;pf=0")
MOCK.addon("AZSLAIRS", "4,held,Mother Fang,12,0,1000,2000,0,0,0,1")
MOCK.addon("AZSCHESTS", "")
MOCK.run(30, 60)
expect(pinAt(0, 6), "a map scale from the last zone placed the pin")
-- Back in a zone with a map.
MOCK.event("ZONE_CHANGED_NEW_AREA")
MOCK.addon("AZSRUN", "ph=playing;t=302;sl=0")
MOCK.addon("AZSLAIRS", "4,held,Mother Fang,12,0,1000,2000,0,0.40,0.60,1;2,empty,Kobold Taskmaster,15,45,1050,1950,0,0.45,0.55,0;3,held,Rhahk'Zor,14,0,950,2050,0,0.35,0.65,0")
MOCK.addon("AZSCHESTS", "7,1200,2300,0,0.10,0.40;8,1010,1990,0,0.41,0.59")
MOCK.run(30, 60)
expect(pinAt(0, 6), "the outdoor scale did not come back")

-- The minimap gear opens the options.
local gear
for i = 1, table.getn(Minimap._children) do
    local c = Minimap._children[i]
    if c._type == "Button" then gear = c end
end
expect(gear and gear._shown, "no gear on the minimap")
if gear then MOCK.click(gear) end
expect(SurvivorsLiteOptions._shown, "minimap gear did not open the options")
SurvivorsLiteOptions:Hide()

-- Settings.
slash("")
slash("unlock")
expect(bar.slHandle._shown and SurvivorsLiteThreats.slHandle._shown, "unlock shows no handles")
slash("lock")
slash("buffs all")
slash("mobs show")
MOCK.run(30, 60)
expect(p1._alpha == 1 and p1._mouse == true and p1.mockBar._w == 118 and p1.mockBar._point[1] == "BOTTOM", "mobs show did not restore the game's plate")
expect(p1.mockName._alpha == 1, "mobs show left the name hidden")
slash("mobs hide")
MOCK.run(30, 60)
expect(p1._alpha == 0 and p1._mouse == false, "mobs hide did not hide plain plates")
slash("plates off")
MOCK.run(30, 60)
expect(not overlay(boss)._shown and boss.mockBar._alpha == 1, "plates off left the boss styled")
slash("plates on")
slash("mobs bars")
slash("scale 1.3")
slash("scale 9")
slash("hero off")
slash("hero on")
slash("party off")
slash("party on")
slash("threats off")
slash("allies off")
slash("allies on")
slash("bogus")
slash("help")

-- ---------------------------------------------------------------- range circles

-- The settings part above opened the options window with a bare /slite.
expect(SurvivorsLiteOptions._shown, "bare /slite did not open the options")
SurvivorsLiteOptions:Hide()

local first, second, pickup = SurvivorsLite.circles[1], SurvivorsLite.circles[2], SurvivorsLite.circles[3]
local function dot(c, i) return c.dots[i]._point end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function shownDots(c)
    local n = 0
    for i = 1, table.getn(c.dots) do if c.dots[i]._shown then n = n + 1 end end
    return n
end

-- 8 yd grown by Area 1.25 at 23 units per yard: 230 units from the center.
expect(first._shown and not second._shown and not pickup._shown, "default circles: only the first one")
expect(near(dot(first, 1)[4], 230) and near(dot(first, 1)[5], 0), "first circle radius: " .. tostring(dot(first, 1)[4]))
expect(first._point[2] == SurvivorsLite.center, "circle not centered on the character mark")
expect(not first.label._shown, "radius label shown while locked and closed")
local quarter = math.floor(shownDots(first) / 4) + 1
expect(near(dot(first, quarter)[5], 230), "first circle not round: " .. tostring(dot(first, quarter)[5]))

slash("range 12")
expect(SurvivorsLite.db.rangeYd == 12 and near(dot(first, 1)[4], 345), "range 12 did not resize")
slash("range 99")
expect(SurvivorsLite.db.rangeYd == 12, "range 99 was accepted")
slash("area off")
expect(near(dot(first, 1)[4], 276) and first.text == "12 yd", "area off still grows the circle")
slash("area on")
slash("pickup on")
expect(pickup._shown and pickup.text == "pickup 12 yd" and near(dot(pickup, 1)[4], 276), "pickup circle wrong")
slash("range2 20")
expect(second._shown and second.text == "25 yd", "second circle wrong: " .. tostring(second.text))
slash("tilt 0.5")
quarter = math.floor(shownDots(first) / 4) + 1
expect(near(dot(first, quarter)[5], 345 * 0.5), "tilt did not squash the circle")
slash("tilt 2")
expect(SurvivorsLite.db.rangeTilt == 0.5, "tilt 2 was accepted")
slash("zoom 30")
expect(near(dot(first, 1)[4], 450), "zoom did not resize the circle")
slash("range off")
expect(not first._shown, "range off left the circle")
slash("range on")
MOCK.addon("AZS", "hp=2000;liv=2;area=1.5;pick=16")
expect(near(dot(first, 1)[4], 540) and pickup.text == "pickup 16 yd", "circles ignored a new stat line")
slash("unlock")
expect(SurvivorsLite.center.slHandle._shown and first.label._shown, "unlock shows no center handle or labels")
slash("lock")
expect(not first.label._shown, "labels stayed after lock")

-- ---------------------------------------------------------------- skill circles

-- Zoom 30 and tilt 0.5 from the steps above. A targeting reach is its tooltip's yards; an
-- area (radius or cone) grows by Area on top, 1.5 here.
local skills = SurvivorsLite.skills
expect(table.getn(skills) == 2, "skills with a reach: " .. table.getn(skills))
expect(skills[1] and skills[1].name == "Eviscerate" and skills[1].yards == 12 and skills[1].kind == "range", "Eviscerate reach not read")
expect(skills[2] and skills[2].name == "Blade Flurry" and skills[2].yards == 8 and skills[2].kind == "radius", "Blade Flurry reach not read")
local function skillCircle(name)
    for i = 1, table.getn(SurvivorsLite.circles) do
        local c = SurvivorsLite.circles[i]
        if c.text and string.find(c.text, "^" .. name) then return c end
    end
end
expect(not skillCircle("Eviscerate") or not skillCircle("Eviscerate")._shown, "skill circle shown before it was picked")
slash("skill eviscerate")
slash("skill blade flurry")
local ev, bf = skillCircle("Eviscerate"), skillCircle("Blade Flurry")
expect(ev and ev._shown and near(dot(ev, 1)[4], 12 * 30) and ev.text == "Eviscerate 12 yd", "Eviscerate circle: " .. tostring(ev and ev.text))
expect(bf and bf._shown and near(dot(bf, 1)[4], 12 * 30) and bf.text == "Blade Flurry 12 yd", "Blade Flurry circle: " .. tostring(bf and bf.text))
slash("skill blood fury")
expect(chatHas("no skill named 'blood fury'"), "a skill without a reach was offered")
slash("skills")
expect(chatHas("Eviscerate 12.0 yd range") and chatHas("Blade Flurry 12.0 yd radius"), "skills list")

-- Area grows to 2 and the tooltips keep their base yards: Blade Flurry's area grows with it,
-- Eviscerate's targeting reach does not.
MOCK.addon("AZS", "hp=2000;liv=2;area=2;pick=16")
MOCK.run(40, 60)
expect(bf.text == "Blade Flurry 16 yd" and near(dot(bf, 1)[4], 480), "Blade Flurry did not grow with Area: " .. tostring(bf.text))
expect(ev.text == "Eviscerate 12 yd" and near(dot(ev, 1)[4], 360), "Eviscerate grew with Area it does not use: " .. tostring(ev.text))
-- Area off: areas stay at their tooltip's yards.
slash("area off")
expect(bf.text == "Blade Flurry 8 yd", "area off still grew Blade Flurry: " .. tostring(bf.text))
slash("area on")
-- A tooltip that follows Area at the same rank already holds it: that skill is used as shown.
MOCK.tips[2] = { { "Blade Flurry" }, { "12 yd radius" } }
MOCK.addon("AZS", "hp=2000;liv=2;area=3;pick=16")
MOCK.run(40, 60)
expect(SurvivorsLite.db.tipArea and SurvivorsLite.db.tipArea["Blade Flurry"] and chatHas("Blade Flurry's tooltip already counts your Area"), "a tooltip that follows Area was not noticed")
expect(bf.text == "Blade Flurry 12 yd", "a tooltip holding Area got Area again: " .. tostring(bf.text))
SurvivorsLite.db.tipArea = nil
MOCK.tips[2] = { { "Blade Flurry" }, { "8 yd radius" } }
-- A new rank reaches farther: its circle follows.
MOCK.tips[1] = { { "Eviscerate", "14 yd range" }, { "Rank 4" } }
MOCK.addon("AZSSPELLS", "eviscerate,6762,4,5,5;blade_flurry,13877,2,8,8")
MOCK.run(40, 60)
expect(ev.text == "Eviscerate 14 yd" and near(dot(ev, 1)[4], 420), "Eviscerate did not follow its new rank: " .. tostring(ev.text))
-- The cooldown part of the spell line changing alone reads nothing again.
MOCK.tips[1] = { { "Eviscerate", "99 yd range" } }
MOCK.addon("AZSSPELLS", "eviscerate,6762,4,3,5;blade_flurry,13877,2,1,8")
MOCK.run(40, 60)
expect(ev.text == "Eviscerate 14 yd", "cooldown line read the tooltips again")
MOCK.tips[1] = { { "Eviscerate", "14 yd range" }, { "Rank 4" } }
MOCK.tips[2] = { { "Blade Flurry" }, { "8 yd radius" } }
MOCK.addon("AZS", "hp=2000;liv=2;area=1.5;pick=16")
MOCK.run(40, 60)

-- ---------------------------------------------------------------- ground circles

-- Flat until the saved view shows a live camera.
expect(SurvivorsLite.db.ground and string.find(SurvivorsLite.CameraStatus(), "^Waiting"), "camera status before it is live: " .. tostring(SurvivorsLite.CameraStatus()))
expect(near(dot(first, 1)[4], 12 * 1.5 * 30), "circle not flat before the camera is live")
-- The camera turns live: 30 yd away, looking down at 60 degrees.
MOCK.camera = { d = 30, p = 60 }
MOCK.run(40, 60)
local function project(yards, t, d, p)
    local f = 384 * math.cos(math.rad(27.5)) / math.sin(math.rad(27.5))
    local sp, cp = math.sin(math.rad(p)), math.cos(math.rad(p))
    local x, y = yards * math.cos(t * 2 * math.pi), yards * math.sin(t * 2 * math.pi)
    local z = y * cp + d + 1.5 * sp
    return f * x / z, f * (y * sp - 1.5 * cp) / z
end
expect(string.find(SurvivorsLite.CameraStatus(), "^Camera read: 30.0 yd"), "camera status: " .. tostring(SurvivorsLite.CameraStatus()))
local gx, gy = project(18, 0, 30, 60)
expect(near(dot(first, 1)[4], gx) and near(dot(first, 1)[5], gy), "ground circle side dot: " .. tostring(dot(first, 1)[4]) .. "," .. tostring(dot(first, 1)[5]))
local n = shownDots(first)
local farIdx, nearIdx = math.floor(n / 4) + 1, math.floor(3 * n / 4) + 1
local _, farY = project(18, (farIdx - 1) / n, 30, 60)
local _, nearY = project(18, (nearIdx - 1) / n, 30, 60)
expect(near(dot(first, farIdx)[5], farY) and near(dot(first, nearIdx)[5], nearY), "ground circle far and near dots")
expect(-nearY > farY, "near side not larger than the far side")
-- The wheel zooms in 10 yd: the next read shrinks nothing and grows the circle on screen.
CameraZoomIn(10)
MOCK.run(6, 60)
gx = project(18, 0, 20, 60)
expect(near(dot(first, 1)[4], gx), "ground circle did not follow the zoom: " .. tostring(dot(first, 1)[4]))
-- Turning the camera down to 85 degrees flattens the perspective.
MOCK.camera.p = 85
MOCK.run(40, 60)
local _, steepFar = project(18, (farIdx - 1) / n, 20, 85)
expect(near(dot(first, farIdx)[5], steepFar), "ground circle did not follow the pitch")
-- Logout puts view 5 back as it was.
MOCK.event("PLAYER_LOGOUT")
expect(MOCK.cvars.cameraDistanceD == "13.88" and MOCK.cvars.cameraPitchD == "10.0", "view 5 not restored at logout")
slash("fov 70")
expect(SurvivorsLite.db.fov == 70, "fov command")
slash("fov 55")
slash("camera")
expect(chatHas("Camera read: "), "camera command")
-- Off: flat again.
slash("ground off")
expect(near(dot(first, 1)[4], 12 * 1.5 * 30), "ground off did not flatten the circle")

-- ---------------------------------------------------------------- options window

local panel = SurvivorsLiteOptions
local function hasText(f, text)
    for i = 1, table.getn(f._regions) do
        local r = f._regions[i]
        if r._type == "FontString" and r._text == text then return true end
    end
end
local function button(text, nth)
    nth = nth or 1
    for i = 1, table.getn(MOCK.frames) do
        local o = MOCK.frames[i]
        if o._type == "Button" and o._parent == panel and hasText(o, text) then
            nth = nth - 1
            if nth == 0 then return o end
        end
    end
end
local function slider(text, nth)
    nth = nth or 1
    for i = 1, table.getn(MOCK.frames) do
        local o = MOCK.frames[i]
        if o._type == "Slider" and hasText(o._parent, text) then
            nth = nth - 1
            if nth == 0 then return o end
        end
    end
end

slash("")
expect(panel._shown and SurvivorsLite.optionsOpen, "/slite did not open the options")
expect(first.label._shown, "radius labels hidden while the options are open")
local ui = {}
for i = 1, table.getn(UISpecialFrames) do if UISpecialFrames[i] == "SurvivorsLiteOptions" then ui.esc = true end end
expect(ui.esc, "Esc does not close the options")

local heroBox = button("Hero bar")
expect(heroBox ~= nil, "no Hero bar check box")
MOCK.fire(heroBox, "OnEnter")
expect(MOCK.tipShown and MOCK.tip == "Hero bar", "no tooltip on a check box")
MOCK.fire(heroBox, "OnLeave")
MOCK.click(heroBox)
expect(SurvivorsLite.db.hero == false and not SurvivorsLiteHero._shown, "check box did not turn the hero bar off")
MOCK.click(heroBox)
expect(SurvivorsLite.db.hero == true and SurvivorsLiteHero._shown, "check box did not turn the hero bar on")

local mobsButton = button("Plain enemies: small bars")
expect(mobsButton ~= nil, "no plain enemies button")
MOCK.click(mobsButton)
expect(SurvivorsLite.db.mobs == "hide" and hasText(mobsButton, "Plain enemies: hidden"), "plain enemies button did not cycle")
MOCK.click(mobsButton)
MOCK.click(mobsButton)
expect(SurvivorsLite.db.mobs == "bars", "plain enemies button did not cycle back")
local leashSlider = slider("Guardian leash")
expect(leashSlider and leashSlider._value == 45, "leash slider not synced")

slash("buffs timed")
local buffsButton = button("Buffs: timed only")
expect(buffsButton ~= nil, "buffs button does not show the mode: " .. tostring(SurvivorsLite.db.buffs))
MOCK.click(buffsButton)
expect(SurvivorsLite.db.buffs == "all" and hasText(buffsButton, "Buffs: all"), "buffs button did not cycle")
MOCK.click(buffsButton)
MOCK.click(buffsButton)
expect(SurvivorsLite.db.buffs == "timed", "buffs button did not cycle back")

local radius = slider("Radius", 1)
expect(radius and radius._value == 12, "radius slider not synced: " .. tostring(radius and radius._value))
radius:SetValue(10.4)
expect(SurvivorsLite.db.rangeYd == 10 and near(dot(first, 1)[4], 10 * 1.5 * 30), "radius slider did not resize the circle")
radius:SetValue(500)
expect(SurvivorsLite.db.rangeYd == 60, "radius slider went past its range")
MOCK.wheel(radius, -1)
expect(SurvivorsLite.db.rangeYd == 59, "mouse wheel did not step the radius")
local zoom = slider("Size per yard (flat circles)")
zoom:SetValue(23)
MOCK.wheel(zoom, 1)
expect(SurvivorsLite.db.rangeZoom == 23.5, "zoom wheel step: " .. tostring(SurvivorsLite.db.rangeZoom))
local size = slider("HUD size")
size:SetValue(1.3)
expect(SurvivorsLite.db.scale == 1.3 and SurvivorsLiteHero._scale == 1.3, "HUD size slider did not scale")
slash("scale 1")
expect(size._value == 1, "slash command did not sync the open options")

-- Skill rows: one per skill with a reach, ticked for its circle.
local bfRow = button("Blade Flurry")
local bfSkill = SurvivorsLite.skills[2]
local bfYards = bfSkill and (math.floor(SurvivorsLite.SkillYards(bfSkill) + 0.5) .. " yd")
expect(bfRow and bfRow._shown and hasText(bfRow, bfYards), "Blade Flurry row: " .. tostring(bfYards))
MOCK.click(bfRow)
expect(not SurvivorsLite.db.skillRings["Blade Flurry"] and not bf._shown, "skill row did not turn its circle off")
MOCK.click(bfRow)
expect(SurvivorsLite.db.skillRings["Blade Flurry"] and bf._shown, "skill row did not turn its circle on")

local moveButton = button("Move frames")
MOCK.click(moveButton)
expect(not SurvivorsLite.locked and hasText(moveButton, "Lock frames"), "Move frames did not unlock")
MOCK.click(moveButton)
expect(SurvivorsLite.locked, "Lock frames did not lock")

local resetButton = button("Reset")
MOCK.click(resetButton)
expect(SurvivorsLite.db.rangeYd == 59, "reset ran without confirmation")
MOCK.click(resetButton)
expect(SurvivorsLite.db.rangeYd == 8 and SurvivorsLite.db.rangeZoom == 23 and not SurvivorsLite.db.pickup, "reset did not restore defaults")
expect(radius._value == 8, "reset did not sync the sliders")
expect(not ev._shown and not bf._shown, "reset left the skill circles")
panel:Hide()
expect(not SurvivorsLite.optionsOpen and not first.label._shown, "closing the options left labels")

-- The game menu rung sits above Key Bindings and opens the window.
local rung = GameMenuButtonSurvivorsLite
expect(rung and rung._text == "SurvivorsLite", "no game menu button")
expect(GameMenuButtonKeybindings._point[2] == rung and rung._point[2] == GameMenuButtonUIOptions, "game menu rungs not chained")
expect(GameMenuFrame._h == 260 + 22, "game menu did not grow: " .. tostring(GameMenuFrame._h))
GameMenuFrame:Show()
MOCK.click(rung)
expect(not GameMenuFrame._shown and panel._shown, "game menu button did not open the options")
SlashCmdList["SURVIVORSLITE"]("options")
expect(not panel._shown, "/slite options did not toggle the window closed")

-- Party leaves: friendly plates go back off.
MOCK.units.party1 = nil
MOCK.event("PARTY_MEMBERS_CHANGED")
expect(not MOCK.friendPlates, "friendly plates left on after the party left")

-- Picked jewelry: a row under the floating bar, in slot order, with quality and cooldowns.
local jewelry = SurvivorsLiteJewelry
MOCK.event("UNIT_INVENTORY_CHANGED", "player")
expect(not jewelry._shown, "the jewelry row shows with nothing picked")
MOCK.worn[11] = { icon = "Interface\\Icons\\INV_Jewelry_Ring_15", quality = 4 }
MOCK.worn[13] = { icon = "Interface\\Icons\\INV_Misc_StoneTablet_11", quality = 3, start = GetTime(), duration = 30 }
MOCK.event("UNIT_INVENTORY_CHANGED", "player")
MOCK.run(10, 60)
local pieces = {}
for i = 1, table.getn(jewelry._children) do
    local c = jewelry._children[i]
    if c._shown and c.tex then table.insert(pieces, c) end
end
expect(jewelry._shown and table.getn(pieces) == 2, "jewelry row pieces: " .. table.getn(pieces))
expect(jewelry._point and jewelry._point[2] == SurvivorsLiteBar and jewelry._point[3] == "BOTTOMLEFT", "jewelry row not under the bar")
expect(pieces[1].tex._tex == "Interface\\Icons\\INV_Jewelry_Ring_15" and same(pieces[1].border._vc, { 0.64, 0.21, 0.93, 1 }), "ring not shown with its quality")
expect(pieces[2].shade._shown and pieces[2].text._text == "30", "trinket cooldown: " .. tostring(pieces[2].text._text))
MOCK.fire(pieces[1], "OnEnter")
expect(MOCK.tipItem == 11, "jewelry tooltip did not show the ring")
slash("jewelry off")
expect(not jewelry._shown, "jewelry off left the row")
slash("jewelry on")
expect(jewelry._shown, "jewelry on did not bring the row back")
MOCK.worn = {}
MOCK.event("UNIT_INVENTORY_CHANGED", "player")

-- Run stats: the character pane's twelve numbers in a panel, then the run stats something
-- raised under a thin line; a changed number shows green or red for a while.
local statsFrame = SurvivorsLiteStats
local function statCells()
    local out = {}
    for i = 1, table.getn(statsFrame._children) do
        local c = statsFrame._children[i]
        if c._shown and c.label and c.label._text then out[c.label._text] = c end
    end
    return out
end
local function statText(label)
    local c = statCells()[label]
    return c and c.value._text
end
local function statColor(label)
    local c = statCells()[label]
    return c and c.value._tc
end
MOCK.addon("AZSZONE", "len=900")
MOCK.addon("AZS", "hp=2000;dmg=1.2;cd=0.9;crit=0.1;cm=1.5;arm=0.15;reg=1.5;area=1.25;cnt=1;echo=0.05;spd=1.1;pick=12;xp=1;luck=0;gold=1;heal=0;"
    .. "ghp=150;gdmg=0.1;gcd=0;gcrit=0;gcm=0;garm=0;greg=0;garea=0;gcnt=0;gecho=0;gspd=0;gpick=0;ggold=0;"
    .. "lch=0.05;thn=0;liv=2;bp=0;dots=1;doth=0;big=0.2;exe=0;cc=0;dotd=0;shd=0;auto=0;pet=0")
MOCK.run(6, 60)
expect(statsFrame._shown, "no run stats panel")
local want = { Health = "2000", Damage = "+20%", Haste = "+10%", Crit = "10.0%", ["Crit Dmg"] = "150%", Armor = "15%",
    Area = "+25%", Targets = "+1", Echo = "5%", Speed = "+10%", Regen = "1.5", Pickup = "12 yd",
    Lifesteal = "5.0%", Lives = "2", ["Vs Elites"] = "+20%" }
for label, text in pairs(want) do
    expect(statText(label) == text, "run stat " .. label .. ": " .. tostring(statText(label)))
end
for _, label in ipairs({ "Kill Heal", "DoT Stacks", "Execute", "Experience", "Thorns" }) do
    expect(not statText(label), "unraised run stat shows: " .. label)
end
local cellsNow = statCells()
expect(cellsNow.Health._point[4] == 6 and cellsNow.Damage._point[4] == 124, "the main stats are not in two columns")
expect(cellsNow.Lifesteal._point[4] == 6 and cellsNow.Lifesteal._point[5] == -90, "the run stats do not start on a line of their own")
expect(statsFrame._h == 6 * 2 + 8 * 13 + 6, "run stats panel height: " .. tostring(statsFrame._h))
MOCK.fire(cellsNow.Health, "OnEnter")
expect(MOCK.tip == "Health 2000" and cellsNow.Health.slGear == "+150 health", "run stat tooltip: " .. tostring(MOCK.tip))
expect(same(statColor("Damage"), { 1, 1, 1 }), "a number shows a change on its first line")
-- An upgrade raises damage and a curse lowers armor.
MOCK.addon("AZS", "hp=2000;dmg=1.3;cd=0.9;crit=0.1;cm=1.5;arm=0.1;reg=1.5;area=1.25;cnt=1;echo=0.05;spd=1.1;pick=12;xp=1;luck=0;gold=1;heal=0;"
    .. "lch=0.05;thn=0;liv=2;bp=0;dots=1;doth=0;big=0.2;exe=0;cc=0;dotd=0;shd=0;auto=0;pet=0")
MOCK.run(6, 60)
expect(statText("Damage") == "+30%" and same(statColor("Damage"), { 0.4, 1, 0.4 }), "a raised number is not green")
expect(statText("Armor") == "10%" and same(statColor("Armor"), { 1, 0.4, 0.4 }), "a lowered number is not red")
expect(same(statColor("Health"), { 1, 1, 1 }), "an unchanged number changed color")
MOCK.run(360, 60)
expect(same(statColor("Damage"), { 1, 1, 1 }) and same(statColor("Armor"), { 1, 1, 1 }), "changed numbers stay colored")
slash("stats all")
expect(statText("Kill Heal") == "0" and statText("DoT Stacks") == "1" and statText("Pet Damage") == "+0%", "stats all does not show every run stat")
slash("stats off")
expect(not statsFrame._shown, "stats off left the panel")
slash("stats")
expect(SurvivorsLite.db.stats == "raised" and statsFrame._shown and not statText("Kill Heal"), "stats did not come back as raised")
-- A new run starts lower: no red numbers for it.
MOCK.addon("AZSZONE", "len=900")
MOCK.addon("AZS", "hp=1000;dmg=1;cd=1;crit=0.05;cm=1.5;arm=0;reg=0;area=1;cnt=0;echo=0;spd=1;pick=8;xp=1;luck=0;gold=1;heal=0;"
    .. "lch=0;thn=0;liv=0;bp=0;dots=1;doth=0;big=0;exe=0;cc=0;dotd=0;shd=0;auto=0;pet=0")
MOCK.run(6, 60)
expect(statText("Health") == "1000" and same(statColor("Health"), { 1, 1, 1 }), "a new run's numbers show as changes")
expect(not statText("Lifesteal"), "unraised run stats after a new run")
MOCK.addon("AZS", "hp=1100;dmg=1;cd=1;crit=0.05;cm=1.5;arm=0;reg=0;area=1;cnt=0;echo=0;spd=1;pick=8;xp=1;luck=0;gold=1;heal=0;"
    .. "lch=0;thn=0;liv=0;bp=0;dots=1;doth=0;big=0;exe=0;cc=0;dotd=0;shd=0;auto=0;pet=0")
MOCK.run(6, 60)
expect(same(statColor("Health"), { 0.4, 1, 0.4 }), "the new run's second line shows no change")

-- Damage meter: the run's meter lines as bars, the longest the top line's, with icons from
-- the action bar and the talents' clocks, a tab for each of the run's meters.
local meter = SurvivorsLiteMeter
local function meterRows()
    local out = {}
    for i = 1, table.getn(meter._children) do
        local r = meter._children[i]
        if r._shown and r.fill and r.name then table.insert(out, r) end
    end
    return out
end
local function meterText(pattern)
    for i = 1, table.getn(meter._regions) do
        local fs = meter._regions[i]
        if fs._type == "FontString" and fs._shown and fs._text and string.find(fs._text, pattern) then return fs._text end
    end
end
local function meterTab(label)
    for i = 1, table.getn(meter._children) do
        local b = meter._children[i]
        if b.text and b.text._text == label then return b end
    end
end
MOCK.addon("AZSTIMERS", "Ignite,Spell_Fire_Incinerate,cooldown,130,60")
MOCK.addon("AZSMETER", "Eviscerate,30000,500,0.6,0;Ignite,15000,250,0.3,1;Rend,5000,83,0.1,0")
MOCK.run(30, 60)
local mrows = meterRows()
expect(meter._shown and table.getn(mrows) == 3, "meter rows: " .. table.getn(mrows))
expect(mrows[1].name._text == "Eviscerate" and mrows[1].value._text == "500  60%", "meter top row: " .. tostring(mrows[1].value._text))
expect(mrows[2].value._text == "250  30%" and mrows[3].value._text == "83  10%", "meter shares")
expect(meterText(" dps$") == "833 dps", "meter total: " .. tostring(meterText(" dps$")))
expect(mrows[1].fill._w == 210 and mrows[2].fill._w == 105 and mrows[3].fill._w == 35, "meter bars not by the top line: "
    .. tostring(mrows[1].fill._w) .. " " .. tostring(mrows[2].fill._w) .. " " .. tostring(mrows[3].fill._w))
expect(mrows[1].fill._tex == SurvivorsLite.MEDIA .. "bar", "meter bars without their texture")
expect(mrows[1].icon._shown and mrows[1].icon._tex == "Interface\\Icons\\Spell_Shadow_ShadowBolt", "action bar spell has no icon in the meter")
expect(mrows[2].icon._shown and mrows[2].icon._tex == "Interface\\Icons\\Spell_Fire_Incinerate", "talent clock icon missing in the meter")
expect(not mrows[3].icon._shown and mrows[3].rank._text == "3", "a spell without an icon shows no rank")
local evisColor = mrows[1].fill._vc
expect(not same(mrows[1].fill._vc, mrows[2].fill._vc) and not same(mrows[2].fill._vc, mrows[3].fill._vc), "meter rows share a color")
MOCK.fire(mrows[1], "OnEnter")
local tipText = table.concat(MOCK.tipLines or {}, ";")
expect(MOCK.tip == "Eviscerate" and tipText == "Damage=30,000;Per second=500;Share=60%", "meter tooltip: " .. tipText)
MOCK.fire(mrows[1], "OnLeave")
-- A new line reorders them; a spell keeps its color and the bars glide there.
MOCK.addon("AZSMETER", "Ignite,60000,700,0.6,1;Eviscerate,30000,350,0.3,0;Rend,5000,50,0.05,0;Blood Fury,4000,40,0.04,0;Hemorrhage,1000,10,0.01,0")
MOCK.run(3, 60)
mrows = meterRows()
expect(table.getn(mrows) == 5 and mrows[2].name._text == "Eviscerate" and same(mrows[2].fill._vc, evisColor), "a spell changed its color")
expect(mrows[3].fill._w > 18 and mrows[3].fill._w < 35, "meter bar jumped instead of gliding: " .. tostring(mrows[3].fill._w))
MOCK.run(60, 60)
expect(mrows[3].fill._w == 18 and mrows[2].fill._w == 105 and mrows[1].fill._w == 210, "meter bar did not arrive: " .. tostring(mrows[3].fill._w))
slash("rows 3")
expect(table.getn(meterRows()) == 3 and SurvivorsLite.db.meterRows == 3, "meter rows setting ignored")
slash("rows 8")
-- The party tab: a hero a row in class colors with the class icon, your own name in gold.
MOCK.click(meterTab("Party"))
MOCK.addon("AZSPARTY", "Ayla,mage,100000,1234,0.5,Fireball,200;Hero,warlock,60000,700,0.3,Shadow Bolt,500")
MOCK.run(60, 60)
mrows = meterRows()
expect(SurvivorsLite.db.meterMode == "party" and table.getn(mrows) == 2 and mrows[1].name._text == "Ayla", "party tab")
expect(same(mrows[1].fill._vc, { 0.41, 0.80, 0.94, 0.92 }) and mrows[1].icon._shown and mrows[1].icon._coords[2] == 0.49609375, "party row not in its class look")
expect(same(mrows[2].name._tc, { 1, 0.82, 0 }) and mrows[2].fill._w == 126, "your own party row")
MOCK.fire(mrows[2], "OnEnter")
expect(table.concat(MOCK.tipLines, ";") == "Damage=60,000;Per second=700;Share=38%;Best spell=Shadow Bolt, 500 dps", "party tooltip: " .. table.concat(MOCK.tipLines, ";"))
MOCK.fire(mrows[2], "OnLeave")
-- An empty tab says so; healing counts per second as hps.
MOCK.click(meterTab("Boss"))
MOCK.run(15, 60)
expect(table.getn(meterRows()) == 0 and meterText("^No boss fight yet%.$"), "empty boss tab")
MOCK.click(meterTab("Heal"))
MOCK.addon("AZSHEAL", "Drain Life,8000,90,1,0")
MOCK.run(15, 60)
expect(table.getn(meterRows()) == 1 and meterText(" hps$") == "90 hps", "healing tab: " .. tostring(meterText("ps$")))
slash("meter off")
expect(not meter._shown, "meter off left the meter")
slash("meter on")
MOCK.click(meterTab("Damage"))
MOCK.run(15, 60)
expect(meter._shown and SurvivorsLite.db.meterMode == "damage" and table.getn(meterRows()) == 5, "meter did not come back")

-- Alterac Valley: the game's layout pass cannot find MinimapCluster. No error window, and the
-- chat dock and bags are still placed; any other error still comes through.
local layoutRuns, docks, bags = MOCK.layoutRuns, MOCK.dockUpdates, MOCK.bagAnchors
MOCK.layoutError = "Interface\\FrameXML\\UIParent.lua:1754: QuestTimerFrame:SetPoint(): Couldn't find region named 'MinimapCluster'"
local layoutOk, layoutErr = pcall(UIParent_ManageFramePositions)
expect(layoutOk, "layout pass still raises the MinimapCluster error: " .. tostring(layoutErr))
expect(MOCK.layoutRuns == layoutRuns + 1 and MOCK.dockUpdates == docks + 1 and MOCK.bagAnchors == bags + 1, "layout guard skipped the dock or bag anchors")
MOCK.layoutError = "Interface\\FrameXML\\UIParent.lua:1700: something else"
layoutOk, layoutErr = pcall(UIParent_ManageFramePositions)
expect(not layoutOk and string.find(tostring(layoutErr), "something else", 1, true), "layout guard swallowed another error")
MOCK.layoutError = nil
layoutOk = pcall(UIParent_ManageFramePositions)
expect(layoutOk and MOCK.dockUpdates == docks + 2 and MOCK.bagAnchors == bags + 2, "layout pass broke where it works")

-- Busy fight: 600 frames with plates cycling and health changing, measured by /slite perf.
slash("perf")
local k = 0
MOCK.onFrame = function(n)
    for j = 1, 10 do
        k = k + 1
        local p = plain[math.mod(k, 300) + 1]
        p.mockBar:SetValue(math.mod(k * 7, 100))
        if math.mod(k, 13) == 0 then
            p:Hide()
            p:Show()
        end
    end
    boss.mockBar:SetValue(math.mod(n, 100))
    if math.mod(n, 6) == 0 then
        MOCK.addon("AZSUNITS", "boss,11,Hogger," .. (50000 - n) .. ",80000,1;guardian,12,Mother Fang,9000,10000,0")
        MOCK.addon("AZSTIMERS", "Cheat Death,Ability_Rogue_CheatDeath,cooldown,130,60")
        MOCK.addon("AZSMETER", "Ignite," .. (60000 + n * 50) .. ",700,0.6,1;Eviscerate," .. (30000 + n * 90) .. ",350,0.3,0;Rend,5000,50,0.05,0")
        MOCK.event("PLAYER_AURAS_CHANGED")
        MOCK.event("UNIT_HEALTH", "player")
    end
end
MOCK.run(660, 60)
MOCK.onFrame = nil

slash("reset")
MOCK.run(10, 60)

return fails
