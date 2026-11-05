-- Range circles around your character: one or two radii you pick in yards, grown by your
-- Area stat, your pickup radius and your skills' reach. While the game can project the ground
-- around your feet (world.lua) they lie on it; otherwise they are flat on the screen around
-- the spot marked as your character, sized by a yards to screen factor you match to your zoom
-- once. Each circle is a ring of small dots: the line stays sharp at any size, and the dots
-- only move when a radius, the view or the screen changes.

local SL = SurvivorsLite
local M = SL.Module({})

local REF_HEIGHT = 768 -- rangeZoom counts screen units per yard on a 768 unit tall screen
local SPACING = 8

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

-- ---------------------------------------------------------------- laying the dots out

-- A circle of `yards` around your feet, each dot where the game puts that spot of ground.
local function LayoutGround(c, yards)
    local top, bottom = -10000, 10000
    local n = math.floor(2 * math.pi * yards * SL.GroundPerYard() / SPACING)
    SL.LayoutDots(c, n, function(t)
        local ux, uy = SL.Turn(t)
        local x, y = SL.GroundPoint(ux * yards, uy * yards)
        if not x or math.abs(x) > 4000 or math.abs(y) > 4000 then return nil end
        if y > top then top = y end
        if y < bottom then bottom = y end
        return x, y
    end)
    return top, bottom
end

-- Lays the dots out again only when the circle's size on screen changed.
local function Layout(c)
    local db = SL.db
    local yards = c.yards
    local h = UIParent:GetHeight()
    if not h or h <= 0 then h = REF_HEIGHT end
    local key
    if SL.GroundReady() then
        key = string.format("g%.2f;%d", yards, SL.groundVersion)
    else
        key = string.format("f%.1f;%.2f;%.2f;%d", yards, db.rangeZoom, db.rangeTilt, h)
    end
    if c.key == key then return end
    c.key = key
    c.label:ClearAllPoints()
    if SL.GroundReady() then
        local top, bottom = LayoutGround(c, yards)
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

local function Draw(c, yards, text)
    c.yards = yards
    Layout(c)
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

-- A skill's reach in the world now. The tooltip shows an area's base yards (with ranks and
-- upgrades) and the run's Area stat grows the area on top, so a radius or cone circle takes
-- Area; a targeting reach ("12 yd range", "within 30 yd") does not grow with it. A skill
-- whose tooltip once moved with Area at the same rank holds Area already (db.tipArea).
local AREA_KINDS = { radius = true, cone = true }

function SL.SkillYards(skill)
    local tip = SL.db.tipArea
    if AREA_KINDS[skill.kind] and not (tip and tip[skill.name]) then
        return skill.yards * AreaFactor()
    end
    return skill.yards
end

-- Each skill's yards and the Area they were read at, to notice a tooltip that follows Area.
local skillReads = {}

local function LearnTipArea(found)
    local area = RawArea()
    for i = 1, table.getn(found) do
        local s = found[i]
        local prev = skillReads[s.name]
        if prev and AREA_KINDS[s.kind] and math.abs(area - prev.area) > 0.02 and s.yards ~= prev.yards then
            local expected = prev.yards * area / prev.area
            if math.abs(s.yards - expected) <= expected * 0.05 then
                SL.db.tipArea = SL.db.tipArea or {}
                if not SL.db.tipArea[s.name] then
                    SL.db.tipArea[s.name] = true
                    SL.Say(s.name .. "'s tooltip already counts your Area; its circle uses it as shown.")
                end
            end
        end
        skillReads[s.name] = { yards = s.yards, area = area }
    end
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
    LearnTipArea(found)
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
    if not SL.projected then SL.Place(SL.center) end
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
    SL.NeedGround(any)
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
    -- The view changed: every circle showing lies on the ground anew.
    SL.OnGroundChanged(function()
        for i = 1, table.getn(M.circles) do
            local c = M.circles[i]
            if c:IsShown() then Layout(c) end
        end
    end)
end
