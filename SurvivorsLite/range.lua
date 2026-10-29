-- Range circles around your character: one or two radii you pick in yards, grown by your
-- Area stat, your pickup radius and your skills' reach. The client has no call that maps the
-- world to the screen. With the camera read from its saved view settings they are projected
-- onto flat ground around your feet; without, they are flat on the screen around the spot
-- marked as your character, sized by a yards to screen factor you match to your zoom once.
-- Each circle is a ring of small dots: the line stays sharp at any size, and the dots only
-- move when a radius, the zoom factor or the screen changes.

local SL = SurvivorsLite
local M = SL.Module({})

local REF_HEIGHT = 768 -- rangeZoom counts screen units per yard on a 768 unit tall screen
local SPACING = 8
local camTicker

local function NewCircle(r, g, b, a, dot, labelBelow)
    local c = SL.NewRing(UIParent, r, g, b, a, dot, 24, 120)
    c:SetFrameStrata("BACKGROUND")
    c:SetPoint("CENTER", SL.center, "CENTER", 0, 0)
    c.below = labelBelow
    c.label = SL.Text(c, 10, true)
    c.label:SetTextColor(r, g, b)
    c:Hide()
    return c
end

local first = NewCircle(0.35, 0.85, 1, 0.85, 3)
local second = NewCircle(1, 0.55, 0.2, 0.85, 3)
local pickup = NewCircle(1, 0.85, 0.25, 0.6, 2, true)
M.circles = { first, second, pickup }
SL.circles = M.circles

local function Yards(v)
    if math.abs(v - math.floor(v + 0.5)) < 0.05 then return math.floor(v + 0.5) .. " yd" end
    return string.format("%.1f yd", v)
end

-- ---------------------------------------------------------------- the live camera

-- The client tells addons nothing about its camera, but 1.12's saved views do: SaveView(5)
-- writes the camera's distance and pitch into the cameraDistanceD and cameraPitchD settings.
-- Read back, they place the circles on the ground in perspective. View 5's own values are
-- put back at logout. Until the settings ever show a live camera, circles stay flat.
local TARGET_HEIGHT = 1.5 -- yards from your feet up to the point the camera orbits
local cam = { live = false }
local saved             -- view 5 as you had it
local hotUntil, lastRead = 0, 0

local function ReadCamera()
    if type(SaveView) ~= "function" or type(GetCVar) ~= "function" then return false end
    if not saved then
        saved = { GetCVar("cameraDistanceD"), GetCVar("cameraPitchD"), GetCVar("cameraYawD") }
        cam.startD, cam.startP = tonumber(saved[1]), tonumber(saved[2])
    end
    SaveView(5)
    local d, p = tonumber(GetCVar("cameraDistanceD")), tonumber(GetCVar("cameraPitchD"))
    if not d or not p or d <= 0 then return false end
    -- Live once the view ever differs from what it held before the first save.
    if not cam.live and (d ~= cam.startD or p ~= cam.startP) then cam.live = true end
    local changed = d ~= cam.d or p ~= cam.p
    cam.d, cam.p = d, p
    return changed
end

local function RestoreView()
    if saved and type(SetCVar) == "function" then
        if saved[1] then SetCVar("cameraDistanceD", saved[1]) end
        if saved[2] then SetCVar("cameraPitchD", saved[2]) end
        if saved[3] then SetCVar("cameraYawD", saved[3]) end
    end
end

-- Whether circles lie on the ground now.
local function Ground()
    return SL.db.ground and cam.live and cam.d and cam.p
end

-- Screen units per unit of view depth: half the screen's height over tan of half the
-- vertical field of view.
local function Focal(screenH)
    local s, c = SL.SinCosDeg(SL.db.fov / 2)
    return (screenH / 2) * c / s
end

-- A circle of `yards` around your feet as the camera sees flat ground: each dot projected
-- through a camera `cam.d` yards from the point above your feet, looking down at cam.p.
local function LayoutGround(c, yards, screenH)
    local f = Focal(screenH)
    local sp, cp = SL.SinCosDeg(cam.p)
    local d, h = cam.d, TARGET_HEIGHT
    local top, bottom = -10000, 10000
    local n = math.floor(2 * math.pi * yards * f / (d + h) / SPACING)
    SL.LayoutDots(c, n, function(t)
        local ux, uy = SL.Turn(t)
        local x, y = ux * yards, uy * yards
        local z = y * cp + d + h * sp
        if z < 0.3 then return nil end
        local sx, sy = f * x / z, f * (y * sp - h * cp) / z
        if sy > top then top = sy end
        if sy < bottom then bottom = sy end
        return sx, sy
    end)
    return top, bottom
end

-- Lays the dots out again only when the circle's size on screen changed.
local function Draw(c, yards, text)
    local db = SL.db
    local h = UIParent:GetHeight()
    if not h or h <= 0 then h = REF_HEIGHT end
    local key
    if Ground() then
        key = string.format("g%.2f;%.2f;%.1f;%.1f;%d", yards, cam.d, cam.p, db.fov, h)
    else
        key = string.format("f%.1f;%.2f;%.2f;%d", yards, db.rangeZoom, db.rangeTilt, h)
    end
    if c.key ~= key then
        c.key = key
        c.label:ClearAllPoints()
        if Ground() then
            local top, bottom = LayoutGround(c, yards, h)
            if c.below then
                c.label:SetPoint("TOP", c, "CENTER", 0, bottom - 3)
            else
                c.label:SetPoint("BOTTOM", c, "CENTER", 0, top + 3)
            end
        else
            local radius = yards * db.rangeZoom * h / REF_HEIGHT
            local tilt = db.rangeTilt
            SL.LayoutRing(c, radius, tilt, SPACING)
            if c.below then
                c.label:SetPoint("TOP", c, "CENTER", 0, -radius * tilt - 3)
            else
                c.label:SetPoint("BOTTOM", c, "CENTER", 0, radius * tilt + 3)
            end
        end
    end
    if c.text ~= text then
        c.text = text
        c.label:SetText(text)
    end
    c:Show()
end

-- Your spells' areas and ranges grow by the run's Area stat (1.25 is +25%).
local function AreaFactor()
    local s = AZS_STATS
    local a = type(s) == "table" and s.area
    if SL.db.area and type(a) == "number" and a > 0.2 and a < 10 then return a end
    return 1
end

local function PickupYards()
    local s = AZS_STATS
    local p = type(s) == "table" and s.pick
    if type(p) == "number" and p > 0 then return p end
    return nil
end

local function RawArea()
    local s = AZS_STATS
    local a = type(s) == "table" and s.area
    if type(a) == "number" and a > 0.2 and a < 10 then return a end
    return 1
end

-- ---------------------------------------------------------------- skill circles

-- A circle for each skill you pick, at the yards its own tooltip shows now, so it grows
-- with whatever grows the skill. The run's skills sit in action slots 1-6 and 12.
local SKILL_SLOTS = { 1, 2, 3, 4, 5, 6, 12 }
SL.SKILL_COLORS = {
    { 0.3, 1, 0.45 }, { 1, 0.4, 0.9 }, { 1, 1, 0.3 }, { 0.55, 0.6, 1 },
    { 1, 0.55, 0.45 }, { 0.4, 1, 1 }, { 1, 1, 1 },
}
-- Tooltip lines that give a skill's reach, best first.
local REACH = {
    { "([%d%.]+) yd radius", "radius" }, { "([%d%.]+) yd range", "range" },
    { "([%d%.]+) yd cone", "cone" }, { "within ([%d%.]+) yd", "within" },
}

SL.skills = {}       -- the run's skills with a reach: { name, slot, pos, yards, kind, icon } in slot order
local skillCircles = {} -- by the skill's slot position, so a skill keeps its color and circle
local scan
local skillsDirty = true

local function Plain(text)
    if not text then return nil end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    return (string.gsub(text, "|r", ""))
end

local function Reach(text, best)
    for i = 1, table.getn(REACH) do
        if best and i >= best.rank then return best end
        local _, _, v = string.find(text, REACH[i][1])
        v = tonumber(v)
        if v and v > 0 then return { yards = v, kind = REACH[i][2], rank = i } end
    end
    return best
end

-- Each skill's tooltip read in a hidden tooltip of our own: its name and its reach.
local function ScanSkills()
    if not scan then scan = CreateFrame("GameTooltip", "SurvivorsLiteScan", nil, "GameTooltipTemplate") end
    local out = {}
    for i = 1, table.getn(SKILL_SLOTS) do
        local slot = SKILL_SLOTS[i]
        if HasAction(slot) then
            scan:SetOwner(WorldFrame, "ANCHOR_NONE")
            scan:ClearLines()
            scan:SetAction(slot)
            local name, best
            for l = 1, scan:NumLines() or 0 do
                local left = getglobal("SurvivorsLiteScanTextLeft" .. l)
                local right = getglobal("SurvivorsLiteScanTextRight" .. l)
                local lt = Plain(left and left:GetText())
                local rt = Plain(right and right:GetText())
                if l == 1 then
                    name = lt
                elseif lt then
                    best = Reach(lt, best)
                end
                if rt then best = Reach(rt, best) end
            end
            if name and best then
                table.insert(out, { name = name, slot = slot, pos = i, yards = best.yards, kind = best.kind,
                    icon = GetActionTexture(slot) })
            end
        end
    end
    scan:Hide()
    return out
end

-- A skill's reach in the world now: its tooltip's yards as the client writes them, which
-- already hold whatever grows that skill (ranks, upgrades and, for the skills it applies
-- to, your Area stat). Not every skill grows with Area, so nothing is added on top.
function SL.SkillYards(skill)
    return skill.yards
end

local function SkillCircle(i)
    local c = skillCircles[i]
    if c then return c end
    local col = SL.SKILL_COLORS[i] or SL.SKILL_COLORS[table.getn(SL.SKILL_COLORS)]
    c = NewCircle(col[1], col[2], col[3], 0.85, 3)
    skillCircles[i] = c
    table.insert(M.circles, c)
    return c
end

local function Rescan()
    skillsDirty = false
    local found = ScanSkills()
    local changed = table.getn(found) ~= table.getn(SL.skills)
    for i = 1, table.getn(found) do
        local a, b = found[i], SL.skills[i]
        if not b or a.name ~= b.name or a.yards ~= b.yards then changed = true end
    end
    SL.skills = found
    if changed and SL.RefreshOptions then SL.RefreshOptions() end
end

function M.apply()
    local db = SL.db
    SL.Place(SL.center)
    if skillsDirty then Rescan() end
    local picked = db.skillRings or {}
    local drawn = {}
    for i = 1, table.getn(SL.skills) do
        local s = SL.skills[i]
        if picked[s.name] then
            local yd = SL.SkillYards(s)
            Draw(SkillCircle(s.pos), yd, s.name .. " " .. Yards(yd))
            drawn[s.pos] = true
        end
    end
    for pos, c in pairs(skillCircles) do
        if not drawn[pos] then c:Hide() end
    end
    local area = AreaFactor()
    if db.range then
        local yd = db.rangeYd * area
        Draw(first, yd, Yards(yd))
    else
        first:Hide()
    end
    if db.range2 then
        local yd = db.range2Yd * area
        Draw(second, yd, Yards(yd))
    else
        second:Hide()
    end
    local pick = PickupYards()
    if db.pickup and pick then
        Draw(pickup, pick, "pickup " .. Yards(pick))
    else
        pickup:Hide()
    end
    -- Radius labels while you set the circles up.
    local labels = SL.optionsOpen or not SL.locked
    local any = false
    for i = 1, table.getn(M.circles) do
        local c = M.circles[i]
        if labels then c.label:Show() else c.label:Hide() end
        if c:IsShown() then any = true end
    end
    M.anyShown = any
    if any and db.ground then SL.Wake(camTicker) end
end
SL.ApplyRange = function() SL.Run(M.apply) end

-- Skill tooltips are read again after a slot, a rank or the Area stat changed, at most
-- twice a second.
local rescanTicker = SL.Every(0.5, function()
    if skillsDirty then M.apply() end
    return false
end, false)

local function SkillsChanged()
    skillsDirty = true
    SL.Wake(rescanTicker)
end

local spellSig, areaSeen = nil, nil

-- The camera is read twice a second, and ten times a second for a while after it moved or
-- the wheel zoomed, only while a circle shows.
camTicker = SL.Every(0.1, function(now)
    if not (SL.db.ground and M.anyShown) then return false end
    if now < hotUntil or now - lastRead >= 0.5 then
        lastRead = now
        local wasLive = cam.live
        if ReadCamera() then
            hotUntil = now + 1
            if cam.live then M.apply() end
        end
        if cam.live ~= wasLive and SL.RefreshOptions then SL.RefreshOptions() end
    end
end, false)

function SL.CameraStatus()
    if not SL.db.ground then return "Ground circles are off." end
    if cam.live then
        return string.format("Camera read: %.1f yd away, looking down %.0f deg.", cam.d, cam.p)
    end
    if type(SaveView) ~= "function" then return "This client has no SaveView: circles stay flat." end
    return "Waiting for the camera: zoom or turn it once. Until then circles are flat."
end

local function HookZoom(name)
    local orig = getglobal(name)
    if type(orig) ~= "function" then return end
    setglobal(name, function(a1, a2)
        orig(a1, a2)
        hotUntil = GetTime() + 1.5
        SL.Wake(camTicker)
    end)
end

function M.init()
    SL.Movable(SL.center, "centerX", "centerY", "You")
    SL.OnAzs("AZS", function()
        local area = RawArea()
        if area ~= areaSeen then
            areaSeen = area
            SkillsChanged()
        end
        M.apply()
    end)
    -- The spell line comes with every cooldown; only a new skill or rank matters here.
    SL.OnAzs("AZSSPELLS", function()
        local sig = ""
        local spells = AZS_SPELLS
        if type(spells) == "table" then
            for i = 1, table.getn(spells) do sig = sig .. tostring(spells[i].key) .. tostring(spells[i].rank) .. ";" end
        end
        if sig ~= spellSig then
            spellSig = sig
            SkillsChanged()
        end
    end)
    SL.On("ACTIONBAR_SLOT_CHANGED", SkillsChanged)
    SL.On("PLAYER_ENTERING_WORLD", SkillsChanged)
    SL.On("DISPLAY_SIZE_CHANGED", M.apply)
    -- The mouse wheel zooms through these bindings; each turn reads the camera at once.
    HookZoom("CameraZoomIn")
    HookZoom("CameraZoomOut")
    SL.On("PLAYER_LOGOUT", RestoreView)
end
