-- Plates of the addon's own over bosses and guardians (and elites if wanted), and markers on
-- the spots party members fell. The game's world anchors name the exact unit, so there is no
-- matching by name or health, the client's plate solver does not push them around, and they
-- show with name plates off. They go over the unit's head at the game's own height and move
-- in the frame handler, in step with the world. They also replace the game's bars at the top of
-- the screen: a boss, or a guardian that is awake, is engaged and has its bar up there, wider,
-- for the whole fight, with only its icon over the unit. A sleeping guardian keeps its bar over
-- the unit while it is on screen.
--
-- Cost control: the catalog is only read a few times a second and only for these kinds, and
-- only the few handles it gives are projected each frame. Plain enemies stay on the client's
-- own plates (plates.lua).

local SL = SurvivorsLite
local M = SL.Module({})

local KIND = { finalBoss = "final", boss = "boss", guardian = "guardian", elite = "elite" }
local STYLE = {
    final = { w = 150, h = 9, font = 12, icon = "skull", size = 13, edge = { 1, 0.2, 1 }, fill = { 0.85, 0.1, 0.1 } },
    boss = { w = 130, h = 8, font = 11, icon = "skull", size = 12, edge = { 1, 0.35, 0.1 }, fill = { 0.85, 0.1, 0.1 } },
    guardian = { w = 120, h = 7, font = 11, icon = "star", size = 14, edge = { 1, 0.82, 0.1 }, fill = { 0.95, 0.5, 0.05 } },
    elite = { w = 70, h = 5, font = 9, icon = "diamond", size = 10, edge = { 0.75, 0.8, 0.95 }, fill = { 0.75, 0.2, 0.15 } },
}
local DEBUFF_SIZE, DEBUFF_MAX = 14, 6
local GAP = 8 -- units between a unit's head and its bar
local RANK = { final = 1, boss = 2, guardian = 3, elite = 4 } -- the order of the bars at the top
-- The bars at the top: wider, the first below the run clock's lines, room for a name above each.
-- A zone's bosses and guardians fit above your character like this. Debuffs go beside the bar.
local TOP_WIDE, TOP_TALLER, TOP_FIRST, TOP_STEP = 1.7, 3, 92, 30
-- Seconds a bar stays where it is when its unit leaves the screen or comes back, so a head at the
-- screen's edge or a frame without an answer does not make it blink or jump.
local SETTLE = 0.4

-- Every marker lives under one frame on WorldFrame: projected places are in WorldFrame's
-- units, and the UI scale would pull a child of UIParent off target.
local holder = CreateFrame("Frame", "SurvivorsLiteMarkers", WorldFrame)
holder:SetAllPoints(WorldFrame)

local plates = {}    -- anchor handle -> plate
local pool = {}      -- plates free to reuse
local requests, list = {}, {} -- what to project each frame, and the plate of each
local byId = {}      -- the run's special units by id
local lastCatalog
local unitsDirty = true

-- Names of the marked units: plates.lua hides the client's plates with these names.
SL.markedNames = {}

-- ---------------------------------------------------------------- one plate

local function NewPlate()
    local o = CreateFrame("Frame", nil, holder)
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
    icon:SetPoint("RIGHT", fill, "LEFT", -4, 0)
    o.edge, o.fill, o.name, o.pct, o.value, o.icon = edge, fill, name, pct, value, icon
    -- Over an engaged unit only its icon, while its bar is at the top.
    local mark = CreateFrame("Frame", nil, holder)
    mark:SetWidth(16)
    mark:SetHeight(16)
    mark.tex = mark:CreateTexture(nil, "OVERLAY")
    mark.tex:SetAllPoints(mark)
    mark:Hide()
    o.mark = mark
    o.debuffs = {}
    o:Hide()
    return o
end

local function HideDebuffs(o)
    for i = 1, table.getn(o.debuffs) do o.debuffs[i]:Hide() end
    o.debuffCount = 0
end

-- Your debuffs on the unit under its bar: icon, stacks and time left.
local function Debuffs(o, row)
    if not (SL.db.debuffs and row and o.kind ~= "elite" and type(AZS_GetDebuffs) == "function") then
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
        if o.atTop then
            f:SetPoint("LEFT", o.fill, "RIGHT", 4 + (i - 1) * (DEBUFF_SIZE + 2), 0)
        else
            f:SetPoint("TOPLEFT", o.fill, "BOTTOMLEFT", (i - 1) * (DEBUFF_SIZE + 2), -3)
        end
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

-- Health, enrage and sleep from the run's unit line.
local function Refresh(o)
    local row = byId[o.unitId]
    local name = o.unitName or ""
    if row then
        o.unitName = tostring(row.name or name)
        name = o.unitName
    end
    if row and row.state == 1 and (o.kind == "boss" or o.kind == "final") then
        o.name:SetText(name .. " - ENRAGED")
        o.name:SetTextColor(1, 0.15, 0.15)
    else
        o.name:SetText(name)
        o.name:SetTextColor(o.nameColor[1], o.nameColor[2], o.nameColor[3])
    end
    if o.kind == "guardian" and row and row.state ~= 1 then o:SetAlpha(0.7) else o:SetAlpha(1) end
    if row and type(row.hp) == "number" and type(row.hpm) == "number" and row.hpm > 0 then
        local f = row.hp / row.hpm
        if f > 1 then f = 1 elseif f < 0 then f = 0 end
        o.fill:SetValue(f)
        local p = math.floor(f * 100 + 0.5)
        if p ~= o.p then
            o.p = p
            o.pct:SetText(p .. "%")
        end
        local text = SL.Short(row.hp)
        if text ~= o.v then
            o.v = text
            o.value:SetText(text)
        end
    end
    Debuffs(o, row)
end

-- A plate wears its kind's look; a guardian its lair's icon and color, as on the minimap and
-- in the status list.
local function Style(o, kind, unitId, name)
    local s = STYLE[kind]
    o.kind, o.unitId, o.unitName = kind, unitId, name
    o.p, o.v = nil, nil
    o.atTop, o.lostAt, o.calmAt = nil, nil, nil
    o:SetWidth(s.w)
    o:SetHeight(s.h)
    o.fill:SetWidth(s.w)
    o.fill:SetHeight(s.h)
    o.fill:SetStatusBarColor(s.fill[1], s.fill[2], s.fill[3])
    SL.Font(o.name, s.font)
    local edge, size = s.edge, s.size
    local lair = kind == "guardian" and SL.LairById(unitId)
    if lair then
        -- The dragon picture has a clear margin, the raid marks fill their square.
        local look = SL.LairLook(lair)
        edge, size = look.color, s.size + 2
        SL.SetLook(o.icon, look)
        SL.SetLook(o.mark.tex, look)
    else
        SL.SetMark(o.icon, s.icon)
        o.icon:SetVertexColor(1, 1, 1, 1)
        SL.SetMark(o.mark.tex, s.icon)
        o.mark.tex:SetVertexColor(1, 1, 1, 1)
    end
    o.mark:SetWidth(size + 4)
    o.mark:SetHeight(size + 4)
    o.nameColor = s.edge
    o.edge:SetVertexColor(edge[1], edge[2], edge[3], 1)
    o.icon:SetWidth(size)
    o.icon:SetHeight(size)
    Refresh(o)
end

local function Free(id)
    local o = plates[id]
    if not o then return end
    plates[id] = nil
    o.seen = nil
    o:Hide()
    o.mark:Hide()
    HideDebuffs(o)
    table.insert(pool, o)
end

-- ---------------------------------------------------------------- the catalog

local function Rebuild()
    requests, list = {}, {}
    local ids = {}
    for id in pairs(plates) do table.insert(ids, id) end
    -- Most important first, and always the same order: the bars at the top are stacked in it.
    table.sort(ids, function(a, b)
        local ra, rb = RANK[plates[a].kind], RANK[plates[b].kind]
        if ra ~= rb then return ra < rb end
        return tostring(a) < tostring(b)
    end)
    for i = 1, table.getn(ids) do
        table.insert(requests, { anchorId = ids[i], attachment = "overhead" })
        table.insert(list, plates[ids[i]])
    end
end

-- Whether a guardian's look or the marked names changed is told by the unit line.
local function ReadUnits()
    unitsDirty = false
    byId = {}
    local units = AZS_UNITS
    local names = {}
    local sig = ""
    if type(units) == "table" then
        for i = 1, table.getn(units) do
            local u = units[i]
            byId[u.id] = u
            if KIND[u.kind] or u.kind == "final" then
                if u.name and (u.kind ~= "elite" or SL.db.elites) then
                    names[tostring(u.name)] = true
                    sig = sig .. tostring(u.name) .. ";"
                end
            end
        end
    end
    SL.markedNames = names
    if sig ~= M.sig then
        M.sig = sig
        if SL.PlatesChanged then SL.PlatesChanged() end
    end
    for _, o in pairs(plates) do Refresh(o) end
end

local function Queries()
    local kinds = { "guardian", "boss", "finalBoss" }
    if SL.db.elites then table.insert(kinds, "elite") end
    return { kinds = kinds, states = { "alive" } }
end

-- One catalog, read whole in one frame; NOT_READY and a catalog that changed under the read
-- wait for the next tick. A handle the catalog no longer lists goes.
local function ReadCatalog()
    local query = Queries()
    local cursor, page
    local found = {}
    local catalog
    repeat
        page = AZS_GetWorldAnchors(query, cursor)
        if not page then return end
        catalog = page.catalogId
        if catalog == lastCatalog and not cursor then return end
        for i = 1, table.getn(page.entries) do
            local e = page.entries[i]
            local kind = KIND[e.kind]
            if kind and e.unitId ~= nil then
                found[e.anchorId] = true
                local o = plates[e.anchorId]
                if not o or o.kind ~= kind then
                    o = o or table.remove(pool) or NewPlate()
                    plates[e.anchorId] = o
                    Style(o, kind, e.unitId, e.name)
                end
            end
        end
        cursor = page.nextCursor
    until not page.hasMore
    lastCatalog = catalog
    for id in pairs(plates) do
        if not found[id] then Free(id) end
    end
    Rebuild()
end

-- Where the bosses and guardians are now, by unit id, for the minimap. The catalog's places are
-- read at most five times a second and only when asked.
local where, whereAt = {}, nil

function SL.UnitWhere(now)
    if type(AZS_GetWorldAnchors) ~= "function" then return {} end
    now = now or GetTime()
    if whereAt and now - whereAt < 0.2 then return where end
    whereAt = now
    local found = {}
    local cursor, page
    repeat
        page = AZS_GetWorldAnchors({ kinds = { "guardian", "boss", "finalBoss" }, states = { "alive" } }, cursor)
        if not page then return where end
        for i = 1, table.getn(page.entries) do
            local e = page.entries[i]
            if e.unitId ~= nil and e.positionAvailable then
                found[e.unitId] = { x = e.x, y = e.y, z = e.z, spaceId = e.spaceId, kind = KIND[e.kind], name = e.name }
            end
        end
        cursor = page.nextCursor
    until not page.hasMore
    where = found
    return where
end

local function Near()
    local near = {}
    for _, o in pairs(plates) do
        if o.seen and o.unitName then near[o.unitName] = true end
    end
    SL.nearby = near
end

local function On()
    return SL.db.plates and type(AZS_GetWorldAnchors) == "function" and type(AZS_ProjectWorldAnchors) == "function"
end

-- Whether these plates stand in for the client's; plates.lua asks.
function SL.MarkersOn()
    return On()
end

-- Health and debuffs under the frame rate; the catalog when the units or kinds changed.
local ticker = SL.Every(0.35, function()
    if not SL.db.plates then return false end
    if unitsDirty then
        ReadUnits()
    else
        for _, o in pairs(plates) do Debuffs(o, byId[o.unitId]) end
    end
    -- A build without anchors still needs the names: the game's plates stay for those.
    if not On() then return false end
    ReadCatalog()
    Near()
end, false)

-- ---------------------------------------------------------------- each frame

-- The bar's size for over the unit or at the top of the screen.
local function SizeBar(o, atTop)
    if o.atTop == atTop then return end
    o.atTop = atTop
    local s = STYLE[o.kind]
    local w, h = s.w, s.h
    if atTop then w, h = math.floor(s.w * TOP_WIDE), s.h + TOP_TALLER end
    o:SetWidth(w)
    o:SetHeight(h)
    o.fill:SetWidth(w)
    o.fill:SetHeight(h)
end

-- Engaged: a boss, or a guardian that is awake. Its bar stands in for the game's at the top while
-- those are hidden.
local function Engaged(o)
    if not SL.db.hidebosses then return false end
    if o.kind == "final" or o.kind == "boss" then return true end
    local row = byId[o.unitId]
    return o.kind == "guardian" and row and row.state == 1
end

local function PlacePlates()
    local n = table.getn(requests)
    if n == 0 or not On() then return end
    local res = AZS_ProjectWorldAnchors(requests)
    if not res then return end
    local dropped = false
    local slot = 0
    local now = GetTime()
    for i = 1, n do
        local e, o = res.entries[i], list[i]
        local place
        local onScreen = e.state == "onScreen" and res.frameCurrent
        if e.state == "expired" or e.state == "worldChanged" or e.state == "unknownAnchor"
            or e.entityState == "dead" then
            o.seen = nil
            o:Hide()
            Free(e.anchorId)
            dropped = true
        else
            local engaged = Engaged(o)
            if engaged then
                o.calmAt = nil
            elseif o.atTop and o:IsShown() then
                -- A guardian that just went back to sleep keeps its place a moment.
                o.calmAt = o.calmAt or now
                if now - o.calmAt < SETTLE then engaged = true end
            end
            if onScreen then
                o.lostAt = nil
                o.seen = true
            else
                o.lostAt = o.lostAt or now
                o.seen = nil
            end
            if engaged then
                place = "top"
            elseif onScreen then
                place = "unit"
            elseif not (now - o.lostAt < SETTLE and o:IsShown()) then
                -- A frame or two without a place keeps the bar where it is.
                o:Hide()
            end
            if engaged and onScreen then
                o.mark:ClearAllPoints()
                o.mark:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", e.x, e.y + GAP)
                o.mark:Show()
            elseif not (engaged and o.lostAt and now - o.lostAt < SETTLE) then
                o.mark:Hide()
            end
        end
        if place == "unit" then
            SizeBar(o, false)
            o:ClearAllPoints()
            o:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", e.x, e.y + GAP)
            o:Show()
        elseif place == "top" then
            SizeBar(o, true)
            o:ClearAllPoints()
            o:SetPoint("CENTER", WorldFrame, "TOP", 0, -TOP_FIRST - slot * TOP_STEP)
            slot = slot + 1
            o:Show()
        end
    end
    if dropped then
        Rebuild()
        -- If the game still lists that unit it comes back at the next read of the catalog.
        lastCatalog = nil
    end
end

-- ---------------------------------------------------------------- friends who are down

local downMarks = {}

local function DownMark(i)
    local f = downMarks[i]
    if f then return f end
    f = CreateFrame("Frame", nil, holder)
    f:SetWidth(20)
    f:SetHeight(20)
    f.icon = f:CreateTexture(nil, "OVERLAY")
    SL.SetMark(f.icon, "cross")
    f.icon:SetAllPoints(f)
    f.label = SL.Text(f, 11)
    f.label:SetPoint("BOTTOM", f, "TOP", 0, 2)
    f.label:SetTextColor(1, 0.35, 0.3)
    f:Hide()
    downMarks[i] = f
    return f
end

local function HideDownMarks(from)
    for i = from, table.getn(downMarks) do downMarks[i]:Hide() end
end

local function PlaceDownMarks()
    local down = SL.downed
    if not (SL.db.downmark and type(down) == "table" and table.getn(down) > 0 and type(AZS_ProjectWorldAnchors) == "function") then
        HideDownMarks(1)
        return
    end
    local req, who = {}, {}
    for i = 1, table.getn(down) do
        local d = down[i]
        if d.anchorId and d.anchorStatus == "ready" then
            table.insert(req, { anchorId = d.anchorId, attachment = "position", offset = { z = 1 } })
            table.insert(who, d)
        end
    end
    if table.getn(req) == 0 then
        HideDownMarks(1)
        return
    end
    local res = AZS_ProjectWorldAnchors(req)
    if not res then return end
    for i = 1, table.getn(req) do
        local e, f = res.entries[i], DownMark(i)
        if e.state == "onScreen" and res.frameCurrent then
            f:ClearAllPoints()
            f:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", e.x, e.y)
            local text = tostring(who[i].name or "?")
            if e.playerDistance then text = text .. "  " .. math.floor(e.playerDistance + 0.5) .. " yd" end
            f.label:SetText(text)
            f:Show()
        else
            f:Hide()
        end
    end
    HideDownMarks(table.getn(req) + 1)
end

SL.OnWorldFrame(PlacePlates)
SL.OnWorldFrame(PlaceDownMarks)

-- ---------------------------------------------------------------- wiring

function M.init()
    SL.OnAzs("AZSUNITS", function()
        unitsDirty = true
        SL.Wake(ticker)
    end)
    -- New lairs restyle the guardians' plates; the line's countdowns alone do not.
    SL.OnAzs("AZSLAIRS", function()
        local sig = ""
        local lairs = AZS_LAIRS
        if type(lairs) == "table" then
            for i = 1, table.getn(lairs) do sig = sig .. tostring(lairs[i].id) .. ":" .. tostring(lairs[i].index) .. ";" end
        end
        if sig ~= M.lairSig then
            M.lairSig = sig
            for _, o in pairs(plates) do Style(o, o.kind, o.unitId, o.unitName) end
        end
    end)
    SL.On("PLAYER_ENTERING_WORLD", function()
        unitsDirty, lastCatalog = true, nil
        SL.Wake(ticker)
    end)
end

function M.apply()
    unitsDirty, lastCatalog = true, nil
    if SL.db.plates then
        SL.Wake(ticker)
    else
        ticker.active = false
        SL.markedNames = {}
        M.sig = nil
    end
    for _, o in pairs(plates) do
        o.atTop = nil
        o.mark:Hide()
    end
    if not On() then
        for id in pairs(plates) do Free(id) end
        Rebuild()
        SL.nearby = {}
    end
    -- Elites going on or off changes which handles are wanted.
    if not SL.db.elites then
        for id, o in pairs(plates) do
            if o.kind == "elite" then Free(id) end
        end
        Rebuild()
    end
end
