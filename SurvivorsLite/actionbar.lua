-- A compact floating action bar made of the game's own buttons (the six run spells, the
-- racial and the character and talent buttons), with cooldown numbers on the buttons and
-- the talents' clocks over the bar. The client keeps every stock frame under its own name
-- for addons that rebuild the bars; turned off, everything goes back where it made it.

local SL = SurvivorsLite
local M = SL.Module({})

local SLOTS = { 1, 2, 3, 4, 5, 6, 12 }
local MICRO = { "CharacterMicroButton", "TalentMicroButton" }
local SIZE, GAP, SPLIT = 36, 3, 9 -- in the bar's own scale; SPLIT sets the racial apart
local CLOCK_SIZE, CLOCK_GAP = 22, 3

local holder = CreateFrame("Frame", "SurvivorsLiteBar", UIParent)
holder:SetFrameStrata("MEDIUM")
holder:SetWidth(SIZE * 9)
holder:SetHeight(SIZE)
holder:Hide()
local back = SL.Tex(holder, "BACKGROUND", 0, 0, 0, 0.35)
back:SetPoint("TOPLEFT", holder, "TOPLEFT", -4, 4)
back:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 4, -4)

local floating = false
local edges = {}   -- slot -> its 1 px dark edge on the bar
local numbers = {} -- button -> the font string over its cooldown

local function Button(slot) return getglobal("ActionButton" .. slot) end

local function Part(b, suffix) return getglobal(b:GetName() .. suffix) end

local function Float()
    local x = 0
    for i = 1, table.getn(SLOTS) do
        local slot = SLOTS[i]
        local b = Button(slot)
        if b then
            if slot == 12 then x = x + SPLIT end
            b:SetParent(holder)
            b:ClearAllPoints()
            b:SetPoint("LEFT", holder, "LEFT", x, 0)
            -- Flat look: no socket art, the icon's own edge trimmed, a thin dark frame.
            local normal = Part(b, "NormalTexture")
            if normal then normal:SetAlpha(0) end
            local icon = Part(b, "Icon")
            if icon then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
            local e = edges[slot]
            if not e then
                e = SL.Tex(holder, "BORDER", 0, 0, 0, 1)
                edges[slot] = e
            end
            e:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
            e:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
            e:Show()
            x = x + SIZE + GAP
        end
    end
    x = x + SPLIT - GAP
    for i = 1, table.getn(MICRO) do
        local m = getglobal(MICRO[i])
        if m then
            m:SetParent(holder)
            m:ClearAllPoints()
            m:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, -2)
            x = x + (m:GetWidth() or 28) - 3
        end
    end
    -- The options' gear at the end.
    if not M.gear and SL.GearButton then M.gear = SL.GearButton(holder, 18) end
    if M.gear then
        x = x + 6
        M.gear:ClearAllPoints()
        M.gear:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, 0)
        x = x + 18
    end
    holder:SetWidth(math.max(x, SIZE))
    if MainMenuBar then MainMenuBar:Hide() end
    floating = true
end

-- Back on the client's main bar, as its own layout has them.
local function Dock()
    if not floating then return end
    floating = false
    local art = MainMenuBarArtFrame
    for i = 1, table.getn(SLOTS) do
        local slot = SLOTS[i]
        local b = Button(slot)
        if b and art then
            b:SetParent(art)
            b:ClearAllPoints()
            if slot == 1 then
                b:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", 8, 4)
            elseif slot == 12 then
                b:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", 280, 4)
            else
                b:SetPoint("LEFT", Button(slot - 1), "RIGHT", 6, 0)
            end
            local normal = Part(b, "NormalTexture")
            if normal then normal:SetAlpha(1) end
            local icon = Part(b, "Icon")
            if icon then icon:SetTexCoord(0, 1, 0, 1) end
        end
        if edges[slot] then edges[slot]:Hide() end
    end
    local character, talent = getglobal(MICRO[1]), getglobal(MICRO[2])
    if art and character then
        character:SetParent(art)
        character:ClearAllPoints()
        character:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", 332, 2)
    end
    if art and talent and character then
        talent:SetParent(art)
        talent:ClearAllPoints()
        talent:SetPoint("BOTTOMLEFT", character, "BOTTOMRIGHT", -3, 0)
    end
    if MainMenuBar then MainMenuBar:Show() end
end

-- ---------------------------------------------------------------- cooldown numbers

local function Number(b)
    local fs = numbers[b]
    if fs then return fs end
    -- Its own frame over the button's cooldown sweep, which is a child frame too.
    local f = CreateFrame("Frame", nil, b)
    f:SetAllPoints(b)
    f:SetFrameLevel(b:GetFrameLevel() + 3)
    fs = SL.Text(f, 15, true)
    fs:SetPoint("CENTER", f, "CENTER", 0, 0)
    numbers[b] = fs
    return fs
end

local function SetNumber(fs, text, r, g, b)
    if fs.slText == text then return end
    fs.slText = text
    fs:SetText(text)
    if r then fs:SetTextColor(r, g, b) end
end

local cdTicker = SL.Every(0.1, function(now)
    local running = false
    local on = SL.db.cds
    for i = 1, table.getn(SLOTS) do
        local b = Button(SLOTS[i])
        if b then
            local fs = Number(b)
            local left = 0
            if on then
                local id = b:GetID()
                if ActionButton_GetPagedID then id = ActionButton_GetPagedID(b) end
                local start, duration, enabled = GetActionCooldown(id)
                -- The global cooldown gets no number.
                if (enabled == 1 or enabled == true) and start and start > 0 and duration and duration > 1.6 then
                    left = start + duration - now
                end
            end
            if left > 0 then
                running = true
                if left < 3 then
                    SetNumber(fs, SL.Clock(left), 1, 0.3, 0.3)
                else
                    SetNumber(fs, SL.Clock(left), 1, 1, 1)
                end
            else
                SetNumber(fs, "")
            end
        end
    end
    if not running then return false end
end, false)

-- ---------------------------------------------------------------- talent clocks

local clockRow = CreateFrame("Frame", "SurvivorsLiteClocks", UIParent)
clockRow:SetFrameStrata("MEDIUM")
clockRow:SetWidth(CLOCK_SIZE)
clockRow:SetHeight(CLOCK_SIZE)
local clocks = {}
local clockCount = 0
local clockTicker

local function RebuildClocks()
    clockCount = 0
    local timers = AZS_TIMERS
    if SL.db.cds and type(timers) == "table" then
        for i = 1, table.getn(timers) do
            clockCount = clockCount + 1
            local f = clocks[clockCount] or SL.NewIcon(clockRow)
            clocks[clockCount] = f
            SL.SizeIcon(f, CLOCK_SIZE)
            f.tex:SetTexture(SL.Icon(timers[i].icon))
            f.timer, f.key, f.ready = i, nil, nil
            f:ClearAllPoints()
            f:SetPoint("LEFT", clockRow, "LEFT", (clockCount - 1) * (CLOCK_SIZE + CLOCK_GAP), 0)
            f:Show()
        end
    end
    for i = clockCount + 1, table.getn(clocks) do clocks[i]:Hide() end
    -- Over the floating bar, or over the client's first button.
    clockRow:ClearAllPoints()
    local first = Button(1)
    if floating then
        clockRow:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 0, 8)
    elseif first then
        clockRow:SetPoint("BOTTOMLEFT", first, "TOPLEFT", 0, 10)
    else
        clockRow:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 90)
    end
    SL.Wake(clockTicker)
end

clockTicker = SL.Every(0.2, function()
    if clockCount == 0 then return false end
    local runNow = SL.RunTime() or 0
    local timers = AZS_TIMERS
    for i = 1, clockCount do
        local f = clocks[i]
        local t = type(timers) == "table" and timers[f.timer]
        if t and type(t.ready) == "number" then
            local waiting = SL.ShowWait(f, t.ready - runNow, t.wait or 0, 0)
            if f.ready ~= not waiting then
                f.ready = not waiting
                if waiting then
                    f.border:SetVertexColor(0, 0, 0, 1)
                else
                    f.border:SetVertexColor(1, 0.82, 0.1, 1)
                end
            end
        end
    end
    -- Talent clocks count with the run, so the ticker stays awake while any shows.
end, false)

-- ---------------------------------------------------------------- wiring

function M.init()
    SL.Movable(holder, "barX", "barY", "Action bar", "BOTTOM")
    -- Anything that shows the client's bar again while this one floats is undone.
    if MainMenuBar then
        local prev = MainMenuBar:GetScript("OnShow")
        MainMenuBar:SetScript("OnShow", function()
            if prev then prev() end
            if floating then this:Hide() end
        end)
    end
    SL.On("ACTIONBAR_UPDATE_COOLDOWN", function() SL.Wake(cdTicker) end)
    SL.On("ACTIONBAR_SLOT_CHANGED", function() SL.Wake(cdTicker) end)
    SL.On("PLAYER_ENTERING_WORLD", function()
        SL.Wake(cdTicker)
        RebuildClocks()
    end)
    SL.OnAzs("AZSTIMERS", RebuildClocks)
end

function M.apply()
    local db = SL.db
    holder:SetScale(db.barScale)
    SL.Place(holder)
    if db.bar then
        Float()
        holder:Show()
    else
        Dock()
        if SL.locked then holder:Hide() end
    end
    SL.Wake(cdTicker)
    RebuildClocks()
end
