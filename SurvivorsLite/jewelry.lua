-- The jewelry you picked this run (amulet, two rings, two trinkets) as a row of small icons
-- under the floating action bar: its quality on the edge, its cooldown as a shade and a
-- number, and its own tooltip under the mouse. The run puts every pick into these slots.

local SL = SurvivorsLite
local M = SL.Module({})

local SLOT_NAMES = { "NeckSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
local SIZE, GAP = 24, 3
-- Item quality colors, as the client's ITEM_QUALITY_COLORS has them.
local QUALITY = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 },
}

local row = CreateFrame("Frame", "SurvivorsLiteJewelry", UIParent)
row:SetFrameStrata("MEDIUM")
row:SetWidth(SIZE)
row:SetHeight(SIZE)
row:Hide()

local slotIds -- inventory slot ids, resolved once the client answers
local icons = {}
local shown = 0
local ticker

local function ResolveSlots()
    if slotIds then return true end
    if not GetInventorySlotInfo then return false end
    local ids = {}
    for i = 1, table.getn(SLOT_NAMES) do
        local id = GetInventorySlotInfo(SLOT_NAMES[i])
        if type(id) ~= "number" then return false end
        ids[i] = id
    end
    slotIds = ids
    return true
end

local function NewSlot()
    local f = SL.NewIcon(row)
    SL.SizeIcon(f, SIZE)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function()
        if not GameTooltip or not this.slotId then return end
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetInventoryItem("player", this.slotId)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return f
end

-- Under the floating bar, or over the client's own bar and the talents' clocks.
local function Anchor()
    row:ClearAllPoints()
    local bar = getglobal("SurvivorsLiteBar")
    local clocks = getglobal("SurvivorsLiteClocks")
    if SL.db.bar and bar then
        row:SetScale(SL.db.barScale)
        row:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -7)
    elseif clocks then
        row:SetScale(1)
        row:SetPoint("BOTTOMLEFT", clocks, "TOPLEFT", 0, 6)
    else
        row:SetScale(1)
        row:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
    end
end

local function Rebuild()
    shown = 0
    if SL.db.jewelry and ResolveSlots() then
        for i = 1, table.getn(slotIds) do
            local id = slotIds[i]
            local texture = GetInventoryItemTexture("player", id)
            if texture then
                shown = shown + 1
                local f = icons[shown] or NewSlot()
                icons[shown] = f
                f.slotId = id
                f.tex:SetTexture(texture)
                local q = GetInventoryItemQuality and GetInventoryItemQuality("player", id)
                local c = QUALITY[q or 1] or QUALITY[1]
                f.border:SetVertexColor(c[1], c[2], c[3], 1)
                f:ClearAllPoints()
                f:SetPoint("LEFT", row, "LEFT", (shown - 1) * (SIZE + GAP), 0)
                f:Show()
            end
        end
    end
    for i = shown + 1, table.getn(icons) do icons[i]:Hide() end
    if shown > 0 then
        row:SetWidth(shown * (SIZE + GAP) - GAP)
        row:Show()
        SL.Wake(ticker)
    else
        row:Hide()
    end
end

-- Cooldowns: a shade from the top and seconds left, while any piece is cooling down.
ticker = SL.Every(0.2, function(now)
    if shown == 0 then return false end
    local running = false
    for i = 1, shown do
        local f = icons[i]
        local start, duration, enabled = 0, 0, 0
        if GetInventoryItemCooldown then start, duration, enabled = GetInventoryItemCooldown("player", f.slotId) end
        local left = 0
        if (enabled == 1 or enabled == true) and start and start > 0 and duration and duration > 1.6 then
            left = start + duration - now
        end
        if SL.ShowWait(f, left, duration or 0, 0) then running = true end
    end
    if not running then return false end
end, false)

function M.init()
    SL.On("UNIT_INVENTORY_CHANGED", function(unit)
        if unit == "player" then Rebuild() end
    end)
    SL.On("PLAYER_ENTERING_WORLD", Rebuild)
    SL.On("BAG_UPDATE_COOLDOWN", function() SL.Wake(ticker) end)
end

function M.apply()
    Anchor()
    Rebuild()
end
