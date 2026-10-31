-- SurvivorsLite: a small, fast HUD for Azeroth Survivors.
-- Written for the client's 1.12 Lua (5.0): no #, no %, no select, no varargs.
-- Everything is event driven or runs on a few shared, throttled tickers. Nothing walks
-- the world's frames every frame.

SurvivorsLite = { version = "1.10.0" }
local SL = SurvivorsLite

SL.DEFAULTS = {
    hero = true, heroX = 0, heroY = -36,
    ring = true, lowhp = true, cds = true, buffs = "timed", uptime = true, shield = true,
    plates = true, autoplates = true, mobs = "bars", elites = false, debuffs = true,
    allies = true, party = true, partyX = -360, partyY = 110,
    threats = true, threatsX = 380, threatsY = 150,
    stats = "raised", statsX = -390, statsY = -70,
    meter = true, meterX = 390, meterY = -40, meterMode = "damage", meterRows = 8,
    alerts = true, scale = 1,
    centerX = 0, centerY = 0,
    range = true, rangeYd = 8, range2 = false, range2Yd = 30, pickup = false, area = true,
    rangeZoom = 23, rangeTilt = 1, ground = true, fov = 55,
    bar = true, barScale = 0.85, barX = 0, barY = 8, jewelry = true,
    lairs = true, chests = true, leashring = true, leashbar = true, leash = 40, mapbutton = true,
}
-- Saved settings older than this get the changed defaults below once.
SL.SCHEMA = 2

SL.WHITE = "Interface\\Buttons\\WHITE8X8"
SL.BAR = "Interface\\TargetingFrame\\UI-StatusBar"
SL.NUMFONT = "Fonts\\ARIALN.TTF"
SL.FONT = "Fonts\\FRIZQT__.TTF"
SL.RAIDICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
-- The addon's own textures (tools/make_media.py draws them): BLP files with alpha.
SL.MEDIA = "Interface\\AddOns\\SurvivorsLite\\media\\"

-- Raid icon cells: star, circle, diamond, triangle, moon, square, cross, skull.
SL.ICON = {
    star = { 0, 0.25, 0, 0.25 }, circle = { 0.25, 0.5, 0, 0.25 },
    diamond = { 0.5, 0.75, 0, 0.25 }, triangle = { 0.75, 1, 0, 0.25 },
    moon = { 0, 0.25, 0.25, 0.5 }, square = { 0.25, 0.5, 0.25, 0.5 },
    cross = { 0.5, 0.75, 0.25, 0.5 }, skull = { 0.75, 1, 0.25, 0.5 },
}
-- Each guardian's lair has a look of its own, by its place in the run's lair line: the
-- dragon's head tinted in a color of its own, the same on its minimap pin, its status line
-- and its guardian's plate. The skull stays the bosses'.
SL.LAIR_ICON = SL.MEDIA .. "lair"
SL.LAIR_LOOKS = {
    { icon = SL.LAIR_ICON, color = { 1, 0.35, 0.3 } },
    { icon = SL.LAIR_ICON, color = { 0.35, 0.65, 1 } },
    { icon = SL.LAIR_ICON, color = { 0.35, 1, 0.45 } },
    { icon = SL.LAIR_ICON, color = { 1, 0.78, 0.25 } },
    { icon = SL.LAIR_ICON, color = { 0.75, 0.5, 1 } },
}
SL.CHEST_ICON = SL.MEDIA .. "chest"

SL.CLASS = {
    WARRIOR = { 0.78, 0.61, 0.43 }, MAGE = { 0.41, 0.80, 0.94 },
    ROGUE = { 1.00, 0.96, 0.41 }, DRUID = { 1.00, 0.49, 0.04 },
    HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0.00, 0.44, 0.87 },
    PRIEST = { 1.00, 1.00, 1.00 }, WARLOCK = { 0.58, 0.51, 0.79 },
    PALADIN = { 0.96, 0.55, 0.73 },
}
local GREY = { 0.6, 0.6, 0.6 }

function SL.ClassColor(class)
    if type(class) ~= "string" then return GREY end
    return SL.CLASS[string.upper(class)] or GREY
end

function SL.UnitColor(unit)
    local _, class = UnitClass(unit)
    return SL.ClassColor(class)
end

-- ---------------------------------------------------------------- errors and timing

local errors, errorCount = {}, 0
local function Report(err)
    err = tostring(err)
    if errors[err] or errorCount >= 5 then return end
    errors[err] = true
    errorCount = errorCount + 1
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555SurvivorsLite error:|r " .. err)
    end
end
SL.Report = Report

local perfOn, perfUsed, perfStart, perfFrames = false, 0, 0, 0

-- Runs fn under pcall and returns its result; while /slite perf measures, also adds up
-- the time spent.
local function Run(fn, a1, a2)
    local ok, res
    if perfOn then
        local t0 = debugprofilestop()
        ok, res = pcall(fn, a1, a2)
        perfUsed = perfUsed + (debugprofilestop() - t0)
    else
        ok, res = pcall(fn, a1, a2)
    end
    if not ok then
        Report(res)
        return nil
    end
    return res
end
SL.Run = Run

-- Hot hooks (plate health) skip pcall but still count toward /slite perf.
function SL.Timed(fn)
    return function()
        if perfOn then
            local t0 = debugprofilestop()
            fn()
            perfUsed = perfUsed + (debugprofilestop() - t0)
        else
            fn()
        end
    end
end

-- ---------------------------------------------------------------- the game's layout pass

-- The stock UIParent_ManageFramePositions anchors the quest timer, durability and quest
-- watch frames to "MinimapCluster" by name (UIParent.lua:1754-1770). In Alterac Valley the
-- run's world-state updates call it while that name does not resolve, so each update raised
-- an error window and skipped the chat dock and bag anchors at its end. Only that error is
-- caught, and those two still run; any other error still reaches the game.
local stockLayout = UIParent_ManageFramePositions
if type(stockLayout) == "function" then
    UIParent_ManageFramePositions = function()
        local ok, err = pcall(stockLayout)
        if ok then return end
        err = tostring(err)
        if not string.find(err, "named 'MinimapCluster'", 1, true) then error(err, 0) end
        if FCF_DockUpdate then FCF_DockUpdate() end
        if updateContainerFrameAnchors then updateContainerFrameAnchors() end
    end
end

-- ---------------------------------------------------------------- events

local eventFrame = CreateFrame("Frame")
local handlers = {}
local azsHandlers = {}

function SL.On(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        eventFrame:RegisterEvent(event)
    end
    table.insert(list, fn)
end

-- The run publishes its state as addon lines (AZSUNITS, AZSTIMERS...). The client's own
-- AZSApiFrame parses them into the AZS_* tables before this frame sees the event.
function SL.OnAzs(prefix, fn)
    local list = azsHandlers[prefix]
    if not list then
        list = {}
        azsHandlers[prefix] = list
    end
    table.insert(list, fn)
end

eventFrame:SetScript("OnEvent", function()
    local list = handlers[event]
    if not list then return end
    for i = 1, table.getn(list) do
        Run(list[i], arg1, arg2)
    end
end)

SL.On("CHAT_MSG_ADDON", function(prefix)
    local list = azsHandlers[prefix]
    if not list then return end
    for i = 1, table.getn(list) do
        list[i](prefix)
    end
end)

-- ---------------------------------------------------------------- tickers

local tickers = {}
local lastUpdate = GetTime()

-- fn(now, dt) runs every `interval` seconds while ticker.active is true; it returns false
-- to sleep until SL.Wake.
function SL.Every(interval, fn, active)
    local t = { interval = interval, fn = fn, active = active ~= false, next = 0, last = GetTime() }
    table.insert(tickers, t)
    return t
end

-- Wakes a sleeping ticker. It still waits out its interval since its last run, which is
-- what throttles bursts of events.
function SL.Wake(t)
    if not t.active then
        t.active = true
        t.last = GetTime()
    end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
    if not SL.db then return end
    local now = GetTime()
    for i = 1, table.getn(tickers) do
        local t = tickers[i]
        if t.active and now >= t.next then
            t.next = now + t.interval
            if Run(t.fn, now, now - t.last) == false then t.active = false end
            t.last = now
        end
    end
    if perfOn then
        perfFrames = perfFrames + 1
        if now - perfStart >= 10 then
            perfOn = false
            local span = now - perfStart
            local perSec = perfUsed / span
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "|cff66ccffSurvivorsLite|r used %.1f ms of Lua in %.0f s: %.2f ms per second, %.3f ms per frame at %.0f fps.",
                perfUsed, span, perSec, perfUsed / math.max(1, perfFrames), perfFrames / span))
        end
    end
    lastUpdate = now
end)

-- ---------------------------------------------------------------- helpers

function SL.Font(fs, size, flags, numeric)
    local path = SL.FONT
    if not numeric and GameFontNormal and GameFontNormal.GetFont then
        local f = GameFontNormal:GetFont()
        if f then path = f end
    elseif numeric then
        path = SL.NUMFONT
    end
    fs:SetFont(path, size, flags or "OUTLINE")
    fs:SetShadowColor(0, 0, 0, 0)
end

function SL.Text(parent, size, numeric, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    SL.Font(fs, size, "OUTLINE", numeric)
    return fs
end

function SL.Tex(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(SL.WHITE)
    t:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
    return t
end

-- A flat status bar with a dark 1 px frame behind it.
function SL.Bar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetWidth(width)
    bar:SetHeight(height)
    bar:SetStatusBarTexture(SL.BAR)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local back = SL.Tex(bar, "BACKGROUND", 0, 0, 0, 0.75)
    back:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    back:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    bar.back = back
    return bar
end

function SL.Short(v)
    if not v then return "" end
    if v >= 1000000000 then return string.format("%.1fB", v / 1000000000) end
    if v >= 1000000 then return string.format("%.1fM", v / 1000000) end
    if v >= 10000 then return string.format("%.0fK", v / 1000) end
    if v >= 1000 then return string.format("%.1fK", v / 1000) end
    return tostring(math.floor(v + 0.5))
end

-- Short clock text for a number of seconds left.
function SL.Clock(r)
    if r >= 60 then return math.ceil(r / 60) .. "m" end
    if r >= 3 then return tostring(math.ceil(r)) end
    return string.format("%.1f", r)
end

-- Green to yellow to red by fraction left.
function SL.HealthColor(f)
    if f > 0.5 then return (1 - f) * 2 * 0.9 + 0.1, 0.85, 0.15 end
    return 0.95, f * 2 * 0.75 + 0.1, 0.1
end

function SL.Icon(value)
    if type(value) ~= "string" or value == "" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    if not string.find(value, "[/\\]") then return "Interface\\Icons\\" .. value end
    return value
end

-- The run's clock in seconds, nil outside a run.
function SL.RunTime()
    if type(AZS_GetRunTime) ~= "function" then return nil end
    return AZS_GetRunTime()
end

function SL.Phase()
    if type(AZS_GetPhase) ~= "function" then return nil end
    return AZS_GetPhase()
end

-- Minutes and seconds, "1:05".
function SL.MinSec(s)
    s = math.max(0, math.floor(s + 0.5))
    local m = math.floor(s / 60)
    s = s - m * 60
    if s < 10 then return m .. ":0" .. s end
    return m .. ":" .. s
end

function SL.LairLook(lair)
    local i = tonumber(lair and lair.index) or 1
    return SL.LAIR_LOOKS[math.mod(math.max(i, 1) - 1, table.getn(SL.LAIR_LOOKS)) + 1]
end

-- Puts a raid mark (by its name in SL.ICON), one of the addon's own textures or a game icon
-- (by path, its edge trimmed) on a texture, only when it changes.
function SL.SetMark(tex, mark)
    if tex.slMark == mark then return end
    tex.slMark = mark
    local c = SL.ICON[mark]
    if c then
        tex:SetTexture(SL.RAIDICONS)
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
    elseif string.find(mark, SL.MEDIA, 1, true) == 1 then
        tex:SetTexture(mark)
        tex:SetTexCoord(0, 1, 0, 1)
    else
        tex:SetTexture(mark)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

-- A lair's look on a texture: its dragon in the lair's color, greyed while it refills.
function SL.SetLook(tex, look, dim)
    SL.SetMark(tex, look.icon)
    local c = look.color
    if dim then
        tex:SetVertexColor(0.25 + c[1] * 0.3, 0.25 + c[2] * 0.3, 0.25 + c[3] * 0.3, 0.85)
    else
        tex:SetVertexColor(c[1], c[2], c[3], 1)
    end
end

-- A spell's icon by its name: from your action bar (range.lua reads its names), the
-- talents' clocks, your pets and totems. Nil when none of them has it.
SL.spellIcons = {}
function SL.SpellIcon(name)
    if not name then return nil end
    local icon = SL.spellIcons[name]
    if icon then return icon end
    local lists = { AZS_TIMERS, AZS_PETS, AZS_TOTEMS }
    for l = 1, 3 do
        local list = lists[l]
        if type(list) == "table" then
            for i = 1, table.getn(list) do
                local e = list[i]
                if e.name == name and type(e.icon) == "string" and e.icon ~= "" then return SL.Icon(e.icon) end
            end
        end
    end
end

function SL.LairById(id)
    local lairs = AZS_LAIRS
    if type(lairs) ~= "table" or id == nil then return nil end
    for i = 1, table.getn(lairs) do
        if lairs[i].id == id then return lairs[i] end
    end
end

-- Seconds until an empty lair fills, from its line's `left` and the line's age.
function SL.LairLeft(lair)
    if lair.state ~= "empty" or type(lair.left) ~= "number" or lair.left <= 0 then return nil end
    return lair.left - (GetTime() - (AZS_LAIRS_UPDATED or GetTime()))
end

-- The empty lair that fills soonest: where to go next.
function SL.NextLair()
    local lairs = AZS_LAIRS
    local best, bestLeft
    if type(lairs) == "table" then
        for i = 1, table.getn(lairs) do
            local left = SL.LairLeft(lairs[i])
            if left and (not bestLeft or left < bestLeft) then best, bestLeft = lairs[i], left end
        end
    end
    return best, bestLeft
end

-- ---------------------------------------------------------------- icons

-- A square icon with a 1 px edge, a shade that drains as time runs out and two texts.
function SL.NewIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    local border = SL.Tex(f, "BACKGROUND", 0, 0, 0, 1)
    border:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local shade = SL.Tex(f, "OVERLAY", 0, 0, 0, 0.7)
    shade:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    shade:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    shade:Hide()
    local text = SL.Text(f, 10, true)
    text:SetPoint("CENTER", f, "CENTER", 0, 0)
    local count = SL.Text(f, 9, true)
    count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -1)
    f.border, f.tex, f.shade, f.text, f.count = border, tex, shade, text, count
    return f
end

function SL.SizeIcon(f, size)
    if f.size == size then return end
    f.size = size
    f:SetWidth(size)
    f:SetHeight(size)
    SL.Font(f.text, math.floor(size * 0.5 + 2), "OUTLINE", true)
end

-- Remaining time as a shade from the top and a number; returns true while it runs.
function SL.ShowWait(f, remaining, duration, minText)
    if remaining <= 0 or duration <= 0 then
        if f.shown then
            f.shade:Hide()
            f.text:SetText("")
            f.shown, f.key = nil, nil
        end
        return false
    end
    local h = math.floor(f.size * math.min(1, remaining / duration) + 0.5)
    if h < 1 then h = 1 end
    if h ~= f.shadeH then
        f.shadeH = h
        f.shade:SetHeight(h)
    end
    if not f.shown then
        f.shade:Show()
        f.shown = true
    end
    local key
    if remaining < minText then
        key = -1
    elseif remaining < 3 then
        key = math.floor(remaining * 10)
    else
        key = math.ceil(remaining) + 100
    end
    if key ~= f.key then
        f.key = key
        if key == -1 then f.text:SetText("") else f.text:SetText(SL.Clock(remaining)) end
    end
    return true
end

-- ---------------------------------------------------------------- dotted rings

-- The client's math.sin may take degrees, as 1.12's did.
local DEGREES = math.abs(math.sin(90) - 1) < 0.001
function SL.Turn(t)
    if DEGREES then return math.cos(t * 360), math.sin(t * 360) end
    local a = t * 2 * math.pi
    return math.cos(a), math.sin(a)
end

-- Lays a ring of dots on frame `c` around its center: one dot every `spacing` units, within
-- c.minDots..c.maxDots, squashed to `tilt` of its height. The dots are c.dots; returns how
-- many show. Only call it when the radius or tilt changed.
function SL.SinCosDeg(deg)
    if DEGREES then return math.sin(deg), math.cos(deg) end
    local a = deg * math.pi / 180
    return math.sin(a), math.cos(a)
end

-- Lays `n` dots on frame `c` (within c.minDots..c.maxDots) at place(t) for t from 0 to 1
-- around the ring; place returns x, y from c's center, or nil to leave a dot out.
function SL.LayoutDots(c, n, place)
    if n < c.minDots then n = c.minDots elseif n > c.maxDots then n = c.maxDots end
    local color = c.color
    for i = 1, n do
        local d = c.dots[i]
        if not d then
            d = SL.Tex(c, "ARTWORK", color[1], color[2], color[3], color[4])
            d:SetWidth(c.dot)
            d:SetHeight(c.dot)
            c.dots[i] = d
        end
        local x, y = place((i - 1) / n)
        if x then
            d.x, d.y = x, y
            d:ClearAllPoints()
            d:SetPoint("CENTER", c, "CENTER", x, y)
            d:Show()
        else
            d.x, d.y = nil, nil
            d:Hide()
        end
    end
    for i = n + 1, table.getn(c.dots) do c.dots[i]:Hide() end
    return n
end

function SL.LayoutRing(c, radius, tilt, spacing)
    return SL.LayoutDots(c, math.floor(2 * math.pi * radius / spacing), function(t)
        local x, y = SL.Turn(t)
        return x * radius, y * radius * tilt
    end)
end

function SL.NewRing(parent, r, g, b, a, dot, minDots, maxDots)
    local c = CreateFrame("Frame", nil, parent)
    c:SetWidth(1)
    c:SetHeight(1)
    c.dots, c.color, c.dot, c.minDots, c.maxDots = {}, { r, g, b, a }, dot, minDots, maxDots
    return c
end

-- ---------------------------------------------------------------- placement

local movers = {}
SL.locked = true

-- Where your character stands on screen. The ring and the range circles center on it; the
-- camera keeps you near the middle, and "You" in unlock mode fine tunes it.
SL.center = CreateFrame("Frame", "SurvivorsLiteCenter", UIParent)
SL.center:SetWidth(28)
SL.center:SetHeight(28)
SL.center:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- Positions are offsets from the same point of UIParent: its center, or its bottom for
-- frames that belong at the screen's edge whatever its size.
local function SavePosition(frame)
    local cx, cy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not ux then return end
    local k = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    local x = math.floor(cx - ux * k + 0.5)
    local y = math.floor(cy - uy * k + 0.5)
    if frame.slPoint == "BOTTOM" then
        local fb, ub = frame:GetBottom(), UIParent:GetBottom()
        if not fb or not ub then return end
        y = math.floor(fb - ub * k + 0.5)
    end
    SL.db[frame.slKeyX] = x
    SL.db[frame.slKeyY] = y
    SL.Place(frame)
end

function SL.Place(frame)
    local p = frame.slPoint or "CENTER"
    frame:ClearAllPoints()
    frame:SetPoint(p, UIParent, p, SL.db[frame.slKeyX] or 0, SL.db[frame.slKeyY] or 0)
end

-- A handle shown over the frame while unlocked; dragging it moves the frame.
function SL.Movable(frame, keyX, keyY, label, point)
    frame.slKeyX, frame.slKeyY, frame.slPoint = keyX, keyY, point
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    local handle = CreateFrame("Frame", nil, frame)
    handle:SetAllPoints(frame)
    handle:SetFrameLevel(frame:GetFrameLevel() + 10)
    local box = SL.Tex(handle, "OVERLAY", 0.2, 0.6, 1, 0.35)
    box:SetAllPoints(handle)
    local text = SL.Text(handle, 11)
    text:SetPoint("CENTER", handle, "CENTER", 0, 0)
    text:SetText(label)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() frame:StartMoving() end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)
    handle:EnableMouse(false)
    handle:Hide()
    frame.slHandle = handle
    table.insert(movers, frame)
end

function SL.SetLocked(locked)
    SL.locked = locked
    for i = 1, table.getn(movers) do
        local f = movers[i]
        if locked then
            f.slHandle:EnableMouse(false)
            f.slHandle:Hide()
            if f.slAfterLock then f.slAfterLock() end
        else
            f:Show()
            f.slHandle:EnableMouse(true)
            f.slHandle:Show()
        end
    end
end

-- ---------------------------------------------------------------- modules and settings

local modules = {}

-- mod.init() once after the saved settings load; mod.apply() after every settings change.
function SL.Module(mod)
    table.insert(modules, mod)
    return mod
end

function SL.ApplyAll()
    for i = 1, table.getn(modules) do
        if modules[i].apply then Run(modules[i].apply) end
    end
end

-- Default settings and positions; a learned leash is forgotten too.
function SL.Reset()
    for k, v in pairs(SL.DEFAULTS) do SL.db[k] = v end
    SL.db.leashLearned, SL.db.leashHeld = nil, nil
    SL.db.skillRings, SL.db.tipArea = nil, nil
    SL.ApplyAll()
end

local loaded = false
local function Load()
    if loaded then return end
    loaded = true
    if type(SurvivorsLiteDB) ~= "table" then SurvivorsLiteDB = {} end
    local db = SurvivorsLiteDB
    -- 1.2.0: plain enemies get small bars instead of hiding.
    if (db.schema or 1) < 2 and db.mobs == "hide" then db.mobs = "bars" end
    db.schema = SL.SCHEMA
    for k, v in pairs(SL.DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    SL.db = db
    for i = 1, table.getn(modules) do
        if modules[i].init then Run(modules[i].init) end
    end
    SL.ApplyAll()
end

-- The client may load loose addons after FrameXML is up, so either event can come first.
SL.On("ADDON_LOADED", function(name)
    if name == "SurvivorsLite" then Load() end
end)
SL.On("PLAYER_LOGIN", Load)

-- ---------------------------------------------------------------- slash commands

local TOGGLE_ORDER = { "hero", "shield", "uptime", "ring", "lowhp", "bar", "jewelry", "cds", "plates", "elites",
    "debuffs", "autoplates", "allies", "party", "meter", "threats", "lairs", "chests", "leashring", "leashbar", "alerts",
    "mapbutton", "range", "range2", "pickup", "area", "ground" }
local TOGGLES = {
    hero = "hero bar with your health and buffs under your character",
    shield = "your shield on the health bar and its amount",
    uptime = "how much of the run each buff was up, under its icon",
    ring = "ring that marks your character through trees",
    lowhp = "red screen edge when your health is low",
    bar = "compact floating action bar",
    jewelry = "your picked jewelry under the action bar",
    cds = "cooldown numbers on the action bar and talent clocks over it",
    plates = "boss and guardian plates",
    elites = "mark elites too",
    debuffs = "your debuffs on boss and guardian plates",
    autoplates = "turn enemy name plates on by itself",
    allies = "ally plates with class colors and an arrow",
    party = "party frames with health, level and damage",
    meter = "damage meter: your spells, the party, the last boss fight and your healing",
    threats = "boss and guardian status: up, respawn, leash",
    lairs = "guardians' lairs on the minimap",
    chests = "chests on the minimap",
    leashring = "leash rings around held lairs on the minimap",
    leashbar = "bar over you: how far you led a guardian from its lair against its leash",
    mapbutton = "gear button on the minimap that opens the options",
    alerts = "boss countdown and ally down warnings",
    range = "range circle, or set its radius: range 8",
    range2 = "second range circle, or set its radius: range2 30",
    pickup = "circle at your pickup radius",
    area = "grow the range circles and area skill circles with your Area stat",
    ground = "circles on the ground from the live camera, when the client gives it",
}
-- Numbers some commands take, with their setting and limits.
local NUMBERS = {
    range = { key = "rangeYd", min = 1, max = 60 },
    range2 = { key = "range2Yd", min = 1, max = 60 },
    zoom = { key = "rangeZoom", min = 5, max = 60 },
    tilt = { key = "rangeTilt", min = 0.3, max = 1 },
    scale = { key = "scale", min = 0.6, max = 2 },
    barscale = { key = "barScale", min = 0.5, max = 1.5 },
    leash = { key = "leash", min = 10, max = 150 },
    fov = { key = "fov", min = 30, max = 100 },
    rows = { key = "meterRows", min = 3, max = 15 },
}

local function Say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSurvivorsLite|r " .. msg)
end
SL.Say = Say

local function OnOff(v)
    if v then return "|cff55ff55on|r" end
    return "|cffff5555off|r"
end

local function Help()
    Say("v" .. SL.version .. " commands (/slite or /sl):")
    Say("  (nothing) or options - open the options window")
    Say("  unlock, lock - drag the hero bar, party, threat list, stats, meter and the circles' center")
    for i = 1, table.getn(TOGGLE_ORDER) do
        local key = TOGGLE_ORDER[i]
        Say("  " .. key .. " [on|off] - " .. TOGGLES[key] .. " (" .. OnOff(SL.db[key]) .. ")")
    end
    Say("  buffs timed|all|off - which of your buffs to show (" .. SL.db.buffs .. ")")
    Say("  stats raised|all|off - the run's numbers from the character pane: raised ones or all (" .. SL.db.stats .. ")")
    Say("  rows 3-15 - rows in the damage meter (" .. SL.db.meterRows .. ")")
    Say("  mobs bars|hide|show - plain enemy plates: small bars, hidden or the game's (" .. SL.db.mobs .. ")")
    Say("  leash 10-150 - guardians' leash radius in yards when not learned yet (" .. SL.db.leash .. ")")
    Say("  barscale 0.5-1.5 - size of the floating action bar (" .. SL.db.barScale .. ")")
    Say("  skills - your skills with a reach; skill <name> - a circle at that skill's reach on or off")
    Say("  camera - what the ground circles read from the camera")
    Say("  fov 30-100 - the camera's field of view for ground circles (" .. SL.db.fov .. ")")
    Say("  zoom 5-60 - circle size per yard, match it to your camera (" .. SL.db.rangeZoom .. ")")
    Say("  tilt 0.3-1 - circle height for a tilted camera (" .. SL.db.rangeTilt .. ")")
    Say("  scale 0.6-2 - size of the hero bar, party and list (" .. SL.db.scale .. ")")
    Say("  perf - measure this addon's own cost for 10 seconds")
    Say("  reset - default settings and positions")
end

local function Slash(msg)
    if not SL.db then return end
    msg = string.lower(msg or "")
    local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd or ""
    local number = NUMBERS[cmd] and tonumber(rest)
    if (cmd == "" or cmd == "options" or cmd == "config") and SL.ToggleOptions then
        SL.ToggleOptions()
    elseif cmd == "" or cmd == "help" then
        Help()
    elseif number or (NUMBERS[cmd] and not TOGGLES[cmd]) then
        local n = NUMBERS[cmd]
        if number and number >= n.min and number <= n.max then
            SL.db[n.key] = number
            if TOGGLES[cmd] then SL.db[cmd] = true end
            if cmd == "leash" and SL.ForgetLeash then SL.ForgetLeash() end
            SL.ApplyAll()
            Say(cmd .. " " .. number)
        else
            Say(cmd .. " takes a number from " .. n.min .. " to " .. n.max)
        end
    elseif cmd == "camera" then
        Say(SL.CameraStatus and SL.CameraStatus() or "no camera reader")
    elseif cmd == "skills" then
        local skills = SL.skills or {}
        if table.getn(skills) == 0 then Say("no skill with a reach on your bar yet") end
        for i = 1, table.getn(skills) do
            local sk = skills[i]
            local picked = SL.db.skillRings and SL.db.skillRings[sk.name]
            Say("  " .. sk.name .. " " .. string.format("%.1f", SL.SkillYards(sk)) .. " yd " .. sk.kind .. " (" .. OnOff(picked) .. ")")
        end
    elseif cmd == "skill" then
        local found
        local skills = SL.skills or {}
        for i = 1, table.getn(skills) do
            if string.lower(skills[i].name) == rest then found = skills[i].name end
        end
        if found then
            local picked = SL.db.skillRings or {}
            SL.db.skillRings = picked
            if picked[found] then picked[found] = nil else picked[found] = true end
            SL.ApplyAll()
            Say(found .. " circle " .. OnOff(picked[found]))
        else
            Say("no skill named '" .. rest .. "' on your bar; /slite skills lists them")
        end
    elseif cmd == "unlock" or cmd == "move" then
        SL.SetLocked(false)
        SL.ApplyAll()
        Say("unlocked: drag the blue boxes, then /slite lock")
    elseif cmd == "lock" then
        SL.SetLocked(true)
        SL.ApplyAll()
        Say("locked")
    elseif cmd == "reset" then
        SL.Reset()
        Say("settings and positions reset")
    elseif cmd == "perf" then
        perfOn, perfUsed, perfStart, perfFrames = true, 0, GetTime(), 0
        Say("measuring for 10 seconds...")
    elseif cmd == "buffs" and (rest == "timed" or rest == "all" or rest == "off") then
        SL.db.buffs = rest
        SL.ApplyAll()
        Say("buffs: " .. rest)
    elseif cmd == "stats" and (rest == "raised" or rest == "all" or rest == "off" or rest == "on" or rest == "") then
        if rest == "on" then rest = "raised" end
        if rest == "" then
            if SL.db.stats == "off" then rest = "raised" else rest = "off" end
        end
        SL.db.stats = rest
        SL.ApplyAll()
        Say("stats: " .. rest)
    elseif cmd == "mobs" and (rest == "bars" or rest == "hide" or rest == "show") then
        SL.db.mobs = rest
        SL.ApplyAll()
        Say("plain enemy plates: " .. rest)
    elseif TOGGLES[cmd] then
        local v
        if rest == "on" then
            v = true
        elseif rest == "off" then
            v = false
        else
            v = not SL.db[cmd]
        end
        SL.db[cmd] = v
        SL.ApplyAll()
        Say(cmd .. " " .. OnOff(v))
    else
        Help()
    end
end

SLASH_SURVIVORSLITE1 = "/slite"
SLASH_SURVIVORSLITE2 = "/sl"
SlashCmdList["SURVIVORSLITE"] = Slash
