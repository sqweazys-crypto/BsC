-- ============================================================
--  BACKROOMS CLOSET SUITE - PART 1 (CORE)
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

if _G.BCS_Unload then pcall(_G.BCS_Unload) end

-- GLOBAL ENVIRONMENT
local env = getgenv or _G
env.LocalPlayer = Players.LocalPlayer
env.playerGui = env.LocalPlayer:WaitForChild("PlayerGui")

env.VERSION = "v6.4"
env.running = true
env.connections = {}
env.sessionStart = os.clock()
env.hasFS = (writefile ~= nil) and (readfile ~= nil) and (isfile ~= nil)

env.State = {
    crateESP = true, crateTags = true, boxESP = true, boxTags = true,
    monsterESP = true, monsterTags = true, pathLine = false,
    redroomsESP = true, redroomsNotify = true, codeHUD = true, heavyDoorMarkers = false,
    antiJumpscare = false, hideDestroyed = true,
    showHits = true, autoSave = false, toasts = true, showBosses = true,
    showHumans = true, showZombies = true, lockpickRadar = true,
}

env.RARITIES = {
    {name = "Contractor-Grade", color = Color3.fromRGB(0, 100, 255),   enabled = true},
    {name = "Restricted",       color = Color3.fromRGB(150, 0, 255),   enabled = true},
    {name = "Specialist",       color = Color3.fromRGB(255, 100, 100), enabled = true},
    {name = "Prototype",        color = Color3.fromRGB(150, 0, 0),     enabled = true},
    {name = "Contraband",       color = Color3.fromRGB(255, 215, 0),   enabled = true},
    {name = "Exclusive",        color = Color3.fromRGB(0, 255, 255),   enabled = true},
    {name = "Unobtainable",     color = Color3.fromRGB(255, 0, 255),   enabled = true},
}

env.WAYPOINTS_L0 = {
    {name = "Armory",        pos = Vector3.new(-858, 6, -320)},
    {name = "Armory 2",      pos = Vector3.new(-471, 6, 242)},
    {name = "Stash Box",     pos = Vector3.new(-356, 6, 494)},
    {name = "Printer Room",  pos = Vector3.new(-149, 6, 406)},
    {name = "Exit Room",     pos = Vector3.new(-265, 6, 605)},
    {name = "Big Rooms Noclip", pos = Vector3.new(-186, 6, -838)},
}
env.WAYPOINTS_L1 = {
    {name = "Safe Room",       pos = Vector3.new(1430, 15, -1695)},
    {name = "Contraband Room", pos = Vector3.new(1480, 15, -1499)},
    {name = "Boiler Noclip",   pos = Vector3.new(1442, 15, -1534)},
}
env.WAYPOINTS = {}
for _, w in ipairs(env.WAYPOINTS_L0) do table.insert(env.WAYPOINTS, w) end
for _, w in ipairs(env.WAYPOINTS_L1) do table.insert(env.WAYPOINTS, w) end

env.REDROOMS_ENTRANCES = {
    {name = "Entrance 1", pos = Vector3.new(-838, 2, -643)},
    {name = "Entrance 2", pos = Vector3.new(-336, 2, -849)},
    {name = "Entrance 3", pos = Vector3.new(-135, 2, -425)},
    {name = "Entrance 4", pos = Vector3.new(-134, 2, 305)},
}

env.REDROOMS_EXTRA = {
    {name = "Exit 1", pos = Vector3.new(1956, 375, 814)},
    {name = "Exit 2", pos = Vector3.new(2919, 375, 822)},
    {name = "Switch 1", pos = Vector3.new(2456, 378, 628)},
    {name = "Switch 2", pos = Vector3.new(2506, 379, 1033)},
    {name = "Maze Start", pos = Vector3.new(2333, 375, 141)},
    {name = "Maze End", pos = Vector3.new(1975, 375, 97)},
}
for _, w in ipairs(env.REDROOMS_EXTRA) do table.insert(env.WAYPOINTS, w) end

env.REDROOMS_EXIT = {name = "Old Exit", pos = Vector3.new(2909, 370, 840)}
env.HEAVY_DOOR_POS   = Vector3.new(2447.7, 377.3, 330.8)
env.HEAVY_KEYPAD_POS = Vector3.new(2464.3, 375.4, 331.7)

env.QOL = {
    cullDistance = 1500, keybind = Enum.KeyCode.RightShift, accent = Color3.fromRGB(255, 150, 50),
    toastDuration = 3.5, scale = nil, opacity = 0,
    parryHoldDuration = 0.08, parryEngageRange = 25, monsterCullDistance = 1000, configPath = "BCS_Config",
}

env.SLOT_COUNT = 5
env.SLOT_NAMES = {"Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5"}
env.currentSlot, env.autoLoadEnabled, env.autoLoadSlot = 1, false, 1
env.lastSaveTime = {}
env.getSlotPath = function(i) return env.QOL.configPath .. "_Slot" .. i .. ".json" end

env.tracked, env.boxTracked, env.monsterTracked = {}, {}, {}
env.pathParts, env.waypointAnchors, env.waypointUI, env.wpStates = {}, {}, {}, {}
env.selectedWaypoint, env.entranceMarkers, env.exitMarker = nil, {}, nil

env.Live = { boxes = 0, crates = 0, monsters = 0, counts = {}, nearestName = nil, nearestDist = nil, codeValue = nil, activeEntrances = 0 }

env._guiScaleValue = 1
env.toggleGui = function() end
env.notify = function() end

env.Theme = {
    bg        = Color3.fromRGB(12, 12, 12),
    panel     = Color3.fromRGB(18, 18, 18),
    card      = Color3.fromRGB(24, 24, 24),
    cardHover = Color3.fromRGB(32, 32, 32),
    stroke    = Color3.fromRGB(50, 50, 50),
    text      = Color3.fromRGB(240, 240, 240),
    subtext   = Color3.fromRGB(140, 140, 140),
    off       = Color3.fromRGB(60, 60, 60),
    accent    = env.QOL.accent,
    accent2   = Color3.fromRGB(255, 180, 100),
    good      = Color3.fromRGB(80, 255, 120),
    bad       = Color3.fromRGB(255, 80, 80),
    warn      = Color3.fromRGB(255, 200, 80),
}

env.accentListeners = {}
env.onAccent = function(fn) table.insert(env.accentListeners, fn); fn() end
env.setAccent = function(color)
    local h, s, v = color:ToHSV()
    env.Theme.accent = color
    env.Theme.accent2 = Color3.fromHSV((h + 0.08) % 1, s, v)
    for _, fn in ipairs(env.accentListeners) do pcall(fn) end
end
env.setAccent(env.QOL.accent)

env.create = function(class, props, children)
    local obj = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else obj[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = obj end
    if parent then obj.Parent = parent end
    return obj
end

env.tween = function(obj, t, props, style, dir)
    local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

env.round = function(r) return env.create("UICorner", {CornerRadius = UDim.new(0, r or 4)}) end
env.stroke = function(color, thick, trans)
    return env.create("UIStroke", {Color = color, Thickness = thick or 1, Transparency = trans or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
env.pad = function(l, t, r, b)
    return env.create("UIPadding", {PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b)})
end
env.cardGradient = function()
    return env.create("UIGradient", {Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 220)), Rotation = 90})
end

env.orderCounters = setmetatable({}, {__mode = "k"})
env.nextOrder = function(parent)
    env.orderCounters[parent] = (env.orderCounters[parent] or 0) + 1
    return env.orderCounters[parent]
end

env.getRoot = function()
    local char = env.player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

env.track = function(conn)
    table.insert(env.connections, conn)
    return conn
end

env.fmtTime = function(sec)
    sec = math.floor(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end

env.getPing = function()
    local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and math.floor(v) or nil
end

env.getPos = function(obj)
    if obj:IsA("Model") then
        local ok, p = pcall(function() return obj:GetPivot().Position end)
        if ok then return p end
    end
    return obj.Position
end

env.hasTrackedAncestor = function(obj, tbl, stop)
    local p = obj.Parent
    while p and p ~= stop and p ~= Workspace do
        if tbl[p] then return true end
        p = p.Parent
    end
    return false
end

env.createHighlight = function(adornee, color, transparency)
    if not adornee then return nil end
    local hl = Instance.new("Highlight")
    hl.Name = "BCS_SafeHighlight"
    hl.Adornee = adornee
    hl.FillColor = color
    hl.FillTransparency = transparency or 0.7
    hl.OutlineColor = color
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = env.playerGui
    return hl
end

-- NOTIFICATIONS
env.toastGui, env.toastHolder = nil, nil
env.activeToasts = {}
env.toastCount = 0

env.ensureToasts = function()
    if env.toastGui and env.toastGui.Parent then return end
    env.toastGui = env.create("ScreenGui", {Name = "BCS_Toasts", ResetOnSpawn = false, DisplayOrder = 1100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = env.playerGui})
    env.toastHolder = env.create("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(330, 600), BackgroundTransparency = 1, Parent = env.toastGui,
    }, {
        env.create("UIListLayout", {Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder}),
    })
end

env.dismissToast = function(t)
    if t.dead then return end
    t.dead = true
    for i, x in ipairs(env.activeToasts) do
        if x == t then table.remove(env.activeToasts, i); break end
    end
    if t.inner.Parent then
        env.tween(t.inner, 0.25, {Position = UDim2.fromOffset(360, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    end
    task.delay(0.25, function()
        if t.wrap.Parent then env.tween(t.wrap, 0.2, {Size = UDim2.new(1, 0, 0, 0)}) end
        task.delay(0.22, function() if t.wrap.Parent then t.wrap:Destroy() end end)
    end)
end

env.notify = function(title, msg, color, icon, duration)
    color = color or env.Theme.accent
    if not icon then
        if color == env.Theme.good then icon = "✓"
        elseif color == env.Theme.bad then icon = "✕"
        elseif color == env.Theme.warn then icon = "!"
        else icon = "i" end
    end

    if not env.running or not env.State.toasts then return end
    env.ensureToasts()
    duration = duration or env.QOL.toastDuration

    while #env.activeToasts >= 5 do env.dismissToast(env.activeToasts[1]) end

    env.toastCount += 1
    local wrap = env.create("Frame", {Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = env.toastCount, Parent = env.toastHolder})
    local inner = env.create("TextButton", {
        Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(360, 0), BackgroundColor3 = env.Theme.panel, AutoButtonColor = false,
        Text = "", BorderSizePixel = 0, ClipsDescendants = true, Parent = wrap,
    }, {
        env.round(4), env.stroke(color, 1.2, 0.35),
        env.create("UIGradient", {Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(color, 0.2), Color3.new(1, 1, 1)), Rotation = 0}),
    })
    env.create("Frame", {Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(12, 14), BackgroundColor3 = env.Theme.panel:Lerp(color, 0.25), BorderSizePixel = 0, Parent = inner}, {
        env.round(4),
        env.create("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = icon, TextColor3 = color, TextSize = 17, Font = Enum.Font.GothamBold}),
    })
    env.create("TextLabel", {Size = UDim2.new(1, -70, 0, 18), Position = UDim2.fromOffset(58, 12), BackgroundTransparency = 1, Text = title, TextColor3 = env.Theme.text, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = inner})
    env.create("TextLabel", {Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(58, 31), BackgroundTransparency = 1, Text = msg or "", TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = inner})
    local bar = env.create("Frame", {Size = UDim2.new(1, -24, 0, 2), Position = UDim2.new(0, 12, 1, -7), BackgroundColor3 = color, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = inner}, {env.round(2)})

    local t = {wrap = wrap, inner = inner}
    table.insert(env.activeToasts, t)
    inner.MouseButton1Click:Connect(function() env.dismissToast(t) end)

    env.tween(inner, 0.45, {Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Back)
    env.tween(bar, duration, {Size = UDim2.new(0, 0, 0, 2)}, Enum.EasingStyle.Linear)
    task.delay(duration, function() env.dismissToast(t) end)
end
