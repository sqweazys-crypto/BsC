-- ============================================================
--  BACKROOMS CLOSET SUITE - PART 4 (STARTUP & LOADER)
-- ============================================================

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local env          = getgenv or _G

-- Cleanup
env.cleanupOld = function()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name
        if n == "BCS_Highlight" or n == "BCS_Billboard" or n == "PathMarker" or n:find("^Waypoint_") or n:find("^BCS_Anchor") then
            obj:Destroy()
        end
    end
    for _, g in ipairs(env.playerGui:GetChildren()) do
        local n = g.Name
        if n == "BCS_GUI" or n == "BCS_Crates" or n == "BCS_Waypoints" or n == "BCS_Monsters" or n == "BCS_Loader" or n == "BCS_Toasts" or n == "BCS_Confirm" or n == "CodeHUD" or n == "BCS_Loader_Arch" or n == "BCS_Lockpick" then
            g:Destroy()
        end
    end
end

for _, g in ipairs(env.playerGui:GetChildren()) do
    if g.Name:find("BCS") or g.Name == "CodeHUD" or g.Name == "MonsterESP" then pcall(function() g:Destroy() end) end
end
for _, obj in ipairs(Workspace:GetDescendants()) do
    local n = obj.Name
    if n:find("^BCS_") or n:find("^Waypoint_") or n == "PathMarker" then pcall(function() obj:Destroy() end) end
end
if Workspace.CurrentCamera:FindFirstChild("BCS_HeavyDoor") then Workspace.CurrentCamera.BCS_HeavyDoor:Destroy() end
env.BCS_Unload = nil
env.running = true

local oldLoader = env.playerGui:FindFirstChild("BCS_Loader_Arch")
if oldLoader then oldLoader:Destroy() end

-- ============================================================
--  ARCH LOADER
-- ============================================================
local sg = env.create("ScreenGui", {Name = "BCS_Loader_Arch", IgnoreGuiInset = true, DisplayOrder = 9999, Parent = env.playerGui})
local bg = env.create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = env.Theme.bg, Parent = sg})
local terminal = env.create("Frame", {Size = UDim2.fromOffset(600, 350), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = sg})
env.create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = terminal})

local function addLine(text, color)
    return env.create("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = color or env.Theme.text, TextSize = 13, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left, Parent = terminal})
end

addLine("> Starting boot sequence...", env.Theme.accent); task.wait(0.15)
addLine("> Client detected.", env.Theme.text); task.wait(0.2)

local packages = {"core_ui", "esp_module", "pathfinding", "parry_system", "memory_hooks", "waypoints", "redrooms_data", "monster_filter", "config_parser", "security_bypass"}
for i = 1, math.random(5, 7) do
    local pkg = packages[math.random(1, #packages)] .. "_v" .. math.random(1, 5) .. "." .. math.random(0, 9)
    local totalMB = math.random(10, 85) / 10
    local speedMBs = math.random(85, 150) / 10
    local line = addLine("", env.Theme.text)
    local progress = 0
    while progress < 100 do
        progress = math.min(100, progress + math.random(10, 25))
        line.Text = string.format("  downloading %s ... [%.1f MiB | %.1f MiB/s] %d%%", pkg, (progress / 100) * totalMB, speedMBs, progress)
        task.wait(math.random(1, 2) / 100) 
    end
    task.wait(0.05)
end
addLine("", env.Theme.text); addLine("(1/1) Checking keys in keyring... [##########] 100%", env.Theme.text); task.wait(0.1)
addLine("(1/1) Checking package integrity... [##########] 100%", env.Theme.text); task.wait(0.1)
addLine("> DOWNLOAD COMPLETE.", env.Theme.good); task.wait(0.3)

-- ============================================================
--  INITIALIZATION
-- ============================================================
env.cleanupOld()
env.billboardContainer = env.create("ScreenGui", {Name = "BCS_Crates", ResetOnSpawn = false, Parent = env.playerGui})
env.waypointContainer = env.create("ScreenGui", {Name = "BCS_Waypoints", ResetOnSpawn = false, Parent = env.playerGui})
env.monsterContainer = env.create("ScreenGui", {Name = "BCS_Monsters", ResetOnSpawn = false, Parent = env.playerGui})

if env.autoLoadEnabled then pcall(env.loadSlot, env.autoLoadSlot) end

env.buildGui()

env.ensureWatchers()
env.scanCrates()
env.scanBoxes()
env.scanMonsters()
env.buildWaypoints()
env.buildRedrooms()

if not env.setupRedroomsWatcher() then
    task.spawn(function()
        while env.running do
            task.wait(2)
            if env.setupRedroomsWatcher() then break end
        end
    end)
end

for key, fn in pairs(env.effects) do pcall(fn, env.State[key]) end

task.spawn(function()
    local fps, acc, frames = 60, 0, 0
    RunService.RenderStepped:Connect(function(dt) acc += dt; frames += 1; if acc >= 0.5 then fps = math.floor(frames / acc + 0.5); acc, frames = 0, 0 end end)
    while env.running do
        if env.footLeft then
            local root = env.getRoot()
            env.footLeft.Text = string.format("📦 %d boxes    🔒 %d crates    👹 %d monsters    🎯 %s", env.Live.boxes, env.Live.crates, env.Live.monsters, env.selectedWaypoint and env.selectedWaypoint.name or "no target")
            local ping = env.getPing(); env.footRight.Text = fps .. " FPS" .. (ping and ("   ·   " .. ping .. " ms") or ""); env.footRight.TextColor3 = fps >= 50 and env.Theme.good or (fps >= 30 and env.Theme.warn or env.Theme.bad)
            env.topSub.Text = env.VERSION .. "   ·   " .. env.fmtTime(os.clock() - env.sessionStart)
        end
        task.wait(0.4)
    end
end)

-- Fade out loader
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

env.toggleGui(true)
task.delay(0.9, function()
    env.notify("Loaded", "Backrooms Closet Suite " .. env.VERSION .. "  ·  " .. env.QOL.keybind.Name .. " toggles menu", env.Theme.good)
end)

print("========================================")
print("✅ BACKROOMS CLOSET SUITE " .. env.VERSION .. " LOADED")
print("📌 Press " .. env.QOL.keybind.Name .. " to toggle GUI")
print("========================================")
