-- ============================================================
--  BACKROOMS CLOSET SUITE - PART 3 (UI & CONFIG)
-- ============================================================

local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")
local env              = getgenv or _G

-- ============================================================
--  CONFIG SYSTEM
-- ============================================================
env.buildSaveData = function()
    local data = {
        version = env.VERSION, slotName = env.SLOT_NAMES[env.currentSlot], timestamp = os.time(),
        rarities = {}, wp = {}, state = {}, autoLoadEnabled = env.autoLoadEnabled, autoLoadSlot = env.autoLoadSlot,
        qol = {
            cullDistance = env.QOL.cullDistance, monsterCullDistance = env.QOL.monsterCullDistance,
            keybind = env.QOL.keybind.Name, accent = {env.QOL.accent.R, env.QOL.accent.G, env.QOL.accent.B},
            toastDuration = env.QOL.toastDuration, scale = env.QOL.scale, opacity = env.QOL.opacity,
        },
    }
    for _, r in ipairs(env.RARITIES) do data.rarities[r.name] = r.enabled end
    for _, w in ipairs(env.WAYPOINTS) do data.wp[w.name] = env.wpStates[w.name] end
    for k, v in pairs(env.State) do data.state[k] = v end
    return data
end

env.applySaveData = function(data)
    if type(data) ~= "table" then return false, "invalid data" end
    if data.rarities then
        for _, r in ipairs(env.RARITIES) do
            if data.rarities[r.name] ~= nil then r.enabled = data.rarities[r.name] end
        end
    end
    if data.wp then
        for _, w in ipairs(env.WAYPOINTS) do
            if data.wp[w.name] ~= nil then env.wpStates[w.name] = data.wp[w.name] end
        end
    end
    if data.state then
        for k, v in pairs(data.state) do
            if env.State[k] ~= nil then env.State[k] = v end
        end
    end
    if data.autoLoadEnabled ~= nil then env.autoLoadEnabled = data.autoLoadEnabled end
    if data.autoLoadSlot ~= nil then env.autoLoadSlot = data.autoLoadSlot end
    if data.qol then
        env.QOL.cullDistance = data.qol.cullDistance or env.QOL.cullDistance
        env.QOL.monsterCullDistance = data.qol.monsterCullDistance or env.QOL.monsterCullDistance
        env.QOL.toastDuration = data.qol.toastDuration or env.QOL.toastDuration
        env.QOL.scale = data.qol.scale or env.QOL.scale
        env.QOL.opacity = data.qol.opacity or env.QOL.opacity
        if data.qol.keybind then
            local ok, key = pcall(function() return Enum.KeyCode[data.qol.keybind] end)
            if ok and key then env.QOL.keybind = key end
        end
        if data.qol.accent then
            env.QOL.accent = Color3.new(data.qol.accent[1], data.qol.accent[2], data.qol.accent[3])
            env.setAccent(env.QOL.accent)
        end
    end
    return true
end

env.saveSlot = function(slotIndex)
    if not env.hasFS then return false, "no file access" end
    local ok, err = pcall(function()
        writefile(env.getSlotPath(slotIndex), HttpService:JSONEncode(env.buildSaveData()))
    end)
    if ok then env.lastSaveTime[slotIndex] = os.time() end
    return ok, err
end

env.loadSlot = function(slotIndex)
    if not env.hasFS then return false, "no file access" end
    local path = env.getSlotPath(slotIndex)
    if not isfile(path) then return false, "no save" end
    local ok, raw = pcall(readfile, path)
    if not ok or not raw then return false, "read failed" end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return false, "invalid json" end
    local ok3 = env.applySaveData(data)
    if ok3 and data.timestamp then env.lastSaveTime[slotIndex] = data.timestamp end
    return ok3
end

env.deleteSlot = function(slotIndex)
    if not env.hasFS or not delfile then return false end
    local path = env.getSlotPath(slotIndex)
    if isfile(path) then
        pcall(delfile, path)
        env.lastSaveTime[slotIndex] = nil
        return true
    end
    return false
end

env.getSlotStatus = function(slotIndex)
    if not env.hasFS or not isfile then return "empty" end
    if not isfile(env.getSlotPath(slotIndex)) then return "empty" end
    if env.lastSaveTime[slotIndex] then
        local ago = os.time() - env.lastSaveTime[slotIndex]
        if ago < 60 then return "saved " .. ago .. "s ago"
        elseif ago < 3600 then return "saved " .. math.floor(ago/60) .. "m ago"
        else return "saved " .. math.floor(ago/3600) .. "h ago" end
    end
    return "has data"
end

env.saveToken = 0
env.scheduleAutoSave = function()
    if not env.State.autoSave or not env.hasFS then return end
    env.saveToken += 1
    local my = env.saveToken
    task.delay(2.0, function()
        if my == env.saveToken and env.running then env.saveSlot(env.currentSlot) end
    end)
end

-- ============================================================
--  UI HELPER FUNCTIONS
-- ============================================================
env.searchRegistry = {}
env.addSearch = function(page, row, text)
    env.searchRegistry[page] = env.searchRegistry[page] or {}
    table.insert(env.searchRegistry[page], {row = row, text = string.lower(text)})
end

env.makeSection = function(parent, text)
    local holder = env.create("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = env.nextOrder(parent), Parent = parent})
    local lbl = env.create("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = string.upper(text),
        TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.GothamBold, Parent = holder,
    }, {env.pad(4, 0, 0, 0)})
    local line = env.create("Frame", {Size = UDim2.new(1, -100, 0, 1), Position = UDim2.new(0, 100, 0.5, 0), BackgroundColor3 = env.Theme.stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = holder})
    local function fit()
        local w = lbl.TextBounds.X + 18
        line.Position = UDim2.new(0, w, 0.5, 0)
        line.Size = UDim2.new(1, -w, 0, 1)
    end
    fit()
    lbl:GetPropertyChangedSignal("TextBounds"):Connect(fit)
    return holder
end

env.makeHeader = function(parent, title, subtitle)
    local f = env.create("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = env.nextOrder(parent), Parent = parent})
    env.create("TextLabel", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = title, TextColor3 = env.Theme.text, TextSize = 22, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
    env.create("TextLabel", {Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 29), BackgroundTransparency = 1, Text = subtitle or "", TextColor3 = env.Theme.subtext, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
    return f
end

env.makeToggle = function(parent, opts)
    local height = opts.desc and 58 or 46
    local row = env.create("TextButton", {
        Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = env.Theme.card, AutoButtonColor = false, Text = "",
        BorderSizePixel = 0, LayoutOrder = env.nextOrder(parent), Parent = parent,
    }, {env.round(4), env.cardGradient()})
    local rowStroke = env.stroke(env.Theme.stroke, 1, 0.5)
    rowStroke.Parent = row

    local left = 16
    if opts.swatch then
        env.create("Frame", {Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 16, 0.5, -6), BackgroundColor3 = opts.swatch, BorderSizePixel = 0, Parent = row}, {env.round(2)})
        left = 38
    end
    local rightPad = opts.badge and 130 or 80
    env.create("TextLabel", {
        Size = UDim2.new(1, -(left + rightPad), 0, 20), Position = UDim2.new(0, left, 0, opts.desc and 10 or 13), BackgroundTransparency = 1,
        Text = opts.label, TextColor3 = opts.labelColor or env.Theme.text, TextSize = 14, Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })
    if opts.desc then
        env.create("TextLabel", {
            Size = UDim2.new(1, -(left + rightPad), 0, 16), Position = UDim2.new(0, left, 0, 30), BackgroundTransparency = 1,
            Text = opts.desc, TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
    end

    local badge
    if opts.badge then
        badge = env.create("TextLabel", {Size = UDim2.fromOffset(42, 20), Position = UDim2.new(1, -118, 0.5, -10), BackgroundColor3 = env.Theme.panel, Text = "0", TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.GothamBold, BorderSizePixel = 0, Parent = row}, {env.round(4)})
    end

    local trackF = env.create("Frame", {Size = UDim2.fromOffset(44, 22), Position = UDim2.new(1, -58, 0.5, -11), BackgroundColor3 = env.Theme.off, BorderSizePixel = 0, Parent = row}, {env.round(4)})
    local knob = env.create("Frame", {Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = trackF}, {env.round(2)})

    local state = opts.state and true or false
    local function render(animate)
        local d = animate and 0.2 or 0
        env.tween(trackF, d, {BackgroundColor3 = state and env.Theme.accent or env.Theme.off})
        env.tween(knob, d, {Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}, Enum.EasingStyle.Back)
        env.tween(rowStroke, d, {Color = state and env.Theme.accent or env.Theme.stroke, Transparency = state and 0.35 or 0.5})
    end
    render(false)
    table.insert(env.accentListeners, function() render(true) end)

    row.MouseEnter:Connect(function() env.tween(row, 0.15, {BackgroundColor3 = env.Theme.cardHover}) end)
    row.MouseLeave:Connect(function() env.tween(row, 0.15, {BackgroundColor3 = env.Theme.card}) end)
    row.MouseButton1Click:Connect(function()
        state = not state
        render(true)
        if opts.callback then opts.callback(state) end
    end)
    env.addSearch(parent, row, opts.label .. " " .. (opts.desc or ""))

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
            badge.TextColor3 = n > 0 and env.Theme.text or env.Theme.subtext
        end
    end
    return obj
end

env.makeButton = function(parent, text, callback, style)
    local base, hover, txt, brd
    if style == "danger" then
        base, hover, txt, brd = Color3.fromRGB(58, 24, 34), Color3.fromRGB(82, 30, 44), env.Theme.bad, env.Theme.bad
    elseif style == "primary" then
        base, hover, txt, brd = env.Theme.accent:Lerp(env.Theme.panel, 0.55), env.Theme.accent:Lerp(env.Theme.panel, 0.35), env.Theme.text, env.Theme.accent
    else
        base, hover, txt, brd = env.Theme.card, env.Theme.cardHover, env.Theme.text, env.Theme.stroke
    end
    local btn = env.create("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = base, AutoButtonColor = false, Text = text, TextColor3 = txt,
        TextSize = 13, Font = Enum.Font.GothamBold, BorderSizePixel = 0, LayoutOrder = env.nextOrder(parent), Parent = parent,
    }, {env.round(4), env.stroke(brd, 1, 0.5)})
    btn.MouseEnter:Connect(function() env.tween(btn, 0.15, {BackgroundColor3 = hover}) end)
    btn.MouseLeave:Connect(function() env.tween(btn, 0.15, {BackgroundColor3 = base}) end)
    btn.MouseButton1Click:Connect(callback)
    env.addSearch(parent, btn, text)
    return btn
end

env.makeButtonRow = function(parent, defs)
    local holder = env.create("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = env.nextOrder(parent), Parent = parent}, {
        env.create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
    })
    for _, d in ipairs(defs) do
        local b = env.makeButton(holder, d[1], d[2], d[3])
        b.Size = UDim2.new(1 / #defs, -8 * (#defs - 1) / #defs, 1, 0)
    end
    return holder
end

env.makeSlider = function(parent, label, min, max, value, step, fmt, callback)
    local row = env.create("Frame", {Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = env.Theme.card, BorderSizePixel = 0, LayoutOrder = env.nextOrder(parent), Parent = parent}, {
        env.round(4), env.stroke(env.Theme.stroke, 1, 0.5), env.cardGradient(),
    })
    env.create("TextLabel", {Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.fromOffset(16, 9), BackgroundTransparency = 1, Text = label, TextColor3 = env.Theme.text, TextSize = 14, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
    local valLabel = env.create("TextLabel", {Size = UDim2.new(0.4, -16, 0, 20), Position = UDim2.new(0.6, 0, 0, 9), BackgroundTransparency = 1, Text = "", TextColor3 = env.Theme.accent, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, Parent = row})
    env.onAccent(function() valLabel.TextColor3 = env.Theme.accent end)

    local hit = env.create("TextButton", {Size = UDim2.new(1, -32, 0, 24), Position = UDim2.fromOffset(16, 32), BackgroundTransparency = 1, Text = "", Parent = row})
    local bar = env.create("Frame", {Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, -3), BackgroundColor3 = env.Theme.off, BorderSizePixel = 0, Parent = hit}, {env.round(3)})
    local fill = env.create("Frame", {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, BackgroundColor3 = env.Theme.accent, Parent = bar}, {env.round(3)})
    local knob = env.create("Frame", {Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = bar}, {env.round(8), env.stroke(env.Theme.accent, 2, 0.2)})
    env.onAccent(function()
        fill.BackgroundColor3 = env.Theme.accent
        local ks = knob:FindFirstChildOfClass("UIStroke"); if ks then ks.Color = env.Theme.accent end
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
    env.track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromInput(i.Position.X)
        end
    end))
    env.track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    env.addSearch(parent, row, label)

    return {Set = function(v) setValue(v, false) end}
end

-- ============================================================
--  BUILD GUI
-- ============================================================
env.buildGui = function()
    local W, H, SIDE, TOP, FOOT = 740, 540, 180, 48, 28
    local PAGE_X, PAGE_Y = SIDE + 12, 12

    env.gui = env.create("ScreenGui", {Name = "BCS_GUI", ResetOnSpawn = false, DisplayOrder = 500, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = env.playerGui})

    env.mainFrame = env.create("CanvasGroup", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = env.Theme.bg, BorderSizePixel = 0, GroupTransparency = 1, Visible = false, Parent = env.gui,
    }, {env.round(4)})

    local mainStroke = env.stroke(env.Theme.stroke, 1.5, 0.2)
    mainStroke.Parent = env.mainFrame
    local strokeGrad = env.create("UIGradient", {Parent = mainStroke})
    env.onAccent(function()
        strokeGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, env.Theme.accent), ColorSequenceKeypoint.new(0.5, env.Theme.accent2), ColorSequenceKeypoint.new(1, env.Theme.accent)})
    end)

    local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local userScale = env.QOL.scale or math.min(1, vp.X / (W + 60), vp.Y / (H + 60))
    env._guiScaleValue = userScale
    local uiScale = env.create("UIScale", {Scale = userScale, Parent = env.mainFrame})

    local topbar = env.create("Frame", {Size = UDim2.new(1, 0, 0, TOP), BackgroundColor3 = env.Theme.panel, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = env.mainFrame})
    
    env.create("TextLabel", {Size = UDim2.fromOffset(190, 20), Position = UDim2.fromOffset(44, 6), BackgroundTransparency = 1, Text = "Backrooms Closet", TextColor3 = env.Theme.text, TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = topbar})
    env.topSub = env.create("TextLabel", {Size = UDim2.fromOffset(190, 14), Position = UDim2.fromOffset(44, 24), BackgroundTransparency = 1, Text = env.VERSION, TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = topbar})
    
    env.searchBox = env.create("TextBox", {Size = UDim2.fromOffset(200, 24), Position = UDim2.fromOffset(220, 12), BackgroundColor3 = env.Theme.bg, Text = "", PlaceholderText = "Search settings...", PlaceholderColor3 = env.Theme.subtext, TextColor3 = env.Theme.text, TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, Parent = topbar}, {env.round(4), env.pad(10, 0, 10, 0), env.stroke(env.Theme.stroke, 1, 0.5)})
    
    local function topButton(text, x, color, hoverColor)
        local b = env.create("TextButton", {Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, x, 0, 10), BackgroundColor3 = color, AutoButtonColor = false, Text = text, TextColor3 = env.Theme.text, TextSize = 14, Font = Enum.Font.GothamBold, BorderSizePixel = 0, Parent = topbar}, {env.round(4)})
        b.MouseEnter:Connect(function() env.tween(b, 0.15, {BackgroundColor3 = hoverColor}) end)
        b.MouseLeave:Connect(function() env.tween(b, 0.15, {BackgroundColor3 = color}) end)
        return b
    end
    local minBtn = topButton("−", -72, env.Theme.card, env.Theme.cardHover); minBtn.TextSize = 18; minBtn.Position = UDim2.new(1, -72, 0, 7)
    local closeBtn = topButton("✕", -40, env.Theme.card, env.Theme.cardHover); closeBtn.TextColor3 = env.Theme.bad; closeBtn.Font = Enum.Font.GothamBlack

    local body = env.create("Frame", {Size = UDim2.new(1, 0, 1, -TOP), Position = UDim2.fromOffset(0, TOP), BackgroundTransparency = 1, Parent = env.mainFrame})
    local sidebar = env.create("Frame", {Size = UDim2.new(0, SIDE, 1, -FOOT), BackgroundColor3 = env.Theme.bg, BorderSizePixel = 0, Parent = body})
    local tabScroll = env.create("ScrollingFrame", {Size = UDim2.new(1, -1, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = env.Theme.stroke, CanvasSize = UDim2.new(), Parent = sidebar}, {env.pad(0, 8, 0, 8)})
    local footer = env.create("Frame", {Size = UDim2.new(1, -SIDE, 0, FOOT), Position = UDim2.new(0, SIDE, 1, -FOOT), BackgroundColor3 = env.Theme.panel, BorderSizePixel = 0, Parent = body})
    env.footLeft = env.create("TextLabel", {Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1, Text = "", TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = footer})
    env.footRight = env.create("TextLabel", {Size = UDim2.new(0.3, -14, 1, 0), Position = UDim2.new(0.7, 0, 0, 0), BackgroundTransparency = 1, Text = "", TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Right, Parent = footer})

    env.tabs = {}
    env.boundToggles = {}
    env.activeIndex, env.activePage = 0, nil
    env.sideY = 8

    env.selectTab = function(idx)
        if env.searchBox.Text ~= "" then env.searchBox.Text = "" end
        env.activeIndex = idx
        for i, t in ipairs(env.tabs) do t.page.Visible = (i == idx) end
        env.activePage = env.tabs[idx].page
        env.activePage.Position = UDim2.fromOffset(PAGE_X, PAGE_Y + 10)
        env.tween(env.activePage, 0.2, {Position = UDim2.fromOffset(PAGE_X, PAGE_Y)})
    end

    env.createTab = function(label, icon)
        local idx = #env.tabs + 1
        local y = env.sideY
        local btn = env.create("TextButton", {Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, y), BackgroundColor3 = env.Theme.card, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", BorderSizePixel = 0, Parent = tabScroll}, {env.round(4)})
        local ico = env.create("TextLabel", {Size = UDim2.fromOffset(24, 28), Position = UDim2.fromOffset(4, 0), BackgroundTransparency = 1, Text = icon, TextSize = 14, Font = Enum.Font.Gotham, TextColor3 = env.Theme.subtext, Parent = btn})
        local nameLbl = env.create("TextLabel", {Size = UDim2.new(1, -32, 1, 0), Position = UDim2.fromOffset(28, 0), BackgroundTransparency = 1, Text = label, TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = env.Theme.subtext, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn})
        
        local page = env.create("ScrollingFrame", {
            Size = UDim2.new(1, -(PAGE_X + 12), 1, -(FOOT + PAGE_Y + 8)), Position = UDim2.fromOffset(PAGE_X, PAGE_Y), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = env.Theme.stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false, Parent = body,
        }, {
            env.create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
            env.pad(0, 0, 8, 12),
        })
        btn.MouseButton1Click:Connect(function() env.selectTab(idx) end)
        table.insert(env.tabs, {btn = btn, ico = ico, name = nameLbl, page = page, y = y})
        env.sideY += 32
        return page
    end

    env.bindToggle = function(parent, key, opts)
        opts.state = env.State[key]
        opts.callback = function(v)
            env.State[key] = v
            local fx = env.effects[key]
            if fx then pcall(fx, v) end
            for _, o in ipairs(env.boundToggles[key] or {}) do
                if o ~= obj then o.Set(v, true) end
            end
            env.scheduleAutoSave()
        end
        local obj = env.makeToggle(parent, opts)
        env.boundToggles[key] = env.boundToggles[key] or {}
        table.insert(env.boundToggles[key], obj)
        return obj
    end

    -- TAB 1: FEATURES
    local pFeat = env.createTab("Features", "⚡")
    env.makeHeader(pFeat, "Features", "Toggle every system in the suite")
    env.makeSection(pFeat, "ESP")
    env.bindToggle(pFeat, "crateESP", {label = "Crate ESP", desc = "Highlight crates"})
    env.bindToggle(pFeat, "boxESP", {label = "Box ESP", desc = "Highlight boxes"})
    env.bindToggle(pFeat, "monsterESP", {label = "Monster ESP", desc = "Show NPCs"})
    env.bindToggle(pFeat, "redroomsESP", {label = "Redrooms ESP", desc = "Show entrances"})
    env.makeSection(pFeat, "World")
    env.bindToggle(pFeat, "waypoints", {label = "Waypoints"})
    env.bindToggle(pFeat, "fullbright", {label = "Fullbright"})
    env.bindToggle(pFeat, "lockpickRadar", {label = "Lockpick Radar"})

    -- TAB 2: NAVIGATE
    local pNav = env.createTab("Navigate", "🎯")
    env.makeHeader(pNav, "Navigate", "Select a destination for the path line")
    
    local function addNavSection(title, list, icon)
        env.makeSection(pNav, title)
        for _, wp in ipairs(list) do
            local btn = env.create("TextButton", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = env.Theme.card, AutoButtonColor = false, Text = "", BorderSizePixel = 0, LayoutOrder = env.nextOrder(pNav), Parent = pNav}, {env.round(4), env.cardGradient()})
            local nm = env.create("TextLabel", {Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1, Text = icon .. "  " .. wp.name, TextColor3 = env.Theme.text, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn})
            local ds = env.create("TextLabel", {Size = UDim2.new(0.4, -16, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), BackgroundTransparency = 1, Text = "-- studs", TextColor3 = env.Theme.subtext, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right, Parent = btn})
            
            btn.MouseButton1Click:Connect(function()
                env.selectedWaypoint = wp
                env.notify("Target set", wp.name, env.Theme.good)
            end)
        end
    end
    addNavSection("Level 0", env.WAYPOINTS_L0, "📍")
    addNavSection("Level 1", env.WAYPOINTS_L1, "📍")
    addNavSection("Redrooms", env.REDROOMS_ENTRANCES, "🚪")
    addNavSection("Redrooms Extra", env.REDROOMS_EXTRA, "🚪")
    
    env.bindToggle(pNav, "pathLine", {label = "Path Line", desc = "Draw a path to your selected target"})

    -- TAB 3: SETTINGS
    local pSet = env.createTab("Settings", "⚙")
    env.makeHeader(pSet, "Settings", "Script control")
    env.makeButton(pSet, "Unload script", function()
        env.notify("Unloading", "Cleaning up...", env.Theme.bad)
        task.wait(0.6)
        env.unload()
    end, "danger")

    tabScroll.CanvasSize = UDim2.fromOffset(0, env.sideY + 8)

    local isOpen = false
    env.toggleGui = function(force)
        local want = force; if want == nil then want = not isOpen end; if want == isOpen then return end; isOpen = want
        if want then 
            env.mainFrame.Visible = true; uiScale.Scale = userScale * 0.86; env.tween(uiScale, 0.45, {Scale = userScale}, Enum.EasingStyle.Back); env.tween(env.mainFrame, 0.3, {GroupTransparency = env.QOL.opacity})
        else 
            env.tween(uiScale, 0.22, {Scale = userScale * 0.92}, Enum.EasingStyle.Quad, Enum.EasingDirection.In); local tw = env.tween(env.mainFrame, 0.22, {GroupTransparency = 1}); tw.Completed:Connect(function() if not isOpen then env.mainFrame.Visible = false end end) 
        end
    end
    env._toggleGui = env.toggleGui -- backward compat
    
    closeBtn.MouseButton1Click:Connect(function() env.toggleGui(false) end)
    minBtn.MouseButton1Click:Connect(function() 
        env.tween(env.mainFrame, 0.2, {Size = UDim2.fromOffset(W, 48)})
    end)
    
    env.track(UserInputService.InputBegan:Connect(function(input, processed) 
        if processed then return end
        if input.KeyCode == env.QOL.keybind then env.toggleGui() end 
    end))

    env.selectTab(1)
end
