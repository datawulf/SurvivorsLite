-- The run's numbers from the character pane in a small panel on the screen: the twelve the
-- pane always shows, then those of its run stats that something raised (or all of them).
-- A number that just went up turns green for a few seconds, one that went down red. Point
-- at a row for what it means and what your worn gear adds to it.

local SL = SurvivorsLite
local M = SL.Module({})

local CELL_W, CELL_H, GAP, PAD, SPLIT = 108, 13, 10, 6, 6
local FLASH = 5 -- seconds a changed number keeps its color
local UP, DOWN, SAME = { 0.4, 1, 0.4 }, { 1, 0.4, 0.4 }, { 1, 1, 1 }

local function Pct(v) return string.format("%+.0f%%", v * 100) end
local function Share(v) return string.format("%.0f%%", v * 100) end
local function Count(v) return string.format("%d", v) end

-- Each row: label, the stat's key, how the pane shows it (from the stat), the number shown
-- (for its color), what it means, the gear key and how gear's part reads. The pane shows
-- some as an offset (Damage 1.2 is +20%, Haste is 1 minus the cooldown factor).
local MAIN = {
    { "Health", "hp", function(v) return string.format("%.0f", v) end, nil, "Your maximum health.",
        "ghp", function(g) return string.format("+%.0f health", g) end },
    { "Damage", "dmg", Pct, -1, "More damage on every spell. Grows with level, gear, talents, jewelry and buffs.",
        "gdmg", function(g) return Pct(g) .. " damage" end },
    { "Haste", "cd", Pct, "haste", "Your spells come back this much sooner.",
        "gcd", function(g) return Pct(g) .. " cooldown reduction" end },
    { "Crit", "crit", function(v) return string.format("%.1f%%", v * 100) end, nil, "Chance of a critical strike. Above 100% the rest adds to critical damage.",
        "gcrit", function(g) return Pct(g) .. " critical strike" end },
    { "Crit Dmg", "cm", Share, nil, "How much of a spell's damage a critical strike deals.",
        "gcm", function(g) return Pct(g) .. " critical damage" end },
    { "Armor", "arm", Share, nil, "Less damage taken, up to 60%.",
        "garm", function(g) return Pct(g) .. " damage reduction" end },
    { "Area", "area", Pct, -1, "Larger areas and ranges for your spells.",
        "garea", function(g) return Pct(g) .. " area" end },
    { "Targets", "cnt", function(v) return string.format("+%d", v) end, nil, "Extra targets for every spell that picks its own.",
        "gcnt", function(g) return string.format("+%d targets", g) end },
    { "Echo", "echo", Share, nil, "Chance a spell strikes twice. Above 100% every spell does and the rest is the chance of a third.",
        "gecho", function(g) return Pct(g) .. " echo" end },
    { "Speed", "spd", Pct, -1, "Faster running.",
        "gspd", function(g) return Pct(g) .. " movement speed" end },
    { "Regen", "reg", function(v) return string.format("%.1f", v) end, nil, "Health back every second.",
        "greg", function(g) return string.format("+%.1f health per second", g) end },
    { "Pickup", "pick", function(v) return string.format("%.0f yd", v) end, nil, "How far away experience and gold fly to you from.",
        "gpick", function(g) return Pct(g) .. " pickup range" end },
}
-- The rest, with the value at which nothing raised it yet.
local MORE = {
    { "Lifesteal", "lch", function(v) return string.format("%.1f%%", v * 100) end, nil, "Heals you for this share of the damage you deal.", nil, nil, 0 },
    { "Kill Heal", "heal", function(v) return string.format("%.0f", v) end, nil, "Health back for every kill.", nil, nil, 0 },
    { "Thorns", "thn", Share, nil, "This share of the melee damage you take hits the attacker back.", nil, nil, 0 },
    { "Lives", "liv", Count, nil, "Times you rise again instead of dying.", nil, nil, 0 },
    { "Experience", "xp", Pct, -1, "More experience.", nil, nil, 0 },
    { "Gold", "gold", Pct, -1, "More gold.", "ggold", function(g) return Pct(g) .. " gold" end, 0 },
    { "Luck", "luck", Pct, nil, "Better odds of rarer upgrades at level ups.", nil, nil, 0 },
    { "Buff Power", "bp", Pct, nil, "Stronger damage, haste, shield and thorns buffs.", nil, nil, 0 },
    { "DoT Stacks", "dots", Count, nil, "How many of each of your damage over time effects one enemy carries.", nil, nil, 1 },
    { "DoT Haste", "doth", Pct, nil, "Your damage over time effects tick this much faster.", nil, nil, 0 },
    { "Vs Elites", "big", Pct, nil, "More damage to elites and bosses.", nil, nil, 0 },
    { "Execute", "exe", Pct, nil, "More damage to enemies under 30% health.", nil, nil, 0 },
    { "Vs Controlled", "cc", Pct, nil, "More damage to rooted, stunned, slowed or fleeing enemies.", nil, nil, 0 },
    { "Vs Afflicted", "dotd", Pct, nil, "More damage to enemies carrying one of your damage over time effects.", nil, nil, 0 },
    { "Shielded", "shd", Pct, nil, "More damage while you hold an absorb shield.", nil, nil, 0 },
    { "Melee", "auto", Pct, nil, "More damage on your melee swings.", nil, nil, 0 },
    { "Pet Damage", "pet", Pct, nil, "More damage for your pets.", nil, nil, 0 },
}

local frame = CreateFrame("Frame", "SurvivorsLiteStats", UIParent)
frame:SetFrameStrata("LOW")
frame:SetWidth(PAD * 2 + CELL_W * 2 + GAP)
frame:SetHeight(PAD * 2 + CELL_H * 6)
frame:Hide()
local back = SL.Tex(frame, "BACKGROUND", 0, 0, 0, 0.4)
back:SetAllPoints(frame)
local split = SL.Tex(frame, "BORDER", 1, 0.82, 0, 0.25)
split:SetHeight(1)
split:Hide()

local cells = {}
local last = {}     -- label -> the text shown before
local flashes = {}  -- label -> { untilAt, color } while a changed number keeps its color
local quiet = false -- a new run's first line is no change from the last run
local ticker

local function ShowTip()
    if not GameTooltip or not this.slTitle then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(this.slTitle, 1, 1, 1)
    GameTooltip:AddLine(this.slTip, 1, 0.82, 0, 1)
    if this.slGear then GameTooltip:AddLine("Worn gear: " .. this.slGear, 0.3, 1, 0.3, 1) end
    GameTooltip:Show()
end

local function NewCell()
    local c = CreateFrame("Frame", nil, frame)
    c:SetWidth(CELL_W)
    c:SetHeight(CELL_H)
    c.label = SL.Text(c, 10)
    c.label:SetPoint("LEFT", c, "LEFT", 0, 0)
    c.label:SetJustifyH("LEFT")
    c.label:SetTextColor(1, 0.82, 0)
    c.value = SL.Text(c, 10, true)
    c.value:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    c.value:SetJustifyH("RIGHT")
    c:EnableMouse(true)
    c:SetScript("OnEnter", ShowTip)
    c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    c:Hide()
    return c
end

-- The number a row shows, nil when the run's line does not carry its stat.
local function Shown(row, s)
    local v = s[row[2]]
    if type(v) ~= "number" then return nil end
    if row[4] == "haste" then return 1 - v end
    if row[4] then return v + row[4] end
    return v
end

local n, lines, now -- cells used, lines laid out and this rebuild's time

local function Cell(row, v, s, top)
    n = n + 1
    local c = cells[n] or NewCell()
    cells[n] = c
    local col = math.mod(n - 1, 2)
    if col == 0 then lines = lines + 1 end
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + col * (CELL_W + GAP), top - (lines - 1) * CELL_H)
    local label, text = row[1], row[3](v)
    if c.slLabel ~= label then
        c.slLabel = label
        c.label:SetText(label)
    end
    if c.slText ~= text then
        c.slText = text
        c.value:SetText(text)
    end
    -- A number that changed keeps its color for a while.
    local before = last[label]
    if not before then
        last[label] = { text = text, v = v }
    elseif before.text ~= text then
        if not quiet then
            local color = DOWN
            if v > before.v then color = UP end
            flashes[label] = { untilAt = now + FLASH, color = color }
        end
        before.text, before.v = text, v
    end
    local f = flashes[label]
    local color = SAME
    if f and f.untilAt > now then color = f.color end
    if c.slColor ~= color then
        c.slColor = color
        c.value:SetTextColor(color[1], color[2], color[3])
    end
    c.slTitle = label .. " " .. text
    c.slTip = row[5]
    c.slGear = nil
    local g = row[6] and s[row[6]]
    if type(g) == "number" and g ~= 0 then c.slGear = row[7](g) end
    c:Show()
end

local function Rebuild()
    n, lines, now = 0, 0, GetTime()
    local mode = SL.db.stats
    local s = AZS_STATS
    if mode ~= "off" and type(s) == "table" then
        for i = 1, table.getn(MAIN) do
            local v = Shown(MAIN[i], s)
            if v then Cell(MAIN[i], v, s, -PAD) end
        end
        local mainLines = lines
        local top = -PAD
        local first = true
        for i = 1, table.getn(MORE) do
            local row = MORE[i]
            local v = Shown(row, s)
            if v and (mode == "all" or v ~= row[8]) then
                if first then
                    -- The run stats start on a line of their own under a thin line.
                    first = false
                    if math.mod(n, 2) == 1 then
                        -- A hidden cell keeps the list without holes.
                        n = n + 1
                        cells[n] = cells[n] or NewCell()
                        cells[n]:Hide()
                    end
                    top = -PAD - SPLIT
                    split:ClearAllPoints()
                    split:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD - mainLines * CELL_H - SPLIT / 2)
                    split:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -PAD - mainLines * CELL_H - SPLIT / 2)
                end
                Cell(row, v, s, top)
            end
        end
        if first then split:Hide() else split:Show() end
    else
        split:Hide()
    end
    for i = n + 1, table.getn(cells) do cells[i]:Hide() end
    local extra = 0
    if split:IsShown() then extra = SPLIT end
    if lines > 0 then
        frame:SetHeight(PAD * 2 + lines * CELL_H + extra)
        frame:Show()
    elseif not SL.locked then
        frame:SetHeight(PAD * 2 + CELL_H * 6)
        frame:Show()
    else
        frame:Hide()
    end
    SL.Wake(ticker)
end

-- Changed numbers go back to white when their time is up.
ticker = SL.Every(0.5, function(t)
    local any, ended = false, false
    for label, f in pairs(flashes) do
        if f.untilAt > t then any = true else ended = true end
    end
    if ended then
        for label, f in pairs(flashes) do
            if f.untilAt <= t then flashes[label] = nil end
        end
        Rebuild()
    end
    if not any then return false end
end, false)

local function StatsLine()
    Rebuild()
    quiet = false
end

-- A new zone starts a new run: its first numbers do not count as changes.
local function NewRun()
    last, flashes, quiet = {}, {}, true
    Rebuild()
end

function M.init()
    SL.Movable(frame, "statsX", "statsY", "Stats")
    frame.slAfterLock = Rebuild
    SL.OnAzs("AZS", StatsLine)
    SL.OnAzs("AZSZONE", NewRun)
    SL.On("PLAYER_ENTERING_WORLD", NewRun)
end

function M.apply()
    frame:SetScale(SL.db.scale)
    SL.Place(frame)
    Rebuild()
end
