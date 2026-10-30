-- A strict mock of the 1.12 frame API, enough to run SurvivorsLite outside the client.
-- Unknown methods raise errors, so a call the 1.12 API does not have shows up here.

MOCK = { now = 1000, chat = {}, calls = 0, frames = {}, eventFrames = {} }
if not math.mod then math.mod = math.fmod end

function GetTime() return MOCK.now end
function debugprofilestop() return os.clock() * 1000 end

local function check(cond, msg)
    if not cond then error(msg, 3) end
end

local Methods = {}
local MT = {
    __index = function(t, k)
        local m = Methods[k]
        if m then
            local allowed = m.types
            if allowed and not allowed[rawget(t, "_type")] then
                error("method " .. k .. " not valid on " .. tostring(rawget(t, "_type")), 2)
            end
            return m.fn
        end
        local v = rawget(t, "_fields") and t._fields[k]
        return v
    end,
    __newindex = function(t, k, v)
        if Methods[k] then error("overwriting method " .. k, 2) end
        rawset(t, k, v)
    end,
}

local FRAMES = { Frame = true, Button = true, CheckButton = true, StatusBar = true, Slider = true, GameTooltip = true }
local ANY = { Frame = true, Button = true, CheckButton = true, StatusBar = true, Slider = true, GameTooltip = true, Texture = true, FontString = true }
local REGION = { Texture = true, FontString = true }

local function def(name, types, fn) Methods[name] = { types = types, fn = fn } end

local function newObj(otype, parent, name)
    local o = { _type = otype, _parent = parent, _children = {}, _regions = {}, _scripts = {},
        _shown = true, _alpha = 1, _w = 0, _h = 0, _level = 1, _mouse = false, _name = name,
        _min = 0, _max = 1, _value = 0, _color = { 1, 1, 1 }, _scale = 1 }
    setmetatable(o, MT)
    if name then setglobal(name, o) end
    table.insert(MOCK.frames, o)
    return o
end

-- Templates the client has; a button from one comes sized like the stock rungs.
local TEMPLATES = { GameMenuButtonTemplate = { 144, 21 }, ActionBarButtonTemplate = { 36, 36 }, MainMenuBarMicroButton = { 28, 58 }, GameTooltipTemplate = { 1, 1 } }

function CreateFrame(otype, name, parent, template)
    check(FRAMES[otype], "CreateFrame type " .. tostring(otype))
    check(template == nil or TEMPLATES[template], "unknown template " .. tostring(template))
    local o = newObj(otype, parent, name)
    if template then o._w, o._h, o._mouse = TEMPLATES[template][1], TEMPLATES[template][2], true end
    if template == "GameTooltipTemplate" then
        check(otype == "GameTooltip" and name, "tooltip template needs a named GameTooltip")
        for i = 1, 8 do
            o:CreateFontString(name .. "TextLeft" .. i, "ARTWORK")
            o:CreateFontString(name .. "TextRight" .. i, "ARTWORK")
        end
    end
    if parent then
        table.insert(parent._children, o)
        o._level = (parent._level or 0) + 1
    end
    return o
end

local function fire(o, script, a1)
    local fn = o._scripts[script]
    if fn then
        local prevThis, prevArg1 = this, arg1
        this, arg1 = o, a1
        fn()
        this, arg1 = prevThis, prevArg1
    end
end
MOCK.fire = fire

local POINTS = { TOPLEFT = 1, TOP = 1, TOPRIGHT = 1, LEFT = 1, CENTER = 1, RIGHT = 1, BOTTOMLEFT = 1, BOTTOM = 1, BOTTOMRIGHT = 1 }

def("SetScript", FRAMES, function(o, s, fn) check(type(s) == "string", "script name"); check(fn == nil or type(fn) == "function", "script fn"); o._scripts[s] = fn end)
def("GetScript", FRAMES, function(o, s) return o._scripts[s] end)
def("RegisterEvent", FRAMES, function(o, e)
    check(type(e) == "string", "event name")
    if not o._events then o._events = {} end
    if not o._events[e] then
        o._events[e] = true
        table.insert(MOCK.eventFrames, { frame = o, event = e })
    end
end)
def("UnregisterEvent", FRAMES, function(o, e) if o._events then o._events[e] = nil end end)
def("Show", ANY, function(o) if not o._shown then o._shown = true; if o._scripts then fire(o, "OnShow") end end end)
def("Hide", ANY, function(o) if o._shown then o._shown = false; if o._scripts then fire(o, "OnHide") end end end)
def("IsShown", ANY, function(o) return o._shown and 1 or nil end)
def("IsVisible", ANY, function(o)
    local p = o
    while p do
        if not p._shown then return nil end
        p = p._parent
    end
    return 1
end)
def("SetAlpha", ANY, function(o, a) check(type(a) == "number", "alpha number"); o._alpha = a end)
def("GetAlpha", ANY, function(o) return o._alpha end)
def("SetWidth", ANY, function(o, w) check(type(w) == "number", "width number"); o._w = w end)
def("SetHeight", ANY, function(o, h) check(type(h) == "number", "height number"); o._h = h end)
def("GetWidth", ANY, function(o) return o._w end)
def("GetHeight", ANY, function(o) return o._h end)
def("SetPoint", ANY, function(o, p, rel, rp, x, y)
    check(POINTS[p], "SetPoint point " .. tostring(p))
    check(type(rel) == "table", "SetPoint needs the full form (point, frame, relPoint, x, y)")
    check(POINTS[rp], "SetPoint relative point " .. tostring(rp))
    check(type(x) == "number" and type(y) == "number", "SetPoint offsets")
    o._point = { p, rel, rp, x, y }
end)
def("SetAllPoints", ANY, function(o, rel) check(type(rel) == "table", "SetAllPoints frame"); o._point = { "ALL", rel } end)
def("ClearAllPoints", ANY, function(o) o._point = nil end)
def("GetPoint", ANY, function(o, i)
    check(i == nil or i == 1, "GetPoint index")
    local p = o._point
    if p and p[1] ~= "ALL" then return p[1], p[2], p[3], p[4], p[5] end
end)
def("GetBottom", ANY, function(o) return 10 end)
def("SetParent", FRAMES, function(o, parent)
    check(type(parent) == "table", "SetParent frame")
    local old = o._parent
    if old then
        for i = table.getn(old._children), 1, -1 do
            if old._children[i] == o then table.remove(old._children, i) end
        end
    end
    o._parent = parent
    table.insert(parent._children, o)
end)
def("GetID", FRAMES, function(o) return o._id or 0 end)
def("SetFrameStrata", FRAMES, function(o, s) check(type(s) == "string", "strata") end)
def("SetFrameLevel", FRAMES, function(o, l) check(type(l) == "number", "level"); o._level = l end)
def("GetFrameLevel", FRAMES, function(o) return o._level end)
def("SetScale", FRAMES, function(o, s) check(type(s) == "number" and s > 0, "scale"); o._scale = s end)
def("GetEffectiveScale", FRAMES, function(o) return o._scale end)
def("GetCenter", ANY, function(o) return 512, 384 end)
def("SetMovable", FRAMES, function(o, v) end)
def("SetClampedToScreen", FRAMES, function(o, v) end)
def("RegisterForDrag", FRAMES, function(o, b) check(type(b) == "string", "drag button") end)
def("RegisterForClicks", { Button = true, CheckButton = true }, function(o, b) check(type(b) == "string", "click button") end)
def("StartMoving", FRAMES, function(o) end)
def("StopMovingOrSizing", FRAMES, function(o) end)
def("EnableMouse", FRAMES, function(o, v) o._mouse = v and true or false end)
def("EnableMouseWheel", FRAMES, function(o, v) o._wheel = v and true or false end)
def("IsMouseEnabled", FRAMES, function(o) return o._mouse and 1 or nil end)
def("GetName", ANY, function(o) return o._name end)
def("GetObjectType", ANY, function(o) return o._type end)
def("GetParent", ANY, function(o) return o._parent end)
def("GetChildren", FRAMES, function(o) return unpack(o._children) end)
def("GetNumChildren", FRAMES, function(o) return table.getn(o._children) end)
def("GetRegions", FRAMES, function(o) return unpack(o._regions) end)
def("CreateTexture", FRAMES, function(o, name, layer)
    local t = newObj("Texture", o, name)
    t._layer = layer
    table.insert(o._regions, t)
    return t
end)
def("CreateFontString", FRAMES, function(o, name, layer)
    local t = newObj("FontString", o, name)
    table.insert(o._regions, t)
    return t
end)
local BAR = { StatusBar = true }
local VALUE = { StatusBar = true, Slider = true }
def("SetStatusBarTexture", BAR, function(o, t) check(type(t) == "string", "bar texture") end)
def("SetMinMaxValues", VALUE, function(o, a, b) check(type(a) == "number" and type(b) == "number", "minmax"); o._min, o._max = a, b end)
def("GetMinMaxValues", VALUE, function(o) return o._min, o._max end)
def("SetValue", VALUE, function(o, v)
    check(type(v) == "number", "bar value number")
    -- A slider keeps its value inside its range, as the client's does.
    if o._type == "Slider" then
        if v < o._min then v = o._min elseif v > o._max then v = o._max end
    end
    if v ~= o._value then
        o._value = v
        fire(o, "OnValueChanged", v)
    end
end)
def("GetValue", VALUE, function(o) return o._value end)
-- A tooltip shows the lines MOCK.tips holds for an action slot: { { left, right }, ... }.
MOCK.tips = {}
local TIP = { GameTooltip = true }
def("SetOwner", TIP, function(o, owner, anchor) check(type(owner) == "table" and type(anchor) == "string", "tooltip owner"); o._owner = owner end)
def("ClearLines", TIP, function(o)
    o._lines = 0
    for i = 1, 8 do
        getglobal(o._name .. "TextLeft" .. i):SetText(nil)
        getglobal(o._name .. "TextRight" .. i):SetText(nil)
    end
end)
def("NumLines", TIP, function(o) return o._lines or 0 end)
def("SetAction", TIP, function(o, slot)
    check(o._owner, "SetAction on a tooltip without an owner")
    check(type(slot) == "number", "SetAction slot")
    local lines = MOCK.tips[slot] or {}
    o._lines = table.getn(lines)
    for i = 1, o._lines do
        getglobal(o._name .. "TextLeft" .. i):SetText(lines[i][1])
        getglobal(o._name .. "TextRight" .. i):SetText(lines[i][2])
    end
end)
local SLIDER = { Slider = true }
def("SetOrientation", SLIDER, function(o, v) check(v == "HORIZONTAL" or v == "VERTICAL", "orientation") end)
def("SetValueStep", SLIDER, function(o, v) check(type(v) == "number" and v > 0, "value step"); o._step = v end)
def("SetThumbTexture", SLIDER, function(o, p)
    check(type(p) == "string", "thumb texture")
    if not o._thumb then o._thumb = newObj("Texture", o) end
    o._thumb._tex = p
end)
def("GetThumbTexture", SLIDER, function(o) return o._thumb end)
def("SetStatusBarColor", BAR, function(o, r, g, b) check(type(r) == "number" and type(g) == "number" and type(b) == "number", "bar color"); o._color = { r, g, b } end)
def("GetStatusBarColor", BAR, function(o) return o._color[1], o._color[2], o._color[3], 1 end)
local TEX = { Texture = true }
def("SetTexture", TEX, function(o, p) check(p == nil or type(p) == "string", "texture path"); o._tex = p end)
def("GetTexture", TEX, function(o) return o._tex end)
def("SetVertexColor", TEX, function(o, r, g, b, a) check(type(r) == "number" and type(g) == "number" and type(b) == "number", "vertex color"); o._vc = { r, g, b, a } end)
def("SetTexCoord", TEX, function(o, a, b, c, d) check(type(a) == "number" and type(d) == "number", "texcoord"); o._coords = { a, b, c, d } end)
def("SetBlendMode", TEX, function(o, m) check(m == "ADD" or m == "BLEND" or m == "MOD" or m == "ALPHAKEY" or m == "DISABLE", "blend") end)
local FS = { FontString = true }
local TEXT = { FontString = true, Button = true, CheckButton = true }
def("SetFont", FS, function(o, path, size, flags) check(type(path) == "string" and type(size) == "number", "font"); o._font = size end)
def("SetText", TEXT, function(o, t)
    check(t == nil or type(t) == "string" or type(t) == "number", "SetText value " .. type(t))
    o._text = t and tostring(t) or nil
end)
def("GetText", TEXT, function(o) return o._text end)
def("SetTextColor", FS, function(o, r, g, b) check(type(r) == "number" and type(g) == "number" and type(b) == "number", "text color") end)
def("SetShadowColor", FS, function(o) end)
def("SetJustifyH", FS, function(o, j) check(j == "LEFT" or j == "CENTER" or j == "RIGHT", "justify") end)

UIParent = CreateFrame("Frame", "UIParent")
UIParent._w, UIParent._h = 1024, 768
WorldFrame = CreateFrame("Frame", "WorldFrame")
UISpecialFrames = { "GameMenuFrame" }

-- The game menu rungs the options window hooks into.
GameMenuFrame = CreateFrame("Frame", "GameMenuFrame", UIParent)
GameMenuFrame._h = 260
GameMenuButtonUIOptions = CreateFrame("Button", "GameMenuButtonUIOptions", GameMenuFrame, "GameMenuButtonTemplate")
GameMenuButtonKeybindings = CreateFrame("Button", "GameMenuButtonKeybindings", GameMenuFrame, "GameMenuButtonTemplate")
function HideUIPanel(f) f:Hide() end

-- The client's main bar: the run's spells in buttons 1-6, the racial in 12, two micro buttons.
MainMenuBar = CreateFrame("Frame", "MainMenuBar", UIParent)
MainMenuBarArtFrame = CreateFrame("Frame", "MainMenuBarArtFrame", MainMenuBar)
for i = 1, 12 do
    local b = CreateFrame("CheckButton", "ActionButton" .. i, MainMenuBarArtFrame, "ActionBarButtonTemplate")
    b._id = i
    b:EnableMouse(true)
    b:CreateTexture("ActionButton" .. i .. "Icon", "BACKGROUND")
    b:CreateTexture("ActionButton" .. i .. "NormalTexture", "ARTWORK")
end
ActionButton1:SetPoint("BOTTOMLEFT", MainMenuBarArtFrame, "BOTTOMLEFT", 8, 4)
CharacterMicroButton = CreateFrame("Button", "CharacterMicroButton", MainMenuBarArtFrame, "MainMenuBarMicroButton")
TalentMicroButton = CreateFrame("Button", "TalentMicroButton", MainMenuBarArtFrame, "MainMenuBarMicroButton")
function ActionButton_GetPagedID(b) return b:GetID() end

-- Equipped jewelry: the run puts picked rings, trinkets and amulets in these slots.
MOCK.slots = { NeckSlot = 2, Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14 }
MOCK.worn = {} -- slot id -> { icon, quality, start, duration }
function GetInventorySlotInfo(name) check(MOCK.slots[name], "unknown slot " .. tostring(name)); return MOCK.slots[name] end
function GetInventoryItemTexture(unit, id) check(unit == "player" and type(id) == "number", "inventory texture"); return MOCK.worn[id] and MOCK.worn[id].icon end
function GetInventoryItemQuality(unit, id) check(unit == "player" and type(id) == "number", "inventory quality"); return MOCK.worn[id] and MOCK.worn[id].quality end
function GetInventoryItemCooldown(unit, id)
    check(unit == "player" and type(id) == "number", "inventory cooldown")
    local w = MOCK.worn[id]
    if w and w.start then return w.start, w.duration, 1 end
    return 0, 0, 0
end

-- The stock layout pass. MOCK.layoutError makes it fail the way it does in Alterac Valley,
-- where "MinimapCluster" does not resolve (UIParent.lua:1754), before the dock and bags.
MOCK.layoutRuns, MOCK.dockUpdates, MOCK.bagAnchors = 0, 0, 0
function FCF_DockUpdate() MOCK.dockUpdates = MOCK.dockUpdates + 1 end
function updateContainerFrameAnchors() MOCK.bagAnchors = MOCK.bagAnchors + 1 end
function UIParent_ManageFramePositions()
    MOCK.layoutRuns = MOCK.layoutRuns + 1
    if MOCK.layoutError then error(MOCK.layoutError, 0) end
    FCF_DockUpdate()
    updateContainerFrameAnchors()
end

-- Settings and the camera's saved views. Until MOCK.camera is set, SaveView changes
-- nothing, like a client whose views do not follow the live camera.
MOCK.cvars = { cameraDistanceD = "13.88", cameraPitchD = "10.0", cameraYawD = "0.0" }
function GetCVar(k) check(type(k) == "string", "GetCVar name"); return MOCK.cvars[k] end
function SetCVar(k, v) check(type(k) == "string" and v ~= nil, "SetCVar"); MOCK.cvars[k] = tostring(v) end
function SaveView(n)
    check(n == 5, "SaveView view " .. tostring(n))
    if MOCK.camera then
        MOCK.cvars.cameraDistanceD = tostring(MOCK.camera.d)
        MOCK.cvars.cameraPitchD = tostring(MOCK.camera.p)
    end
end
function CameraZoomIn(v) if MOCK.camera then MOCK.camera.d = MOCK.camera.d - v end end
function CameraZoomOut(v) if MOCK.camera then MOCK.camera.d = MOCK.camera.d + v end end

-- The minimap and the world map position.
Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap._w, Minimap._h = 140, 140
MOCK.zoom = 0
Minimap.GetZoom = function(self) return MOCK.zoom end
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame:Hide()
MOCK.mapX, MOCK.mapY = 0, 0
function GetPlayerMapPosition(unit) check(unit == "player", "map position unit"); return MOCK.mapX, MOCK.mapY end
function SetMapToCurrentZone() MOCK.mapSet = (MOCK.mapSet or 0) + 1 end

-- A tooltip that checks its arguments.
GameTooltip = {
    SetOwner = function(self, owner, anchor) check(type(owner) == "table" and type(anchor) == "string", "tooltip owner"); MOCK.tipOwner = owner end,
    SetText = function(self, t, r, g, b) check(type(t) == "string", "tooltip text " .. type(t)); MOCK.tip = t end,
    AddLine = function(self, t, r, g, b, wrap) check(type(t) == "string" and type(r) == "number", "tooltip line") end,
    Show = function(self) MOCK.tipShown = true end,
    Hide = function(self) MOCK.tipShown = false end,
    SetInventoryItem = function(self, unit, id) check(unit == "player" and type(id) == "number", "tooltip inventory item"); MOCK.tipItem = id end,
}
GameFontNormal = { GetFont = function() return "Fonts\\FRIZQT__.TTF", 12 end }
DEFAULT_CHAT_FRAME = { AddMessage = function(self, msg) table.insert(MOCK.chat, msg) end }
SlashCmdList = {}

-- ---------------------------------------------------------------- unit state

MOCK.units = {
    player = { name = "Hero", class = "WARLOCK", level = 12, hp = 1500, hpm = 2000, xp = 300, xpm = 1000 },
}
local function U(unit) return MOCK.units[unit] end
function UnitExists(u) return U(u) and 1 or nil end
function UnitName(u) return U(u) and U(u).name end
function UnitClass(u) local x = U(u); if x then return x.class, x.class end end
function UnitLevel(u) return U(u) and U(u).level end
function UnitHealth(u) return U(u) and U(u).hp or 0 end
function UnitHealthMax(u) return U(u) and U(u).hpm or 0 end
function UnitIsDeadOrGhost(u) return U(u) and U(u).hp <= 0 and 1 or nil end
function UnitIsConnected(u) return U(u) and 1 or nil end
function UnitXP(u) return U(u).xp end
function UnitXPMax(u) return U(u).xpm end
function CheckInteractDistance(u, i) return U(u) and U(u).near and 1 or nil end
function TargetUnit(u) MOCK.targeted = u end
function GetNumPartyMembers()
    local n = 0
    for i = 1, 4 do if MOCK.units["party" .. i] then n = n + 1 end end
    return n
end
function ShowNameplates() MOCK.enemyPlates = true end
function HideNameplates() MOCK.enemyPlates = false end
function ShowFriendNameplates() MOCK.friendPlates = true end
function HideFriendNameplates() MOCK.friendPlates = false end

MOCK.buffs = {
    HELPFUL = { { tex = "Interface\\Icons\\Spell_Shadow_DemonArmor", left = 0, untilCancelled = 1 }, { tex = "Interface\\Icons\\Spell_Holy_PowerWordShield", left = 8.4, stacks = 3 } },
    HARMFUL = { { tex = "Interface\\Icons\\Spell_Frost_FrostNova", left = 2.2, dispel = "Magic" } },
}
local function auraFor(index)
    local h = table.getn(MOCK.buffs.HELPFUL)
    if index < h then return MOCK.buffs.HELPFUL[index + 1] end
    return MOCK.buffs.HARMFUL[index - h + 1]
end
function GetPlayerBuff(i, filter)
    local list = MOCK.buffs[filter]
    if not list or not list[i + 1] then return -1, nil end
    local index = i
    if filter == "HARMFUL" then index = i + table.getn(MOCK.buffs.HELPFUL) end
    return index, list[i + 1].untilCancelled
end
function GetPlayerBuffTexture(index) local a = auraFor(index); return a and a.tex end
function GetPlayerBuffApplications(index) local a = auraFor(index); return a and a.stacks or 0 end
function GetPlayerBuffTimeLeft(index) local a = auraFor(index); return a and a.left or 0 end
function GetPlayerBuffDispelType(index) local a = auraFor(index); return a and a.dispel end

MOCK.actions = {
    [1] = { tex = "Interface\\Icons\\Spell_Shadow_ShadowBolt", start = 999, dur = 4 },
    [2] = { tex = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", start = 0, dur = 0 },
    [12] = { tex = "Interface\\Icons\\Spell_Shadow_DeathCoil", start = 995, dur = 30 },
}
function HasAction(slot) return MOCK.actions[slot] and 1 or nil end
function GetActionTexture(slot) return MOCK.actions[slot] and MOCK.actions[slot].tex end
function GetActionCooldown(slot)
    local a = MOCK.actions[slot]
    if not a then return 0, 0, 0 end
    return a.start, a.dur, 1
end

-- ---------------------------------------------------------------- events

function MOCK.event(e, a1, a2, a3, a4)
    for i = 1, table.getn(MOCK.eventFrames) do
        local entry = MOCK.eventFrames[i]
        if entry.event == e and entry.frame._events[e] then
            local f = entry.frame._scripts.OnEvent
            if f then
                local pe, p1, p2, p3, p4, pt = event, arg1, arg2, arg3, arg4, this
                event, arg1, arg2, arg3, arg4, this = e, a1, a2, a3, a4, entry.frame
                f()
                event, arg1, arg2, arg3, arg4, this = pe, p1, p2, p3, p4, pt
            end
        end
    end
end

function MOCK.click(o) check(o._mouse, "clicked a frame without mouse"); fire(o, "OnClick", "LeftButton") end
function MOCK.wheel(o, delta) check(o._wheel, "wheel on a frame without mouse wheel"); fire(o, "OnMouseWheel", delta) end

function MOCK.addon(prefix, msg) MOCK.event("CHAT_MSG_ADDON", prefix, msg, "WHISPER", "Server") end

-- Runs every frame's OnUpdate for `frames` frames at `fps`.
function MOCK.run(frames, fps)
    local dt = 1 / (fps or 60)
    for n = 1, frames do
        MOCK.now = MOCK.now + dt
        for i = 1, table.getn(MOCK.frames) do
            local o = MOCK.frames[i]
            if o._scripts and o._scripts.OnUpdate and o._shown then fire(o, "OnUpdate", dt) end
        end
        if MOCK.onFrame then MOCK.onFrame(n) end
    end
end

-- A stock 1.12 name plate under WorldFrame.
function MOCK.plate(name, r, g, b, value)
    local p = CreateFrame("Frame", nil, WorldFrame)
    p:EnableMouse(true)
    local border = p:CreateTexture(nil, "BORDER")
    border:SetTexture("Interface\\Tooltips\\Nameplate-Border")
    local glow = p:CreateTexture(nil, "BORDER")
    glow:SetTexture("Interface\\Tooltips\\Nameplate-Glow")
    local fsName = p:CreateFontString(nil, "ARTWORK")
    fsName:SetText(name)
    local fsLevel = p:CreateFontString(nil, "ARTWORK")
    fsLevel:SetText("60")
    local skull = p:CreateTexture(nil, "ARTWORK")
    skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    p:SetWidth(128)
    p:SetHeight(32)
    local bar = CreateFrame("StatusBar", nil, p)
    bar:SetWidth(118)
    bar:SetHeight(8)
    bar:SetPoint("BOTTOM", p, "BOTTOM", 0, 5)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(value or 100)
    bar:SetStatusBarColor(r, g, b)
    p.mockName, p.mockBar = fsName, bar
    return p
end
