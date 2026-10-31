-- Pins on the minimap: every guardian's lair (its dragon in the lair's color, "!" while
-- awake, grey while it refills) with a ring at its leash radius, and the chests. The run's lair and chest lines carry both
-- map and world coordinates, so the map's size in yards comes from them and your distance to
-- a lair from your own map position. Where the zone has no map (Naxxramas and other
-- instances) the run line's world position of your hero stands in; it moves only when the
-- line comes, while the map position follows you every frame.
--
-- The leash is how far from its lair you can lead a guardian before it gives up and goes
-- home. The client does not say, so it starts at the setting and is learned both ways:
-- - while a guardian keeps chasing, the farthest you stood from its lair (counted once it
--   is still awake two seconds later, as the run's line lags) is a distance it holds at;
-- - when an awake guardian falls back asleep alive while you live, where you stood is a
--   distance it gave up at.
-- While a guardian chases you, a bar over your character shows how far you are from its
-- lair against the leash, with a warning before it gives up.

local SL = SurvivorsLite
local M = SL.Module({})

-- 1.12's minimap shows this many yards across at zoom 0 to 5, outdoors and indoors.
local OUTDOOR = { [0] = 466.67, 400, 333.33, 266.67, 200, 133.33 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }
-- The pins are transparent pictures with a margin, so a little larger than the old squares.
local LAIR_SIZE, CHEST_SIZE = 16, 14
local RING_SPACING = 5

local lairPins, chestPins, rings = {}, {}, {}
local scaleX, scaleY -- yards per map unit across and down
local px, py         -- your map position
local awake = {}     -- lair id -> true while its guardian is awake
local chase = {}     -- lair id -> { { t, d }, ... } while its guardian chases, not yet counted
local warned = {}    -- lair id -> true once the leash warning showed for this chase
local CONFIRM = 2    -- seconds a guardian must stay awake after a sample for it to count
local lastSetMap     -- when the world map was last set to your zone
local indoors, indoorsZoom, probedAt -- the minimap's indoor answer, for which zoom, and when
local ticker

-- ---------------------------------------------------------------- map scale and position

-- The slope of b over a across the points, and how straight a line they make (0 to 1).
local function Fit(points, a, b)
    local n = table.getn(points)
    if n < 2 then return nil end
    local sa, sb = 0, 0
    for i = 1, n do
        sa = sa + points[i][a]
        sb = sb + points[i][b]
    end
    local ma, mb = sa / n, sb / n
    local saa, sbb, sab = 0, 0, 0
    for i = 1, n do
        local da, db = points[i][a] - ma, points[i][b] - mb
        saa = saa + da * da
        sbb = sbb + db * db
        sab = sab + da * db
    end
    if saa < 0.00000001 or sbb < 0.000001 then return nil end
    return math.abs(sab / saa), math.abs(sab) / math.sqrt(saa * sbb)
end

local function Usable(s, r) return s and r > 0.98 and s > 100 and s < 50000 end

-- WoW's world x runs north and y west, the map's across east and down south; the other
-- pairing is tried too in case the run's lines use it.
local function FitScale()
    -- A scale left from the last zone would place this one's pins wrong.
    scaleX, scaleY = nil, nil
    local points = {}
    local sources = { AZS_LAIRS, AZS_CHESTS }
    for k = 1, 2 do
        local src = sources[k]
        if type(src) == "table" then
            for i = 1, table.getn(src) do
                local p = src[i]
                if type(p.x) == "number" and type(p.y) == "number" and type(p.mx) == "number" and type(p.my) == "number" then
                    table.insert(points, p)
                end
            end
        end
    end
    local w, rw = Fit(points, "mx", "y")
    local h, rh = Fit(points, "my", "x")
    if Usable(w, rw) and Usable(h, rh) then
        scaleX, scaleY = w, h
        return
    end
    w, rw = Fit(points, "mx", "x")
    h, rh = Fit(points, "my", "y")
    if Usable(w, rw) and Usable(h, rh) then scaleX, scaleY = w, h end
end

local function PlayerPos()
    -- The world map's zone is the player's to pick while it is open.
    if WorldMapFrame and WorldMapFrame:IsVisible() then return px, py end
    local x, y = GetPlayerMapPosition("player")
    -- A zone without a map reads 0, 0 for good, so the map is set to it only now and then.
    local now = GetTime()
    if (not x or (x == 0 and y == 0)) and SetMapToCurrentZone and not (lastSetMap and now - lastSetMap < 5) then
        lastSetMap = now
        SetMapToCurrentZone()
        x, y = GetPlayerMapPosition("player")
    end
    if x and not (x == 0 and y == 0) then px, py = x, y end
    return px, py
end

-- Yards east and south from you to a point, nil while unknown.
local function Offset(p)
    if scaleX and px and type(p.mx) == "number" and type(p.my) == "number" then
        return (p.mx - px) * scaleX, (p.my - py) * scaleY
    end
    -- WoW's world x runs north and y west, in yards.
    local run = AZS_RUN
    if type(run) == "table" and type(run.px) == "number" and type(run.py) == "number"
        and type(p.x) == "number" and type(p.y) == "number" then
        return run.py - p.y, run.px - p.x
    end
end

function SL.LairDistance(lair)
    if not px then PlayerPos() end
    local dx, dy = Offset(lair)
    if not dx then return nil end
    return math.sqrt(dx * dx + dy * dy)
end

-- The leash in yards, and whether a guardian giving up has confirmed it.
function SL.LeashRadius()
    local db = SL.db
    local held = type(db.leashHeld) == "number" and db.leashHeld or 0
    if type(db.leashLearned) == "number" then return math.max(db.leashLearned, held), true end
    return math.max(db.leash, held), false
end

-- Forgets what play taught, for the slider and /slite leash.
function SL.ForgetLeash()
    SL.db.leashLearned, SL.db.leashHeld = nil, nil
end

-- ---------------------------------------------------------------- the minimap's scale

-- The minimap keeps one zoom for outdoors and one for indoors, each in a setting of its own,
-- and shows a smaller area indoors. When both settings hold the minimap's zoom, a step to
-- the next zoom and back shows which one moves; the answer holds until you go in or out.
local function Indoors(zoom)
    if type(GetCVar) ~= "function" then return false end
    local out, ins = tonumber(GetCVar("minimapZoom")), tonumber(GetCVar("minimapInsideZoom"))
    if not (out and ins) or (zoom ~= out and zoom ~= ins) then return false end
    if out ~= ins then return zoom == ins end
    if indoorsZoom == zoom then return indoors end
    indoors, indoorsZoom = false, zoom
    if not Minimap.SetZoom then return false end
    local top = 5
    if Minimap.GetZoomLevels then top = (Minimap:GetZoomLevels() or 6) - 1 end
    local step = zoom + 1
    if step > top then step = zoom - 1 end
    probedAt = GetTime()
    Minimap:SetZoom(step)
    local movedIn = tonumber(GetCVar("minimapInsideZoom")) == step
    local movedOut = tonumber(GetCVar("minimapZoom")) == step
    Minimap:SetZoom(zoom)
    if SetCVar then
        if tonumber(GetCVar("minimapZoom")) ~= out then SetCVar("minimapZoom", out) end
        if tonumber(GetCVar("minimapInsideZoom")) ~= ins then SetCVar("minimapInsideZoom", ins) end
    end
    indoors = movedIn and not movedOut
    return indoors
end

-- Going in or out asks again, but not the minimap's zoom event that a step itself causes.
local function ForgetIndoors()
    indoorsZoom = nil
    if ticker then SL.Wake(ticker) end
end

local function ZoomChanged()
    if probedAt and GetTime() - probedAt < 1 then return end
    ForgetIndoors()
end

-- ---------------------------------------------------------------- the leash bar

local leashBar = CreateFrame("Frame", "SurvivorsLiteLeash", UIParent)
leashBar:SetFrameStrata("LOW")
leashBar:SetWidth(120)
leashBar:SetHeight(5)
leashBar:SetPoint("BOTTOM", SL.center, "CENTER", 0, 48)
local leashFill = SL.Bar(leashBar, 120, 5)
leashFill:SetPoint("CENTER", leashBar, "CENTER", 0, 0)
local leashText = SL.Text(leashBar, 10, true)
leashText:SetPoint("BOTTOM", leashBar, "TOP", 0, 2)
leashBar:Hide()
M.leashBar, M.leashText = leashBar, leashText

-- The guardian closest to giving up, of those chasing you.
local function ShowLeash(name, dist, radius, confirmed)
    if not name then
        leashBar:Hide()
        return
    end
    local f = dist / radius
    if f > 1 then f = 1 end
    leashFill:SetValue(f)
    if f >= 0.9 then
        leashFill:SetStatusBarColor(1, 0.2, 0.2)
    elseif f >= 0.7 then
        leashFill:SetStatusBarColor(1, 0.6, 0.15)
    else
        leashFill:SetStatusBarColor(0.3, 0.9, 0.3)
    end
    local text = name .. "  " .. math.floor(dist + 0.5) .. " / " .. math.floor(radius + 0.5) .. " yd"
    if not confirmed then text = text .. "?" end
    if text ~= leashText.slText then
        leashText.slText = text
        leashText:SetText(text)
    end
    leashBar:Show()
end

-- ---------------------------------------------------------------- pins

local function NewPin(size, icon)
    local f = CreateFrame("Frame", nil, Minimap)
    f:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    f:SetWidth(size)
    f:SetHeight(size)
    local t = f:CreateTexture(nil, "OVERLAY")
    SL.SetMark(t, icon)
    t:SetAllPoints(f)
    f.tex = t
    -- The next lair to fill glows, and an empty one counts down under its pin.
    local glow = f:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture("Interface\\Cooldown\\ping4")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.82, 0.2, 0.9)
    glow:SetPoint("CENTER", f, "CENTER", 0, 0)
    glow:SetWidth(size * 2.4)
    glow:SetHeight(size * 2.4)
    glow:Hide()
    f.glow = glow
    f.label = SL.Text(f, 9, true)
    f.label:SetPoint("TOP", f, "BOTTOM", 0, -1)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function()
        if not GameTooltip or not this.tip then return end
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.tip, 1, 1, 1)
        if this.tip2 then GameTooltip:AddLine(this.tip2, 1, 0.82, 0, 1) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f:Hide()
    return f
end

local function NewLeashRing()
    local c = SL.NewRing(Minimap, 1, 0.5, 0.2, 0.8, 2, 16, 48)
    c:SetFrameLevel(Minimap:GetFrameLevel() + 4)
    c:Hide()
    return c
end

-- Places a pin `ox, oy` units from the minimap's center, kept on its edge when outside;
-- returns whether it fits inside.
local function Place(f, ox, oy, radius, clamp)
    local d = math.sqrt(ox * ox + oy * oy)
    local inside = d <= radius - 4
    if not inside then
        if not clamp then
            f:Hide()
            return false
        end
        local k = (radius - 4) / d
        ox, oy = ox * k, oy * k
    end
    f:ClearAllPoints()
    f:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
    if inside then f:SetAlpha(1) else f:SetAlpha(0.6) end
    f:Show()
    return inside
end

-- Only the ring's dots inside the round minimap show.
local function Clip(c, ox, oy, radius)
    local r2 = (radius - 2) * (radius - 2)
    for i = 1, table.getn(c.dots) do
        local dot = c.dots[i]
        if dot.x then
            local x, y = ox + dot.x, oy + dot.y
            local inside = x * x + y * y <= r2
            if inside ~= dot.inside then
                dot.inside = inside
                if inside then dot:SetAlpha(1) else dot:SetAlpha(0) end
            end
        end
    end
end

-- Samples where you stand while a guardian chases; those it stayed awake through count.
local function Chase(lair, dist, now)
    local list = chase[lair.id]
    if not list then
        list = {}
        chase[lair.id] = list
    end
    table.insert(list, { t = now, d = dist })
    while list[1] and now - list[1].t >= CONFIRM do
        local d = list[1].d
        table.remove(list, 1)
        local held = SL.db.leashHeld
        if d >= 10 and d <= 150 and (type(held) ~= "number" or d > held + 0.5) then
            SL.db.leashHeld = math.floor(d + 0.5)
        end
    end
end

local function Leash(now)
    local db = SL.db
    local lairs = AZS_LAIRS
    local best, bestName, bestDist, bestId
    local radius, confirmed = SL.LeashRadius()
    if type(lairs) == "table" then
        for i = 1, table.getn(lairs) do
            local lair = lairs[i]
            if awake[lair.id] then
                local dist = SL.LairDistance(lair)
                if dist then
                    Chase(lair, dist, now)
                    local f = dist / radius
                    if not best or f > best then
                        best, bestName, bestDist, bestId = f, tostring(lair.name or "?"), dist, lair.id
                    end
                    if f < 0.7 then warned[lair.id] = nil end
                end
            end
        end
    end
    if db.leashbar and bestName then
        ShowLeash(bestName, bestDist, radius, confirmed)
        if best >= 0.85 and not warned[bestId] then
            warned[bestId] = true
            SL.Alert(bestName .. " gives up soon", 1, 0.6, 0.2, 2)
        end
    else
        ShowLeash(nil)
    end
    return bestName ~= nil
end

local function Update(now)
    local db = SL.db
    PlayerPos()
    local chasing = Leash(now or GetTime())
    if not Minimap or not (db.lairs or db.chests) then
        if not chasing then return false end
        return
    end
    local zoom = Minimap:GetZoom() or 0
    local width = Minimap:GetWidth() or 140
    local radius = width / 2
    local across = OUTDOOR
    if Indoors(zoom) then across = INDOOR end
    local ppy = width / (across[zoom] or across[0])
    local lairs = AZS_LAIRS
    local n = 0
    if db.lairs and type(lairs) == "table" then
        local leash = SL.LeashRadius()
        local nextLair = SL.NextLair()
        for i = 1, table.getn(lairs) do
            local lair = lairs[i]
            local dx, dy = Offset(lair)
            if dx then
                n = n + 1
                local look = SL.LairLook(lair)
                local f = lairPins[n] or NewPin(LAIR_SIZE, look.icon)
                lairPins[n] = f
                SL.SetLook(f.tex, look, lair.state == "empty")
                local isNext = lair == nextLair
                local size = LAIR_SIZE
                if isNext then size = LAIR_SIZE + 4 end
                if f.size ~= size then
                    f.size = size
                    f:SetWidth(size)
                    f:SetHeight(size)
                end
                local ox, oy = dx * ppy, -dy * ppy
                Place(f, ox, oy, radius, true)
                f.tip = tostring(lair.name or "?")
                local away = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5) .. " yd away"
                local label = ""
                if lair.state == "empty" then
                    -- Grey while it refills; the next to come back glows and counts down.
                    local left = SL.LairLeft(lair)
                    if left then
                        label = SL.MinSec(left)
                        f.tip2 = "Back in " .. SL.MinSec(left) .. ", " .. away
                        if isNext then f.tip2 = f.tip2 .. ". Comes back first." end
                    else
                        f.tip2 = "Slain"
                    end
                    if isNext then f.label:SetTextColor(1, 0.82, 0.2) else f.label:SetTextColor(0.7, 0.7, 0.7) end
                elseif awake[lair.id] then
                    label = "!"
                    f.label:SetTextColor(1, 0.3, 0.2)
                    f.tip2 = "Awake, " .. away
                else
                    f.tip2 = "Asleep, " .. away
                end
                if f.labelText ~= label then
                    f.labelText = label
                    f.label:SetText(label)
                end
                if isNext then f.glow:Show() else f.glow:Hide() end
                -- Its leash ring while a guardian holds it.
                local ring = rings[n] or NewLeashRing()
                rings[n] = ring
                if db.leashring and lair.state ~= "empty" then
                    local size = leash * ppy
                    local key = math.floor(size * 10 + 0.5)
                    if ring.key ~= key then
                        ring.key = key
                        SL.LayoutRing(ring, size, 1, RING_SPACING)
                        for j = 1, table.getn(ring.dots) do ring.dots[j].inside = nil end
                    end
                    ring:ClearAllPoints()
                    ring:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
                    Clip(ring, ox, oy, radius)
                    ring:Show()
                else
                    ring:Hide()
                end
            end
        end
    end
    for i = n + 1, table.getn(lairPins) do
        lairPins[i]:Hide()
        rings[i]:Hide()
    end
    local chests = AZS_CHESTS
    local m = 0
    if db.chests and type(chests) == "table" then
        for i = 1, table.getn(chests) do
            local dx, dy = Offset(chests[i])
            if dx then
                m = m + 1
                local f = chestPins[m] or NewPin(CHEST_SIZE, SL.CHEST_ICON)
                chestPins[m] = f
                f.tip, f.tip2 = "Chest", math.floor(math.sqrt(dx * dx + dy * dy) + 0.5) .. " yd away"
                Place(f, dx * ppy, -dy * ppy, radius, false)
            end
        end
    end
    for i = m + 1, table.getn(chestPins) do chestPins[i]:Hide() end
    if n == 0 and m == 0 and not chasing then return false end
end

ticker = SL.Every(0.1, Update, false)

-- ---------------------------------------------------------------- the run's lines

-- Awake and asleep from the unit line; a guardian that gives up on you teaches the leash.
local function UnitsChanged()
    local units = AZS_UNITS
    local lairs = AZS_LAIRS
    if type(units) ~= "table" or type(lairs) ~= "table" then return end
    local byId = {}
    for i = 1, table.getn(units) do byId[units[i].id] = units[i] end
    for i = 1, table.getn(lairs) do
        local lair = lairs[i]
        local u = byId[lair.id]
        local now = u and u.state == 1 or false
        if awake[lair.id] and not now and u and type(u.hp) == "number" and u.hp > 0
            and SL.Phase() == "playing" and (UnitHealth("player") or 0) > 0 then
            local dist = SL.LairDistance(lair)
            local learned = SL.db.leashLearned
            if dist and dist >= 10 and dist <= 150 and (type(learned) ~= "number" or dist < learned) then
                SL.db.leashLearned = math.floor(dist + 0.5)
                SL.Say("learned the guardians' leash: about " .. SL.db.leashLearned .. " yd")
            end
        end
        if not now then
            -- Samples from the last seconds of a chase that ended do not count.
            chase[lair.id], warned[lair.id] = nil, nil
        end
        awake[lair.id] = now or nil
    end
    SL.Wake(ticker)
end

local function PointsChanged()
    FitScale()
    UnitsChanged()
    SL.Wake(ticker)
end

function M.init()
    SL.OnAzs("AZSLAIRS", PointsChanged)
    SL.OnAzs("AZSCHESTS", PointsChanged)
    SL.OnAzs("AZSUNITS", UnitsChanged)
    SL.On("PLAYER_ENTERING_WORLD", function()
        px, py, lastSetMap, indoorsZoom = nil, nil, nil, nil
        if SetMapToCurrentZone and not (WorldMapFrame and WorldMapFrame:IsVisible()) then SetMapToCurrentZone() end
        PointsChanged()
    end)
    SL.On("ZONE_CHANGED_NEW_AREA", function()
        px, py, lastSetMap = nil, nil, nil
        ForgetIndoors()
    end)
    SL.On("ZONE_CHANGED", ForgetIndoors)
    SL.On("ZONE_CHANGED_INDOORS", ForgetIndoors)
    SL.On("MINIMAP_UPDATE_ZOOM", ZoomChanged)
end

function M.apply()
    if not SL.db.leashbar then ShowLeash(nil) end
    if not (SL.db.lairs or SL.db.chests or SL.db.leashbar) then
        ticker.active = false
        for i = 1, table.getn(lairPins) do
            lairPins[i]:Hide()
            rings[i]:Hide()
        end
        for i = 1, table.getn(chestPins) do chestPins[i]:Hide() end
        return
    end
    SL.Wake(ticker)
end
