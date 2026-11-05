-- Party frames: class colored health, level, damage per second from the run's meter,
-- down and revive state with how far away they fell. Click a row to target that hero.
--
-- The game's list of downed friends works at any distance on every map. Rows are joined to it
-- by name, as party units have nothing else in common with it.

local SL = SurvivorsLite
local M = SL.Module({})

local ROW_W, ROW_H, GAP = 176, 18, 5
local BAR_W = 140

local frame = CreateFrame("Frame", "SurvivorsLiteParty", UIParent)
frame:SetFrameStrata("LOW")
frame:SetWidth(ROW_W)
frame:SetHeight(4 * (ROW_H + GAP))
frame:Hide()

local rows = {}
local down = {}
local dps = {}
local downedByName = {}

-- Everyone in your party who is down now, with where: read by markers.lua and minimap.lua.
SL.downed = {}

for i = 1, 4 do
    local unit = "party" .. i
    local b = CreateFrame("Button", nil, frame)
    b:SetWidth(ROW_W)
    b:SetHeight(ROW_H)
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(i - 1) * (ROW_H + GAP))
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function() TargetUnit(unit) end)
    local lvl = SL.Text(b, 12, true)
    lvl:SetPoint("LEFT", b, "LEFT", 0, 0)
    lvl:SetWidth(24)
    lvl:SetJustifyH("CENTER")
    lvl:SetTextColor(1, 0.82, 0)
    local bar = SL.Bar(b, BAR_W, ROW_H - 4)
    bar:SetPoint("LEFT", b, "LEFT", 26, 0)
    local name = SL.Text(bar, 11)
    name:SetPoint("LEFT", bar, "LEFT", 3, 0)
    name:SetJustifyH("LEFT")
    local pct = SL.Text(bar, 10, true)
    pct:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    local rate = SL.Text(b, 10, true)
    rate:SetPoint("LEFT", bar, "RIGHT", 5, 0)
    rate:SetTextColor(0.8, 0.8, 0.8)
    rows[i] = { unit = unit, button = b, level = lvl, bar = bar, name = name, pct = pct, rate = rate }
end

local function UpdateRow(i)
    local r = rows[i]
    local unit = r.unit
    if not UnitExists(unit) then
        r.button:Hide()
        down[i] = nil
        return false
    end
    r.button:Show()
    local name = UnitName(unit) or "?"
    r.name:SetText(name)
    r.level:SetText(tostring(UnitLevel(unit) or ""))
    local cur, max = UnitHealth(unit) or 0, UnitHealthMax(unit) or 0
    if max <= 0 then max = 1 end
    local f = cur / max
    if f > 1 then f = 1 elseif f < 0 then f = 0 end
    local fell = downedByName[name]
    local isDown = fell or cur <= 0 or UnitIsDeadOrGhost(unit)
    if not UnitIsConnected(unit) then
        r.bar:SetValue(1)
        r.bar:SetStatusBarColor(0.3, 0.3, 0.3)
        r.pct:SetText("offline")
        r.pct:SetTextColor(0.7, 0.7, 0.7)
    elseif isDown then
        r.bar:SetValue(1)
        r.bar:SetStatusBarColor(0.35, 0.1, 0.1)
        local revive = AZS_REVIVE
        if type(revive) == "table" and revive.reviving == name and type(revive.rshare) == "number" then
            r.pct:SetText("revive " .. math.floor(revive.rshare * 100) .. "%")
            r.pct:SetTextColor(0.4, 1, 0.4)
        else
            local text = "DOWN"
            local dx, dy
            if fell then dx, dy = SL.WorldOffset(fell) end
            if dx then text = "DOWN " .. math.floor(math.sqrt(dx * dx + dy * dy) + 0.5) .. " yd" end
            r.pct:SetText(text)
            r.pct:SetTextColor(1, 0.3, 0.3)
        end
        if not down[i] then
            down[i] = true
            SL.Alert(name .. " is down!", 1, 0.3, 0.3, 4)
        end
    else
        local c = SL.UnitColor(unit)
        r.bar:SetValue(f)
        r.bar:SetStatusBarColor(c[1], c[2], c[3])
        r.pct:SetText(math.floor(f * 100 + 0.5) .. "%")
        if f < 0.35 then r.pct:SetTextColor(1, 0.35, 0.35) else r.pct:SetTextColor(1, 1, 1) end
        down[i] = nil
    end
    local d = dps[name]
    if d then r.rate:SetText(SL.Short(d)) else r.rate:SetText("") end
    return true
end

local function UpdateAll()
    local any = false
    for i = 1, 4 do
        if UpdateRow(i) then any = true end
    end
    if SL.db.party and (any or not SL.locked) then
        frame:Show()
        if any then SL.Wake(M.rangeTicker) end
    else
        frame:Hide()
    end
end

-- Reads the game's list. A list it cannot tell yet leaves the last one standing.
local function ReadDowned()
    if type(AZS_GetDownedPartyMembers) ~= "function" then return false end
    local list = AZS_GetDownedPartyMembers()
    if not list then return table.getn(SL.downed) > 0 end
    local byName = {}
    for i = 1, table.getn(list) do byName[list[i].name] = list[i] end
    local changed = table.getn(list) ~= table.getn(SL.downed)
    SL.downed, downedByName = list, byName
    if changed and SL.WakeMinimap then SL.WakeMinimap() end
    if SL.db.party then UpdateAll() end
    return table.getn(list) > 0
end

-- Four times a second while someone is down, for the yards on their row.
local downTicker = SL.Every(0.25, function()
    if not ReadDowned() then return false end
end, false)

local function UnitIndex(unit)
    if type(unit) ~= "string" then return nil end
    local _, _, n = string.find(unit, "^party(%d)$")
    return tonumber(n)
end

local function UnitChanged(unit)
    if not SL.db.party then return end
    local i = UnitIndex(unit)
    if i then UpdateRow(i) end
end

-- Out of follow range (about 28 yards) fades the row.
M.rangeTicker = SL.Every(1, function()
    if not frame:IsShown() then return false end
    for i = 1, 4 do
        local r = rows[i]
        if r.button:IsShown() then
            if CheckInteractDistance(r.unit, 4) then r.button:SetAlpha(1) else r.button:SetAlpha(0.55) end
        end
    end
end, false)

function M.init()
    SL.Movable(frame, "partyX", "partyY", "Party")
    frame.slAfterLock = UpdateAll
    SL.On("PLAYER_ENTERING_WORLD", UpdateAll)
    SL.On("PARTY_MEMBERS_CHANGED", UpdateAll)
    SL.On("UNIT_HEALTH", UnitChanged)
    SL.On("UNIT_MAXHEALTH", UnitChanged)
    SL.On("UNIT_LEVEL", UnitChanged)
    SL.OnAzs("AZSPARTY", function()
        local meter = AZS_PARTY
        local new = {}
        if type(meter) == "table" then
            for i = 1, table.getn(meter) do
                local line = meter[i]
                if line.name and type(line.dps) == "number" then new[tostring(line.name)] = line.dps end
            end
        end
        dps = new
        if SL.db.party then
            for i = 1, 4 do
                local r = rows[i]
                if r.button:IsShown() then
                    local v = dps[UnitName(r.unit) or ""]
                    if v then r.rate:SetText(SL.Short(v)) else r.rate:SetText("") end
                end
            end
        end
    end)
    SL.OnAzs("AZSREVIVE", function()
        if SL.db.party then UpdateAll() end
    end)
    SL.OnAzs("AZSDOWNED", function() SL.Wake(downTicker) end)
    SL.On("PLAYER_ENTERING_WORLD", function() SL.Wake(downTicker) end)
    SL.On("PARTY_MEMBERS_CHANGED", function() SL.Wake(downTicker) end)
end

function M.apply()
    frame:SetScale(SL.db.scale)
    SL.Place(frame)
    if not SL.db.party then M.rangeTicker.active = false end
    UpdateAll()
end
