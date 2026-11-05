-- What the game's addon API says about the world, for the other files: where your hero
-- stands, the place of any point on the ground around your feet on screen, and the parts of
-- the game's own HUD this addon replaces.
--
-- The world anchors have no handle on your own hero, but a request can add an offset in yards
-- to any anchor. So one anchor that stays put (a lair, a cache, or a place something fell)
-- plus your live position reaches any point in the world. Your feet are projected every frame
-- and SL.center follows them. While a circle shows, four more points around your feet give the
-- ground's perspective, and every dot of every circle comes from those by plain math, so the
-- dots only move when the view really changed.

local SL = SurvivorsLite
local M = SL.Module({})

-- ---------------------------------------------------------------- your position

local sampleAt, sample

-- This frame's position table, nil while the game cannot tell.
function SL.Position()
    if type(AZS_GetPlayerPosition) ~= "function" then return nil end
    local now = GetTime()
    if sampleAt ~= now then
        sampleAt = now
        sample = AZS_GetPlayerPosition()
    end
    return sample
end

-- Yards east and south from you to a point with world x, y (+x north, +y west), nil while
-- unknown or when the point is in another space.
function SL.WorldOffset(pt)
    if type(pt.x) ~= "number" or type(pt.y) ~= "number" then return nil end
    if type(AZS_GetPlayerPosition) == "function" then
        local p = SL.Position()
        if not p or (pt.spaceId and pt.spaceId ~= p.spaceId) then return nil end
        return p.y - pt.y, p.x - pt.x
    end
    -- A build older than the position call: the run line, which moves in steps.
    local run = AZS_RUN
    if type(run) == "table" and type(run.px) == "number" and type(run.py) == "number" then
        return run.py - pt.y, run.px - pt.x
    end
end

-- ---------------------------------------------------------------- the frame handler

local subscribers = {}

-- fn runs once a frame in the world, after the camera moved and before anything is drawn.
function SL.OnWorldFrame(fn)
    table.insert(subscribers, fn)
end

local function WorldFrameHandler()
    if not SL.db then return end
    for i = 1, table.getn(subscribers) do SL.Run(subscribers[i]) end
end

-- ---------------------------------------------------------------- the reference anchor

local ref               -- { id, x, y, z, space, kind }: the anchor everything is measured from
local nextFind = 0
local LOST_AFTER = 1    -- seconds without a place on screen before circles go flat
local lastGood = 0

local function Pick(page, space, want)
    for i = 1, table.getn(page.entries) do
        local e = page.entries[i]
        if e.kind == want and e.positionAvailable and e.spaceId == space then return e end
    end
end

-- A lair stays all run, a cache until it is opened, a fallen enemy's place for a minute. All
-- of them stay where they are, which a living enemy would not.
local function FindRef(now)
    if now < nextFind or type(AZS_GetWorldAnchors) ~= "function" then return end
    nextFind = now + 1
    local p = SL.Position()
    if not p then return end
    local e
    local page = AZS_GetWorldAnchors({ kinds = { "guardianLair", "cache" } })
    if page then e = Pick(page, p.spaceId, "guardianLair") or Pick(page, p.spaceId, "cache") end
    if not e then
        page = AZS_GetWorldAnchors({ kinds = { "enemy", "elite", "guardian", "boss", "finalBoss" }, states = { "dead" } })
        if page and page.entries[1] and page.entries[1].positionAvailable and page.entries[1].spaceId == p.spaceId then
            e = page.entries[1]
        end
    end
    if e then ref = { id = e.anchorId, x = e.x, y = e.y, z = e.z, space = e.spaceId, kind = e.kind } end
end

-- ---------------------------------------------------------------- the ground's perspective

local TOLERANCE = 0.2     -- UI units a corner may move before the circles are laid out again
local MIN_LAYOUT = 0.03   -- seconds between layouts while the camera turns
local WIDE, NARROW = 8, 0.5 -- yards from your feet to the corners measured
local reach = WIDE
local reachAt = 0
local want = false        -- whether a circle needs the ground now
local H                   -- the corners' screen places and the plane's coefficients
local lastLayout = 0
local groundListeners = {}

SL.groundVersion = 0

function SL.NeedGround(on)
    want = on and true or false
end

function SL.OnGroundChanged(fn)
    table.insert(groundListeners, fn)
end

local function NewRequest()
    return { attachment = "position", offset = {} }
end
local one = { NewRequest() }
local five = { one[1], NewRequest(), NewRequest(), NewRequest(), NewRequest() }
-- East and north of each corner, in reaches: s and t of the plane below.
local CORNERS = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }

-- Screen = (a s + b t + c, d s + e t + f) / (g s + h t + 1) for s, t from 0 to 1 across the
-- square of ground the corners make (Heckbert's square to quad).
local function Solve(x, y)
    local dx1, dx2, sx = x[2] - x[3], x[4] - x[3], x[1] - x[2] + x[3] - x[4]
    local dy1, dy2, sy = y[2] - y[3], y[4] - y[3], y[1] - y[2] + y[3] - y[4]
    local den = dx1 * dy2 - dx2 * dy1
    if math.abs(den) < 0.000001 then return nil end
    local g = (sx * dy2 - dx2 * sy) / den
    local h = (dx1 * sy - sx * dy1) / den
    return {
        a = x[2] - x[1] + g * x[2], b = x[4] - x[1] + h * x[4], c = x[1],
        d = y[2] - y[1] + g * y[2], e = y[4] - y[1] + h * y[4], f = y[1],
        g = g, h = h,
    }
end

-- Where the point `east`, `north` yards from your feet lies on screen, in UI units from your
-- feet; nil at or behind the horizon.
function SL.GroundPoint(east, north)
    if not H then return nil end
    local s = (east + H.reach) / (2 * H.reach)
    local t = (north + H.reach) / (2 * H.reach)
    local w = H.g * s + H.h * t + 1
    if w < 0.02 then return nil end
    return (H.a * s + H.b * t + H.c) / w, (H.d * s + H.e * t + H.f) / w
end

function SL.GroundReady()
    return SL.projected and H ~= nil
end

-- UI units one yard measures on the ground at your feet.
function SL.GroundPerYard()
    return H and H.perYard or 1
end

local function Ground(entries, center, k, now)
    local x, y = {}, {}
    for i = 1, 4 do
        local e = entries[i + 1]
        if e.state ~= "onScreen" then
            -- A corner off the screen has no coordinates: measure closer to your feet.
            if reach > NARROW then
                reach = reach / 2
                reachAt = now
            end
            return
        end
        x[i], y[i] = (e.x - center.x) / k, (e.y - center.y) / k
    end
    if H and H.reach == reach then
        local moved = false
        for i = 1, 4 do
            if math.abs(x[i] - H.x[i]) > TOLERANCE or math.abs(y[i] - H.y[i]) > TOLERANCE then moved = true end
        end
        if not moved then return end
    end
    if now - lastLayout < MIN_LAYOUT then return end
    local solved = Solve(x, y)
    if not solved then return end
    lastLayout = now
    solved.x, solved.y, solved.reach = x, y, reach
    H = solved
    local ex, ey = SL.GroundPoint(reach, 0)
    local wx, wy = SL.GroundPoint(-reach, 0)
    if ex and wx then H.perYard = math.sqrt((ex - wx) * (ex - wx) + (ey - wy) * (ey - wy)) / (2 * reach) end
    SL.groundVersion = SL.groundVersion + 1
    for i = 1, table.getn(groundListeners) do groundListeners[i]() end
end

-- ---------------------------------------------------------------- following your feet

local function SetProjected(on)
    if SL.projected == on then return end
    SL.projected = on
    if not on then
        H = nil
        SL.Place(SL.center)
    end
    SL.PlaceFollowers()
    -- Nothing to drag while the game says where your feet are.
    if SL.center.slHandle and not SL.locked then
        if on then SL.center.slHandle:Hide() else SL.center.slHandle:Show() end
    end
    if SL.ApplyRange then SL.ApplyRange() end
    if SL.RefreshOptions then SL.RefreshOptions() end
end

local function Lost(now)
    if SL.projected and now - lastGood > LOST_AFTER then SetProjected(false) end
end

local centerX, centerY

local function Follow()
    if not SL.db.ground or type(AZS_ProjectWorldAnchors) ~= "function" then
        SetProjected(false)
        return
    end
    local now = GetTime()
    local p = SL.Position()
    if ref and p and ref.space ~= p.spaceId then ref = nil end
    if not ref then FindRef(now) end
    if not (ref and p) then return Lost(now) end
    if reach < WIDE and now - reachAt > 2 then
        reach = reach * 2
        reachAt = now
    end
    local ox, oy, oz = p.x - ref.x, p.y - ref.y, p.z - ref.z
    local list = one
    one[1].anchorId = ref.id
    one[1].offset.x, one[1].offset.y, one[1].offset.z = ox, oy, oz
    if want then
        list = five
        for i = 1, 4 do
            local r = five[i + 1]
            -- s runs east (world -y) and t north (world +x), from the square's south west.
            local east = (CORNERS[i][1] * 2 - 1) * reach
            local north = (CORNERS[i][2] * 2 - 1) * reach
            r.anchorId = ref.id
            r.offset.x, r.offset.y, r.offset.z = ox + north, oy - east, oz
        end
    end
    local res = AZS_ProjectWorldAnchors(list)
    if not res then return Lost(now) end
    local e = res.entries[1]
    if e.state == "expired" or e.state == "unknownAnchor" or e.state == "worldChanged" then
        ref, nextFind = nil, 0
        return Lost(now)
    end
    if e.state ~= "onScreen" then return Lost(now) end
    lastGood = now
    local wasProjected = SL.projected
    SetProjected(true)
    local k = UIParent:GetEffectiveScale()
    local x, y = e.x / k, e.y / k
    if not wasProjected or x ~= centerX or y ~= centerY then
        centerX, centerY = x, y
        SL.center:ClearAllPoints()
        SL.center:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", x, y)
    end
    if want then Ground(res.entries, e, k, now) end
end

SL.OnWorldFrame(Follow)

-- What circles read now, for /slite world and the options window.
function SL.WorldStatus()
    if not SL.db.ground then return "Ground circles are off: circles are flat." end
    if type(AZS_ProjectWorldAnchors) ~= "function" then return "This client has no world anchors: circles are flat." end
    local p = SL.Position()
    if not p then return "Your position is not known yet: circles are flat for now." end
    if not ref or not SL.projected then return "Waiting for a lair, cache or fallen enemy to measure from: circles are flat for now." end
    if not H then return "On the ground, from a " .. tostring(ref.kind) .. " anchor." end
    return string.format("On the ground, from a %s anchor. 1 yd at your feet is %.1f units.", tostring(ref.kind), H.perYard or 0)
end

-- ---------------------------------------------------------------- the game's own HUD

-- Each part this addon replaces: the part, its setting, and the features that replace it.
local HUD_PARTS = {
    { part = "meter", key = "hidemeter", by = { "meter" } },
    { part = "bosses", key = "hidebosses", by = { "threats", "plates" } },
    { part = "flag", key = "hideflag", by = { "lairs" } },
}

-- The parts this addon hid are in db.hudHidden, so only those come back, and a part you had
-- off in the game's options stays off.
local function ApplyHud()
    if type(AZS_SetHudShown) ~= "function" or type(AZS_IsHudShown) ~= "function" then return end
    local db = SL.db
    db.hudHidden = db.hudHidden or {}
    for i = 1, table.getn(HUD_PARTS) do
        local part = HUD_PARTS[i]
        local replaced = false
        for j = 1, table.getn(part.by) do
            if db[part.by[j]] then replaced = true end
        end
        if db[part.key] and replaced then
            if AZS_IsHudShown(part.part) then
                AZS_SetHudShown(part.part, false)
                db.hudHidden[part.part] = true
            end
        elseif db.hudHidden[part.part] then
            AZS_SetHudShown(part.part, true)
            db.hudHidden[part.part] = nil
        end
    end
end

-- These settings are saved by the game, so at logout every part goes back: removing the addon
-- must not leave parts of the HUD hidden, and some have no check box in the game's options.
local function RestoreHud()
    local held = SL.db.hudHidden
    if type(held) ~= "table" or type(AZS_SetHudShown) ~= "function" then return end
    for part in pairs(held) do AZS_SetHudShown(part, true) end
    SL.db.hudHidden = {}
end

-- ---------------------------------------------------------------- over the level-up cards

local OVER_CARDS = { "SurvivorsLiteStats", "SurvivorsLiteBar", "SurvivorsLiteClocks", "SurvivorsLiteJewelry", "SurvivorsLiteMeter", "GameTooltip" }

local function ApplyOverCards()
    if type(AZS_SetOnTopOfScreens) ~= "function" then return end
    for i = 1, table.getn(OVER_CARDS) do
        AZS_SetOnTopOfScreens(OVER_CARDS[i], SL.db.overcards and true or false)
    end
end

-- ---------------------------------------------------------------- wiring

function M.init()
    SL.center.slNoHandle = function() return SL.projected end
    if type(AZS_RegisterWorldAnchorFrameHandler) == "function" then
        AZS_RegisterWorldAnchorFrameHandler(WorldFrameHandler)
    end
    SL.On("PLAYER_ENTERING_WORLD", function()
        ref, nextFind = nil, 0
    end)
    SL.On("PLAYER_LOGOUT", RestoreHud)
    -- A new run retires the old run's anchors.
    SL.OnAzs("AZSZONE", function() nextFind = 0 end)
    SL.OnAzs("AZSLAIRS", function() if not ref then nextFind = 0 end end)
end

function M.apply()
    ApplyHud()
    ApplyOverCards()
end
