-- The hero bar under your character: level, health, experience, lives and auras with how
-- much of the run each buff was up, plus the marker ring, the low health edge and the boss
-- countdown. Spell cooldowns live on the action bar (actionbar.lua).

local SL = SurvivorsLite
local M = SL.Module({})

local W = 96
local AURA_SIZE, AURA_GAP, AURA_MAX = 16, 2, 12
local DISPEL = {
    Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 },
    Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 },
}
local HARMFUL = { 0.8, 0, 0 }

local hud = CreateFrame("Frame", "SurvivorsLiteHero", UIParent)
hud:SetFrameStrata("LOW")
hud:SetWidth(W)
hud:SetHeight(10)
hud:Hide()

local hp = SL.Bar(hud, W, 7)
hp:SetPoint("TOP", hud, "TOP", 0, 0)

-- Your shield on the bar, as later clients draw it: a pale segment after your health as long
-- as the shield, and a bright tick at the end when health and shield pass your maximum.
-- Its own frame over the fill, and the text on one over that.
local shieldFrame = CreateFrame("Frame", nil, hp)
shieldFrame:SetAllPoints(hp)
shieldFrame:SetFrameLevel(hp:GetFrameLevel() + 1)
local shieldTex = SL.Tex(shieldFrame, "ARTWORK", 0.75, 0.9, 1, 0.6)
shieldTex:SetHeight(7)
shieldTex:Hide()
local overTick = SL.Tex(shieldFrame, "OVERLAY", 0.85, 0.95, 1, 1)
overTick:SetWidth(2)
overTick:SetHeight(9)
overTick:SetPoint("RIGHT", hp, "RIGHT", 1, 0)
overTick:Hide()
local textFrame = CreateFrame("Frame", nil, hp)
textFrame:SetAllPoints(hp)
textFrame:SetFrameLevel(hp:GetFrameLevel() + 2)
local hpText = SL.Text(textFrame, 8, true)
hpText:SetPoint("CENTER", hp, "CENTER", 0, 0)

local level = SL.Text(hud, 10, true)
level:SetPoint("RIGHT", hp, "LEFT", -3, 0)
level:SetTextColor(1, 0.82, 0)

local lives = SL.Text(hud, 9, true)
lives:SetPoint("LEFT", hp, "RIGHT", 3, 0)
lives:SetTextColor(1, 0.85, 0.35)

local xp = SL.Bar(hud, W, 2)
xp:SetPoint("TOP", hp, "BOTTOM", 0, -2)
xp:SetStatusBarColor(0.62, 0.35, 1)

local auraRow = CreateFrame("Frame", nil, hud)
auraRow:SetWidth(W)
auraRow:SetHeight(AURA_SIZE)
auraRow:SetPoint("TOP", xp, "BOTTOM", 0, -4)

-- On the hero: a ring that shows where you stand under trees, warnings above it.
local ring = CreateFrame("Frame", nil, UIParent)
ring:SetFrameStrata("BACKGROUND")
ring:SetWidth(70)
ring:SetHeight(70)
ring:SetPoint("CENTER", SL.center, "CENTER", 0, 0)
local ringTex = ring:CreateTexture(nil, "ARTWORK")
ringTex:SetTexture("Interface\\Cooldown\\ping4")
ringTex:SetBlendMode("ADD")
ringTex:SetAllPoints(ring)
ring:Hide()

-- Warnings stay up when the hero bar is turned off, so they get a frame of their own.
local over = CreateFrame("Frame", nil, UIParent)
over:SetFrameStrata("LOW")
over:SetWidth(W)
over:SetHeight(1)
over:SetPoint("BOTTOM", SL.center, "CENTER", 0, 70)
local alert = SL.Text(over, 18)
alert:SetPoint("BOTTOM", over, "TOP", 0, 0)
alert:Hide()
local countdown = SL.Text(over, 15)
countdown:SetPoint("BOTTOM", alert, "TOP", 0, 4)
countdown:Hide()

local edge = CreateFrame("Frame", nil, UIParent)
edge:SetFrameStrata("BACKGROUND")
edge:SetAllPoints(UIParent)
local edgeTex = edge:CreateTexture(nil, "BACKGROUND")
edgeTex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
edgeTex:SetBlendMode("ADD")
edgeTex:SetAllPoints(edge)
edge:Hide()

-- ---------------------------------------------------------------- health, level, lives

local lowTicker
local low = 0

-- The run's line carries your shield: AZS_RUN.sh, in health points.
local function Shield()
    local run = AZS_RUN
    local sh = type(run) == "table" and run.sh
    if SL.db.shield and type(sh) == "number" and sh > 0 then return sh end
    return 0
end

local function UpdateHealth()
    local cur, max = UnitHealth("player") or 0, UnitHealthMax("player") or 0
    if max <= 0 then max = 1 end
    local f = cur / max
    if f > 1 then f = 1 elseif f < 0 then f = 0 end
    hp:SetValue(f)
    hp:SetStatusBarColor(SL.HealthColor(f))
    local sh = Shield()
    local text = SL.Short(cur)
    if sh > 0 then
        local s = sh / max
        local stop = f + s
        if stop > 1 then stop = 1 end
        local width = (stop - f) * W
        shieldTex:ClearAllPoints()
        shieldTex:SetPoint("LEFT", hp, "LEFT", f * W, 0)
        if width >= 1 then
            shieldTex:SetWidth(width)
            shieldTex:Show()
        else
            shieldTex:Hide()
        end
        if f + s > 1 then overTick:Show() else overTick:Hide() end
        text = text .. " |cffaee0ff+" .. SL.Short(sh) .. "|r"
    else
        shieldTex:Hide()
        overTick:Hide()
    end
    if text ~= hpText.slText then
        hpText.slText = text
        hpText:SetText(text)
    end
    if SL.db.lowhp and cur > 0 and f < 0.35 then
        low = 1 - f / 0.35
        edge:Show()
        SL.Wake(lowTicker)
    else
        low = 0
        lowTicker.active = false
        edge:Hide()
    end
end

lowTicker = SL.Every(0.03, function(now)
    -- A triangle wave; the client's math.sin may take degrees, this needs no trig.
    local phase = math.mod(now * 1.6, 1) * 2
    if phase > 1 then phase = 2 - phase end
    edgeTex:SetVertexColor(1, 0.1, 0.1, 0.25 + 0.35 * low + 0.3 * phase)
end, false)

local function UpdateLevel(value)
    level:SetText(tostring(value or UnitLevel("player") or ""))
end

local function UpdateXP()
    local max = UnitXPMax("player") or 0
    if max <= 0 then
        xp:SetValue(0)
        return
    end
    xp:SetValue((UnitXP("player") or 0) / max)
end

local function UpdateLives()
    local s = AZS_STATS
    if type(s) == "table" and type(s.liv) == "number" and s.liv > 0 then
        lives:SetText("+" .. s.liv)
    else
        lives:SetText("")
    end
end

-- ---------------------------------------------------------------- buff uptime

-- Seconds each timed buff (by its icon) was up in this run, while the run was playing.
local up, upTotal, upClock = {}, 0, nil
local auraIcons = {}
local auraCount = 0
local RebuildAuras

local function UptimeText(key)
    if not key or upTotal < 5 then return "" end
    return math.floor((up[key] or 0) / upTotal * 100 + 0.5) .. "%"
end

local uptimeTicker = SL.Every(1, function()
    local t = SL.RunTime()
    if not t then return end
    if upClock and t < upClock - 1 then
        -- The clock went back: a new run.
        up, upTotal = {}, 0
        RebuildAuras()
    end
    local dt = 0
    if upClock then dt = t - upClock end
    upClock = t
    if dt <= 0 or dt > 5 or SL.Phase() ~= "playing" then return end
    upTotal = upTotal + dt
    for i = 0, 31 do
        local index, untilCancelled = GetPlayerBuff(i, "HELPFUL")
        if not index or index < 0 then break end
        if untilCancelled ~= 1 then
            local tex = GetPlayerBuffTexture(index)
            if tex then up[tex] = (up[tex] or 0) + dt end
        end
    end
    for i = 1, auraCount do
        local f = auraIcons[i]
        if f.upKey then
            local text = UptimeText(f.upKey)
            if text ~= f.upText then
                f.upText = text
                f.up:SetText(text)
            end
        end
    end
end, false)

-- ---------------------------------------------------------------- auras

local auraTicker

local function NextAura()
    auraCount = auraCount + 1
    local f = auraIcons[auraCount]
    if not f then
        f = SL.NewIcon(auraRow)
        f.up = SL.Text(f, 7, true)
        f.up:SetPoint("TOP", f, "BOTTOM", 0, -1)
        f.up:SetTextColor(0.85, 0.85, 0.6)
        auraIcons[auraCount] = f
    end
    SL.SizeIcon(f, AURA_SIZE)
    f.index, f.key, f.shown, f.upKey, f.upText = nil, nil, nil, nil, nil
    f.shade:Hide()
    f.text:SetText("")
    f.count:SetText("")
    f.up:SetText("")
    f:SetAlpha(1)
    return f
end

local function AddAura(index, harmful, timed)
    local f = NextAura()
    local tex = GetPlayerBuffTexture(index)
    f.tex:SetTexture(tex)
    local stacks = GetPlayerBuffApplications(index)
    if stacks and stacks > 1 then f.count:SetText(tostring(stacks)) end
    if harmful then
        local c = DISPEL[GetPlayerBuffDispelType(index) or ""] or HARMFUL
        f.border:SetVertexColor(c[1], c[2], c[3], 1)
    else
        f.border:SetVertexColor(0, 0, 0, 1)
        if timed and SL.db.uptime then f.upKey = tex end
    end
    f.index = index
    return tex
end

-- A buff that was up earlier in the run, dimmed, with its uptime.
local function AddDown(tex)
    local f = NextAura()
    f.tex:SetTexture(tex)
    f.border:SetVertexColor(0, 0, 0, 1)
    f.upKey = tex
    f:SetAlpha(0.4)
end

local function Layout()
    local total = auraCount * AURA_SIZE + math.max(0, auraCount - 1) * AURA_GAP
    local x = -total / 2
    for i = 1, auraCount do
        local f = auraIcons[i]
        f:ClearAllPoints()
        f:SetPoint("LEFT", auraRow, "CENTER", x, 0)
        x = x + AURA_SIZE + AURA_GAP
        f.upText = UptimeText(f.upKey)
        f.up:SetText(f.upText)
        f:Show()
    end
    for i = auraCount + 1, table.getn(auraIcons) do auraIcons[i]:Hide() end
end

RebuildAuras = function()
    auraCount = 0
    local mode = SL.db.buffs
    if mode ~= "off" then
        local active = {}
        for i = 0, 31 do
            local index, untilCancelled = GetPlayerBuff(i, "HELPFUL")
            if not index or index < 0 or auraCount >= AURA_MAX then break end
            local timed = untilCancelled ~= 1
            if mode == "all" or timed then
                local tex = AddAura(index, false, timed)
                if tex then active[tex] = true end
            end
        end
        if SL.db.uptime and upTotal >= 5 then
            local down = {}
            for tex, secs in pairs(up) do
                if not active[tex] and secs > 0 then table.insert(down, tex) end
            end
            table.sort(down, function(a, b) return up[a] > up[b] end)
            for i = 1, table.getn(down) do
                if auraCount >= AURA_MAX - 2 then break end
                AddDown(down[i])
            end
        end
        for i = 0, 15 do
            local index = GetPlayerBuff(i, "HARMFUL")
            if not index or index < 0 or auraCount >= AURA_MAX then break end
            AddAura(index, true)
        end
    end
    Layout()
    SL.Wake(auraTicker)
end

auraTicker = SL.Every(0.25, function()
    local timed = false
    for i = 1, auraCount do
        local f = auraIcons[i]
        local left = 0
        if f.index then left = GetPlayerBuffTimeLeft(f.index) or 0 end
        if left > 0 then
            timed = true
            local key = math.ceil(left)
            if key ~= f.key then
                f.key = key
                f.text:SetText(SL.Clock(left))
            end
        elseif f.key then
            f.key = nil
            f.text:SetText("")
        end
    end
    if not timed then return false end
end)

-- ---------------------------------------------------------------- alerts

local alertUntil = 0
local alertTicker = SL.Every(0.25, function(now)
    if now >= alertUntil then
        alert:Hide()
        return false
    end
end, false)

-- A short warning over your character (ally down, guardian woke...).
function SL.Alert(text, r, g, b, seconds)
    if not SL.db or not SL.db.alerts then return end
    alert:SetText(text)
    alert:SetTextColor(r or 1, g or 0.3, b or 0.3)
    alert:Show()
    alertUntil = GetTime() + (seconds or 3)
    SL.Wake(alertTicker)
end

-- The next boss when it is ten seconds away or less.
local countdownTicker = SL.Every(0.5, function()
    local now = SL.RunTime()
    local schedule = AZS_SCHEDULE
    local best, row
    if SL.db.alerts and now and SL.Phase() == "playing" and type(schedule) == "table" then
        for i = 1, table.getn(schedule) do
            local b = schedule[i]
            if b.state == "due" and type(b.at) == "number" then
                local left = b.at - now
                if left > 0 and (not best or left < best) then best, row = left, b end
            end
        end
    end
    if best and best <= 10 then
        countdown:SetText(tostring(row.name) .. "  " .. math.ceil(best))
        if row.final == 1 then
            countdown:SetTextColor(1, 0.2, 1)
        else
            countdown:SetTextColor(1, 0.55, 0.1)
        end
        countdown:Show()
    else
        countdown:Hide()
    end
end)

-- ---------------------------------------------------------------- wiring

local function Refresh()
    UpdateHealth()
    UpdateLevel()
    UpdateXP()
    UpdateLives()
    RebuildAuras()
end

-- Aura changes can come in bursts during a fight; rebuild at most five times a second.
local rebuildTicker = SL.Every(0.2, function()
    RebuildAuras()
    return false
end, false)

function M.init()
    SL.Movable(hud, "heroX", "heroY", "Hero")
    SL.On("PLAYER_ENTERING_WORLD", Refresh)
    SL.On("UNIT_HEALTH", function(unit) if unit == "player" then UpdateHealth() end end)
    SL.On("UNIT_MAXHEALTH", function(unit) if unit == "player" then UpdateHealth() end end)
    SL.On("PLAYER_LEVEL_UP", function(value) UpdateLevel(value) end)
    SL.On("UNIT_LEVEL", function(unit) if unit == "player" then UpdateLevel() end end)
    SL.On("PLAYER_XP_UPDATE", UpdateXP)
    SL.On("PLAYER_AURAS_CHANGED", function() SL.Wake(rebuildTicker) end)
    SL.OnAzs("AZS", UpdateLives)
    SL.OnAzs("AZSRUN", UpdateHealth)
end

function M.apply()
    local db = SL.db
    hud:SetScale(db.scale)
    ring:SetScale(db.scale)
    SL.Place(hud)
    if db.hero or not SL.locked then hud:Show() else hud:Hide() end
    if db.ring then
        local c = SL.UnitColor("player")
        ringTex:SetVertexColor(c[1], c[2], c[3], 0.75)
        ring:Show()
    else
        ring:Hide()
    end
    if not db.alerts then
        alert:Hide()
        countdown:Hide()
    end
    countdownTicker.active = db.alerts
    uptimeTicker.active = db.uptime
    Refresh()
end
