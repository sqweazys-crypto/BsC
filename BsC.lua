-- ============================================================
--  BACKROOMS CLOSET SUITE  v6.2
--  Full Uncompressed Build - Part 1/3
-- ============================================================

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local PathfindingService  = game:GetService("PathfindingService")
local Lighting            = game:GetService("Lighting")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local Workspace           = game:GetService("Workspace")
local HttpService         = game:GetService("HttpService")
local Stats               = game:GetService("Stats")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if _G.BCS_Unload then pcall(_G.BCS_Unload) end

-- ============================================================
--  STATE
-- ============================================================
local VERSION = "v6.2"
local running = true
local connections = {}
local sessionStart = os.clock()
local hasFS = (writefile ~= nil) and (readfile ~= nil) and (isfile ~= nil)

local State = {
    crateESP = true,
    boxESP = true,
    monsterESP = true,
    waypoints = true,
    pathLine = false,
    redroomsESP = true,
    redroomsNotify = true,
    codeHUD = true,
    heavyDoorMarkers = false,
    autoParry = false,
    fullbright = false,
    antiJumpscare = false,
    hideDestroyed = true,
    showHits = true,
    autoSave = false,
    toasts = true,
    showBosses = true,
    showHumans = true,
    showZombies = true,
}

local RARITIES = {
    {name = "Contractor-Grade", color = Color3.fromRGB(0, 100, 255),   enabled = true},
    {name = "Restricted",       color = Color3.fromRGB(150, 0, 255),   enabled = true},
    {name = "Specialist",       color = Color3.fromRGB(255, 100, 100), enabled = true},
    {name = "Prototype",        color = Color3.fromRGB(150, 0, 0),     enabled = true},
    {name = "Contraband",       color = Color3.fromRGB(255, 215, 0),   enabled = true},
    {name = "Common",           color = Color3.fromRGB(200, 200, 200), enabled = true},
    {name = "Field",            color = Color3.fromRGB(255, 150, 50),  enabled = true},
}

local WAYPOINTS_L0 = {
    {name = "Armory",        pos = Vector3.new(-858, 6, -320)},
    {name = "Armory 2",      pos = Vector3.new(-471, 6, 242)},
    {name = "Stash Box",     pos = Vector3.new(-356, 6, 494)},
    {name = "Printer Room",  pos = Vector3.new(-149, 6, 406)},
    {name = "Exit Room",     pos = Vector3.new(-265, 6, 605)},
    {name = "Big Rooms Noclip", pos = Vector3.new(-186, 6, -838)},
}
local WAYPOINTS_L1 = {
    {name = "Safe Room",       pos = Vector3.new(1430, 15, -1695)},
    {name = "Contraband Room", pos = Vector3.new(1480, 15, -1499)},
    {name = "Boiler Noclip",   pos = Vector3.new(1442, 15, -1534)},
}
local WAYPOINTS = {}
for _, w in ipairs(WAYPOINTS_L0) do table.insert(WAYPOINTS, w) end
for _, w in ipairs(WAYPOINTS_L1) do table.insert(WAYPOINTS, w) end

local REDROOMS_ENTRANCES = {
    {name = "Entrance 1", pos = Vector3.new(-838, 2, -643)},
    {name = "Entrance 2", pos = Vector3.new(-336, 2, -849)},
    {name = "Entrance 3", pos = Vector3.new(-135, 2, -425)},
    {name = "Entrance 4", pos = Vector3.new(-134, 2, 305)},
}
local REDROOMS_EXIT = {name = "Exit", pos = Vector3.new(2909, 370, 840)}

local HEAVY_DOOR_POS   = Vector3.new(2447.7, 377.3, 330.8)
local HEAVY_KEYPAD_POS = Vector3.new(2464.3, 375.4, 331.7)
local CODE_DISPLAY_POS = Vector3.new(-49.9, -24.9, -476.3)

local ATTACK_ANIMS = {
    ["rbxassetid://132062634440694"] = "Skin Stealer", ["rbxassetid://93447566042287"]  = "Wanderer/Skin Stealer",
    ["rbxassetid://16513826389"]     = "Wretch/Brute", ["rbxassetid://116270226290864"] = "Wretch/Brute",
    ["rbxassetid://115057255000463"] = "Wretch",       ["rbxassetid://103058445318313"] = "Wretch",
    ["rbxassetid://119638056060044"] = "Brute",        ["rbxassetid://99835657615739"]  = "Shrieker",
    ["rbxassetid://84561718813387"]  = "Bacteria/Lancelot", ["rbxassetid://127192843487284"] = "Bacteria/Lancelot",
}

local QOL = {
    cullDistance = 1500, keybind = Enum.KeyCode.RightShift, accent = Color3.fromRGB(255, 150, 50),
    log = {}, logMax = 60, toastDuration = 3.5, scale = nil, opacity = 0,
    parryHoldDuration = 0.08, parryEngageRange = 25, monsterCullDistance = 1000, configPath = "BCS_Config",
}

local SLOT_COUNT = 5
local SLOT_NAMES = {"Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5"}
local currentSlot, autoLoadEnabled, autoLoadSlot = 1, false, 1
local lastSaveTime = {}
local function getSlotPath(i) return QOL.configPath .. "_Slot" .. i .. ".json" end

local tracked, boxTracked, monsterTracked = {}, {}, {}
local pathParts, waypointAnchors, waypointUI, wpStates = {}, {}, {}, {}
local selectedWaypoint, entranceMarkers, exitMarker = nil, {}, nil

local Live = { boxes = 0, crates = 0, monsters = 0, counts = {}, nearestName = nil, nearestDist = nil, codeValue = nil, activeEntrances = 0 }

local billboardContainer, waypointContainer, monsterContainer
local gui, mainFrame
local guiScaleValue = 1
local toggleGui = function() end
local notify = function() end

-- ============================================================
--  THEME
-- ============================================================
local Theme = {
    bg        = Color3.fromRGB(12, 12, 12),
    panel     = Color3.fromRGB(18, 18, 18),
    card      = Color3.fromRGB(24, 24, 24),
    cardHover = Color3.fromRGB(32, 32, 32),
    stroke    = Color3.fromRGB(50, 50, 50),
    text      = Color3.fromRGB(240, 240, 240),
    subtext   = Color3.fromRGB(140, 140, 140),
    off       = Color3.fromRGB(60, 60, 60),
    accent    = QOL.accent,
    accent2   = Color3.fromRGB(255, 180, 100),
    good      = Color3.fromRGB(80, 255, 120),
    bad       = Color3.fromRGB(255, 80, 80),
    warn      = Color3.fromRGB(255, 200, 80),
}

local accentListeners = {}
local function onAccent(fn) table.insert(accentListeners, fn); fn() end
local function setAccent(color)
    local h, s, v = color:ToHSV()
    Theme.accent = color
    Theme.accent2 = Color3.fromHSV((h + 0.08) % 1, s, v)
    for _, fn in ipairs(accentListeners) do pcall(fn) end
end
setAccent(QOL.accent)

-- ============================================================
--  HELPERS
-- ============================================================
local function create(class, props, children)
    local obj = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else obj[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = obj end
    if parent then obj.Parent = parent end
    return obj
end

local function tween(obj, t, props, style, dir)
    local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function round(r) return create("UICorner", {CornerRadius = UDim.new(0, r or 4)}) end
local function stroke(color, thick, trans)
    return create("UIStroke", {Color = color, Thickness = thick or 1, Transparency = trans or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function pad(l, t, r, b)
    return create("UIPadding", {PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b)})
end
local function cardGradient()
    return create("UIGradient", {Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 220)), Rotation = 90})
end

local orderCounters = setmetatable({}, {__mode = "k"})
local function nextOrder(parent)
    orderCounters[parent] = (orderCounters[parent] or 0) + 1
    return orderCounters[parent]
end

local function getRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function track(conn)
    table.insert(connections, conn)
    return conn
end

local function fmtTime(sec)
    sec = math.floor(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end

local function getPing()
    local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and math.floor(v) or nil
end

local function getPos(obj)
    if obj:IsA("Model") then
        local ok, p = pcall(function() return obj:GetPivot().Position end)
        if ok then return p end
    end
    return obj.Position
end

local function hasTrackedAncestor(obj, tbl, stop)
    local p = obj.Parent
    while p and p ~= stop and p ~= Workspace do
        if tbl[p] then return true end
        p = p.Parent
    end
    return false
end

-- ============================================================
--  NOTIFICATIONS
-- ============================================================
local toastGui, toastHolder
local activeToasts = {}
local toastCount = 0
local logDirty, logUnread = false, 0

local function ensureToasts()
    if toastGui and toastGui.Parent then return end
    toastGui = create("ScreenGui", {Name = "BCS_Toasts", ResetOnSpawn = false, DisplayOrder = 1100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui})
    toastHolder = create("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(330, 600), BackgroundTransparency = 1, Parent = toastGui,
    }, {
        create("UIListLayout", {Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder}),
    })
end

local function dismissToast(t)
    if t.dead then return end
    t.dead = true
    for i, x in ipairs(activeToasts) do
        if x == t then table.remove(activeToasts, i); break end
    end
    if t.inner.Parent then
        tween(t.inner, 0.25, {Position = UDim2.fromOffset(360, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    end
    task.delay(0.25, function()
        if t.wrap.Parent then tween(t.wrap, 0.2, {Size = UDim2.new(1, 0, 0, 0)}) end
        task.delay(0.22, function() if t.wrap.Parent then t.wrap:Destroy() end end)
    end)
end

notify = function(title, msg, color, icon, duration)
    color = color or Theme.accent
    if not icon then
        if color == Theme.good then icon = "✓"
        elseif color == Theme.bad then icon = "✕"
        elseif color == Theme.warn then icon = "!"
        else icon = "i" end
    end
    table.insert(QOL.log, 1, {title = title, msg = msg or "", color = color, icon = icon, time = os.time()})
    while #QOL.log > QOL.logMax do table.remove(QOL.log) end
    logDirty = true
    logUnread += 1

    if not running or not State.toasts then return end
    ensureToasts()
    duration = duration or QOL.toastDuration

    while #activeToasts >= 5 do dismissToast(activeToasts[1]) end

    toastCount += 1
    local wrap = create("Frame", {Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = toastCount, Parent = toastHolder})
    local inner = create("TextButton", {
        Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(360, 0), BackgroundColor3 = Theme.panel, AutoButtonColor = false,
        Text = "", BorderSizePixel = 0, ClipsDescendants = true, Parent = wrap,
    }, {
        round(4), stroke(color, 1.2, 0.35),
        create("UIGradient", {Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(color, 0.2), Color3.new(1, 1, 1)), Rotation = 0}),
    })
    create("Frame", {Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(12, 14), BackgroundColor3 = Theme.panel:Lerp(color, 0.25), BorderSizePixel = 0, Parent = inner}, {
        round(4),
        create("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = icon, TextColor3 = color, TextSize = 17, Font = Enum.Font.GothamBold}),
    })
    create("TextLabel", {Size = UDim2.new(1, -70, 0, 18), Position = UDim2.fromOffset(58, 12), BackgroundTransparency = 1, Text = title, TextColor3 = Theme.text, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = inner})
    create("TextLabel", {Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(58, 31), BackgroundTransparency = 1, Text = msg or "", TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = inner})
    local bar = create("Frame", {Size = UDim2.new(1, -24, 0, 2), Position = UDim2.new(0, 12, 1, -7), BackgroundColor3 = color, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = inner}, {round(2)})

    local t = {wrap = wrap, inner = inner}
    table.insert(activeToasts, t)
    inner.MouseButton1Click:Connect(function() dismissToast(t) end)

    tween(inner, 0.45, {Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Back)
    tween(bar, duration, {Size = UDim2.new(0, 0, 0, 2)}, Enum.EasingStyle.Linear)
    task.delay(duration, function() dismissToast(t) end)
end

-- ============================================================
--  CONFIG
-- ============================================================
local function buildSaveData()
    local data = {
        version = VERSION, slotName = SLOT_NAMES[currentSlot], timestamp = os.time(),
        rarities = {}, wp = {}, state = {}, autoLoadEnabled = autoLoadEnabled, autoLoadSlot = autoLoadSlot,
        qol = {
            cullDistance = QOL.cullDistance, monsterCullDistance = QOL.monsterCullDistance,
            keybind = QOL.keybind.Name, accent = {QOL.accent.R, QOL.accent.G, QOL.accent.B},
            toastDuration = QOL.toastDuration, scale = QOL.scale, opacity = QOL.opacity,
            parryHoldDuration = QOL.parryHoldDuration, parryEngageRange = QOL.parryEngageRange,
        },
    }
    for _, r in ipairs(RARITIES) do data.rarities[r.name] = r.enabled end
    for _, w in ipairs(WAYPOINTS) do data.wp[w.name] = wpStates[w.name] end
    for k, v in pairs(State) do data.state[k] = v end
    return data
end

local function applySaveData(data)
    if type(data) ~= "table" then return false, "invalid data" end
    if data.rarities then
        for _, r in ipairs(RARITIES) do
            if data.rarities[r.name] ~= nil then r.enabled = data.rarities[r.name] end
        end
    end
    if data.wp then
        for _, w in ipairs(WAYPOINTS) do
            if data.wp[w.name] ~= nil then wpStates[w.name] = data.wp[w.name] end
        end
    end
    if data.state then
        for k, v in pairs(data.state) do
            if State[k] ~= nil then State[k] = v end
        end
    end
    if data.autoLoadEnabled ~= nil then autoLoadEnabled = data.autoLoadEnabled end
    if data.autoLoadSlot ~= nil then autoLoadSlot = data.autoLoadSlot end
    if data.qol then
        QOL.cullDistance = data.qol.cullDistance or QOL.cullDistance
        QOL.monsterCullDistance = data.qol.monsterCullDistance or QOL.monsterCullDistance
        QOL.toastDuration = data.qol.toastDuration or QOL.toastDuration
        QOL.scale = data.qol.scale or QOL.scale
        QOL.opacity = data.qol.opacity or QOL.opacity
        QOL.parryHoldDuration = data.qol.parryHoldDuration or QOL.parryHoldDuration
        QOL.parryEngageRange = data.qol.parryEngageRange or QOL.parryEngageRange
        if data.qol.keybind then
            local ok, key = pcall(function() return Enum.KeyCode[data.qol.keybind] end)
            if ok and key then QOL.keybind = key end
        end
        if data.qol.accent then
            QOL.accent = Color3.new(data.qol.accent[1], data.qol.accent[2], data.qol.accent[3])
            setAccent(QOL.accent)
        end
    end
    return true
end

local function saveSlot(slotIndex)
    if not hasFS then return false, "no file access" end
    local ok, err = pcall(function()
        writefile(getSlotPath(slotIndex), HttpService:JSONEncode(buildSaveData()))
    end)
    if ok then lastSaveTime[slotIndex] = os.time() end
    return ok, err
end

local function loadSlot(slotIndex)
    if not hasFS then return false, "no file access" end
    local path = getSlotPath(slotIndex)
    if not isfile(path) then return false, "no save" end
    local ok, raw = pcall(readfile, path)
    if not ok or not raw then return false, "read failed" end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return false, "invalid json" end
    local ok3 = applySaveData(data)
    if ok3 and data.timestamp then lastSaveTime[slotIndex] = data.timestamp end
    return ok3
end

local function deleteSlot(slotIndex)
    if not hasFS or not delfile then return false end
    local path = getSlotPath(slotIndex)
    if isfile(path) then
        pcall(delfile, path)
        lastSaveTime[slotIndex] = nil
        return true
    end
    return false
end

local function getSlotStatus(slotIndex)
    if not hasFS or not isfile then return "empty" end
    if not isfile(getSlotPath(slotIndex)) then return "empty" end
    if lastSaveTime[slotIndex] then
        local ago = os.time() - lastSaveTime[slotIndex]
        if ago < 60 then return "saved " .. ago .. "s ago"
        elseif ago < 3600 then return "saved " .. math.floor(ago/60) .. "m ago"
        else return "saved " .. math.floor(ago/3600) .. "h ago" end
    end
    return "has data"
end

local saveToken = 0
local function scheduleAutoSave()
    if not State.autoSave or not hasFS then return end
    saveToken += 1
    local my = saveToken
    task.delay(2.0, function()
        if my == saveToken and running then saveSlot(currentSlot) end
    end)
end

-- ============================================================
--  ESP HELPERS
-- ============================================================
local function parseRarity(name)
    local lower = name:lower()
    if lower:find("unobtainable") then return "Unobtainable" end
    if lower:find("exclusive") then return "Exclusive" end
    if lower:find("contraband") then return "Contraband" end
    if lower:find("prototype") then return "Prototype" end
    if lower:find("specialist") then return "Specialist" end
    if lower:find("restricted") then return "Restricted" end
    if lower:find("contractor") then return "Contractor-Grade" end
    if lower:find("field") then return "Field-Grade" end
    if lower:find("standard") then return "Standard Issue" end
    if lower:find("common") then return "Standard Issue" end
    return nil
end

local function getRarityColor(rarityName)
    for _, r in ipairs(RARITIES) do
        if r.name == rarityName then return r.color end
    end
    return Color3.new(1, 1, 1)
end

local function getRarityState(rarityName)
    for _, r in ipairs(RARITIES) do
        if r.name == rarityName then return r.enabled end
    end
    return false
end

local function getLevelFolder(name)
    local g = Workspace:FindFirstChild("Game")
    g = g and g:FindFirstChild("Maps")
    g = g and g:FindFirstChild("Level0")
    return g and g:FindFirstChild(name)
end

local function rarityFromHierarchy(obj, stop)
    local cur = obj
    while cur and cur ~= stop and cur ~= Workspace do
        local r = parseRarity(cur.Name)
        if r then return r end
        cur = cur.Parent
    end
    return nil
end

local function makeESPPill(size, offset, adornee, color, titleText, subText, container)
    local billboard = create("BillboardGui", {
        Name = "BCS_Billboard", Size = size, StudsOffset = offset,
        AlwaysOnTop = true, LightInfluence = 0, Adornee = adornee, Parent = container,
    })
    local pill = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.card, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = billboard}, {
        round(4), stroke(color, 1.5, 0.15),
    })
    create("TextLabel", {Size = UDim2.new(1, 0, 0.58, 0), BackgroundTransparency = 1, Text = titleText, TextColor3 = color, TextSize = 14, Font = Enum.Font.GothamBold, Parent = pill})
    local info = create("TextLabel", {Size = UDim2.new(1, 0, 0.4, 0), Position = UDim2.fromScale(0, 0.58), BackgroundTransparency = 1, Text = subText, TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, Parent = pill})
    return billboard, info
end

-- ============================================================
--  CLIENT-SAFE HIGHLIGHT FACTORY
-- ============================================================
local function createHighlight(adornee, color, transparency)
    if not adornee then return nil end
    local hl = Instance.new("Highlight")
    hl.Name = "BCS_SafeHighlight"
    hl.Adornee = adornee
    hl.FillColor = color
    hl.FillTransparency = transparency or 0.7
    hl.OutlineColor = color
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = playerGui -- Lives in PlayerGui, invisible to server
    return hl
end

-- ============================================================
--  BOX ESP
-- ============================================================
local function isBoxDestroyed(box)
    if not box.Parent then return true end
    
    -- 1. Check for the game's built-in Destroyed bool
    local d = box:FindFirstChild("Destroyed", true)
    if d and d:IsA("BoolValue") and d.Value then return true end
    
    -- 2. Check if the primary part is invisible
    local part = nil
    if box:IsA("BasePart") then
        part = box
    elseif box:IsA("Model") then
        part = box.PrimaryPart or box:FindFirstChildWhichIsA("BasePart", true)
    end
    
    if part and part.Transparency >= 1 then return true end
    
    return false
end

local function getBoxHits(box)
    local h = box:FindFirstChild("Hits", true)
    return h and h:IsA("NumberValue") and h.Value or nil
end

local function isBoxName(obj)
    local n = obj.Name:lower()
    return n:find("rarity") ~= nil or n:find("randomized") ~= nil
end

local function removeBoxESP(box)
    local data = boxTracked[box]
    if data then
        if data.billboard then data.billboard:Destroy() end
        boxTracked[box] = nil
    end
end

local function clearBoxes()
    for box in pairs(boxTracked) do removeBoxESP(box) end
end

local function applyBoxESP(box)
    if not State.boxESP or not billboardContainer or not box.Parent then return end
    if boxTracked[box] then return end
    local folder = getLevelFolder("Boxes")
    if hasTrackedAncestor(box, boxTracked, folder) then return end
    if State.hideDestroyed and isBoxDestroyed(box) then return end

    local rarityName = rarityFromHierarchy(box, folder) or "Common"
    if not getRarityState(rarityName) then return end

    local color = getRarityColor(rarityName)
    local adornee = box
    if box:IsA("Model") then adornee = box.PrimaryPart or box:FindFirstChildWhichIsA("BasePart", true) end
    if not adornee then return end

    local billboard, info = makeESPPill(UDim2.fromOffset(190, 42), Vector3.new(0, 3, 0), adornee, color, "📦 " .. rarityName, "", billboardContainer)
    boxTracked[box] = {color = color, billboard = billboard, infoLabel = info, adornee = adornee, rarityName = rarityName}
    
    table.insert(connections, adornee:GetPropertyChangedSignal("Transparency"):Connect(function()
        if adornee.Transparency >= 1 then removeBoxESP(box) end
    end))
end

local function scanBoxes()
    if not State.boxESP then return end
    local folder = getLevelFolder("Boxes")
    if not folder then return end
    for _, obj in ipairs(folder:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and isBoxName(obj) then
            applyBoxESP(obj)
        end
    end
    for box in pairs(boxTracked) do
        if not box.Parent then removeBoxESP(box) end
    end
end

-- ============================================================
--  CRATE ESP
-- ============================================================
local function removeESP(crate)
    local data = tracked[crate]
    if data then
        if data.billboard then data.billboard:Destroy() end
        tracked[crate] = nil
    end
end

local function clearCrates()
    for crate in pairs(tracked) do removeESP(crate) end
end

local function clearAllESP()
    clearCrates()
    clearBoxes()
    for m in pairs(monsterTracked) do
        if monsterTracked[m].billboard then monsterTracked[m].billboard:Destroy() end
    end
    tracked, boxTracked, monsterTracked = {}, {}, {}
    if billboardContainer then
        for _, c in ipairs(billboardContainer:GetChildren()) do c:Destroy() end
    end
end

local function isCrate(obj)
    return obj.Name:lower():find("lockpickcrate") ~= nil
end

local function applyESP(crate)
    if not State.crateESP or not billboardContainer or not crate.Parent then return end
    if tracked[crate] then return end
    local folder = getLevelFolder("LockpickCrates")
    if hasTrackedAncestor(crate, tracked, folder) then return end

    local rarityName = rarityFromHierarchy(crate, folder) or "Contractor-Grade"
    if not getRarityState(rarityName) then return end

    local root = getRoot()
    if root and (root.Position - getPos(crate)).Magnitude > QOL.cullDistance then return end

    local color = getRarityColor(rarityName)
    local adornee = crate
    if crate:IsA("Model") then adornee = crate.PrimaryPart or crate:FindFirstChildWhichIsA("BasePart", true) end
    if not adornee then return end

    local billboard, info = makeESPPill(UDim2.fromOffset(200, 44), Vector3.new(0, 5, 0), adornee, color, "🔒 " .. rarityName, "-- studs", billboardContainer)
    tracked[crate] = {color = color, billboard = billboard, distLabel = info, adornee = adornee, rarityName = rarityName}
end

local function scanCrates()
    if not State.crateESP then return end
    local folder = getLevelFolder("LockpickCrates")
    if not folder then return end
    for _, obj in ipairs(folder:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and isCrate(obj) then
            applyESP(obj)
        end
    end
    for crate in pairs(tracked) do
        if not crate.Parent then removeESP(crate) end
    end
end

local watchers = {box = false, crate = false}
local function ensureWatchers()
    if not watchers.box then
        local f = getLevelFolder("Boxes")
        if f then
            watchers.box = true
            track(f.DescendantAdded:Connect(function(obj)
                task.wait(0.1)
                if running and obj.Parent and (obj:IsA("Model") or obj:IsA("BasePart")) and isBoxName(obj) then applyBoxESP(obj) end
            end))
        end
    end
    if not watchers.crate then
        local f = getLevelFolder("LockpickCrates")
        if f then
            watchers.crate = true
            track(f.DescendantAdded:Connect(function(obj)
                task.wait(0.1)
                if running and obj.Parent and (obj:IsA("Model") or obj:IsA("BasePart")) and isCrate(obj) then applyESP(obj) end
            end))
        end
    end
end

-- ============================================================
--  MONSTER ESP
-- ============================================================
local MONSTER_IGNORE = {
    "vendor", "armory", "mechanic", "researcher", "turret",
    "rig", "dummy", "neutral",
}
local MONSTER_IGNORE_CATS = {"wanderer", "recon"}

local function shouldIgnoreMonster(model)
    local cur = model
    local depth = 0
    while cur and cur ~= Workspace and depth < 10 do
        local lower = cur.Name:lower()
        for _, kw in ipairs(MONSTER_IGNORE) do
            if lower:find(kw, 1, true) then return true end
        end
        for _, kw in ipairs(MONSTER_IGNORE_CATS) do
            if lower:find(kw, 1, true) then return true end
        end
        cur = cur.Parent
        depth = depth + 1
    end
    return false
end

local function classifyMonster(obj)
    local path = obj:GetFullName():lower()
    if path:find("boss") then return "boss", Theme.accent end
    if path:find("phantom") then return "phantom", Color3.fromRGB(150, 80, 200) end
    if path:find("shrieker") then return "zombie", Color3.fromRGB(255, 60, 60) end
    if path:find("zombie") then return "zombie", Color3.fromRGB(120, 220, 120) end
    if path:find("skin stealer") or path:find("dissolver") or path:find("wretch") or path:find("brute") then
        return "zombie", Color3.fromRGB(255, 100, 200)
    end
    if path:find("bandit") or path:find("lfsg") then return "human", Color3.fromRGB(255, 150, 100) end
    return "misc", Theme.text
end

local function isMonster(obj)
    if not obj:IsA("Model") then return false end
    if not obj:FindFirstChildOfClass("Humanoid") then return false end
    if not obj:FindFirstChild("HumanoidRootPart") then return false end
    if player.Character == obj then return false end
    if Players:GetPlayerFromCharacter(obj) then return false end
    if shouldIgnoreMonster(obj) then return false end
    return true
end

local function removeMonsterESP(npc)
    local data = monsterTracked[npc]
    if data then
        if data.billboard then data.billboard:Destroy() end
        monsterTracked[npc] = nil
    end
end

local function clearMonsters()
    for npc in pairs(monsterTracked) do removeMonsterESP(npc) end
end

local function applyMonsterESP(npc)
    if not State.monsterESP or not monsterContainer or not npc.Parent then return end
    if monsterTracked[npc] then return end
    if not isMonster(npc) then return end

    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cat, color = classifyMonster(npc)
    if cat == "boss" and not State.showBosses then return end
    if cat == "human" and not State.showHumans then return end
    if cat == "zombie" and not State.showZombies then return end

    local billboard = create("BillboardGui", {
        Name = "BCS_Billboard", Size = UDim2.fromOffset(160, 38), StudsOffset = Vector3.new(0, 3.5, 0),
        AlwaysOnTop = true, LightInfluence = 0, Adornee = hrp, Parent = monsterContainer,
    })
    local pill = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.card, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = billboard}, {
        round(4), stroke(color, 1.5, 0.1),
    })
    local nameLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0.55, 0), BackgroundTransparency = 1, Text = npc.Name, TextColor3 = color, TextSize = 13, Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd, Parent = pill})
    local infoLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0.45, 0), Position = UDim2.fromScale(0, 0.55), BackgroundTransparency = 1, Text = "--", TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, Parent = pill})

    monsterTracked[npc] = {billboard = billboard, nameLabel = nameLabel, infoLabel = infoLabel, hrp = hrp, color = color}
end

local function getNPCFolders()
    local folders = {}
    local a = Workspace:FindFirstChild("NPCs")
    if a then table.insert(folders, a) end
    local g = Workspace:FindFirstChild("Game")
    if g then
        local b = g:FindFirstChild("NPCs")
        if b then table.insert(folders, b) end
    end
    return folders
end

local function scanMonsters()
    if not State.monsterESP then return end
    for _, folder in ipairs(getNPCFolders()) do
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj:IsA("Model") and isMonster(obj) and not monsterTracked[obj] then
                applyMonsterESP(obj)
            end
        end
    end
    for npc in pairs(monsterTracked) do
        if not npc.Parent or shouldIgnoreMonster(npc) then
            removeMonsterESP(npc)
        end
    end
end

-- ============================================================
--  WAYPOINTS
-- ============================================================
local function buildWaypoints()
    for _, wp in ipairs(WAYPOINTS) do
        if wpStates[wp.name] == nil then wpStates[wp.name] = true end
        local anchor = create("Part", {
            Name = "Waypoint_" .. wp.name, Size = Vector3.new(0.1, 0.1, 0.1), Position = wp.pos,
            Anchored = true, CanCollide = false, Transparency = 1, Parent = Workspace.CurrentCamera,
        })
        waypointAnchors[wp.name] = anchor

        local billboard = create("BillboardGui", {
            Name = "WaypointBillboard_" .. wp.name, Size = UDim2.fromOffset(240, 34), StudsOffset = Vector3.new(0, 6, 0),
            AlwaysOnTop = true, LightInfluence = 0, Adornee = anchor,
            Enabled = State.waypoints and wpStates[wp.name], Parent = waypointContainer,
        })
        local pill = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.card, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = billboard}, {
            round(4), stroke(Theme.accent2, 1.5, 0.15),
        })
        local label = create("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "📍 " .. wp.name, TextColor3 = Theme.accent2, TextSize = 14, Font = Enum.Font.GothamBold, Parent = pill})
        waypointUI[wp.name] = {billboard = billboard, label = label, stroke = pill:FindFirstChildOfClass("UIStroke")}
    end
end

-- ============================================================
--  REDROOMS MARKERS
-- ============================================================
local IDLE_COLOR    = Color3.fromRGB(150, 70, 230)
local ACTIVE_COLOR  = Color3.fromRGB(255, 60, 60)
local UNKNOWN_COLOR = Color3.fromRGB(140, 140, 150)
local EXIT_COLOR    = Color3.fromRGB(0, 255, 110)

local function stateColor(state)
    if state == "active" then return ACTIVE_COLOR end
    if state == "idle" then return IDLE_COLOR end
    return UNKNOWN_COLOR
end

local function buildRedroomsMarker(name, pos, color, text)
    local anchor = create("Part", {
        Name = "BCS_Anchor_" .. (name:gsub("%s", "_")), Size = Vector3.new(0.1, 0.1, 0.1), Position = pos,
        Anchored = true, CanCollide = false, Transparency = 1, Parent = Workspace.CurrentCamera,
    })
    local billboard = create("BillboardGui", {
        Name = "BCS_Billboard_Redrooms", Size = UDim2.fromOffset(250, 52), StudsOffset = Vector3.new(0, 5, 0),
        AlwaysOnTop = true, LightInfluence = 0, Adornee = anchor, Enabled = State.redroomsESP, Parent = billboardContainer,
    })
    local pill = create("Frame", {Size = UDim2.fromScale(1, 0.75), BackgroundColor3 = Theme.card, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = billboard}, {
        round(4), stroke(color, 1.5, 0.3),
    })
    local label = create("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextColor3 = color, TextSize = 15, Font = Enum.Font.GothamBold, Parent = pill})
    local distLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0.25, 0), Position = UDim2.fromScale(0, 0.75), BackgroundTransparency = 1, Text = "-- studs", TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, Parent = billboard})
    return {
        anchor = anchor, billboard = billboard, label = label, distLabel = distLabel,
        stroke = pill:FindFirstChildOfClass("UIStroke"), pos = pos, name = name,
        prompt = nil, lastState = nil, state = "unknown",
    }
end

local function applyRedroomsState(marker, state)
    marker.state = state
    local col = stateColor(state)
    marker.label.TextColor3 = col
    marker.stroke.Color = col
    if state == "active" then
        marker.label.Text = "🚪 " .. marker.name .. " — ACTIVE"
        marker.stroke.Transparency = 0
    elseif state == "idle" then
        marker.label.Text = "🚪 " .. marker.name .. " — Idle"
        marker.stroke.Transparency = 0.3
    else
        marker.label.Text = "🚪 " .. marker.name .. " — ?"
        marker.stroke.Transparency = 0.5
    end
end

local function buildRedrooms()
    for _, ent in ipairs(REDROOMS_ENTRANCES) do
        entranceMarkers[ent.name] = buildRedroomsMarker(ent.name, ent.pos, UNKNOWN_COLOR, "🚪 " .. ent.name .. " — ?")
    end
    exitMarker = buildRedroomsMarker(REDROOMS_EXIT.name, REDROOMS_EXIT.pos, EXIT_COLOR, "🚪 EXIT")
    exitMarker.state = "exit"
end

local function registerPrompt(promptPart)
    if not promptPart:IsA("BasePart") then return end
    local prompt = promptPart:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return end

    local bestMarker, bestDist = nil, 50
    for _, marker in pairs(entranceMarkers) do
        local d = (promptPart.Position - marker.pos).Magnitude
        if d < bestDist then bestDist = d; bestMarker = marker end
    end
    if not bestMarker then return end

    bestMarker.prompt = prompt
    bestMarker.lastState = prompt.Enabled
    applyRedroomsState(bestMarker, prompt.Enabled and "active" or "idle")

    track(prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not bestMarker.prompt then return end
        if bestMarker.lastState ~= prompt.Enabled then
            bestMarker.lastState = prompt.Enabled
            applyRedroomsState(bestMarker, prompt.Enabled and "active" or "idle")
            if prompt.Enabled and State.redroomsNotify then
                notify("Redrooms entrance active", bestMarker.name, ACTIVE_COLOR, "🚪", 7)
            end
        end
    end))
    track(prompt.AncestryChanged:Connect(function()
        if not prompt:IsDescendantOf(Workspace) then
            bestMarker.prompt = nil
            bestMarker.lastState = nil
            applyRedroomsState(bestMarker, "unknown")
        end
    end))
end

local redroomsWatching = false
local function setupRedroomsWatcher()
    if redroomsWatching then return true end
    local folder = getLevelFolder("CustomScripts")
    folder = folder and folder:FindFirstChild("Redrooms")
    local prompts = folder and folder:FindFirstChild("Prompts")
    if not prompts then return false end
    redroomsWatching = true
    for _, child in ipairs(prompts:GetChildren()) do registerPrompt(child) end
    track(prompts.ChildAdded:Connect(function(obj) task.wait(0.2); registerPrompt(obj) end))
    return true
end

-- ============================================================
--  CODE HUD & HEAVY DOOR
-- ============================================================
local codeHUDGui, codeHUDLabel, codeHUDStroke
local cachedCode, codeLocked = nil, false

local function findCodeLabel()
    local node = Workspace:FindFirstChild("Game")
    node = node and node:FindFirstChild("Maps")
    node = node and node:FindFirstChild("Level0")
    node = node and node:FindFirstChild("Redrooms")
    node = node and node:FindFirstChild("Puzzles")
    node = node and node:FindFirstChild("HeavyDoorPuzzle")
    node = node and node:FindFirstChild("Code")
    if node then
        local s = node:FindFirstChildOfClass("SurfaceGui")
        if s then
            local tl = s:FindFirstChildOfClass("TextLabel")
            if tl then return tl end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Text and #obj.Text >= 4 and #obj.Text <= 20 then
            if obj.Text:match("^%d+$") and obj:GetFullName():find("HeavyDoorPuzzle") then
                return obj
            end
        end
    end
    return nil
end

local function ensureCodeHUD()
    if codeHUDGui and codeHUDGui.Parent then return end
    codeHUDGui = create("ScreenGui", {Name = "CodeHUD", ResetOnSpawn = false, DisplayOrder = 9999, Parent = playerGui})
    local frame = create("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(340, 60), BackgroundColor3 = Theme.bg, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = codeHUDGui}, {round(4)})
    codeHUDStroke = stroke(Theme.accent, 2, 0); codeHUDStroke.Parent = frame
    create("TextLabel", {Size = UDim2.new(1, 0, 0.4, 0), BackgroundTransparency = 1, Text = "🔐 HEAVY DOOR CODE", TextColor3 = Theme.subtext, TextSize = 12, Font = Enum.Font.GothamBold, Parent = frame})
    codeHUDLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.fromScale(0, 0.4), BackgroundTransparency = 1, Text = "searching...", TextColor3 = Theme.text, TextSize = 26, Font = Enum.Font.Code, Parent = frame})
end

local function updateCodeHUD()
    if not State.codeHUD then
        if codeHUDGui then codeHUDGui.Enabled = false end
        return
    end
    ensureCodeHUD()
    codeHUDGui.Enabled = true
    if codeLocked and cachedCode then
        codeHUDLabel.Text = cachedCode
        codeHUDLabel.TextColor3 = Theme.good
        codeHUDStroke.Color = Theme.good
        Live.codeValue = cachedCode
        return
    end
    local tl = findCodeLabel()
    if tl and tl.Text and tl.Text:match("^%d+$") then
        if #tl.Text >= 6 and #tl.Text <= 10 and tl.Text ~= cachedCode then
            cachedCode = tl.Text
            codeHUDLabel.Text = cachedCode
            codeHUDLabel.TextColor3 = Theme.good
            codeHUDStroke.Color = Theme.good
            Live.codeValue = cachedCode
            notify("Code captured", "Door code: " .. cachedCode, Theme.good)
            codeLocked = true
        end
    elseif cachedCode then
        codeHUDLabel.Text = cachedCode
        codeHUDLabel.TextColor3 = Theme.accent
        codeHUDStroke.Color = Theme.accent
    else
        codeHUDLabel.Text = "not seen yet"
        codeHUDLabel.TextColor3 = Theme.bad
        codeHUDStroke.Color = Theme.bad
    end
end

task.spawn(function()
    while running do
        task.wait(2)
        if game.JobId ~= game.JobId then
            codeLocked = false
            cachedCode = nil
        end
    end
end)

local heavyDoorFolder = nil
local heavyDoorMarkers = {}

local function buildHeavyDoorMarkers()
    if heavyDoorFolder then return end
    heavyDoorFolder = create("Folder", {Name = "BCS_HeavyDoor", Parent = Workspace.CurrentCamera})

    local function makeMarker(pos, color, label)
        local part = create("Part", {
            Name = "HeavyDoorMarker", Size = Vector3.new(1, 1, 1), Position = pos,
            Anchored = true, CanCollide = false, Material = Enum.Material.Neon,
            Color = color, Shape = Enum.PartType.Ball, Transparency = 0.3, Parent = heavyDoorFolder,
        })
        local bb = create("BillboardGui", {Size = UDim2.fromOffset(260, 44), StudsOffset = Vector3.new(0, 3, 0), AlwaysOnTop = true, Parent = part})
        local frame = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.bg, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = bb}, {round(4), stroke(color, 1.5, 0.1)})
        create("TextLabel", {Size = UDim2.new(1, 0, 0.6, 0), BackgroundTransparency = 1, Text = label, TextColor3 = color, TextSize = 13, Font = Enum.Font.GothamBold, Parent = frame})
        local info = create("TextLabel", {Size = UDim2.new(1, 0, 0.4, 0), Position = UDim2.fromScale(0, 0.6), BackgroundTransparency = 1, Text = "--", TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, Parent = frame})
        table.insert(heavyDoorMarkers, {part = part, info = info})
    end

    makeMarker(HEAVY_DOOR_POS, Theme.bad, "🚪 HEAVY DOOR")
    makeMarker(HEAVY_KEYPAD_POS, Theme.accent, "⌨️ KEYPAD")
end

-- ============================================================
--  AUTO-PARRY
-- ============================================================
local parryHooked = {}
local parryLastTap = 0

local function parryDistToMe(npc)
    local root = getRoot()
    local nrp = npc:FindFirstChild("HumanoidRootPart")
    if root and nrp then return (root.Position - nrp.Position).Magnitude end
    return nil
end

local function doParryTap()
    local now = os.clock()
    if now - parryLastTap < 0.25 then return end
    parryLastTap = now
    task.spawn(function()
        pcall(function()
            local qKey = Enum.KeyCode.Q
            VirtualInputManager:SendKeyEvent(true, qKey, false, game)
            task.wait(QOL.parryHoldDuration)
            VirtualInputManager:SendKeyEvent(false, qKey, false, game)
        end)
    end)
end

local function hookParryAnimator(animator)
    if parryHooked[animator] then return end
    parryHooked[animator] = true

    animator.AnimationPlayed:Connect(function(track)
        if not State.autoParry then return end
        local owner = animator:FindFirstAncestorOfClass("Model")
        if not owner then return end
        if Players:GetPlayerFromCharacter(owner) then return end

        local animId = nil
        pcall(function()
            if track.Animation then animId = track.Animation.AnimationId end
        end)
        if not animId then return end

        local enemy = ATTACK_ANIMS[animId]
        if not enemy then return end

        local d = parryDistToMe(owner)
        if not d or d > QOL.parryEngageRange then return end

        doParryTap()
    end)
end

local function setupParryHooks()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Animator") then hookParryAnimator(obj) end
    end
    track(Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Animator") then hookParryAnimator(obj) end
    end))
end

-- ============================================================
--  UTILITIES
-- ============================================================
local fullbrightBackup = nil
local jumpscareConnection = nil
local mutedSounds = {}

local function enableFullbright()
    if fullbrightBackup then return end
    fullbrightBackup = {
        Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient, FogEnd = Lighting.FogEnd,
    }
    Lighting.Brightness = 3
    Lighting.Ambient = Color3.fromRGB(180, 180, 180)
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
    Lighting.FogEnd = 100000
end

local function disableFullbright()
    if fullbrightBackup then
        for k, v in pairs(fullbrightBackup) do Lighting[k] = v end
        fullbrightBackup = nil
    end
end

local function isScareSound(obj)
    if not obj:IsA("Sound") then return false end
    local n = obj.Name:lower()
    return n:find("scare") ~= nil or n:find("jump") ~= nil
end

local function muteSound(obj)
    if mutedSounds[obj] == nil then mutedSounds[obj] = obj.Volume end
    obj.Volume = 0
end

local function enableAntiJumpscare()
    if jumpscareConnection then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isScareSound(obj) then muteSound(obj) end
    end
    jumpscareConnection = Workspace.DescendantAdded:Connect(function(obj)
        if isScareSound(obj) then muteSound(obj) end
    end)
end

local function disableAntiJumpscare()
    if jumpscareConnection then jumpscareConnection:Disconnect(); jumpscareConnection = nil end
    for snd, vol in pairs(mutedSounds) do
        if snd and snd.Parent then snd.Volume = vol end
    end
    mutedSounds = {}
end

local hiddenParticles, originalEffects = {}, {}
local function enableFPS()
    for _, obj in ipairs(Lighting:GetChildren()) do 
        if obj:IsA("PostEffect") then 
            originalEffects[obj] = obj.Enabled
            obj.Enabled = false 
        end 
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then 
            hiddenParticles[obj] = obj.Enabled
            obj.Enabled = false 
        end
    end
end

local function disableFPS()
    for obj, val in pairs(originalEffects) do if obj.Parent then obj.Enabled = val end end; originalEffects = {}
    for obj, val in pairs(hiddenParticles) do if obj.Parent then obj.Enabled = val end end; hiddenParticles = {}
end

local effects = {
    crateESP = function(v) if v then scanCrates() else clearCrates() end end,
    boxESP = function(v) if v then scanBoxes() else clearBoxes() end end,
    monsterESP = function(v) if v then scanMonsters() else clearMonsters() end end,
    redroomsESP = function(v) for _, m in pairs(entranceMarkers) do m.billboard.Enabled = v end; if exitMarker then exitMarker.billboard.Enabled = v end end,
    waypoints = function(v) for name, ui in pairs(waypointUI) do ui.billboard.Enabled = v and wpStates[name] ~= false end end,
    pathLine = function(v) if not v then for _, part in ipairs(pathParts) do if part and part.Parent then part:Destroy() end end; pathParts = {} end end,
    fullbright = function(v) if v then enableFullbright() else disableFullbright() end end,
    antiJumpscare = function(v) if v then enableAntiJumpscare() else disableAntiJumpscare() end end,
    fpsBoost = function(v) if v then enableFPS() else disableFPS() end end,
    hideDestroyed = function() clearBoxes(); scanBoxes() end,
    showBosses = function() clearMonsters(); scanMonsters() end,
    showHumans = function() clearMonsters(); scanMonsters() end,
    showZombies = function() clearMonsters(); scanMonsters() end,
    heavyDoorMarkers = function(v) 
        if v then 
            buildHeavyDoorMarkers()
            if heavyDoorFolder then heavyDoorFolder.Parent = Workspace.CurrentCamera end
        else 
            if heavyDoorFolder then heavyDoorFolder.Parent = nil end
        end
    end,
    codeHUD = function(v) updateCodeHUD() end,
}

local function rescanAll()
    clearCrates(); clearBoxes(); clearMonsters()
    scanCrates(); scanBoxes(); scanMonsters()
end

local function unload()
    running = false
    if State.autoSave then pcall(saveSlot, currentSlot) end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    connections = {}
    pcall(clearAllESP)
    for _, part in ipairs(pathParts) do if part and part.Parent then part:Destroy() end end
    pcall(disableFullbright)
    pcall(disableAntiJumpscare)
    pcall(disableFPS)
    for _, a in pairs(waypointAnchors) do pcall(function() a:Destroy() end) end
    for _, m in pairs(entranceMarkers) do if m.anchor then pcall(function() m.anchor:Destroy() end) end end
    if exitMarker and exitMarker.anchor then pcall(function() exitMarker.anchor:Destroy() end) end
    if billboardContainer then billboardContainer:Destroy() end
    if waypointContainer then waypointContainer:Destroy() end
    if monsterContainer then monsterContainer:Destroy() end
    if heavyDoorFolder then heavyDoorFolder:Destroy() end
    if gui then gui:Destroy() end
    if toastGui then toastGui:Destroy() end
    if codeHUDGui then codeHUDGui:Destroy() end
    local c = playerGui:FindFirstChild("BCS_Confirm")
    if c then c:Destroy() end
end
_G.BCS_Unload = unload

-- ============================================================
--  PATH LINE LOGIC
-- ============================================================
local function clearPath()
    for _, part in ipairs(pathParts) do
        if part and part.Parent then part:Destroy() end
    end
    pathParts = {}
end

local function makeMarker(pos, color)
    local part = create("Part", {
        Name = "PathMarker", Size = Vector3.new(0.5, 0.5, 0.5), Position = pos, Anchored = true, CanCollide = false,
        Material = Enum.Material.Neon, Color = color, Transparency = 0.3, Parent = Workspace.CurrentCamera,
    })
    table.insert(pathParts, part)
end

local function drawSegment(a, b, color)
    local steps = math.max(1, math.floor((b - a).Magnitude / 5))
    for i = 0, steps do 
        makeMarker(a:Lerp(b, i / steps), color) 
    end
end

local function drawManhattanPath(from, to)
    local corner = Vector3.new(to.X, from.Y, from.Z)
    drawSegment(from, corner, Theme.accent)
    drawSegment(corner, to, Theme.accent)
end

task.spawn(function()
    while running do
        if State.pathLine and selectedWaypoint then
            local root = getRoot()
            if root then
                local from, to = root.Position, selectedWaypoint.pos
                clearPath()
                drawManhattanPath(from, to)
            end
        else
            clearPath()
        end
        task.wait(0.5)
    end
end)

local function liveUpdate()
    local root = getRoot()
    local rp = root and root.Position
    for _, wp in ipairs(WAYPOINTS) do
        local ui = waypointUI[wp.name]
        if ui and State.waypoints and wpStates[wp.name] and rp then
            ui.label.Text = "📍 " .. wp.name .. "  ·  " .. math.floor((rp - wp.pos).Magnitude) .. " studs"
            local col = (selectedWaypoint == wp) and Theme.good or Theme.accent2
            ui.label.TextColor3 = col
            if ui.stroke then ui.stroke.Color = col end
        end
    end
    local counts, nCrates, nBoxes, nMonsters = {}, 0, 0, 0
    local nearestD, nearestN = math.huge, nil
    for crate, data in pairs(tracked) do
        if not crate.Parent then removeESP(crate)
        elseif rp and data.adornee and data.adornee.Parent then
            local d = (rp - data.adornee.Position).Magnitude
            if d > QOL.cullDistance * 1.15 then removeESP(crate)
            else
                data.distLabel.Text = math.floor(d) .. " studs"
                if d < nearestD then nearestD = d; nearestN = "🔒 " .. data.rarityName end
                counts[data.rarityName] = (counts[data.rarityName] or 0) + 1
                nCrates += 1
            end
        end
    end
    for box, data in pairs(boxTracked) do
        if not box.Parent then removeBoxESP(box)
        elseif State.hideDestroyed and isBoxDestroyed(box) then removeBoxESP(box)
        else
            local parts = {}
            local hits = getBoxHits(box)
            if State.showHits and hits then table.insert(parts, hits .. " hits") end
            if rp and data.adornee and data.adornee.Parent then
                local d = (rp - data.adornee.Position).Magnitude
                table.insert(parts, math.floor(d) .. " studs")
                if d < nearestD then nearestD = d; nearestN = "📦 " .. data.rarityName end
                counts[data.rarityName] = (counts[data.rarityName] or 0) + 1
                nBoxes += 1
            end
            data.infoLabel.Text = table.concat(parts, "  ·  ")
        end
    end
    for npc, data in pairs(monsterTracked) do
        if not npc.Parent or not data.hrp or not data.hrp.Parent then removeMonsterESP(npc)
        elseif rp then
            local d = (rp - data.hrp.Position).Magnitude
            if d > QOL.monsterCullDistance then data.billboard.Enabled = false
            else
                data.billboard.Enabled = true
                local info = math.floor(d) .. " studs"
                local hum = npc:FindFirstChildOfClass("Humanoid")
                if hum then
                    local hp = math.floor(hum.Health)
                    local max = math.floor(hum.MaxHealth)
                    if max > 200 then info = info .. "  ·  " .. hp .. "/" .. max
                    else info = info .. "  ·  ❤ " .. hp end
                end
                data.infoLabel.Text = info
                nMonsters += 1
            end
        end
    end
    Live.counts, Live.crates, Live.boxes, Live.monsters = counts, nCrates, nBoxes, nMonsters
    Live.nearestName = nearestN
    Live.nearestDist = nearestN and math.floor(nearestD) or nil
    local activeCount = 0
    for _, ent in ipairs(REDROOMS_ENTRANCES) do
        local m = entranceMarkers[ent.name]
        if m and m.state == "active" then activeCount += 1 end
    end
    Live.activeEntrances = activeCount
    for _, ent in ipairs(REDROOMS_ENTRANCES) do
        local m = entranceMarkers[ent.name]
        if m and rp then m.distLabel.Text = math.floor((rp - m.pos).Magnitude) .. " studs" end
    end
    if exitMarker and rp then exitMarker.distLabel.Text = math.floor((rp - exitMarker.pos).Magnitude) .. " studs" end
        -- Update Path Line target distance
    if selectedWaypoint and root then
        targetInfo.Text = math.floor((root.Position - selectedWaypoint.pos).Magnitude) .. " studs away"
    end
    if heavyDoorFolder and heavyDoorFolder.Parent then
        local positions = {HEAVY_DOOR_POS, HEAVY_KEYPAD_POS}
        for i, marker in ipairs(heavyDoorMarkers) do
            if rp and positions[i] then marker.info.Text = math.floor((rp - positions[i]).Magnitude) .. " studs" end
        end
    end
    updateCodeHUD()
end

task.spawn(function()
    while running do
        pcall(liveUpdate)
        task.wait(0.35)
    end
end)

task.spawn(function()
    while running do
        task.wait(5)
        if not running then break end
        pcall(function()
            ensureWatchers()
            scanCrates()
            scanBoxes()
            scanMonsters()
        end)
    end
end)
-- ============================================================
--  UI COMPONENTS & MAIN GUI (Part 2/3)
-- ============================================================

local searchRegistry = {}
local function addSearch(page, row, text)
    searchRegistry[page] = searchRegistry[page] or {}
    table.insert(searchRegistry[page], {row = row, text = string.lower(text)})
end

local function makeSection(parent, text)
    local holder = create("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = nextOrder(parent), Parent = parent})
    local lbl = create("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = string.upper(text),
        TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.GothamBold, Parent = holder,
    }, {pad(4, 0, 0, 0)})
    local line = create("Frame", {Size = UDim2.new(1, -100, 0, 1), Position = UDim2.new(0, 100, 0.5, 0), BackgroundColor3 = Theme.stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = holder})
    local function fit()
        local w = lbl.TextBounds.X + 18
        line.Position = UDim2.new(0, w, 0.5, 0)
        line.Size = UDim2.new(1, -w, 0, 1)
    end
    fit()
    lbl:GetPropertyChangedSignal("TextBounds"):Connect(fit)
    return holder
end

local function makeHeader(parent, title, subtitle)
    local f = create("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = nextOrder(parent), Parent = parent})
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = title, TextColor3 = Theme.text, TextSize = 22, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 29), BackgroundTransparency = 1, Text = subtitle or "", TextColor3 = Theme.subtext, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
    return f
end

local function makeNote(parent, text, color)
    local f = create("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.card, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = nextOrder(parent), Parent = parent}, {
        round(4), stroke(color or Theme.stroke, 1, 0.55),
    })
    create("TextLabel", {Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Text = text, TextColor3 = color or Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
    return f
end

local function makeToggle(parent, opts)
    local height = opts.desc and 58 or 46
    local row = create("TextButton", {
        Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Theme.card, AutoButtonColor = false, Text = "",
        BorderSizePixel = 0, LayoutOrder = nextOrder(parent), Parent = parent,
    }, {round(4), cardGradient()})
    local rowStroke = stroke(Theme.stroke, 1, 0.5)
    rowStroke.Parent = row

    local left = 16
    if opts.swatch then
        create("Frame", {Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 16, 0.5, -6), BackgroundColor3 = opts.swatch, BorderSizePixel = 0, Parent = row}, {round(2)})
        left = 38
    end
    local rightPad = opts.badge and 130 or 80
    create("TextLabel", {
        Size = UDim2.new(1, -(left + rightPad), 0, 20), Position = UDim2.new(0, left, 0, opts.desc and 10 or 13), BackgroundTransparency = 1,
        Text = opts.label, TextColor3 = opts.labelColor or Theme.text, TextSize = 14, Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })
    if opts.desc then
        create("TextLabel", {
            Size = UDim2.new(1, -(left + rightPad), 0, 16), Position = UDim2.new(0, left, 0, 30), BackgroundTransparency = 1,
            Text = opts.desc, TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
    end

    local badge
    if opts.badge then
        badge = create("TextLabel", {Size = UDim2.fromOffset(42, 20), Position = UDim2.new(1, -118, 0.5, -10), BackgroundColor3 = Theme.panel, Text = "0", TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.GothamBold, BorderSizePixel = 0, Parent = row}, {round(4)})
    end

    local trackF = create("Frame", {Size = UDim2.fromOffset(44, 22), Position = UDim2.new(1, -58, 0.5, -11), BackgroundColor3 = Theme.off, BorderSizePixel = 0, Parent = row}, {round(4)})
    local knob = create("Frame", {Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = trackF}, {round(2)})

    local state = opts.state and true or false
    local function render(animate)
        local d = animate and 0.2 or 0
        tween(trackF, d, {BackgroundColor3 = state and Theme.accent or Theme.off})
        tween(knob, d, {Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}, Enum.EasingStyle.Back)
        tween(rowStroke, d, {Color = state and Theme.accent or Theme.stroke, Transparency = state and 0.35 or 0.5})
    end
    render(false)
    table.insert(accentListeners, function() render(true) end)

    row.MouseEnter:Connect(function() tween(row, 0.15, {BackgroundColor3 = Theme.cardHover}) end)
    row.MouseLeave:Connect(function() tween(row, 0.15, {BackgroundColor3 = Theme.card}) end)
    row.MouseButton1Click:Connect(function()
        state = not state
        render(true)
        if opts.callback then opts.callback(state) end
    end)
    addSearch(parent, row, opts.label .. " " .. (opts.desc or ""))

    local obj = {row = row}
    function obj.Set(v, silent)
        state = v and true or false
        render(true)
        if not silent and opts.callback then opts.callback(state) end
    end
    function obj.Get() return state end
    function obj.SetBadge(n)
        if badge then
            badge.Text = tostring(n)
            badge.TextColor3 = n > 0 and Theme.text or Theme.subtext
        end
    end
    return obj
end

local function makeChip(parent, label, state, callback)
    local btn = create("TextButton", {
        Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Theme.card, AutoButtonColor = false,
        Text = label, TextColor3 = Theme.subtext, TextSize = 12, Font = Enum.Font.GothamMedium, BorderSizePixel = 0,
        LayoutOrder = nextOrder(parent), Parent = parent,
    }, {round(4), pad(14, 0, 14, 0)})
    local st = stroke(Theme.stroke, 1, 0.4)
    st.Parent = btn
    local on = state and true or false
    local function render(animate)
        local d = animate and 0.18 or 0
        tween(btn, d, {BackgroundColor3 = on and Theme.card:Lerp(Theme.accent, 0.35) or Theme.card, TextColor3 = on and Theme.text or Theme.subtext})
        tween(st, d, {Color = on and Theme.accent or Theme.stroke, Transparency = on and 0.1 or 0.4})
    end
    render(false)
    table.insert(accentListeners, function() render(true) end)
    btn.MouseButton1Click:Connect(function()
        on = not on
        render(true)
        if callback then callback(on) end
    end)
    local obj = {}
    function obj.Set(v, silent)
        on = v and true or false
        render(true)
        if not silent and callback then callback(on) end
    end
    function obj.Get() return on end
    return obj
end

local function makeButton(parent, text, callback, style)
    local base, hover, txt, brd
    if style == "danger" then
        base, hover, txt, brd = Color3.fromRGB(58, 24, 34), Color3.fromRGB(82, 30, 44), Theme.bad, Theme.bad
    elseif style == "primary" then
        base, hover, txt, brd = Theme.accent:Lerp(Theme.panel, 0.55), Theme.accent:Lerp(Theme.panel, 0.35), Theme.text, Theme.accent
    else
        base, hover, txt, brd = Theme.card, Theme.cardHover, Theme.text, Theme.stroke
    end
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = base, AutoButtonColor = false, Text = text, TextColor3 = txt,
        TextSize = 13, Font = Enum.Font.GothamBold, BorderSizePixel = 0, LayoutOrder = nextOrder(parent), Parent = parent,
    }, {round(4), stroke(brd, 1, 0.5)})
    btn.MouseEnter:Connect(function() tween(btn, 0.15, {BackgroundColor3 = hover}) end)
    btn.MouseLeave:Connect(function() tween(btn, 0.15, {BackgroundColor3 = base}) end)
    btn.MouseButton1Click:Connect(callback)
    addSearch(parent, btn, text)
    return btn
end

local function makeButtonRow(parent, defs)
    local holder = create("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = nextOrder(parent), Parent = parent}, {
        create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
    })
    for _, d in ipairs(defs) do
        local b = makeButton(holder, d[1], d[2], d[3])
        b.Size = UDim2.new(1 / #defs, -8 * (#defs - 1) / #defs, 1, 0)
    end
    return holder
end

local function makeSlider(parent, label, min, max, value, step, fmt, callback)
    local row = create("Frame", {Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.card, BorderSizePixel = 0, LayoutOrder = nextOrder(parent), Parent = parent}, {
        round(4), stroke(Theme.stroke, 1, 0.5), cardGradient(),
    })
    create("TextLabel", {Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.fromOffset(16, 9), BackgroundTransparency = 1, Text = label, TextColor3 = Theme.text, TextSize = 14, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
    local valLabel = create("TextLabel", {Size = UDim2.new(0.4, -16, 0, 20), Position = UDim2.new(0.6, 0, 0, 9), BackgroundTransparency = 1, Text = "", TextColor3 = Theme.accent, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, Parent = row})
    onAccent(function() valLabel.TextColor3 = Theme.accent end)

    local hit = create("TextButton", {Size = UDim2.new(1, -32, 0, 24), Position = UDim2.fromOffset(16, 32), BackgroundTransparency = 1, Text = "", Parent = row})
    local bar = create("Frame", {Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, -3), BackgroundColor3 = Theme.off, BorderSizePixel = 0, Parent = hit}, {round(3)})
    local fill = create("Frame", {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, BackgroundColor3 = Theme.accent, Parent = bar}, {round(3)})
    local knob = create("Frame", {Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = bar}, {round(8), stroke(Theme.accent, 2, 0.2)})
    onAccent(function()
        fill.BackgroundColor3 = Theme.accent
        local ks = knob:FindFirstChildOfClass("UIStroke"); if ks then ks.Color = Theme.accent end
    end)

    local function setValue(v, fire)
        v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
        local aa = (v - min) / (max - min)
        fill.Size = UDim2.fromScale(aa, 1)
        knob.Position = UDim2.fromScale(aa, 0.5)
        valLabel.Text = string.format(fmt, v)
        if fire then callback(v) end
    end
    setValue(value, false)

    local dragging = false
    local function fromInput(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        setValue(min + a * (max - min), true)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromInput(i.Position.X)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromInput(i.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    addSearch(parent, row, label)

    return {Set = function(v) setValue(v, false) end}
end

local function makeStatCard(parent, icon, label)
    local card = create("Frame", {BackgroundColor3 = Theme.card, BorderSizePixel = 0, LayoutOrder = nextOrder(parent), Parent = parent}, {
        round(4), stroke(Theme.stroke, 1, 0.5), cardGradient(),
    })
    create("TextLabel", {Size = UDim2.fromOffset(22, 20), Position = UDim2.fromOffset(12, 10), BackgroundTransparency = 1, Text = icon, TextSize = 15, Font = Enum.Font.Gotham, TextColor3 = Theme.text, Parent = card})
    local nameLbl = create("TextLabel", {Size = UDim2.new(1, -44, 0, 20), Position = UDim2.fromOffset(36, 10), BackgroundTransparency = 1, Text = label, TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card})
    local val = create("TextLabel", {Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(12, 36), BackgroundTransparency = 1, Text = "--", TextColor3 = Theme.text, TextSize = 21, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card})
    return function(value, lab, color)
        val.Text = value
        val.TextColor3 = color or Theme.text
        if lab then nameLbl.Text = lab else nameLbl.Text = label end
    end
end

local function buildGui()
    local W, H, SIDE, TOP, FOOT = 740, 540, 180, 48, 28
    local PAGE_X, PAGE_Y = SIDE + 12, 12

    gui = create("ScreenGui", {Name = "BCS_GUI", ResetOnSpawn = false, DisplayOrder = 500, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui})

    mainFrame = create("CanvasGroup", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = Theme.bg, BorderSizePixel = 0, GroupTransparency = 1, Visible = false, Parent = gui,
    }, {round(4)})

    local mainStroke = stroke(Theme.stroke, 1.5, 0.2)
    mainStroke.Parent = mainFrame
    local strokeGrad = create("UIGradient", {Parent = mainStroke})
    onAccent(function()
        strokeGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.accent), ColorSequenceKeypoint.new(0.5, Theme.accent2), ColorSequenceKeypoint.new(1, Theme.accent)})
    end)

    local glow1 = create("Frame", {Size = UDim2.fromOffset(400, 400), Position = UDim2.new(1, -240, 0, -220), BackgroundColor3 = Theme.accent, BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = mainFrame}, {round(200)})
    local glow2 = create("Frame", {Size = UDim2.fromOffset(400, 400), Position = UDim2.new(0, -200, 1, -230), BackgroundColor3 = Theme.accent2, BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = mainFrame}, {round(200)})
    onAccent(function() glow1.BackgroundColor3 = Theme.accent; glow2.BackgroundColor3 = Theme.accent2 end)

    local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local userScale = QOL.scale or math.min(1, vp.X / (W + 60), vp.Y / (H + 60))
    guiScaleValue = userScale
    local uiScale = create("UIScale", {Scale = userScale, Parent = mainFrame})

    local refreshTargets = function() end
    local refreshUI = function() end
    local rarToggles, wpToggles = {}, {}
    local boundToggles = {}
    local keyBtn, cullSlider, monsterCullSlider, scaleSlider, opacitySlider

    local topbar = create("Frame", {Size = UDim2.new(1, 0, 0, TOP), BackgroundColor3 = Theme.panel, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = mainFrame})
    local topLine = create("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Theme.stroke, BorderSizePixel = 0, Parent = topbar})
    
    local logo = create("Frame", {Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(12, 12), BorderSizePixel = 0, BackgroundColor3 = Theme.accent, Parent = topbar}, {round(4), create("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "◈", TextColor3 = Theme.bg, TextSize = 16, Font = Enum.Font.GothamBold})})
    
    create("TextLabel", {Size = UDim2.fromOffset(190, 20), Position = UDim2.fromOffset(44, 6), BackgroundTransparency = 1, Text = "Backrooms Closet", TextColor3 = Theme.text, TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = topbar})
    local topSub = create("TextLabel", {Size = UDim2.fromOffset(190, 14), Position = UDim2.fromOffset(44, 24), BackgroundTransparency = 1, Text = VERSION, TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = topbar})
    
    local searchBox = create("TextBox", {Size = UDim2.fromOffset(200, 24), Position = UDim2.fromOffset(220, 12), BackgroundColor3 = Theme.bg, Text = "", PlaceholderText = "Search settings...", PlaceholderColor3 = Theme.subtext, TextColor3 = Theme.text, TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, Parent = topbar}, {round(4), pad(10, 0, 10, 0), stroke(Theme.stroke, 1, 0.5)})
    
    local function topButton(text, x, color, hoverColor)
        local b = create("TextButton", {Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, x, 0, 10), BackgroundColor3 = color, AutoButtonColor = false, Text = text, TextColor3 = Theme.text, TextSize = 14, Font = Enum.Font.GothamBold, BorderSizePixel = 0, Parent = topbar}, {round(4)})
        b.MouseEnter:Connect(function() tween(b, 0.15, {BackgroundColor3 = hoverColor}) end)
        b.MouseLeave:Connect(function() tween(b, 0.15, {BackgroundColor3 = color}) end)
        return b
    end
    local minBtn = topButton("_", -72, Theme.card, Theme.cardHover); minBtn.TextSize = 18; minBtn.Position = UDim2.new(1, -72, 0, 7)
    local closeBtn = topButton("X", -40, Theme.card, Theme.cardHover); closeBtn.TextColor3 = Theme.bad; closeBtn.Font = Enum.Font.GothamBlack

    local dragging, dragStart, startPos = false, nil, nil
    topbar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, mainFrame.Position
        end
    end)
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))

    local body = create("Frame", {Size = UDim2.new(1, 0, 1, -TOP), Position = UDim2.fromOffset(0, TOP), BackgroundTransparency = 1, Parent = mainFrame})

    local sidebar = create("Frame", {Size = UDim2.new(0, SIDE, 1, -FOOT), BackgroundColor3 = Theme.bg, BorderSizePixel = 0, Parent = body})
    create("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = Theme.stroke, BorderSizePixel = 0, Parent = sidebar})
    local tabScroll = create("ScrollingFrame", {Size = UDim2.new(1, -1, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.stroke, CanvasSize = UDim2.new(), Parent = sidebar}, {pad(0, 8, 0, 8)})
    local footer = create("Frame", {Size = UDim2.new(1, -SIDE, 0, FOOT), Position = UDim2.new(0, SIDE, 1, -FOOT), BackgroundColor3 = Theme.panel, BorderSizePixel = 0, Parent = body})
    local footLeft = create("TextLabel", {Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1, Text = "", TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = footer})
    local footRight = create("TextLabel", {Size = UDim2.new(0.3, -14, 1, 0), Position = UDim2.new(0.7, 0, 0, 0), BackgroundTransparency = 1, Text = "", TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Right, Parent = footer})

    local prof = create("Frame", {Size = UDim2.new(1, -16, 0, 40), Position = UDim2.new(0, 8, 1, -48), BackgroundColor3 = Theme.card, BorderSizePixel = 0, Parent = sidebar}, {round(4), stroke(Theme.stroke, 1, 0.5)})
    create("ImageLabel", {Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Theme.bg, BorderSizePixel = 0, Image = "", Parent = prof}, {round(4)})
    create("TextLabel", {Size = UDim2.new(1, -44, 0, 16), Position = UDim2.fromOffset(40, 6), BackgroundTransparency = 1, Text = player.DisplayName, TextColor3 = Theme.text, TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = prof})
    local profSub = create("TextLabel", {Size = UDim2.new(1, -44, 0, 14), Position = UDim2.fromOffset(40, 20), BackgroundTransparency = 1, Text = "● Active", TextColor3 = Theme.good, TextSize = 10, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = prof})

    local tabs, pages = {}, {}
    local activeIndex, activePage = 0, nil
    local sideY = 8
    local pLog

    local function refreshTabs()
        for i, t in ipairs(tabs) do
            local active = i == activeIndex
            tween(t.btn, 0.2, {BackgroundTransparency = active and 0 or 1, BackgroundColor3 = Theme.card})
            tween(t.name, 0.2, {TextColor3 = active and Theme.accent or Theme.subtext})
            tween(t.ico, 0.2, {TextColor3 = active and Theme.accent or Theme.subtext})
        end
    end
    onAccent(refreshTabs)

    local function addGroup(text)
        if #tabs > 0 then sideY += 8 end
        create("TextLabel", {Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(16, sideY), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.subtext, TextTransparency = 0.3, TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = tabScroll})
        sideY += 20
    end

    local function selectTab(idx)
        if searchBox.Text ~= "" then searchBox.Text = "" end
        activeIndex = idx
        for i, t in ipairs(tabs) do t.page.Visible = (i == idx) end
        activePage = tabs[idx].page
        refreshTabs()
        activePage.Position = UDim2.fromOffset(PAGE_X, PAGE_Y + 10)
        tween(activePage, 0.2, {Position = UDim2.fromOffset(PAGE_X, PAGE_Y)})
        if tabs[idx].onShow then tabs[idx].onShow() end
    end

    local function createTab(label, icon)
        local idx = #tabs + 1
        local y = sideY
        local btn = create("TextButton", {Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, y), BackgroundColor3 = Theme.card, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", BorderSizePixel = 0, Parent = tabScroll}, {round(4)})
        local ico = create("TextLabel", {Size = UDim2.fromOffset(24, 28), Position = UDim2.fromOffset(4, 0), BackgroundTransparency = 1, Text = icon, TextSize = 14, Font = Enum.Font.Gotham, TextColor3 = Theme.subtext, Parent = btn})
        local nameLbl = create("TextLabel", {Size = UDim2.new(1, -32, 1, 0), Position = UDim2.fromOffset(28, 0), BackgroundTransparency = 1, Text = label, TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = Theme.subtext, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn})
        local badge = create("TextLabel", {Size = UDim2.fromOffset(22, 16), Position = UDim2.new(1, -26, 0.5, -8), BackgroundColor3 = Theme.accent, Text = "0", TextColor3 = Theme.bg, TextSize = 10, Font = Enum.Font.GothamBold, Visible = false, BorderSizePixel = 0, Parent = btn}, {round(4)})
        local page = create("ScrollingFrame", {
            Size = UDim2.new(1, -(PAGE_X + 12), 1, -(FOOT + PAGE_Y + 8)), Position = UDim2.fromOffset(PAGE_X, PAGE_Y), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false, Parent = body,
        }, {
            create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
            pad(0, 0, 8, 12),
        })
        onAccent(function() page.ScrollBarImageColor3 = Theme.stroke end)
        btn.MouseEnter:Connect(function() if activeIndex ~= idx then tween(btn, 0.15, {BackgroundTransparency = 0.5, BackgroundColor3 = Theme.card}) end end)
        btn.MouseLeave:Connect(function() if activeIndex ~= idx then tween(btn, 0.15, {BackgroundTransparency = 1}) end end)
        btn.MouseButton1Click:Connect(function() selectTab(idx) end)
        table.insert(tabs, {btn = btn, ico = ico, name = nameLbl, badge = badge, page = page, y = y})
        sideY += 32
        return page, tabs[idx]
    end

    local function bindToggle(parent, key, opts)
        local obj
        opts.state = State[key]
        opts.callback = function(v)
            State[key] = v
            local fx = effects[key]
            if fx then pcall(fx, v) end
            for _, o in ipairs(boundToggles[key] or {}) do
                if o ~= obj then o.Set(v, true) end
            end
            if not opts.quiet then
                notify(opts.label, v and "Enabled" or "Disabled", v and Theme.good or Theme.bad)
            end
            scheduleAutoSave()
        end
        obj = makeToggle(parent, opts)
        boundToggles[key] = boundToggles[key] or {}
        table.insert(boundToggles[key], obj)
        return obj
    end

    local function bindChip(parent, key, label)
        local obj
        obj = makeChip(parent, label, State[key], function(v)
            State[key] = v
            local fx = effects[key]
            if fx then pcall(fx, v) end
            for _, o in ipairs(boundToggles[key] or {}) do
                if o ~= obj then o.Set(v, true) end
            end
            notify(label, v and "Enabled" or "Disabled", v and Theme.good or Theme.bad)
            scheduleAutoSave()
        end)
        boundToggles[key] = boundToggles[key] or {}
        table.insert(boundToggles[key], obj)
        return obj
    end

    -- === DASHBOARD ===
    addGroup("MAIN")
    local pDash = createTab("Dashboard", "◈")
    makeHeader(pDash, "Dashboard", "Live overview of everything the suite is tracking")

    local banner = create("Frame", {Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = Theme.card, BorderSizePixel = 0, LayoutOrder = nextOrder(pDash), Parent = pDash}, {round(4), stroke(Theme.accent, 1, 0.2)})
    create("TextLabel", {Size = UDim2.new(1, -30, 0, 28), Position = UDim2.fromOffset(18, 14), BackgroundTransparency = 1, Text = "Welcome, " .. player.DisplayName, TextColor3 = Theme.text, TextSize = 20, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = banner})
    local bannerSub = create("TextLabel", {Size = UDim2.new(1, -30, 0, 18), Position = UDim2.fromOffset(18, 40), BackgroundTransparency = 1, Text = "", TextColor3 = Theme.subtext, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = banner})

    makeSection(pDash, "Live stats")
    local grid = create("Frame", {Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1, LayoutOrder = nextOrder(pDash), Parent = pDash}, {
        create("UIGridLayout", {CellSize = UDim2.new(1 / 3, -7, 0, 80), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder}),
    })
    local statBoxes    = makeStatCard(grid, "📦", "Boxes tracked")
    local statCrates   = makeStatCard(grid, "🔒", "Crates tracked")
    local statMonsters = makeStatCard(grid, "👹", "Monsters tracked")
    local statTarget   = makeStatCard(grid, "🎯", "Target")
    local statRedrooms = makeStatCard(grid, "🚪", "Redrooms active")
    local statCode     = makeStatCard(grid, "🔐", "Heavy Door code")

    makeSection(pDash, "Quick toggles")
    local chipHolder = create("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder(pDash), Parent = pDash}, {
        create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
    })
    bindChip(chipHolder, "crateESP", "Crates")
    bindChip(chipHolder, "boxESP", "Boxes")
    bindChip(chipHolder, "monsterESP", "Monsters")
    bindChip(chipHolder, "redroomsESP", "Redrooms")
    bindChip(chipHolder, "waypoints", "Waypoints")
    bindChip(chipHolder, "autoParry", "Auto-Parry")
    bindChip(chipHolder, "codeHUD", "Code HUD")
    bindChip(chipHolder, "fullbright", "Fullbright")
    bindChip(chipHolder, "fpsBoost", "FPS Boost")

    -- === FEATURES ===
    local pFeat = createTab("Features", "⚡")
    makeHeader(pFeat, "Features", "Toggle every system in the suite")
    makeSection(pFeat, "ESP")
    bindToggle(pFeat, "crateESP", {label = "Crate ESP", desc = "Highlight crates"})
    bindToggle(pFeat, "boxESP", {label = "Box ESP", desc = "Highlight boxes"})
    bindToggle(pFeat, "monsterESP", {label = "Monster ESP", desc = "Show NPCs"})
    bindToggle(pFeat, "redroomsESP", {label = "Redrooms ESP", desc = "Show entrances"})
    makeSection(pFeat, "Filters")
    bindToggle(pFeat, "showBosses", {label = "Show bosses", quiet = true})
    bindToggle(pFeat, "showHumans", {label = "Show humans", quiet = true})
    bindToggle(pFeat, "showZombies", {label = "Show zombies", quiet = true})
    makeSection(pFeat, "World")
    bindToggle(pFeat, "waypoints", {label = "Waypoints"})
    bindToggle(pFeat, "fullbright", {label = "Fullbright"})
    bindToggle(pFeat, "fpsBoost", {label = "FPS Boost (Potato Graphics)"})
    makeSection(pFeat, "Auto-Parry")
    bindToggle(pFeat, "autoParry", {label = "Auto-Parry", desc = "Tap Q on enemy attack"})

    -- === RARITIES ===
    addGroup("ESP")
    local pRar = createTab("Rarities", "💎")
    makeHeader(pRar, "Rarities", "Filter which rarities show up")
    makeButtonRow(pRar, {
        {"Enable all", function()
            for i, r in ipairs(RARITIES) do r.enabled = true; rarToggles[i].Set(true, true) end
            rescanAll(); scheduleAutoSave()
        end, "primary"},
        {"Disable all", function()
            for i, r in ipairs(RARITIES) do r.enabled = false; rarToggles[i].Set(false, true) end
            rescanAll(); scheduleAutoSave()
        end},
    })
    makeSection(pRar, "Filters  ·  live counts")
    for i, rarity in ipairs(RARITIES) do
        rarToggles[i] = makeToggle(pRar, {label = rarity.name, labelColor = rarity.color, swatch = rarity.color, state = rarity.enabled, badge = true, callback = function(v)
            rarity.enabled = v
            rescanAll(); scheduleAutoSave()
        end})
    end

    -- === REDROOMS ===
    local pRR = createTab("Redrooms", "🚪")
    makeHeader(pRR, "Redrooms", "Entrance status, code, dashboard")
    makeButtonRow(pRR, {
        {"Entrance 1", function() selectedWaypoint = REDROOMS_ENTRANCES[1]; refreshTargets(); notify("Target set", "Entrance 1", Theme.good) end},
        {"Entrance 2", function() selectedWaypoint = REDROOMS_ENTRANCES[2]; refreshTargets(); notify("Target set", "Entrance 2", Theme.good) end},
    })
    makeButtonRow(pRR, {
        {"Entrance 3", function() selectedWaypoint = REDROOMS_ENTRANCES[3]; refreshTargets(); notify("Target set", "Entrance 3", Theme.good) end},
        {"Entrance 4", function() selectedWaypoint = REDROOMS_ENTRANCES[4]; refreshTargets(); notify("Target set", "Entrance 4", Theme.good) end},
    })
    makeButtonRow(pRR, {
        {"Exit", function() selectedWaypoint = REDROOMS_EXIT; refreshTargets(); notify("Target set", "Exit", Theme.good) end},
        {"Heavy Door", function() selectedWaypoint = {name = "Heavy Door", pos = HEAVY_DOOR_POS}; refreshTargets(); notify("Target set", "Heavy Door", Theme.good) end},
    })
    makeSection(pRR, "Code info")
    local codeInfoRow = create("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.card, BorderSizePixel = 0, LayoutOrder = nextOrder(pRR), Parent = pRR}, {round(4), stroke(Theme.accent, 1, 0.3)})
    local codeInfoLabel = create("TextLabel", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = "Code: searching...", TextColor3 = Theme.text, TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = codeInfoRow})
    task.spawn(function()
        while running do
            task.wait(1)
            if Live.codeValue then
                codeInfoLabel.Text = "Code: " .. Live.codeValue
                codeInfoLabel.TextColor3 = Theme.good
            else
                codeInfoLabel.Text = "Code: not yet found"
                codeInfoLabel.TextColor3 = Theme.subtext
            end
        end
    end)
    makeSection(pRR, "Toggles")
    bindToggle(pRR, "redroomsESP", {label = "Show Redrooms markers", quiet = true})
    bindToggle(pRR, "redroomsNotify", {label = "Notify when entrance opens"})

    -- === WAYPOINTS ===
    local pWp = createTab("Waypoints", "📍")
    makeHeader(pWp, "Waypoints", "Choose which beacons to show")
    local function wpToggle(wp)
        if wpStates[wp.name] == nil then wpStates[wp.name] = true end
        wpToggles[wp.name] = makeToggle(pWp, {label = "📍  " .. wp.name, state = wpStates[wp.name], callback = function(v)
            wpStates[wp.name] = v
            if waypointUI[wp.name] then waypointUI[wp.name].billboard.Enabled = v and State.waypoints end
            scheduleAutoSave()
        end})
    end
    local function wpBulk(list, v)
        for _, wp in ipairs(list) do
            wpStates[wp.name] = v
            if wpToggles[wp.name] then wpToggles[wp.name].Set(v, true) end
            if waypointUI[wp.name] then waypointUI[wp.name].billboard.Enabled = v and State.waypoints end
        end
        scheduleAutoSave()
    end
    makeSection(pWp, "Level 0")
    makeButtonRow(pWp, {{"Show all", function() wpBulk(WAYPOINTS_L0, true) end}, {"Hide all", function() wpBulk(WAYPOINTS_L0, false) end}})
    for _, wp in ipairs(WAYPOINTS_L0) do wpToggle(wp) end
    makeSection(pWp, "Level 1")
    makeButtonRow(pWp, {{"Show all", function() wpBulk(WAYPOINTS_L1, true) end}, {"Hide all", function() wpBulk(WAYPOINTS_L1, false) end}})
    for _, wp in ipairs(WAYPOINTS_L1) do wpToggle(wp) end

    -- === NAVIGATE ===
    local pNav = createTab("Navigate", "🎯")
    makeHeader(pNav, "Navigate", "Pick a destination for the path line")
    local targetCard = create("Frame", {Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = Theme.card, BorderSizePixel = 0, LayoutOrder = nextOrder(pNav), Parent = pNav}, {round(4), cardGradient()})
    local targetStroke = stroke(Theme.stroke, 1.2, 0.4)
    targetStroke.Parent = targetCard
    create("TextLabel", {Size = UDim2.fromOffset(40, 66), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = "🎯", TextSize = 24, Font = Enum.Font.Gotham, TextColor3 = Theme.text, Parent = targetCard})
    local targetName = create("TextLabel", {Size = UDim2.new(1, -70, 0, 24), Position = UDim2.fromOffset(56, 12), BackgroundTransparency = 1, Text = "No target selected", TextColor3 = Theme.subtext, TextSize = 16, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = targetCard})
    local targetInfo = create("TextLabel", {Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(56, 37), BackgroundTransparency = 1, Text = "Pick a location below", TextColor3 = Theme.subtext, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = targetCard})

    local navRows = {}
    refreshTargets = function()
        for _, r in ipairs(navRows) do
            local sel = selectedWaypoint == r.wp
            tween(r.btn, 0.2, {BackgroundColor3 = sel and Theme.accent:Lerp(Theme.panel, 0.45) or Theme.card})
            r.name.Text = (sel and "🎯  " or r.icon .. "  ") .. r.wp.name
            tween(r.stroke, 0.2, {Color = sel and Theme.accent or Theme.stroke, Transparency = sel and 0.1 or 0.5})
        end
        if selectedWaypoint then
            targetName.Text = selectedWaypoint.name
            targetName.TextColor3 = Theme.good
            tween(targetStroke, 0.2, {Color = Theme.good, Transparency = 0.2})
        else
            targetName.Text = "No target selected"
            targetName.TextColor3 = Theme.subtext
            tween(targetStroke, 0.2, {Color = Theme.stroke, Transparency = 0.4})
        end
    end
    onAccent(function() refreshTargets() end)

    makeButtonRow(pNav, {
        {"Clear target", function() selectedWaypoint = nil; refreshTargets() end},
        {"Select nearest", function()
            local root = getRoot()
            if not root then return end
            local best, bd = nil, math.huge
            for _, wp in ipairs(WAYPOINTS) do
                local d = (root.Position - wp.pos).Magnitude
                if d < bd then bd = d; best = wp end
            end
            if best then selectedWaypoint = best; refreshTargets(); notify("Target set", best.name, Theme.good) end
        end, "primary"},
    })
    bindToggle(pNav, "pathLine", {label = "Path Line", desc = "Draw a route to your selected target"})

    local function addNavSection(title, list, icon)
        makeSection(pNav, title)
        for _, wp in ipairs(list) do
            local btn = create("TextButton", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.card, AutoButtonColor = false, Text = "", BorderSizePixel = 0, LayoutOrder = nextOrder(pNav), Parent = pNav}, {round(4), cardGradient()})
            local st = stroke(Theme.stroke, 1, 0.5)
            st.Parent = btn
            local nm = create("TextLabel", {Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1, Text = icon .. "  " .. wp.name, TextColor3 = Theme.text, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn})
            local ds = create("TextLabel", {Size = UDim2.new(0.4, -16, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), BackgroundTransparency = 1, Text = "-- studs", TextColor3 = Theme.subtext, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right, Parent = btn})
            table.insert(navRows, {wp = wp, btn = btn, name = nm, dist = ds, stroke = st, icon = icon})
            btn.MouseEnter:Connect(function() if selectedWaypoint ~= wp then tween(btn, 0.15, {BackgroundColor3 = Theme.cardHover}) end end)
            btn.MouseLeave:Connect(function() if selectedWaypoint ~= wp then tween(btn, 0.15, {BackgroundColor3 = Theme.card}) end end)
            btn.MouseButton1Click:Connect(function()
                if selectedWaypoint == wp then selectedWaypoint = nil
                else selectedWaypoint = wp; notify("Target set", wp.name, Theme.good) end
                refreshTargets()
            end)
            addSearch(pNav, btn, wp.name)
        end
    end
    addNavSection("Level 0", WAYPOINTS_L0, "📍")
    addNavSection("Level 1", WAYPOINTS_L1, "📍")
    addNavSection("Redrooms", REDROOMS_ENTRANCES, "🚪")
    addNavSection("Redrooms exit", {REDROOMS_EXIT}, "🚪")
    refreshTargets()

    -- === CONFIG ===
    addGroup("SYSTEM")
    local pCfg = createTab("Config", "🛠")
    makeHeader(pCfg, "Config", "Save / load profile slots")
    makeSection(pCfg, "Active slot")
    local slotRow = create("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.card, BorderSizePixel = 0, LayoutOrder = nextOrder(pCfg), Parent = pCfg}, {round(4), stroke(Theme.stroke, 1, 0.5)})
    create("TextLabel", {Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1, Text = "Slot", TextColor3 = Theme.text, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = slotRow})
    local slotBtn = create("TextButton", {Size = UDim2.new(0.45, 0, 0, 28), Position = UDim2.new(0.5, 0, 0.5, -14), BackgroundColor3 = Theme.cardHover, AutoButtonColor = false, Text = SLOT_NAMES[currentSlot] .. " ▾", TextColor3 = Theme.text, TextSize = 13, Font = Enum.Font.GothamBold, BorderSizePixel = 0, Parent = slotRow}, {round(4), stroke(Theme.stroke, 1, 0.5)})
    local slotStatus = create("TextLabel", {Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Theme.card, BorderSizePixel = 0, LayoutOrder = nextOrder(pCfg), Parent = pCfg}, {round(4), stroke(Theme.stroke, 1, 0.5)})
    slotStatus.Text = "📁 " .. SLOT_NAMES[currentSlot] .. " · " .. getSlotStatus(currentSlot); slotStatus.TextColor3 = Theme.subtext; slotStatus.TextSize = 11; slotStatus.Font = Enum.Font.Gotham

    local dropdownPanel = create("Frame", {Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Theme.panel, BorderSizePixel = 0, LayoutOrder = nextOrder(pCfg), Visible = false, Parent = pCfg}, {round(4), stroke(Theme.accent, 1.5, 0.3)})
    create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = dropdownPanel}); create("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = dropdownPanel})
    local dropdownOpen = false
    local function refreshSlotUI() slotBtn.Text = SLOT_NAMES[currentSlot] .. " ▾"; slotStatus.Text = "📁 " .. SLOT_NAMES[currentSlot] .. " · " .. getSlotStatus(currentSlot) end
    local function closeDropdown() dropdownOpen = false; tween(dropdownPanel, 0.15, {Size = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In); task.delay(0.16, function() if not dropdownOpen then dropdownPanel.Visible = false end end) end
    for i = 1, SLOT_COUNT do
        local opt = create("TextButton", {Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = i == currentSlot and Theme.accent or Theme.card, AutoButtonColor = false, Text = SLOT_NAMES[i] .. "  ·  " .. getSlotStatus(i), TextColor3 = Theme.text, TextSize = 12, Font = Enum.Font.GothamBold, BorderSizePixel = 0, LayoutOrder = i, Parent = dropdownPanel}, {round(4)})
        opt.MouseButton1Click:Connect(function() currentSlot = i; closeDropdown(); refreshSlotUI(); notify("Slot changed", SLOT_NAMES[i], Theme.accent) end)
    end
    slotBtn.MouseButton1Click:Connect(function() dropdownOpen = not dropdownOpen; if dropdownOpen then dropdownPanel.Visible = true; dropdownPanel.Size = UDim2.new(1, 0, 0, 0); tween(dropdownPanel, 0.2, {Size = UDim2.new(1, 0, 0, 6 + SLOT_COUNT * 34)}, Enum.EasingStyle.Back) else closeDropdown() end end)
    makeButtonRow(pCfg, {{"Save", function() local ok = saveSlot(currentSlot); if ok then notify("Slot " .. currentSlot, "Saved", Theme.good); refreshSlotUI() end end, "primary"}, {"Load", function() local ok = loadSlot(currentSlot); if ok then refreshUI(); notify("Slot " .. currentSlot, "Loaded", Theme.good); refreshSlotUI() end end}, {"Delete", function() if deleteSlot(currentSlot) then notify("Slot " .. currentSlot, "Deleted", Theme.bad); refreshSlotUI() end end, "danger"}})
    makeToggle(pCfg, {label = "Auto-load on startup", state = autoLoadEnabled, callback = function(v) autoLoadEnabled = v; autoLoadSlot = currentSlot; scheduleAutoSave() end})
    bindToggle(pCfg, "autoSave", {label = "Auto-save changes"})
    makeSection(pCfg, "Range")
    cullSlider = makeSlider(pCfg, "Crate/Box ESP range", 200, 3000, QOL.cullDistance, 50, "%d studs", function(v) QOL.cullDistance = v; clearCrates(); scanCrates(); scheduleAutoSave() end)
    monsterCullSlider = makeSlider(pCfg, "Monster ESP range", 200, 3000, QOL.monsterCullDistance, 50, "%d studs", function(v) QOL.monsterCullDistance = v; scheduleAutoSave() end)
    makeSection(pCfg, "Keybind")
    local keyRow = create("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Theme.card, BorderSizePixel = 0, LayoutOrder = nextOrder(pCfg), Parent = pCfg}, {round(4), stroke(Theme.stroke, 1, 0.5)})
    create("TextLabel", {Size = UDim2.new(0.5, 0, 0, 20), Position = UDim2.fromOffset(16, 8), BackgroundTransparency = 1, Text = "Toggle GUI key", TextColor3 = Theme.text, TextSize = 14, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = keyRow})
    keyBtn = create("TextButton", {Size = UDim2.new(0.34, 0, 0, 28), Position = UDim2.new(0.62, 0, 0.5, -14), BackgroundColor3 = Theme.cardHover, AutoButtonColor = false, Text = QOL.keybind.Name, TextColor3 = Theme.text, TextSize = 13, Font = Enum.Font.GothamBold, BorderSizePixel = 0, Parent = keyRow}, {round(4), stroke(Theme.stroke, 1, 0.4)})
    local listening = false
    keyBtn.MouseButton1Click:Connect(function() listening = true; keyBtn.Text = "press..."; keyBtn.TextColor3 = Theme.accent end)
    track(UserInputService.InputBegan:Connect(function(input) if not listening or input.UserInputType ~= Enum.UserInputType.Keyboard then return end; listening = false; keyBtn.TextColor3 = Theme.text; if input.KeyCode == Enum.KeyCode.Escape then keyBtn.Text = QOL.keybind.Name; return end; QOL.keybind = input.KeyCode; keyBtn.Text = input.KeyCode.Name; notify("Keybind", "GUI toggle set to " .. input.KeyCode.Name, Theme.good); scheduleAutoSave() end))

    pLog, logTab = createTab("Log", "📜")
    makeHeader(pLog, "Activity log", "Everything the suite has told you this session")
    makeButton(pLog, "Clear log", function() QOL.log = {}; logDirty = true end)
    local logRows = {}
    local function refreshLog()
        for _, r in ipairs(logRows) do r:Destroy() end; logRows = {}
        if #QOL.log == 0 then local empty = create("TextLabel", {Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, Text = "Nothing here yet", TextColor3 = Theme.subtext, TextSize = 12, Font = Enum.Font.Gotham, LayoutOrder = 999, Parent = pLog}); table.insert(logRows, empty); return end
        for i, e in ipairs(QOL.log) do
            local row = create("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.card, BorderSizePixel = 0, LayoutOrder = 1000 + i, Parent = pLog}, {round(4), stroke(e.color, 1, 0.75)})
            create("Frame", {Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = Theme.panel:Lerp(e.color, 0.25), BorderSizePixel = 0, Parent = row}, {round(4), create("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = e.icon or "i", TextColor3 = e.color, TextSize = 14, Font = Enum.Font.GothamBold})})
            create("TextLabel", {Size = UDim2.new(1, -120, 0, 16), Position = UDim2.fromOffset(44, 6), BackgroundTransparency = 1, Text = e.title, TextColor3 = Theme.text, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row})
            create("TextLabel", {Size = UDim2.new(1, -120, 0, 14), Position = UDim2.fromOffset(44, 23), BackgroundTransparency = 1, Text = e.msg, TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row})
            create("TextLabel", {Size = UDim2.fromOffset(60, 16), Position = UDim2.new(1, -70, 0, 14), BackgroundTransparency = 1, Text = os.date("%H:%M:%S", e.time), TextColor3 = Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right, Parent = row})
            table.insert(logRows, row)
        end
    end
    logTab.onShow = function() logUnread = 0; refreshLog(); logDirty = false end

    local pSet = createTab("Settings", "⚙")
    makeHeader(pSet, "Settings", "Appearance, notifications, script control")
    makeSection(pSet, "Accent color")
    local swatchHolder = create("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Theme.card, BorderSizePixel = 0, LayoutOrder = nextOrder(pSet), Parent = pSet}, {round(4), stroke(Theme.stroke, 1, 0.5), pad(16, 0, 16, 0), create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder})})
    local accents = {Color3.fromRGB(255, 150, 50), Color3.fromRGB(0, 190, 255), Color3.fromRGB(0, 220, 130), Color3.fromRGB(255, 80, 160), Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 180, 200)}
    local swatchRings = {}
    for i, c in ipairs(accents) do
        local sw = create("TextButton", {Size = UDim2.fromOffset(24, 24), BackgroundColor3 = c, Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i, Parent = swatchHolder}, {round(4)})
        local ring = stroke(Color3.new(1, 1, 1), 2, (QOL.accent == c) and 0 or 1); ring.Parent = sw
        swatchRings[i] = ring
        sw.MouseEnter:Connect(function() tween(sw, 0.15, {Size = UDim2.fromOffset(28, 28)}) end); sw.MouseLeave:Connect(function() tween(sw, 0.15, {Size = UDim2.fromOffset(24, 24)}) end)
        sw.MouseButton1Click:Connect(function() for j, r in ipairs(swatchRings) do tween(r, 0.2, {Transparency = j == i and 0 or 1}) end; QOL.accent = c; setAccent(c); scheduleAutoSave() end)
    end
    makeSection(pSet, "Interface")
    scaleSlider = makeSlider(pSet, "GUI scale", 0.6, 1.3, userScale, 0.05, "%.2fx", function(v) userScale = v; guiScaleValue = v; QOL.scale = v; uiScale.Scale = v; scheduleAutoSave() end)
    opacitySlider = makeSlider(pSet, "Transparency", 0, 0.4, QOL.opacity, 0.05, "%.2f", function(v) QOL.opacity = v; if mainFrame.Visible then mainFrame.GroupTransparency = v end; scheduleAutoSave() end)
    makeSection(pSet, "Notifications")
    bindToggle(pSet, "toasts", {label = "Show notifications", desc = "Pop-up toasts", quiet = true})
    makeSlider(pSet, "Toast duration", 1.5, 8, QOL.toastDuration, 0.5, "%.1f s", function(v) QOL.toastDuration = v; scheduleAutoSave() end)
    makeSection(pSet, "Script")
    makeButton(pSet, "Unload script", function()
        local confirm = create("ScreenGui", {Name = "BCS_Confirm", ResetOnSpawn = false, DisplayOrder = 900, Parent = playerGui})
        local backdrop = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = confirm}); tween(backdrop, 0.25, {BackgroundTransparency = 0.45})
        local box = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(340, 160), BackgroundColor3 = Theme.panel, BorderSizePixel = 0, Parent = backdrop}, {round(4), stroke(Theme.bad, 1.5, 0.3)})
        local bs = create("UIScale", {Scale = 0.85, Parent = box}); tween(bs, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
        create("TextLabel", {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 16), BackgroundTransparency = 1, Text = "⚠  Unload script?", TextColor3 = Theme.bad, TextSize = 17, Font = Enum.Font.GothamBold, Parent = box})
        create("TextLabel", {Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 48), BackgroundTransparency = 1, Text = "This removes all ESP and the GUI.", TextColor3 = Theme.subtext, TextSize = 12, Font = Enum.Font.Gotham, TextWrapped = true, Parent = box})
        local row = create("Frame", {Size = UDim2.new(1, -40, 0, 38), Position = UDim2.fromOffset(20, 100), BackgroundTransparency = 1, Parent = box}, {create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
        local cancel = create("TextButton", {Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = Theme.card, AutoButtonColor = false, Text = "Cancel", TextColor3 = Theme.text, TextSize = 13, Font = Enum.Font.GothamBold, BorderSizePixel = 0, LayoutOrder = 1, Parent = row}, {round(4), stroke(Theme.stroke, 1, 0.5)})
        local ok = create("TextButton", {Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = Color3.fromRGB(50, 20, 20), AutoButtonColor = false, Text = "Unload", TextColor3 = Theme.bad, TextSize = 13, Font = Enum.Font.GothamBold, BorderSizePixel = 0, LayoutOrder = 2, Parent = row}, {round(4), stroke(Theme.bad, 1, 0.5)})
        cancel.MouseButton1Click:Connect(function() confirm:Destroy() end)
        ok.MouseButton1Click:Connect(function() confirm:Destroy(); notify("Unloading", "Cleaning up...", Theme.bad); task.wait(0.6); unload() end)
    end, "danger")

    tabScroll.CanvasSize = UDim2.fromOffset(0, sideY + 8)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = string.lower(searchBox.Text); local list = searchRegistry[activePage]
        if list then for _, e in ipairs(list) do e.row.Visible = (q == "" or string.find(e.text, q, 1, true) ~= nil) end end
    end)
    refreshUI = function()
        for key, list in pairs(boundToggles) do for _, o in ipairs(list) do o.Set(State[key], true) end end
        for i, r in ipairs(RARITIES) do rarToggles[i].Set(r.enabled, true) end
        for name, t in pairs(wpToggles) do t.Set(wpStates[name] ~= false, true) end
        keyBtn.Text = QOL.keybind.Name; cullSlider.Set(QOL.cullDistance); monsterCullSlider.Set(QOL.monsterCullDistance); opacitySlider.Set(QOL.opacity)
        if QOL.scale then userScale = QOL.scale; guiScaleValue = userScale; uiScale.Scale = userScale; scaleSlider.Set(userScale) end
        for i, c in ipairs(accents) do swatchRings[i].Transparency = (QOL.accent == c) and 0 or 1 end
        for key, fn in pairs(effects) do pcall(fn, State[key]) end; rescanAll()
    end
    local isOpen, minimized = false, false
    toggleGui = function(force)
        local want = force; if want == nil then want = not isOpen end; if want == isOpen then return end; isOpen = want
        if want then mainFrame.Visible = true; uiScale.Scale = userScale * 0.86; tween(uiScale, 0.45, {Scale = userScale}, Enum.EasingStyle.Back); tween(mainFrame, 0.3, {GroupTransparency = QOL.opacity})
        else tween(uiScale, 0.22, {Scale = userScale * 0.92}, Enum.EasingStyle.Quad, Enum.EasingDirection.In); local tw = tween(mainFrame, 0.22, {GroupTransparency = 1}); tw.Completed:Connect(function() if not isOpen then mainFrame.Visible = false end end) end
    end
    closeBtn.MouseButton1Click:Connect(function() toggleGui(false); notify("Menu hidden", "Press " .. QOL.keybind.Name .. " to reopen", Theme.accent) end)
    minBtn.MouseButton1Click:Connect(function() minimized = not minimized; local dy = (H - TOP) / 2 * userScale; if minimized then body.Visible = false; searchBox.Visible = false; tween(mainFrame, 0.3, {Size = UDim2.fromOffset(W, TOP), Position = mainFrame.Position + UDim2.fromOffset(0, -dy)}) else tween(mainFrame, 0.3, {Size = UDim2.fromOffset(W, H), Position = mainFrame.Position + UDim2.fromOffset(0, dy)}); task.delay(0.15, function() body.Visible = true; searchBox.Visible = true end) end; minBtn.Text = minimized and "+" or "-" end)
    track(UserInputService.InputBegan:Connect(function(input, processed) if processed or listening then return end; if input.KeyCode == QOL.keybind then toggleGui() end end))
    local fps, acc, frames = 60, 0, 0
    track(RunService.RenderStepped:Connect(function(dt) acc += dt; frames += 1; if acc >= 0.5 then fps = math.floor(frames / acc + 0.5); acc, frames = 0, 0 end end))
    task.spawn(function()
        while running do
            local root = getRoot()
            footLeft.Text = string.format("📦 %d boxes    🔒 %d crates    👹 %d monsters    🎯 %s", Live.boxes, Live.crates, Live.monsters, selectedWaypoint and selectedWaypoint.name or "no target")
            local ping = getPing(); footRight.Text = fps .. " FPS" .. (ping and ("   ·   " .. ping .. " ms") or ""); footRight.TextColor3 = fps >= 50 and Theme.good or (fps >= 30 and Theme.warn or Theme.bad)
            topSub.Text = VERSION .. "   ·   " .. fmtTime(os.clock() - sessionStart)
            statBoxes(tostring(Live.boxes)); statCrates(tostring(Live.crates)); statMonsters(tostring(Live.monsters))
            if selectedWaypoint and root then statTarget(math.floor((root.Position - selectedWaypoint.pos).Magnitude) .. " studs", "Target  " .. selectedWaypoint.name, Theme.good) else statTarget("None", "Target") end
            statRedrooms(Live.activeEntrances .. " / " .. #REDROOMS_ENTRANCES .. " active", nil, Live.activeEntrances > 0 and ACTIVE_COLOR or Theme.text)
            statCode(Live.codeValue or "--", nil, Live.codeValue and Theme.good or Theme.text)
            if root then local p = root.Position; bannerSub.Text = string.format("Session %s   ·   %d, %d, %d", fmtTime(os.clock() - sessionStart), p.X, p.Y, p.Z) else bannerSub.Text = "Session " .. fmtTime(os.clock() - sessionStart) end
            for i, r in ipairs(RARITIES) do rarToggles[i].SetBadge(Live.counts[r.name] or 0) end
            if activeIndex ~= 0 and tabs[activeIndex].page == pLog then logUnread = 0; if logDirty then refreshLog(); logDirty = false end end
            logTab.badge.Visible = logUnread > 0 and tabs[activeIndex] ~= logTab; logTab.badge.Text = logUnread > 99 and "99+" or tostring(logUnread)
            task.wait(0.4)
        end
    end)
    selectTab(1)
end
-- ============================================================
--  BOOT, CLEANUP & ARCH LOADER (Part 3/3)
-- ============================================================

local function cleanupOld()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name
        if n == "BCS_Highlight" or n == "BCS_Billboard" or n == "PathMarker"
            or n:find("^Waypoint_") or n:find("^BCS_Anchor") then
            obj:Destroy()
        end
    end
    for _, g in ipairs(playerGui:GetChildren()) do
        local n = g.Name
        if n == "BCS_GUI" or n == "BCS_Crates" or n == "BCS_Waypoints" or n == "BCS_Monsters"
            or n == "BCS_Loader" or n == "BCS_Toasts" or n == "BCS_Confirm" or n == "CodeHUD" or n == "BCS_Loader_Arch" then
            g:Destroy()
        end
    end
end

local player_gui = player:WaitForChild("PlayerGui")

-- Hard reset leftovers
for _, g in ipairs(player_gui:GetChildren()) do
    if g.Name:find("BCS") or g.Name == "CodeHUD" or g.Name == "MonsterESP" then
        pcall(function() g:Destroy() end)
    end
end
for _, obj in ipairs(Workspace:GetDescendants()) do
    local n = obj.Name
    if n:find("^BCS_") or n:find("^Waypoint_") or n == "PathMarker" then
        pcall(function() obj:Destroy() end)
    end
end
if Workspace.CurrentCamera:FindFirstChild("BCS_HeavyDoor") then
    Workspace.CurrentCamera.BCS_HeavyDoor:Destroy()
end
_G.BCS_Unload = nil
running = true

-- Clean up old loader if it exists
local oldLoader = playerGui:FindFirstChild("BCS_Loader_Arch")
if oldLoader then oldLoader:Destroy() end

-- ============================================================
--  ARCH LOADER
-- ============================================================
local sg = create("ScreenGui", {Name = "BCS_Loader_Arch", IgnoreGuiInset = true, DisplayOrder = 9999, Parent = playerGui})
local bg = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.bg, Parent = sg})
local terminal = create("Frame", {Size = UDim2.fromOffset(600, 350), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = sg})
create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = terminal})

local function addLine(text, color)
    return create("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = color or Theme.text, TextSize = 13, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left, Parent = terminal})
end

addLine("> Starting boot sequence...", Theme.accent); task.wait(0.15)
addLine("> Client detected.", Theme.text); task.wait(0.2)

local packages = {"core_ui", "esp_module", "pathfinding", "parry_system", "memory_hooks", "waypoints", "redrooms_data", "monster_filter", "config_parser", "security_bypass"}
for i = 1, math.random(5, 7) do
    local pkg = packages[math.random(1, #packages)] .. "_v" .. math.random(1, 5) .. "." .. math.random(0, 9)
    local totalMB = math.random(10, 85) / 10
    local speedMBs = math.random(85, 150) / 10
    local line = addLine("", Theme.text)
    local progress = 0
    while progress < 100 do
        progress = math.min(100, progress + math.random(10, 25))
        line.Text = string.format("  downloading %s ... [%.1f MiB | %.1f MiB/s] %d%%", pkg, (progress / 100) * totalMB, speedMBs, progress)
        task.wait(math.random(1, 2) / 100) 
    end
    task.wait(0.05)
end
addLine("", Theme.text); addLine("(1/1) Checking keys in keyring... [##########] 100%", Theme.text); task.wait(0.1)
addLine("(1/1) Checking package integrity... [##########] 100%", Theme.text); task.wait(0.1)
addLine("> DOWNLOAD COMPLETE.", Theme.good); task.wait(0.3)

-- ============================================================
--  INITIALIZATION
-- ============================================================
cleanupOld()
billboardContainer = create("ScreenGui", {Name = "BCS_Crates", ResetOnSpawn = false, Parent = player_gui})
waypointContainer = create("ScreenGui", {Name = "BCS_Waypoints", ResetOnSpawn = false, Parent = player_gui})
monsterContainer = create("ScreenGui", {Name = "BCS_Monsters", ResetOnSpawn = false, Parent = player_gui})

if autoLoadEnabled then
    pcall(loadSlot, autoLoadSlot)
end

buildGui()

ensureWatchers()
scanCrates()
scanBoxes()
scanMonsters()
buildWaypoints()
buildRedrooms()

if not setupRedroomsWatcher() then
    task.spawn(function()
        while running do
            task.wait(2)
            if setupRedroomsWatcher() then break end
        end
    end)
end

setupParryHooks()

for key, fn in pairs(effects) do
    pcall(fn, State[key])
end

-- ============================================================
--  LOADER FADE OUT
-- ============================================================
for _, v in ipairs(terminal:GetDescendants()) do
    if v:IsA("TextLabel") then
        TweenService:Create(v, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1}):Play()
    end
end
local bgFade = TweenService:Create(bg, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
bgFade:Play()
TweenService:Create(terminal, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0.5, 0.45)}):Play()
task.wait(0.6)
sg:Destroy()

-- ============================================================
--  FINAL STARTUP
-- ============================================================
toggleGui(true)
task.delay(0.9, function()
    notify("Loaded", "Backrooms Closet Suite " .. VERSION .. "  ·  " .. QOL.keybind.Name .. " toggles menu", Theme.good)
end)

print("========================================")
print("✅ BACKROOMS CLOSET SUITE " .. VERSION .. " LOADED")
print("📌 Press " .. QOL.keybind.Name .. " to toggle GUI")
print("========================================")
