-- The client's name plates: party members get a class colored bar with an arrow, plain
-- enemies a thin bar of their own health or nothing. Bosses and guardians have plates of the
-- addon's own (markers.lua), so the client's plates with their names stay hidden.
--
-- The client places plates with a solver of its own that keeps them apart; an addon only
-- sees where it put them, so plates cannot be made to overlap from here.
--
-- Cost control: the world's frames are only listed when their count grows, a plate is
-- classified when it shows or its name changes. Plain bars are the client's own health bar
-- made small, so they run no addon code; only ally plates listen to health.

local SL = SurvivorsLite
local M = SL.Module({})

local ALLY = { w = 90, h = 6, font = 10 }
local MOB_W, MOB_H = 40, 3

local plates = {}    -- plate frame -> data
local list = {}      -- the same data as an array, for sweeps
local seen = 0       -- WorldFrame children already looked at
local gen = 0        -- bumped when settings or who is special change
local allies = {}    -- party member name -> unit
local hideFriends = false
local sweeper

-- Names of marked units whose plate shows now: the status list calls them near.
SL.nearby = {}

function SL.PlatesChanged()
    gen = gen + 1
end

-- ---------------------------------------------------------------- plate parts

local function Regions(d, alpha)
    if d.regionAlpha == alpha then return end
    d.regionAlpha = alpha
    for i = 1, table.getn(d.regions) do d.regions[i]:SetAlpha(alpha) end
end

local function BarAlpha(d, alpha)
    if d.barAlpha == alpha then return end
    d.barAlpha = alpha
    d.bar:SetAlpha(alpha)
end

local function PlateAlpha(d, alpha)
    if d.alpha == alpha then return end
    d.alpha = alpha
    d.plate:SetAlpha(alpha)
    -- An invisible plate must not catch clicks meant for the ground or a cache.
    if d.mouse then d.plate:EnableMouse(alpha > 0) end
end

-- The client's health bar: small and centered on the plate, or where the client put it.
local function Shape(d, compact)
    if d.compact == compact then return end
    d.compact = compact
    local bar = d.bar
    bar:ClearAllPoints()
    if compact then
        if not d.back then
            d.back = SL.Tex(bar, "BACKGROUND", 0, 0, 0, 0.8)
            d.back:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
            d.back:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
        end
        bar:SetPoint("CENTER", d.plate, "CENTER", 0, 0)
        bar:SetWidth(MOB_W)
        bar:SetHeight(MOB_H)
        d.back:Show()
    else
        local p = d.barPoint
        if p then
            bar:SetPoint(p[1], p[2] or d.plate, p[3], p[4], p[5])
        else
            bar:SetPoint("BOTTOM", d.plate, "BOTTOM", 0, 5)
        end
        if d.bw and d.bw > 0 and d.bh and d.bh > 0 then
            bar:SetWidth(d.bw)
            bar:SetHeight(d.bh)
        end
        if d.back then d.back:Hide() end
    end
end

local function Overlay(d)
    if d.ov then return d.ov end
    local o = CreateFrame("Frame", nil, d.plate)
    o:SetFrameLevel(d.plate:GetFrameLevel() + 3)
    o:SetPoint("CENTER", d.plate, "CENTER", 0, 0)
    o:SetWidth(100)
    o:SetHeight(10)
    local edge = SL.Tex(o, "BACKGROUND", 1, 1, 1, 1)
    local fill = SL.Bar(o, 100, 10)
    fill:SetPoint("CENTER", o, "CENTER", 0, 0)
    edge:SetPoint("TOPLEFT", fill, "TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 1, -1)
    local name = SL.Text(o, 12)
    name:SetPoint("BOTTOM", fill, "TOP", 0, 3)
    local pct = SL.Text(fill, 8, true)
    pct:SetPoint("RIGHT", fill, "RIGHT", -2, 0)
    local value = SL.Text(fill, 8, true)
    value:SetPoint("LEFT", fill, "LEFT", 2, 0)
    local arrow = o:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow:SetTexCoord(0, 1, 1, 0)
    arrow:SetWidth(26)
    arrow:SetHeight(26)
    arrow:SetPoint("BOTTOM", name, "TOP", 0, -2)
    o.edge, o.fill, o.name, o.pct, o.value, o.arrow = edge, fill, name, pct, value, arrow
    d.ov = o
    return o
end

local function Fraction(d)
    local lo, hi = d.bar:GetMinMaxValues()
    local v = d.bar:GetValue() or 0
    local f = 1
    if lo and hi and hi > lo then f = (v - lo) / (hi - lo) end
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    return f
end

-- Health from the client's bar, which moves live.
local function Refresh(d)
    local o = d.ov
    local f = Fraction(d)
    o.fill:SetValue(f)
    local p = math.floor(f * 100 + 0.5)
    if p ~= o.p then
        o.p = p
        o.pct:SetText(p .. "%")
    end
end

local function Unhook(d)
    if d.hooked then
        d.bar:SetScript("OnValueChanged", d.prevValue)
        d.hooked = nil
    end
end

local function Hook(d)
    if d.hooked then return end
    d.prevValue = d.bar:GetScript("OnValueChanged")
    local prev = d.prevValue
    d.bar:SetScript("OnValueChanged", SL.Timed(function()
        if prev then prev() end
        if d.ov and d.styled then Refresh(d) end
    end))
    d.hooked = true
end

local function Unmark(d)
    d.styled = nil
    Unhook(d)
    if d.ov then d.ov:Hide() end
end

-- The client's plate as it made it, shown or hidden.
local function Stock(d, alpha)
    Unmark(d)
    Shape(d, false)
    Regions(d, 1)
    BarAlpha(d, 1)
    PlateAlpha(d, alpha)
end

-- A plain enemy: just its health, small.
local function Thin(d)
    Unmark(d)
    Shape(d, true)
    Regions(d, 0)
    BarAlpha(d, 1)
    PlateAlpha(d, 1)
end

local function StyleAlly(d, name)
    local s = ALLY
    local o = Overlay(d)
    o:SetWidth(s.w)
    o:SetHeight(s.h)
    o.fill:SetWidth(s.w)
    o.fill:SetHeight(s.h)
    SL.Font(o.name, s.font)
    o.p = nil
    local unit = allies[name]
    local c = SL.UnitColor(unit)
    o.fill:SetStatusBarColor(c[1], c[2], c[3])
    o.edge:SetVertexColor(1, 1, 1, 0.9)
    o.name:SetText(name)
    o.name:SetTextColor(1, 1, 1)
    o.value:SetText(tostring(UnitLevel(unit) or ""))
    o.arrow:SetVertexColor(c[1], c[2], c[3], 1)
    o.arrow:Show()
    o:SetAlpha(1)
    Regions(d, 0)
    BarAlpha(d, 0)
    PlateAlpha(d, 1)
    d.styled = true
    Hook(d)
    o:Show()
    Refresh(d)
end

-- ---------------------------------------------------------------- classification

local function KindOf(d, name)
    if not name or name == "" then return "mob" end
    if allies[name] then return "ally" end
    if SL.markedNames[name] then return "marked" end
    -- Stock plate colors: red hostile, yellow neutral, green friendly, blue friendly player.
    local r, g, b = d.bar:GetStatusBarColor()
    if r and g and b and r < 0.3 and (g > 0.7 or b > 0.7) then return "friend" end
    return "mob"
end

local function Classify(d, name)
    d.lastName = name
    d.gen = gen
    local db = SL.db
    local kind = KindOf(d, name)
    d.kind = kind
    if kind == "marked" then
        -- A plate of the addon's own is over this unit. Without one the game's plate stays.
        if SL.MarkersOn() then return Stock(d, 0) end
        return Stock(d, 1)
    elseif kind == "ally" then
        if db.allies then return StyleAlly(d, name) end
        return Stock(d, 1)
    elseif kind == "friend" then
        -- Your own summons and friendly NPCs.
        if hideFriends or (db.plates and db.mobs ~= "show") then return Stock(d, 0) end
        return Stock(d, 1)
    end
    if db.plates and db.mobs == "bars" then return Thin(d) end
    if db.plates and db.mobs == "hide" then return Stock(d, 0) end
    Stock(d, 1)
end

-- A stock plate: a frame with the plate border, a name and a health bar.
local function Inspect(frame)
    if plates[frame] or not frame.GetRegions then return end
    local regions = { frame:GetRegions() }
    local border
    local fonts = {}
    for i = 1, table.getn(regions) do
        local r = regions[i]
        local t = r:GetObjectType()
        if t == "Texture" then
            local path = r:GetTexture()
            if type(path) == "string" and string.find(string.lower(path), "nameplate%-border") then border = r end
        elseif t == "FontString" then
            table.insert(fonts, r)
        end
    end
    if not border or not fonts[1] then return end
    local kids = { frame:GetChildren() }
    local bar
    for i = 1, table.getn(kids) do
        if kids[i]:GetObjectType() == "StatusBar" then
            bar = kids[i]
            break
        end
    end
    if not bar then return end
    -- The name is the first font string unless that one holds the level.
    local name = fonts[1]
    local text = name:GetText()
    if fonts[2] and text and (text == "??" or string.find(text, "^%d+$")) then name = fonts[2] end
    local d = { plate = frame, bar = bar, name = name, regions = regions }
    d.mouse = frame.IsMouseEnabled and frame:IsMouseEnabled() and true or nil
    -- The client's own geometry, to put back when a plate shows as it made it.
    d.bw, d.bh = bar:GetWidth(), bar:GetHeight()
    if bar.GetPoint then
        local ok, p, rel, rp, x, y = pcall(bar.GetPoint, bar, 1)
        if ok and p then d.barPoint = { p, rel, rp or p, x or 0, y or 0 } end
    end
    plates[frame] = d
    table.insert(list, d)
    local prevShow, prevHide = frame:GetScript("OnShow"), frame:GetScript("OnHide")
    frame:SetScript("OnShow", function()
        if prevShow then prevShow() end
        d.alpha = nil
        if sweeper.active then Classify(d, d.name:GetText()) end
    end)
    frame:SetScript("OnHide", function()
        if prevHide then prevHide() end
        d.lastName = nil
    end)
    if sweeper.active and frame:IsShown() then Classify(d, name:GetText()) end
end

local function RebuildAllies()
    local new = {}
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local name = UnitName(unit)
            if name then new[name] = unit end
        end
    end
    allies = new
    gen = gen + 1
end

local function Sweep()
    local n = WorldFrame:GetNumChildren() or 0
    if n > seen then
        local kids = { WorldFrame:GetChildren() }
        for i = seen + 1, n do Inspect(kids[i]) end
    end
    seen = n
    for i = 1, table.getn(list) do
        local d = list[i]
        if d.plate:IsShown() then
            local name = d.name:GetText()
            if name ~= d.lastName or d.gen ~= gen then Classify(d, name) end
        end
    end
end

sweeper = SL.Every(0.35, Sweep, false)

-- ---------------------------------------------------------------- plates on and off

local function EnsurePlates()
    local db = SL.db
    if db.plates and db.autoplates and not NAMEPLATES_ON and ShowNameplates then
        ShowNameplates()
        NAMEPLATES_ON = 1
    end
    local grouped = (GetNumPartyMembers() or 0) > 0
    if db.allies and grouped then
        if not FRIENDNAMEPLATES_ON and ShowFriendNameplates then
            ShowFriendNameplates()
            FRIENDNAMEPLATES_ON = 1
            hideFriends = true
        end
    elseif hideFriends then
        -- Only undo what this addon turned on.
        if HideFriendNameplates then HideFriendNameplates() end
        FRIENDNAMEPLATES_ON = nil
        hideFriends = false
    end
end

function M.init()
    SL.On("PLAYER_ENTERING_WORLD", function()
        RebuildAllies()
        EnsurePlates()
    end)
    SL.On("PARTY_MEMBERS_CHANGED", function()
        RebuildAllies()
        EnsurePlates()
    end)
    SL.On("UNIT_LEVEL", function(unit)
        if unit and string.find(unit, "^party") then gen = gen + 1 end
    end)
end

function M.apply()
    local db = SL.db
    gen = gen + 1
    EnsurePlates()
    if db.plates or db.allies or hideFriends then
        SL.Wake(sweeper)
    else
        sweeper.active = false
        for i = 1, table.getn(list) do
            local d = list[i]
            d.kind, d.lastName = nil, nil
            Stock(d, 1)
        end
    end
end
