-- The bosses' and guardians' status, one short line each: bosses alive with their health,
-- every guardian's lair (asleep, awake with how far you are from it against its leash, or
-- when it refills) and the next boss. The health bars themselves are on the plates of the
-- ones near you; a line whose unit has its plate up is bright, the rest dim.

local SL = SurvivorsLite
local M = SL.Module({})

local MAX_ROWS = 9
local ROW_W, ROW_H = 200, 14
local COLOR = {
    final = { 1, 0.3, 1 }, boss = { 1, 0.45, 0.15 }, guardian = { 1, 0.82, 0.1 },
    next = { 0.75, 0.75, 0.75 }, empty = { 0.6, 0.6, 0.6 },
}
local ICON = { final = "skull", boss = "skull", guardian = "star", next = "skull", empty = "star" }

local frame = CreateFrame("Frame", "SurvivorsLiteThreats", UIParent)
frame:SetFrameStrata("LOW")
frame:SetWidth(ROW_W)
frame:SetHeight(MAX_ROWS * ROW_H)
frame:Hide()

local rows = {}
for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, frame)
    r:SetWidth(ROW_W)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(i - 1) * ROW_H)
    local icon = r:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(SL.RAIDICONS)
    icon:SetWidth(12)
    icon:SetHeight(12)
    icon:SetPoint("LEFT", r, "LEFT", 0, 0)
    local name = SL.Text(r, 10)
    name:SetPoint("LEFT", icon, "RIGHT", 3, 0)
    name:SetJustifyH("LEFT")
    local status = SL.Text(r, 10, true)
    status:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    status:SetJustifyH("RIGHT")
    r.icon, r.name, r.status = icon, name, status
    r:Hide()
    rows[i] = r
end

local MinSec = SL.MinSec

local function Pct(u)
    if type(u.hp) == "number" and type(u.hpm) == "number" and u.hpm > 0 then
        return math.floor(u.hp / u.hpm * 100 + 0.5) .. "%"
    end
    return ""
end

local count = 0
local counting = false

-- A line; `look` is a lair's own icon and color, as on its minimap pin.
local function Line(kind, name, status, sr, sg, sb, look)
    if count >= MAX_ROWS then return end
    count = count + 1
    local r = rows[count]
    local col = COLOR[kind]
    if look then
        SL.SetMark(r.icon, look.icon)
        col = look.color
        if kind ~= "empty" then
            r.icon:SetVertexColor(1, 1, 1, 1)
            r.name:SetTextColor(col[1], col[2], col[3])
        else
            r.icon:SetVertexColor(0.45, 0.45, 0.45, 1)
            r.name:SetTextColor(col[1] * 0.7, col[2] * 0.7, col[3] * 0.7)
        end
    else
        SL.SetMark(r.icon, ICON[kind])
        r.icon:SetVertexColor(col[1], col[2], col[3], 1)
        r.name:SetTextColor(col[1], col[2], col[3])
    end
    r.name:SetText(name)
    r.status:SetText(status)
    r.status:SetTextColor(sr or 1, sg or 1, sb or 1)
    -- Bright when its plate is up near you.
    if SL.nearby[name] then r:SetAlpha(1) else r:SetAlpha(0.7) end
    r:Show()
end

-- How far you stand from a held lair against its leash, colored by how close to it you are.
local function Leash(lair)
    if not SL.LairDistance then return nil end
    local dist = SL.LairDistance(lair)
    if not dist then return nil end
    local radius, learned = SL.LeashRadius()
    local text = math.floor(dist + 0.5) .. "/" .. math.floor(radius + 0.5) .. " yd"
    if not learned then text = text .. "?" end
    local f = dist / radius
    if f >= 1 then return text, 1, 0.25, 0.25 end
    if f >= 0.8 then return text, 1, 0.65, 0.2 end
    return text, 0.5, 1, 0.5
end

local function Rebuild()
    count, counting = 0, false
    local db = SL.db
    local units = AZS_UNITS
    if db.threats and type(units) == "table" then
        local byId = {}
        for i = 1, table.getn(units) do
            local u = units[i]
            byId[u.id] = u
            if u.kind == "final" or u.kind == "boss" then
                local status = Pct(u)
                if u.state == 1 then status = "ENRAGED " .. status end
                Line(u.kind, tostring(u.name or "?"), status)
            end
        end
        local lairs = AZS_LAIRS
        if type(lairs) == "table" and table.getn(lairs) > 0 then
            local nextLair = SL.NextLair()
            for i = 1, table.getn(lairs) do
                local lair = lairs[i]
                local name = tostring(lair.name or "?")
                local mark = SL.LairLook(lair)
                local dist = SL.LairDistance and SL.LairDistance(lair)
                local away = ""
                if dist then away = "  " .. math.floor(dist + 0.5) .. " yd" end
                if lair.state == "empty" then
                    local left = SL.LairLeft(lair)
                    if left and lair == nextLair then
                        -- The next to come back, and how far to walk to be there.
                        Line("empty", name, "next " .. MinSec(left) .. away, 1, 0.82, 0.2, mark)
                        counting = true
                    elseif left then
                        Line("empty", name, "back in " .. MinSec(left), 0.7, 0.7, 0.7, mark)
                        counting = true
                    else
                        Line("empty", name, "slain", 0.7, 0.7, 0.7, mark)
                    end
                else
                    local u = byId[lair.id]
                    local pct = u and Pct(u) or ""
                    if u and u.state == 1 then
                        local text, r, g, b = Leash(lair)
                        if text then
                            Line("guardian", name, pct .. "  " .. text, r, g, b, mark)
                            counting = true
                        else
                            Line("guardian", name, "awake " .. pct, 1, 0.5, 0.3, mark)
                        end
                    else
                        Line("guardian", name, "asleep " .. pct .. away, 0.8, 0.8, 0.8, mark)
                        if dist then counting = true end
                    end
                end
            end
        else
            for i = 1, table.getn(units) do
                local u = units[i]
                if u.kind == "guardian" then
                    local word = "asleep "
                    if u.state == 1 then word = "awake " end
                    Line("guardian", tostring(u.name or "?"), word .. Pct(u))
                end
            end
        end
        -- The next boss to come.
        local now = SL.RunTime()
        local schedule = AZS_SCHEDULE
        if now and type(schedule) == "table" then
            local best
            for i = 1, table.getn(schedule) do
                local b = schedule[i]
                if b.state == "due" and type(b.at) == "number" and b.at > now and (not best or b.at < best.at) then best = b end
            end
            if best then
                Line("next", tostring(best.name), "in " .. MinSec(best.at - now), 0.8, 0.8, 0.8)
                counting = true
            end
        end
    end
    for i = count + 1, MAX_ROWS do rows[i]:Hide() end
    if count > 0 or not SL.locked then frame:Show() else frame:Hide() end
end

local dirty = false
local ticker = SL.Every(0.25, function()
    if dirty then
        dirty = false
        Rebuild()
    end
    return false
end, false)

-- Countdowns and leash distances move on their own: once a second while any shows.
local clock = SL.Every(1, function()
    if not counting then return false end
    Rebuild()
end, false)

local function Changed()
    dirty = true
    SL.Wake(ticker)
    SL.Wake(clock)
end
M.Changed = Changed
SL.StatusChanged = Changed

function M.init()
    SL.Movable(frame, "threatsX", "threatsY", "Status")
    frame.slAfterLock = Rebuild
    SL.OnAzs("AZSUNITS", Changed)
    SL.OnAzs("AZSLAIRS", Changed)
    SL.OnAzs("AZSBOSSES", Changed)
    SL.On("PLAYER_ENTERING_WORLD", Changed)
end

function M.apply()
    frame:SetScale(SL.db.scale)
    SL.Place(frame)
    Rebuild()
    SL.Wake(clock)
end
