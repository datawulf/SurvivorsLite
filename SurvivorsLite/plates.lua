-- Name plates: bosses and guardians (and elites if wanted) get a colored bar with their
-- health and your debuffs on them, party members a class colored bar with an arrow, plain
-- enemies a thin bar of their own health or nothing.
--
-- The client places plates with a solver of its own that keeps them apart; an addon only
-- sees where it put them, so plates cannot be made to overlap from here.
--
-- A plate is matched to the run's unit list by name, and where several units share a name
-- (an elite pack mob named like a guardian) by health, so only the real one is marked.
--
-- Cost control: the world's frames are only listed when their count grows, a plate is
-- classified when it shows, its name or its match changes. Plain bars are the client's own
-- health bar made small, so they run no addon code; only the marked few listen to health.

local SL = SurvivorsLite
local M = SL.Module({})

local RANK = { elite = 1, guardian = 2, boss = 3, final = 4 }
local STYLE = {
    final = { w = 150, h = 9, font = 12, icon = "skull", size = 13, edge = { 1, 0.2, 1 }, fill = { 0.85, 0.1, 0.1 } },
    boss = { w = 130, h = 8, font = 11, icon = "skull", size = 12, edge = { 1, 0.35, 0.1 }, fill = { 0.85, 0.1, 0.1 } },
    guardian = { w = 120, h = 7, font = 11, icon = "star", size = 14, edge = { 1, 0.82, 0.1 }, fill = { 0.95, 0.5, 0.05 } },
    elite = { w = 70, h = 5, font = 9, icon = "diamond", size = 10, edge = { 0.75, 0.8, 0.95 }, fill = { 0.75, 0.2, 0.15 } },
    ally = { w = 90, h = 6, font = 10, edge = { 1, 1, 1 } },
}
local MOB_W, MOB_H = 40, 3
local DEBUFF_SIZE, DEBUFF_MAX = 14, 6
-- How close a plate's health must be to a unit's to be that unit (closer when several share
-- the name), and to stay it: the run's line can lag the plate's live health.
local MATCH, ALONE, KEEP = 0.12, 0.25, 0.3

local plates = {}    -- plate frame -> data
local list = {}      -- the same data as an array, for sweeps
local seen = 0       -- WorldFrame children already looked at
local gen = 0        -- bumped when settings or who is special change
local byName = {}    -- unit name -> the run's marked units with that name
local allies = {}    -- party member name -> unit
local unitsDirty = true
local hideFriends = false
local sweeper

-- Names of marked units whose plate shows now: the status list calls them near.
SL.nearby = {}

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
    local icon = o:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(SL.RAIDICONS)
    icon:SetPoint("RIGHT", fill, "LEFT", -4, 0)
    local arrow = o:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow:SetTexCoord(0, 1, 1, 0)
    arrow:SetWidth(26)
    arrow:SetHeight(26)
    arrow:SetPoint("BOTTOM", name, "TOP", 0, -2)
    o.edge, o.fill, o.name, o.pct, o.value, o.icon, o.arrow = edge, fill, name, pct, value, icon, arrow
    o.debuffs = {}
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

-- Health from the client's bar (it moves live), the absolute number from the run's own
-- full precision line for the unit this plate was matched to.
local function Refresh(d)
    local o = d.ov
    local f = Fraction(d)
    o.fill:SetValue(f)
    local p = math.floor(f * 100 + 0.5)
    if p ~= o.p then
        o.p = p
        o.pct:SetText(p .. "%")
    end
    if d.kind ~= "ally" then
        local row = d.match
        local text = ""
        if row and type(row.hpm) == "number" and row.hpm > 0 then text = SL.Short(row.hpm * f) end
        if text ~= o.v then
            o.v = text
            o.value:SetText(text)
        end
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

local function HideDebuffs(o)
    for i = 1, table.getn(o.debuffs) do o.debuffs[i]:Hide() end
    o.debuffCount = 0
end

-- Your debuffs on the unit under its bar: icon, stacks and time left.
local function Debuffs(d)
    local o = d.ov
    local row = d.match
    if not (SL.db.debuffs and row and d.kind ~= "elite" and type(AZS_GetDebuffs) == "function") then
        if o.debuffCount ~= 0 then HideDebuffs(o) end
        return
    end
    local found = AZS_GetDebuffs(row.id)
    local n = math.min(table.getn(found), DEBUFF_MAX)
    for i = 1, n do
        local x = found[i]
        local f = o.debuffs[i]
        if not f then
            f = SL.NewIcon(o)
            SL.SizeIcon(f, DEBUFF_SIZE)
            SL.Font(f.text, 8, "OUTLINE", true)
            o.debuffs[i] = f
        end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", o.fill, "BOTTOMLEFT", (i - 1) * (DEBUFF_SIZE + 2), -3)
        if f.icon ~= x.icon then
            f.icon = x.icon
            f.tex:SetTexture(SL.Icon(x.icon))
        end
        local stacks = ""
        if type(x.stacks) == "number" and x.stacks > 1 then stacks = tostring(x.stacks) end
        if stacks ~= f.stacks then
            f.stacks = stacks
            f.count:SetText(stacks)
        end
        local left = ""
        if x.remaining and not x.permanent then left = SL.Clock(x.remaining) end
        if left ~= f.left then
            f.left = left
            f.text:SetText(left)
        end
        f:Show()
    end
    for i = n + 1, table.getn(o.debuffs) do o.debuffs[i]:Hide() end
    o.debuffCount = n
end

local function Unmark(d)
    d.styled = nil
    Unhook(d)
    if d.ov then d.ov:Hide() end
    if d.near then
        SL.nearby[d.near] = nil
        d.near = nil
    end
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

-- Enraged bosses and sleeping guardians, from the run's unit line.
local function State(d, kind)
    local o = d.ov
    local row = d.match
    local s = STYLE[kind]
    local name = d.lastName or ""
    if row and row.state == 1 and (kind == "boss" or kind == "final") then
        o.name:SetText(name .. " - ENRAGED")
        o.name:SetTextColor(1, 0.15, 0.15)
    else
        o.name:SetText(name)
        o.name:SetTextColor(s.edge[1], s.edge[2], s.edge[3])
    end
    if kind == "guardian" and row and row.state ~= 1 then o:SetAlpha(0.7) else o:SetAlpha(1) end
end

local function Style(d, kind, name)
    local s = STYLE[kind]
    local o = Overlay(d)
    o:SetWidth(s.w)
    o:SetHeight(s.h)
    o.fill:SetWidth(s.w)
    o.fill:SetHeight(s.h)
    SL.Font(o.name, s.font)
    o.p, o.v = nil, nil
    if kind == "ally" then
        local unit = allies[name]
        local c = SL.UnitColor(unit)
        o.fill:SetStatusBarColor(c[1], c[2], c[3])
        o.edge:SetVertexColor(1, 1, 1, 0.9)
        o.name:SetText(name)
        o.name:SetTextColor(1, 1, 1)
        o.value:SetText(tostring(UnitLevel(unit) or ""))
        o.arrow:SetVertexColor(c[1], c[2], c[3], 1)
        o.arrow:Show()
        o.icon:Hide()
        o:SetAlpha(1)
        HideDebuffs(o)
    else
        o.fill:SetStatusBarColor(s.fill[1], s.fill[2], s.fill[3])
        -- A guardian wears its lair's icon and color, as on the minimap and in the status list.
        local edge, size = s.edge, s.size
        local lair = kind == "guardian" and d.match and SL.LairById(d.match.id)
        if lair then
            -- The dragon picture has a clear margin, the raid marks fill their square.
            local look = SL.LairLook(lair)
            edge, size = look.color, s.size + 2
            SL.SetLook(o.icon, look)
        else
            SL.SetMark(o.icon, s.icon)
            o.icon:SetVertexColor(1, 1, 1, 1)
        end
        o.edge:SetVertexColor(edge[1], edge[2], edge[3], 1)
        o.icon:SetWidth(size)
        o.icon:SetHeight(size)
        o.icon:Show()
        o.arrow:Hide()
        State(d, kind)
        Debuffs(d)
        if d.near ~= name then
            if d.near then SL.nearby[d.near] = nil end
            d.near = name
            SL.nearby[name] = true
        end
    end
    Regions(d, 0)
    BarAlpha(d, 0)
    PlateAlpha(d, 1)
    d.styled = true
    Hook(d)
    o:Show()
    Refresh(d)
end

-- ---------------------------------------------------------------- matching

-- Pairs the shown plates named like marked units with those units by health, closest first.
-- A plate keeps its unit while the two stay near, so a lagging health line does not flip it.
local function Match()
    local groups = {}
    for i = 1, table.getn(list) do
        local d = list[i]
        if d.plate:IsShown() then
            local name = d.name:GetText()
            if name and byName[name] then
                local g = groups[name]
                if not g then
                    g = {}
                    groups[name] = g
                end
                table.insert(g, d)
            else
                d.match = nil
            end
        end
    end
    for name, group in pairs(groups) do
        local units = byName[name]
        local candidates = {}
        local base = MATCH
        if table.getn(group) == 1 and table.getn(units) == 1 then base = ALONE end
        for i = 1, table.getn(group) do
            local d = group[i]
            local f = Fraction(d)
            for j = 1, table.getn(units) do
                local u = units[j]
                local diff = math.abs(f - u.frac)
                local limit = base
                if d.match and d.match.id == u.id then
                    diff = diff - 0.05
                    limit = KEEP
                end
                if diff <= limit then table.insert(candidates, { d = d, u = u, diff = diff }) end
            end
        end
        table.sort(candidates, function(a, b) return a.diff < b.diff end)
        local takenD, takenU = {}, {}
        for i = 1, table.getn(group) do group[i].next = nil end
        for k = 1, table.getn(candidates) do
            local c = candidates[k]
            if not takenD[c.d] and not takenU[c.u] then
                takenD[c.d], takenU[c.u] = true, true
                c.d.next = c.u
            end
        end
        for i = 1, table.getn(group) do
            group[i].match = group[i].next
            group[i].next = nil
        end
    end
end

-- A plate that just showed: a name only one marked unit has, at its health, is that unit.
local function QuickMatch(d, name)
    d.match = nil
    local units = name and byName[name]
    if units and table.getn(units) == 1 and math.abs(Fraction(d) - units[1].frac) <= ALONE then
        d.match = units[1]
    end
end

-- ---------------------------------------------------------------- classification

local function KindOf(d, name)
    if not name or name == "" then return "mob" end
    if d.match then return d.match.kind end
    if allies[name] then return "ally" end
    -- Stock plate colors: red hostile, yellow neutral, green friendly, blue friendly player.
    local r, g, b = d.bar:GetStatusBarColor()
    if r and g and b and r < 0.3 and (g > 0.7 or b > 0.7) then return "friend" end
    return "mob"
end

local function Classify(d, name)
    d.lastName = name
    d.lastMatch = d.match
    d.gen = gen
    local db = SL.db
    local kind = KindOf(d, name)
    d.kind = kind
    if RANK[kind] then
        if db.plates then return Style(d, kind, name) end
        return Stock(d, 1)
    elseif kind == "ally" then
        if db.allies then return Style(d, kind, name) end
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
        if sweeper.active then
            local n = d.name:GetText()
            QuickMatch(d, n)
            Classify(d, n)
        end
    end)
    frame:SetScript("OnHide", function()
        if prevHide then prevHide() end
        d.lastName, d.match = nil, nil
        if d.near then
            SL.nearby[d.near] = nil
            d.near = nil
        end
    end)
    if sweeper.active and frame:IsShown() then
        QuickMatch(d, name:GetText())
        Classify(d, name:GetText())
    end
end

-- The run's marked units by name. Only a change in who is marked reclassifies everything.
local function RebuildSpecial()
    unitsDirty = false
    local units = AZS_UNITS
    local new, sig = {}, ""
    if type(units) == "table" then
        for i = 1, table.getn(units) do
            local u = units[i]
            local k = u.kind
            if RANK[k] and u.name and (k ~= "elite" or SL.db.elites) then
                local name = tostring(u.name)
                local row = { id = u.id, kind = k, hp = u.hp, hpm = u.hpm, state = u.state, frac = 1 }
                if type(u.hp) == "number" and type(u.hpm) == "number" and u.hpm > 0 then row.frac = u.hp / u.hpm end
                if not new[name] then new[name] = {} end
                table.insert(new[name], row)
                sig = sig .. name .. k .. tostring(u.id) .. ";"
            end
        end
    end
    -- Keep each plate's match pointing at its unit's newest row.
    local byId = {}
    for _, rows in pairs(new) do
        for i = 1, table.getn(rows) do byId[rows[i].id] = rows[i] end
    end
    for i = 1, table.getn(list) do
        local d = list[i]
        if d.match then
            d.match = byId[d.match.id]
            d.lastMatch = d.match
        end
    end
    byName = new
    if sig ~= M.sig then
        M.sig = sig
        gen = gen + 1
    end
    -- Health numbers and enrage come with every line, so the marked few update here.
    for i = 1, table.getn(list) do
        local d = list[i]
        if d.styled and RANK[d.kind] and d.plate:IsShown() and d.match then
            State(d, d.kind)
            Refresh(d)
        end
    end
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
    if unitsDirty then RebuildSpecial() end
    local n = WorldFrame:GetNumChildren() or 0
    if n > seen then
        local kids = { WorldFrame:GetChildren() }
        for i = seen + 1, n do Inspect(kids[i]) end
    end
    seen = n
    Match()
    for i = 1, table.getn(list) do
        local d = list[i]
        if d.plate:IsShown() then
            local name = d.name:GetText()
            if name ~= d.lastName or d.gen ~= gen or d.match ~= d.lastMatch then
                Classify(d, name)
            elseif d.styled and d.match then
                Debuffs(d)
            end
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
        unitsDirty = true
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
    SL.OnAzs("AZSUNITS", function() unitsDirty = true end)
    -- New lairs or marks restyle the guardians' plates; the line's countdowns alone do not.
    SL.OnAzs("AZSLAIRS", function()
        local sig = ""
        local lairs = AZS_LAIRS
        if type(lairs) == "table" then
            for i = 1, table.getn(lairs) do sig = sig .. tostring(lairs[i].id) .. ":" .. tostring(lairs[i].index) .. ";" end
        end
        if sig ~= M.lairSig then
            M.lairSig = sig
            gen = gen + 1
        end
    end)
end

function M.apply()
    local db = SL.db
    gen = gen + 1
    unitsDirty = true
    EnsurePlates()
    if db.plates or db.allies or hideFriends then
        SL.Wake(sweeper)
    else
        sweeper.active = false
        for i = 1, table.getn(list) do
            local d = list[i]
            d.kind, d.lastName, d.match = nil, nil, nil
            Stock(d, 1)
        end
    end
end
