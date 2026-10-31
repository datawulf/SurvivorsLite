-- The damage meter: your spells by damage, the party's heroes, the last boss fight or your
-- healing, from the run's own meter lines. Each row is a bar as long as its share of the
-- top row, with its icon, its damage per second and its share of the whole. The tabs at
-- the top switch between them; point at a row for its numbers.
--
-- New lines are drawn at most five times a second, and a bar glides to its new length on a
-- short ticker that sleeps once every bar has arrived.

local SL = SurvivorsLite
local M = SL.Module({})

local W, ROW_H, GAP, HEAD_H, PAD = 236, 16, 2, 20, 4
local BAR_W = W - PAD * 2 - ROW_H - 2
local BAR_TEX = SL.MEDIA .. "bar"
local GOLD = { 1, 0.82, 0 }
local CLASSES = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_COORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
    ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
    HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN = { 0, 0.25, 0.5, 0.75 },
}
-- Spells take these colors in the order they first show and keep them, so the top rows
-- differ and a spell looks the same every update.
local PALETTE = {
    { 0.90, 0.45, 0.24 }, { 0.36, 0.62, 0.95 }, { 0.62, 0.44, 0.90 }, { 0.32, 0.78, 0.50 },
    { 0.95, 0.75, 0.28 }, { 0.88, 0.36, 0.52 }, { 0.30, 0.76, 0.82 }, { 0.74, 0.60, 0.42 },
}
-- The tabs: what each shows and the word after its rate.
local MODES = {
    { key = "damage", label = "Damage", w = 50, unit = "dps", what = "Damage", empty = "No damage yet." },
    { key = "party", label = "Party", w = 38, unit = "dps", what = "Damage", empty = "Not in a party." },
    { key = "boss", label = "Boss", w = 34, unit = "dps", what = "Damage to bosses", empty = "No boss fight yet." },
    { key = "healing", label = "Heal", w = 34, unit = "hps", what = "Healing", empty = "No healing yet." },
}

local function Lines(key)
    local t
    if key == "damage" then t = AZS_METER
    elseif key == "party" then t = AZS_PARTY
    elseif key == "boss" then t = AZS_BOSSMETER
    else t = AZS_HEALING end
    if type(t) ~= "table" then return {} end
    return t
end

local function Mode()
    for i = 1, table.getn(MODES) do
        if MODES[i].key == SL.db.meterMode then return MODES[i] end
    end
    return MODES[1]
end

local colors, colorCount = {}, 0
local function SpellColor(name)
    local c = colors[name]
    if not c then
        c = PALETTE[math.mod(colorCount, table.getn(PALETTE)) + 1]
        colorCount = colorCount + 1
        colors[name] = c
    end
    return c
end

-- ---------------------------------------------------------------- the frame

local frame = CreateFrame("Frame", "SurvivorsLiteMeter", UIParent)
frame:SetFrameStrata("LOW")
frame:SetWidth(W)
frame:SetHeight(HEAD_H + PAD * 2 + ROW_H)
frame:Hide()
local back = SL.Tex(frame, "BACKGROUND", 0.03, 0.035, 0.05, 0.78)
back:SetAllPoints(frame)
local head = SL.Tex(frame, "BORDER", 0.1, 0.085, 0.04, 0.9)
head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
head:SetHeight(HEAD_H)
local rule = SL.Tex(frame, "ARTWORK", GOLD[1], GOLD[2], GOLD[3], 0.45)
rule:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
rule:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, 0)
rule:SetHeight(1)

local total = SL.Text(frame, 10, true)
total:SetPoint("RIGHT", head, "RIGHT", -PAD - 1, 0)
total:SetJustifyH("RIGHT")
total:SetTextColor(1, 1, 1)

local empty = SL.Text(frame, 10)
empty:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -HEAD_H - PAD - 2)
empty:SetTextColor(0.55, 0.55, 0.55)

local Rebuild

local tabs = {}
local function TabTip()
    if not GameTooltip then return end
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:SetText(this.slMode.label, 1, 1, 1)
    local what = this.slMode.key
    local tip = "Your damage by spell this run."
    if what == "party" then tip = "Each hero's damage this run, and their best spell."
    elseif what == "boss" then tip = "Your damage by spell to bosses, in the last boss fight."
    elseif what == "healing" then tip = "Your healing by spell this run, without overhealing." end
    GameTooltip:AddLine(tip, 1, 0.82, 0, 1)
    GameTooltip:Show()
end
local x = PAD
for i = 1, table.getn(MODES) do
    local mode = MODES[i]
    local b = CreateFrame("Button", nil, frame)
    b:SetHeight(HEAD_H)
    b.text = SL.Text(b, 10)
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(mode.label)
    b:SetWidth(mode.w)
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
    x = x + b:GetWidth()
    b.line = SL.Tex(b, "OVERLAY", GOLD[1], GOLD[2], GOLD[3], 1)
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 0)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 0)
    b.line:SetHeight(2)
    b.slMode = mode
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function()
        SL.db.meterMode = this.slMode.key
        Rebuild()
    end)
    b:SetScript("OnEnter", TabTip)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    tabs[i] = b
end

local function ShowTip()
    if not GameTooltip or not this.slName then return end
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText(this.slName, 1, 1, 1)
    for i = 1, table.getn(this.slTip) do
        local line = this.slTip[i]
        GameTooltip:AddDoubleLine(line[1], line[2], 1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:Show()
end

local rows = {}
local function NewRow(i)
    local r = CreateFrame("Frame", nil, frame)
    r:SetWidth(W - PAD * 2)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -HEAD_H - PAD - (i - 1) * (ROW_H + GAP))
    local iconBack = SL.Tex(r, "BACKGROUND", 0, 0, 0, 0.9)
    iconBack:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    iconBack:SetWidth(ROW_H)
    iconBack:SetHeight(ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetPoint("TOPLEFT", iconBack, "TOPLEFT", 1, -1)
    r.icon:SetPoint("BOTTOMRIGHT", iconBack, "BOTTOMRIGHT", -1, 1)
    r.rank = SL.Text(r, 9, true)
    r.rank:SetPoint("CENTER", iconBack, "CENTER", 0, 0)
    r.rank:SetTextColor(0.7, 0.7, 0.7)
    r.track = SL.Tex(r, "BACKGROUND", 1, 1, 1, 0.07)
    r.track:SetPoint("TOPLEFT", r, "TOPLEFT", ROW_H + 2, 0)
    r.track:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
    r.fill = r:CreateTexture(nil, "BORDER")
    r.fill:SetTexture(BAR_TEX)
    r.fill:SetPoint("TOPLEFT", r.track, "TOPLEFT", 0, 0)
    r.fill:SetPoint("BOTTOMLEFT", r.track, "BOTTOMLEFT", 0, 0)
    r.fill:SetWidth(1)
    r.name = SL.Text(r, 10)
    r.name:SetPoint("LEFT", r.track, "LEFT", 4, 0)
    r.name:SetPoint("RIGHT", r.track, "RIGHT", -70, 0)
    r.name:SetJustifyH("LEFT")
    r.value = SL.Text(r, 10, true)
    r.value:SetPoint("RIGHT", r.track, "RIGHT", -4, 0)
    r.value:SetJustifyH("RIGHT")
    r.cur, r.goal = 0, 0
    r:EnableMouse(true)
    r:SetScript("OnEnter", ShowTip)
    r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    r:Hide()
    return r
end

-- ---------------------------------------------------------------- bars that glide

local glide

local function SetFill(r, f)
    r.cur = f
    local w = math.floor(BAR_W * f + 0.5)
    if w < 1 then
        r.fill:Hide()
    else
        r.fill:SetWidth(w)
        r.fill:Show()
    end
end

glide = SL.Every(0.03, function()
    local moving = false
    for i = 1, table.getn(rows) do
        local r = rows[i]
        if r:IsShown() and r.cur ~= r.goal then
            local d = r.goal - r.cur
            if math.abs(d) < 0.004 then
                SetFill(r, r.goal)
            else
                SetFill(r, r.cur + d * 0.35)
                moving = true
            end
        end
    end
    if not moving then return false end
end, false)

-- ---------------------------------------------------------------- filling it

local function Percent(part, whole)
    if whole <= 0 then return "" end
    return string.format("%.0f%%", part / whole * 100)
end

local function Whole(v)
    v = math.floor((tonumber(v) or 0) + 0.5)
    local s = tostring(v)
    local out = ""
    while string.len(s) > 3 do
        out = "," .. string.sub(s, -3) .. out
        s = string.sub(s, 1, -4)
    end
    return s .. out
end

function Rebuild()
    local db = SL.db
    local mode = Mode()
    local lines = Lines(mode.key)
    local any = false
    for i = 1, table.getn(MODES) do
        local b = tabs[i]
        local on = MODES[i] == mode
        local has = table.getn(Lines(MODES[i].key)) > 0
        if has then any = true end
        if on then
            b.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            b.line:Show()
        elseif has then
            b.text:SetTextColor(0.8, 0.8, 0.8)
            b.line:Hide()
        else
            b.text:SetTextColor(0.42, 0.42, 0.42)
            b.line:Hide()
        end
    end
    if not db.meter or not (any or SL.RunTime() or not SL.locked) then
        frame:Hide()
        return
    end
    local count = math.min(table.getn(lines), db.meterRows)
    local top, sum, rate = 0, 0, 0
    for i = 1, table.getn(lines) do
        local d = tonumber(lines[i].dmg) or 0
        if d > top then top = d end
        sum = sum + d
        rate = rate + (tonumber(lines[i].dps) or 0)
    end
    if table.getn(lines) > 0 then
        total:SetText(SL.Short(rate) .. " " .. mode.unit)
    else
        total:SetText("")
    end
    local me = UnitName("player")
    local moving = false
    for i = 1, count do
        local line = lines[i]
        local r = rows[i] or NewRow(i)
        rows[i] = r
        local name = tostring(line.name or "?")
        local color
        if mode.key == "party" then
            color = SL.ClassColor(line.class)
            local c = CLASS_COORDS[string.upper(tostring(line.class or ""))]
            if c then
                r.icon:SetTexture(CLASSES)
                r.icon:SetTexCoord(c[1], c[2], c[3], c[4])
                r.icon:Show()
                r.rank:SetText("")
            else
                r.icon:Hide()
                r.rank:SetText(i)
            end
        else
            color = SpellColor(name)
            local icon = SL.SpellIcon and SL.SpellIcon(name)
            if icon then
                r.icon:SetTexture(icon)
                r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                r.icon:Show()
                r.rank:SetText("")
            else
                r.icon:Hide()
                r.rank:SetText(i)
            end
        end
        r.fill:SetVertexColor(color[1], color[2], color[3], 0.92)
        r.name:SetText(name)
        if mode.key == "party" and name == me then
            r.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            r.name:SetTextColor(1, 1, 1)
        end
        local dmg = tonumber(line.dmg) or 0
        r.value:SetText(SL.Short(tonumber(line.dps) or 0) .. "  " .. Percent(dmg, sum))
        local goal = 0
        if top > 0 then goal = dmg / top end
        if not r:IsShown() then
            SetFill(r, 0)
            r:Show()
        end
        r.goal = goal
        if r.cur ~= goal then moving = true end
        r.slName = name
        r.slTip = {
            { mode.what, Whole(line.dmg) },
            { "Per second", Whole(line.dps) },
            { "Share", Percent(dmg, sum) },
        }
        if mode.key == "party" and line.top and line.top ~= "" then
            table.insert(r.slTip, { "Best spell", tostring(line.top) .. ", " .. SL.Short(tonumber(line.topdps) or 0) .. " dps" })
        end
    end
    for i = count + 1, table.getn(rows) do rows[i]:Hide() end
    local shown = count
    if shown == 0 then
        empty:SetText(mode.empty)
        empty:Show()
        shown = 1
    else
        empty:Hide()
    end
    frame:SetHeight(HEAD_H + PAD * 2 + shown * ROW_H + (shown - 1) * GAP)
    frame:Show()
    if moving then SL.Wake(glide) end
end

local dirty = false
local ticker = SL.Every(0.2, function()
    if dirty then
        dirty = false
        Rebuild()
    end
    return false
end, false)

local function Changed()
    if not SL.db.meter then return end
    dirty = true
    SL.Wake(ticker)
end

function M.init()
    SL.Movable(frame, "meterX", "meterY", "Meter")
    frame.slAfterLock = Rebuild
    SL.OnAzs("AZSMETER", Changed)
    SL.OnAzs("AZSPARTY", Changed)
    SL.OnAzs("AZSBOSSDMG", Changed)
    SL.OnAzs("AZSHEAL", Changed)
    SL.OnAzs("AZSZONE", Changed)
    SL.On("PLAYER_ENTERING_WORLD", Changed)
end

function M.apply()
    frame:SetScale(SL.db.scale)
    SL.Place(frame)
    Rebuild()
end
