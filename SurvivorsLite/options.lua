-- The options window: every setting as a check box or slider, changed live. Opens with
-- /slite, the gear buttons (minimap and action bar) and the game menu (Esc), closes with Esc.
-- It is built the first time it opens, under the error guard, and runs no code while closed.

local SL = SurvivorsLite
local M = SL.Module({})

local W, H = 714, 592
local CHECK_UP = "Interface\\Buttons\\UI-CheckBox-Up"
local CHECK_MARK = "Interface\\Buttons\\UI-CheckBox-Check"
local THUMB = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal"
SL.GEAR = "Interface\\Icons\\INV_Misc_Gear_01"
local GOLD = { 1, 0.82, 0 }
local ACCENT = { 0.25, 0.55, 1 }
local COL_W = 206

local panel = CreateFrame("Frame", "SurvivorsLiteOptions", UIParent)
panel:SetFrameStrata("DIALOG")
panel:SetWidth(W)
panel:SetHeight(H)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
panel:EnableMouse(true)
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
panel:Hide()
if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "SurvivorsLiteOptions") end

local widgets = {}
local built = false
local reset

local function Label(parent, size, numeric)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    SL.Font(fs, size, "", numeric)
    return fs
end

local function Edge(f, r, g, b, a)
    local top = SL.Tex(f, "BORDER", r, g, b, a)
    top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    top:SetHeight(1)
    local bottom = SL.Tex(f, "BORDER", r, g, b, a)
    bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)
    local left = SL.Tex(f, "BORDER", r, g, b, a)
    left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)
    local right = SL.Tex(f, "BORDER", r, g, b, a)
    right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
end

local function ShowTip(owner, head, text)
    if not GameTooltip or not text then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(head or "", 1, 1, 1)
    GameTooltip:AddLine(text, GOLD[1], GOLD[2], GOLD[3], 1)
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then GameTooltip:Hide() end
end
SL.ShowTip, SL.HideTip = ShowTip, HideTip

-- ---------------------------------------------------------------- widgets

local function NewButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp")
    return b
end

local function Button(parent, width, text, tip, onClick)
    local b = NewButton(parent)
    b:SetWidth(width)
    b:SetHeight(22)
    local bg = SL.Tex(b, "BACKGROUND", 0.1, 0.14, 0.22, 1)
    bg:SetAllPoints(b)
    Edge(b, ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
    local fs = Label(b, 11)
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    fs:SetText(text)
    b:SetScript("OnEnter", function()
        bg:SetVertexColor(0.18, 0.28, 0.44, 1)
        ShowTip(this, fs:GetText(), tip)
    end)
    b:SetScript("OnLeave", function()
        bg:SetVertexColor(0.1, 0.14, 0.22, 1)
        HideTip()
    end)
    b:SetScript("OnClick", onClick)
    b.label = fs
    return b
end

-- A small icon button with the gear, for the minimap and the action bar.
function SL.GearButton(parent, size)
    local b = NewButton(parent)
    b:SetWidth(size)
    b:SetHeight(size)
    local border = SL.Tex(b, "BACKGROUND", 0, 0, 0, 1)
    border:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(SL.GEAR)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetAllPoints(b)
    b:SetScript("OnEnter", function() ShowTip(this, "SurvivorsLite", "Click for the options. /slite does the same.") end)
    b:SetScript("OnLeave", HideTip)
    b:SetScript("OnClick", function() SL.ToggleOptions() end)
    return b
end

-- Columns fill top down; each widget moves the column's cursor.
local function Column(x) return { x = x, y = -44 } end

local function Header(col, text)
    if col.y < -44 then col.y = col.y - 8 end
    local fs = Label(panel, 12)
    fs:SetPoint("TOPLEFT", panel, "TOPLEFT", col.x, col.y)
    fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    fs:SetText(text)
    local line = SL.Tex(panel, "ARTWORK", GOLD[1], GOLD[2], GOLD[3], 0.25)
    line:SetWidth(COL_W)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", panel, "TOPLEFT", col.x, col.y - 15)
    col.y = col.y - 20
end

local function Check(col, text, tip, get, set)
    local b = NewButton(panel)
    b:SetWidth(COL_W)
    b:SetHeight(20)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", col.x, col.y)
    local hover = SL.Tex(b, "BACKGROUND", 1, 1, 1, 0.06)
    hover:SetAllPoints(b)
    hover:Hide()
    local box = b:CreateTexture(nil, "ARTWORK")
    box:SetTexture(CHECK_UP)
    box:SetWidth(22)
    box:SetHeight(22)
    box:SetPoint("LEFT", b, "LEFT", -3, 0)
    local mark = b:CreateTexture(nil, "OVERLAY")
    mark:SetTexture(CHECK_MARK)
    mark:SetAllPoints(box)
    local fs = Label(b, 11)
    fs:SetPoint("LEFT", box, "RIGHT", 1, 0)
    fs:SetText(text)
    b.Refresh = function()
        if get() then mark:Show() else mark:Hide() end
    end
    b:SetScript("OnEnter", function()
        hover:Show()
        ShowTip(this, text, tip)
    end)
    b:SetScript("OnLeave", function()
        hover:Hide()
        HideTip()
    end)
    b:SetScript("OnClick", function()
        set(not get())
        this.Refresh()
    end)
    table.insert(widgets, b)
    col.y = col.y - 20
    return b
end

-- A button that steps through a few choices.
local function Cycle(col, tip, order, texts, get, set)
    local b = Button(panel, 170, "", tip, function()
        local cur = get()
        local nextValue = order[1]
        for i = 1, table.getn(order) do
            if order[i] == cur and order[i + 1] then nextValue = order[i + 1] end
        end
        set(nextValue)
    end)
    b:SetHeight(18)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", col.x + 2, col.y - 1)
    b.Refresh = function() b.label:SetText(texts[get()] or "?") end
    table.insert(widgets, b)
    col.y = col.y - 22
    return b
end

local function Slider(col, text, tip, minv, maxv, step, fmt, get, set)
    local f = CreateFrame("Frame", nil, panel)
    f:SetWidth(COL_W - 6)
    f:SetHeight(32)
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", col.x + 3, col.y - 2)
    local name = Label(f, 11)
    name:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    name:SetText(text)
    local value = Label(f, 11, true)
    value:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    value:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetWidth(COL_W - 6)
    s:SetHeight(16)
    s:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -14)
    local track = SL.Tex(s, "BACKGROUND", 0, 0, 0, 0.85)
    track:SetHeight(6)
    track:SetPoint("LEFT", s, "LEFT", 0, 0)
    track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
    s:SetThumbTexture(THUMB)
    local thumb = s:GetThumbTexture()
    if thumb then
        thumb:SetWidth(32)
        thumb:SetHeight(32)
    end
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(step)
    s:EnableMouse(true)
    s:EnableMouseWheel(true)
    local function Snap(v)
        v = minv + math.floor((v - minv) / step + 0.5) * step
        if v < minv then v = minv elseif v > maxv then v = maxv end
        return tonumber(string.format("%.2f", v))
    end
    s:SetScript("OnValueChanged", function()
        if f.syncing then return end
        local v = Snap(this:GetValue())
        if v ~= get() then set(v) end
        value:SetText(fmt(v))
    end)
    s:SetScript("OnMouseWheel", function()
        this:SetValue(Snap(this:GetValue() + (arg1 or 0) * step))
    end)
    s:SetScript("OnEnter", function() ShowTip(this, text, tip) end)
    s:SetScript("OnLeave", HideTip)
    f.Refresh = function()
        f.syncing = true
        s:SetValue(get())
        f.syncing = false
        value:SetText(fmt(get()))
    end
    f.slider = s
    table.insert(widgets, f)
    col.y = col.y - 38
    return f
end

-- A setting that changes the whole HUD, and one that only moves the circles.
local function Toggle(key)
    return function() return SL.db[key] end, function(v)
        SL.db[key] = v
        SL.ApplyAll()
    end
end

local function RangeSetting(key)
    return function() return SL.db[key] end, function(v)
        SL.db[key] = v
        SL.ApplyRange()
    end
end

local function YardsText(v) return v .. " yd" end
local function PctText(v) return math.floor(v * 100 + 0.5) .. "%" end
local function ZoomText(v) return string.format("%.1f", v) end
local function LeashText(v)
    local radius, confirmed = SL.LeashRadius()
    if confirmed then return math.floor(radius + 0.5) .. " yd, learned" end
    if radius > v then return math.floor(radius + 0.5) .. " yd, held at" end
    return v .. " yd"
end

-- ---------------------------------------------------------------- skill circles

local SKILL_ROWS = 7
local KIND_TIP = {
    radius = "its radius around you",
    range = "how far from you it picks targets",
    cone = "the length of its cone",
    within = "how far from you it picks targets",
}

local function ShortYards(v)
    if math.abs(v - math.floor(v + 0.5)) < 0.05 then return math.floor(v + 0.5) .. " yd" end
    return string.format("%.1f yd", v)
end

local function SkillRow(col, i)
    local b = NewButton(panel)
    b:SetWidth(COL_W)
    b:SetHeight(18)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", col.x, col.y)
    local hover = SL.Tex(b, "BACKGROUND", 1, 1, 1, 0.06)
    hover:SetAllPoints(b)
    hover:Hide()
    local box = b:CreateTexture(nil, "ARTWORK")
    box:SetTexture(CHECK_UP)
    box:SetWidth(20)
    box:SetHeight(20)
    box:SetPoint("LEFT", b, "LEFT", -3, 0)
    local mark = b:CreateTexture(nil, "OVERLAY")
    mark:SetTexture(CHECK_MARK)
    mark:SetAllPoints(box)
    local swatch = SL.Tex(b, "ARTWORK", 1, 1, 1, 1)
    swatch:SetWidth(8)
    swatch:SetHeight(8)
    swatch:SetPoint("LEFT", box, "RIGHT", 1, 0)
    local fs = Label(b, 11)
    fs:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
    local yd = Label(b, 11, true)
    yd:SetPoint("RIGHT", b, "RIGHT", -2, 0)
    yd:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    b.Refresh = function()
        local s = SL.skills[i]
        if not s then
            b:Hide()
            return
        end
        fs:SetText(s.name)
        yd:SetText(ShortYards(SL.SkillYards(s)))
        local c = SL.SKILL_COLORS[s.pos] or SL.SKILL_COLORS[1]
        swatch:SetVertexColor(c[1], c[2], c[3], 1)
        local picked = SL.db.skillRings
        if picked and picked[s.name] then mark:Show() else mark:Hide() end
        b:Show()
    end
    b:SetScript("OnEnter", function()
        hover:Show()
        local s = SL.skills[i]
        if s then
            ShowTip(this, s.name, "A circle at " .. (KIND_TIP[s.kind] or "its reach") .. ", read from its tooltip, so it grows with whatever grows this skill. Remembered by name for later runs.")
        end
    end)
    b:SetScript("OnLeave", function()
        hover:Hide()
        HideTip()
    end)
    b:SetScript("OnClick", function()
        local s = SL.skills[i]
        if not s then return end
        local picked = SL.db.skillRings or {}
        SL.db.skillRings = picked
        if picked[s.name] then picked[s.name] = nil else picked[s.name] = true end
        SL.ApplyRange()
        this.Refresh()
    end)
    table.insert(widgets, b)
    col.y = col.y - 18
end

-- Where no skill has a reach yet: a line saying when they come.
local function SkillsHint(col)
    local f = CreateFrame("Frame", nil, panel)
    f:SetWidth(COL_W)
    f:SetHeight(14)
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", col.x, col.y + 18 * SKILL_ROWS)
    local fs = Label(f, 10)
    fs:SetPoint("LEFT", f, "LEFT", 0, 0)
    fs:SetTextColor(0.6, 0.6, 0.6)
    fs:SetText("Your skills show here during a run.")
    f.Refresh = function()
        if table.getn(SL.skills) == 0 then f:Show() else f:Hide() end
    end
    table.insert(widgets, f)
end

-- What the ground circles read from the camera, kept up to date while the window is open.
local function CameraStatus(col)
    local f = CreateFrame("Frame", nil, panel)
    f:SetWidth(COL_W)
    f:SetHeight(24)
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", col.x, col.y - 2)
    local fs = Label(f, 10)
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    fs:SetWidth(COL_W)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.7, 0.7, 0.7)
    f.Refresh = function()
        if SL.CameraStatus then fs:SetText(SL.CameraStatus()) end
    end
    table.insert(widgets, f)
    col.y = col.y - 28
end

local CALIBRATE = "How big a yard is on your screen, which the game does not tell addons. "
    .. "Zoom out the way you play, turn on Pickup radius and change this until experience starts "
    .. "flying to you as it touches the gold circle. Change it again after zooming."

-- ---------------------------------------------------------------- the window

local function Build()
    built = true
    local back = SL.Tex(panel, "BACKGROUND", 0.04, 0.05, 0.08, 0.94)
    back:SetAllPoints(panel)
    Edge(panel, ACCENT[1], ACCENT[2], ACCENT[3], 0.7)

    local title = Label(panel, 15)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -14)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    title:SetText("SurvivorsLite")
    local version = Label(panel, 10, true)
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
    version:SetTextColor(0.6, 0.6, 0.6)
    version:SetText("v" .. SL.version .. "  /slite")

    local get, set

    -- Left: you, your group, sizes.
    local left = Column(18)
    Header(left, "Your character")
    get, set = Toggle("hero")
    Check(left, "Hero bar", "Health, level, experience, lives and your auras under your character.", get, set)
    get, set = Toggle("buffs")
    Cycle(left, "Timed only skips the permanent talent auras. Click to switch.",
        { "timed", "all", "off" }, { timed = "Buffs: timed only", all = "Buffs: all", off = "Buffs: off" }, get, set)
    get, set = Toggle("shield")
    Check(left, "Shield on the health bar", "Your absorb shield as a pale segment after your health, a bright tick when it passes your maximum, and its amount after your health.", get, set)
    get, set = Toggle("uptime")
    Check(left, "Buff uptime", "How much of this run each timed buff was up, under its icon. Buffs that ran out stay dimmed.", get, set)
    get, set = Toggle("ring")
    Check(left, "Ring around you", "A class colored ring that marks you under tree tops.", get, set)
    get, set = Toggle("lowhp")
    Check(left, "Low health edge", "A red pulsing screen edge under 35% health.", get, set)
    get, set = Toggle("alerts")
    Check(left, "Warnings", "The next boss in its last 10 seconds and allies going down, over your character.", get, set)

    Header(left, "Group")
    get, set = Toggle("party")
    Check(left, "Party frames", "Health, level, damage per second and revive state. Click a row to target.", get, set)
    get, set = Toggle("allies")
    Check(left, "Ally plates and arrows", "Class colored plates and an arrow over each party member.", get, set)

    Header(left, "Action bar")
    get, set = Toggle("bar")
    Check(left, "Floating action bar", "Your spells, racial and the character and talent buttons on a compact bar you can move.", get, set)
    get, set = Toggle("barScale")
    Slider(left, "Bar size", "Size of the floating action bar.", 0.5, 1.5, 0.05, PctText, get, set)
    get, set = Toggle("cds")
    Check(left, "Cooldown numbers", "Seconds left on each spell's button, and the talents' clocks over the bar.", get, set)

    Header(left, "Layout")
    get, set = Toggle("scale")
    Slider(left, "HUD size", "Size of the hero bar, party frames and status list.", 0.6, 2, 0.05, PctText, get, set)

    -- Middle: enemies and the minimap.
    local mid = Column(254)
    Header(mid, "Enemies")
    get, set = Toggle("plates")
    Check(mid, "Boss and guardian plates", "Bars with health, absolute and in percent, for the final boss, bosses and guardians.", get, set)
    get, set = Toggle("mobs")
    Cycle(mid, "Small bars show only each plain enemy's health. Click to switch.",
        { "bars", "hide", "show" }, { bars = "Plain enemies: small bars", hide = "Plain enemies: hidden", show = "Plain enemies: game plates" }, get, set)
    get, set = Toggle("elites")
    Check(mid, "Mark elites", "Small marked bars for elites. Off, they are plain enemies.", get, set)
    get, set = Toggle("debuffs")
    Check(mid, "Debuffs on boss plates", "Your debuffs on bosses and guardians under their bar, with stacks and time left.", get, set)
    get, set = Toggle("autoplates")
    Check(mid, "Turn plates on by itself", "Turns the game's enemy name plates on; the boss plates need them.", get, set)
    get, set = Toggle("threats")
    Check(mid, "Boss status list", "Bosses alive, each guardian asleep, awake or when it comes back, and the next boss.", get, set)

    Header(mid, "Minimap")
    get, set = Toggle("lairs")
    Check(mid, "Guardian lairs", "Every lair: gold asleep, red awake, grey while it refills. Off the map edge it points the way.", get, set)
    get, set = Toggle("chests")
    Check(mid, "Chests", "The run's chests on the minimap.", get, set)
    get, set = Toggle("leashring")
    Check(mid, "Leash rings", "A ring around each held lair at the guardians' leash radius.", get, set)
    get, set = Toggle("leashbar")
    Check(mid, "Leash bar over you", "While a guardian chases you: how far you led it from its lair against its leash, and a warning before it gives up and goes home.", get, set)
    get, set = Toggle("mapbutton")
    Check(mid, "Gear on the minimap", "A button on the minimap's edge that opens this window.", get, set)
    Slider(mid, "Guardian leash", "How far from its lair you can lead a guardian before it gives up and goes home. Learned in play, from how far one kept chasing and where one gave up; moving this forgets that.",
        10, 150, 1, LeashText,
        function() return SL.db.leash end,
        function(v)
            SL.db.leash = v
            SL.ForgetLeash()
            SL.ApplyAll()
        end)

    -- Right: the range circles.
    local right = Column(490)
    Header(right, "Range circles")
    get, set = RangeSetting("range")
    Check(right, "Range circle", "A blue circle around you at a radius you pick.", get, set)
    get, set = RangeSetting("rangeYd")
    Slider(right, "Radius", "The circle's radius in yards, before your Area stat.", 1, 60, 1, YardsText, get, set)
    get, set = RangeSetting("area")
    Check(right, "Grow with your Area stat", "Multiplies that radius by the run's Area stat, as it does for your spells.", get, set)

    Header(right, "Skill circles")
    for i = 1, SKILL_ROWS do SkillRow(right, i) end
    SkillsHint(right)

    get, set = RangeSetting("pickup")
    Check(right, "Pickup radius", "A gold circle at the distance experience and gold fly to you from. Shows in a run.", get, set)

    Header(right, "Camera")
    get, set = RangeSetting("ground")
    Check(right, "Circles on the ground", "Reads the camera's distance and angle (through saved view 5, put back at logout) and lays the circles on the ground around your feet in perspective, at any zoom.", get, set)
    get, set = RangeSetting("fov")
    Slider(right, "Field of view", "The camera's vertical field of view for ground circles. Match it once with Pickup radius: experience should start flying as it touches the gold circle.",
        30, 100, 1, function(v) return v .. " deg" end, get, set)
    CameraStatus(right)
    get, set = RangeSetting("rangeZoom")
    Slider(right, "Size per yard (flat circles)", CALIBRATE, 5, 60, 0.5, ZoomText, get, set)
    get, set = RangeSetting("rangeTilt")
    Slider(right, "Height (flat circles)", "100% for a camera straight overhead, less when it looks in from the side. Only for flat circles.",
        0.3, 1, 0.05, PctText, get, set)

    -- Bottom row.
    local move = Button(panel, 120, "Move frames", "Drag the hero bar, action bar, party frames, status list and the circles' center (You).", function()
        SL.SetLocked(not SL.locked)
        SL.ApplyAll()
    end)
    move:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 14)
    move.Refresh = function()
        if SL.locked then move.label:SetText("Move frames") else move.label:SetText("Lock frames") end
    end
    table.insert(widgets, move)

    reset = Button(panel, 120, "Reset", "Default settings and positions. Asks once more.", function()
        if not this.armed then
            this.armed = true
            this.label:SetText("Click to confirm")
            return
        end
        this.armed = nil
        this.label:SetText("Reset")
        SL.Reset()
    end)
    reset:SetPoint("LEFT", move, "RIGHT", 8, 0)

    local hint = Label(panel, 10)
    hint:SetPoint("BOTTOM", panel, "BOTTOM", 0, 20)
    hint:SetTextColor(0.6, 0.6, 0.6)
    hint:SetText("Point at a setting for what it does.")

    local close = Button(panel, 120, "Close", nil, function() panel:Hide() end)
    close:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -18, 14)
end

-- ---------------------------------------------------------------- opening

local function RefreshAll()
    for i = 1, table.getn(widgets) do widgets[i].Refresh() end
end

panel:SetScript("OnShow", function()
    SL.optionsOpen = true
    SL.Run(RefreshAll)
    SL.ApplyRange()
end)
panel:SetScript("OnHide", function()
    SL.optionsOpen = nil
    if reset then
        reset.armed = nil
        reset.label:SetText("Reset")
    end
    HideTip()
    SL.ApplyRange()
end)

function SL.RefreshOptions()
    if panel:IsShown() then RefreshAll() end
end

function SL.ShowOptions()
    if not built then SL.Run(Build) end
    panel:Show()
end

function SL.ToggleOptions()
    if panel:IsShown() then panel:Hide() else SL.ShowOptions() end
end

-- A rung in the game menu, put in above Key Bindings the way the client expects addons to.
local function AddMenuButton()
    if not (GameMenuFrame and GameMenuButtonUIOptions and GameMenuButtonKeybindings) then return end
    -- Built before any stock rung moves, so a client without the template keeps its menu.
    local ok, b = pcall(function()
        local made = CreateFrame("Button", "GameMenuButtonSurvivorsLite", GameMenuFrame, "GameMenuButtonTemplate")
        made:SetText("SurvivorsLite")
        return made
    end)
    if not ok or not b then return end
    b:SetPoint("TOP", GameMenuButtonUIOptions, "BOTTOM", 0, -1)
    GameMenuButtonKeybindings:ClearAllPoints()
    GameMenuButtonKeybindings:SetPoint("TOP", b, "BOTTOM", 0, -1)
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + b:GetHeight() + 1)
    b:SetScript("OnClick", function()
        if HideUIPanel then HideUIPanel(GameMenuFrame) else GameMenuFrame:Hide() end
        SL.ShowOptions()
    end)
end

-- The gear on the minimap's edge, down and to the left.
local mapButton
local function MapButton()
    if mapButton or not Minimap then return mapButton end
    mapButton = SL.GearButton(Minimap, 18)
    mapButton:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    local x, y = SL.Turn(0.625)
    local r = (Minimap:GetWidth() or 140) / 2 + 6
    mapButton:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
    return mapButton
end

local greeted = false

function M.init()
    AddMenuButton()
    SL.On("PLAYER_ENTERING_WORLD", function()
        if greeted then return end
        greeted = true
        SL.Say("v" .. SL.version .. ": /slite or a gear button opens the options.")
    end)
end

function M.apply()
    local b = MapButton()
    if b then
        if SL.db.mapbutton then b:Show() else b:Hide() end
    end
    if panel:IsShown() then RefreshAll() end
end
