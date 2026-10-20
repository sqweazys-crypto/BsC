-- ============================================================
--  BACKROOMS CLOSET SUITE - PART 2 (ESP & LOGIC)
-- ============================================================

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local PathfindingService  = game:GetService("PathfindingService")
local RunService          = game:GetService("RunService")
local Workspace           = game:GetService("Workspace")
local Lighting            = game:GetService("Lighting")
local HttpService         = game:GetService("HttpService")

local env = getgenv()

-- ESP HELPERS
env.getRarityColor = function(rarityName)
    for _, r in ipairs(env.RARITIES) do
        if r.name == rarityName then return r.color end
    end
    return Color3.new(1, 1, 1)
end

env.getRarityState = function(rarityName)
    for _, r in ipairs(env.RARITIES) do
        if r.name == rarityName then return r.enabled end
    end
    return false
end

env.getLevelFolder = function(name)
    local g = Workspace:FindFirstChild("Game")
    g = g and g:FindFirstChild("Maps")
    g = g and g:FindFirstChild("Level0")
    return g and g:FindFirstChild(name)
end

env.getRarity = function(obj, stopFolder)
    local objName = obj.Name:lower()
    if objName:find("contraband") then return "Contraband" end
    if objName:find("prototype") then return "Prototype" end
    if objName:find("specialist") then return "Specialist" end
    if objName:find("restricted") then return "Restricted" end
    if objName:find("contractor") then return "Contractor-Grade" end

    local cur = obj
    while cur and cur ~= stopFolder and cur ~= Workspace do
        local rPart = cur:FindFirstChild("Rarity")
        if rPart and rPart:IsA("BasePart") then
            local c = rPart.Color
            if c == Color3.fromRGB(37, 121, 255) then return "Contractor-Grade" end
            if c.R > 0.8 and c.G < 0.3 and c.B < 0.3 then return "Prototype" end 
            if c.R > 0.8 and c.G > 0.6 and c.B < 0.3 then return "Contraband" end
            if c.R < 0.3 and c.G > 0.8 and c.B > 0.8 then return "Exclusive" end
            if c.R > 0.3 and c.G < 0.3 and c.B > 0.8 then return "Restricted" end
        end

        local rVal = cur:FindFirstChild("Rarity")
        if rVal and rVal:IsA("IntValue") then
            local map = {
                [3]="Contractor-Grade", [4]="Restricted", [5]="Specialist", 
                [6]="Prototype", [7]="Contraband", [8]="Exclusive", 
                [9]="Contraband", [10]="Unobtainable",
            }
            if map[rVal.Value] then return map[rVal.Value] end
        end
        
        if cur ~= obj then
            local lower = cur.Name:lower()
            if lower == "restricted" then return "Restricted" end
            if lower == "prototype" then return "Prototype" end
            if lower == "contraband" then return "Contraband" end
            if lower == "exclusive" then return "Exclusive" end
        end
        cur = cur.Parent
    end
    return "Contractor-Grade"
end

env.makeESPPill = function(size, offset, adornee, color, titleText, subText, container)
    local billboard = env.create("BillboardGui", {
        Name = "BCS_Billboard", Size = size, StudsOffset = offset,
        AlwaysOnTop = true, LightInfluence = 0, Adornee = adornee, Parent = container,
    })
    local pill = env.create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = env.Theme.card, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = billboard}, {
        env.round(4), env.stroke(color, 1.5, 0.15),
    })
    env.create("TextLabel", {Size = UDim2.new(1, 0, 0.58, 0), BackgroundTransparency = 1, Text = titleText, TextColor3 = color, TextSize = 14, Font = Enum.Font.GothamBold, Parent = pill})
    local info = env.create("TextLabel", {Size = UDim2.new(1, 0, 0.4, 0), Position = UDim2.fromScale(0, 0.58), BackgroundTransparency = 1, Text = subText, TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, Parent = pill})
    return billboard, info
end

-- BOX ESP
env.isBoxDestroyed = function(box)
    if not box.Parent then return true end
    local d = box:FindFirstChild("Destroyed", true)
    if d and d:IsA("BoolValue") and d.Value then return true end
    local part = nil
    if box:IsA("BasePart") then part = box
    elseif box:IsA("Model") then part = box.PrimaryPart or box:FindFirstChildWhichIsA("BasePart", true) end
    if part and part.Transparency >= 1 then return true end
    return false
end

env.getBoxHits = function(box)
    local h = box:FindFirstChild("Hits", true)
    return h and h:IsA("NumberValue") and h.Value or nil
end

env.isBoxName = function(obj)
    local n = obj.Name:lower()
    return n:find("rarity") ~= nil or n:find("randomized") ~= nil
end

env.removeBoxESP = function(box)
    local data = env.boxTracked[box]
    if data then
        if data.billboard then data.billboard:Destroy() end
        if data.highlight then data.highlight:Destroy() end
        env.boxTracked[box] = nil
    end
end

env.clearBoxes = function()
    for box in pairs(env.boxTracked) do env.removeBoxESP(box) end
end

env.applyBoxESP = function(box)
    if not env.State.boxESP and not env.State.boxTags then return end
    if not env.billboardContainer or not box.Parent then return end
    if env.boxTracked[box] then return end
    local folder = env.getLevelFolder("Boxes")
    if env.hasTrackedAncestor(box, env.boxTracked, folder) then return end
    if env.State.hideDestroyed and env.isBoxDestroyed(box) then return end

    local rarityName = env.getRarity(box, folder)
    if not env.getRarityState(rarityName) then return end

    local color = env.getRarityColor(rarityName)
    
    local adornee = box
    local highlightTarget = box
    if box:IsA("Model") then
        local biggestPart = nil
        local maxSize = 0
        for _, child in ipairs(box:GetChildren()) do
            if child:IsA("BasePart") and child.Name ~= "Rarity" then
                local size = child.Size.X * child.Size.Y * child.Size.Z
                if size > maxSize then
                    maxSize = size
                    biggestPart = child
                end
            end
        end
        if biggestPart then
            adornee = biggestPart
            highlightTarget = biggestPart
        else
            adornee = box.PrimaryPart or box
        end
    end

    local billboard, info = env.makeESPPill(UDim2.fromOffset(190, 42), Vector3.new(0, 3, 0), adornee, color, "📦 " .. rarityName, "", env.billboardContainer)
    billboard.Enabled = env.State.boxTags
    local highlight = env.createHighlight(highlightTarget, color, 0.7)
    if highlight then highlight.Enabled = env.State.boxESP end

    env.boxTracked[box] = {color = color, billboard = billboard, infoLabel = info, adornee = adornee, rarityName = rarityName, highlight = highlight}
    
    env.track(adornee:GetPropertyChangedSignal("Transparency"):Connect(function()
        if adornee.Transparency >= 1 then env.removeBoxESP(box) end
    end))
    env.track(box.AncestryChanged:Connect(function()
        if not box:IsDescendantOf(folder) then env.removeBoxESP(box) end
    end))
end

env.scanBoxes = function()
    if not env.State.boxESP and not env.State.boxTags then return end
    local folder = env.getLevelFolder("Boxes")
    if not folder then return end
    for _, obj in ipairs(folder:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and env.isBoxName(obj) then
            env.applyBoxESP(obj)
        end
    end
    for box in pairs(env.boxTracked) do
        if not box.Parent then env.removeBoxESP(box) end
    end
end

-- CRATE ESP
env.removeESP = function(crate)
    local data = env.tracked[crate]
    if data then
        if data.billboard then data.billboard:Destroy() end
        if data.highlight then data.highlight:Destroy() end
        env.tracked[crate] = nil
    end
end

env.clearCrates = function()
    for crate in pairs(env.tracked) do env.removeESP(crate) end
end

env.clearAllESP = function()
    env.clearCrates()
    env.clearBoxes()
    for m in pairs(env.monsterTracked) do
        if env.monsterTracked[m].billboard then env.monsterTracked[m].billboard:Destroy() end
        if env.monsterTracked[m].highlight then env.monsterTracked[m].highlight:Destroy() end
    end
    env.tracked, env.boxTracked, env.monsterTracked = {}, {}, {}
    if env.billboardContainer then
        for _, c in ipairs(env.billboardContainer:GetChildren()) do c:Destroy() end
    end
end

env.isCrate = function(obj)
    return obj.Name:lower():find("lockpickcrate") ~= nil
end

env.applyESP = function(crate)
    if not env.State.crateESP and not env.State.crateTags then return end
    if not env.billboardContainer or not crate.Parent then return end
    if env.tracked[crate] then return end
    local folder = env.getLevelFolder("LockpickCrates")
    if env.hasTrackedAncestor(crate, env.tracked, folder) then return end

    local rarityName = env.getRarity(crate, folder)
    if not env.getRarityState(rarityName) then return end

    local root = env.getRoot()
    if root and (root.Position - env.getPos(crate)).Magnitude > env.QOL.cullDistance then return end

    local color = env.getRarityColor(rarityName)
    
    local adornee = crate
    local highlightTarget = crate
    if crate:IsA("Model") then
        local biggestPart = nil
        local maxSize = 0
        for _, child in ipairs(crate:GetChildren()) do
            if child:IsA("BasePart") and child.Name ~= "Rarity" then
                local size = child.Size.X * child.Size.Y * child.Size.Z
                if size > maxSize then
                    maxSize = size
                    biggestPart = child
                end
            end
        end
        if biggestPart then
            adornee = biggestPart
            highlightTarget = biggestPart
        else
            adornee = crate.PrimaryPart or crate
        end
    end

    local billboard, info = env.makeESPPill(UDim2.fromOffset(200, 44), Vector3.new(0, 5, 0), adornee, color, "🔒 " .. rarityName, "-- studs", env.billboardContainer)
    billboard.Enabled = env.State.crateTags
    local highlight = env.createHighlight(highlightTarget, color, 0.6)
    if highlight then highlight.Enabled = env.State.crateESP end

    env.tracked[crate] = {color = color, billboard = billboard, distLabel = info, adornee = adornee, rarityName = rarityName, highlight = highlight}
    
    env.track(crate.AncestryChanged:Connect(function()
        if not crate:IsDescendantOf(folder) then env.removeESP(crate) end
    end))
end

env.scanCrates = function()
    if not env.State.crateESP and not env.State.crateTags then return end
    local folder = env.getLevelFolder("LockpickCrates")
    if not folder then return end
    for _, obj in ipairs(folder:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and env.isCrate(obj) then
            env.applyESP(obj)
        end
    end
    for crate in pairs(env.tracked) do
        if not crate.Parent then env.removeESP(crate) end
    end
end

env.watchers = {box = false, crate = false}
env.ensureWatchers = function()
    if not env.watchers.box then
        local f = env.getLevelFolder("Boxes")
        if f then
            env.watchers.box = true
            env.track(f.DescendantAdded:Connect(function(obj)
                task.wait(0.1)
                if env.running and obj.Parent and (obj:IsA("Model") or obj:IsA("BasePart")) and env.isBoxName(obj) then env.applyBoxESP(obj) end
            end))
        end
    end
    if not env.watchers.crate then
        local f = env.getLevelFolder("LockpickCrates")
        if f then
            env.watchers.crate = true
            env.track(f.DescendantAdded:Connect(function(obj)
                task.wait(0.1)
                if env.running and obj.Parent and (obj:IsA("Model") or obj:IsA("BasePart")) and env.isCrate(obj) then env.applyESP(obj) end
            end))
        end
    end
end

-- MONSTER ESP
env.MONSTER_IGNORE = {"vendor", "armory", "mechanic", "researcher", "turret", "rig", "dummy", "neutral", "bandit", "lfsg"}
env.MONSTER_IGNORE_CATS = {"wanderer", "recon"}

env.shouldIgnoreMonster = function(model)
    local cur = model
    local depth = 0
    while cur and cur ~= Workspace and depth < 10 do
        local lower = cur.Name:lower()
        for _, kw in ipairs(env.MONSTER_IGNORE) do
            if lower:find(kw, 1, true) then return true end
        end
        for _, kw in ipairs(env.MONSTER_IGNORE_CATS) do
            if lower:find(kw, 1, true) then return true end
        end
        cur = cur.Parent
        depth = depth + 1
    end
    return false
end

env.classifyMonster = function(obj)
    local path = obj:GetFullName():lower()
    if path:find("boss") then return "boss", env.Theme.accent end
    if path:find("phantom") then return "phantom", Color3.fromRGB(150, 80, 200) end
    if path:find("shrieker") then return "zombie", Color3.fromRGB(255, 60, 60) end
    if path:find("zombie") then return "zombie", Color3.fromRGB(120, 220, 120) end
    if path:find("skin stealer") or path:find("dissolver") or path:find("wretch") or path:find("brute") then
        return "zombie", Color3.fromRGB(255, 100, 200)
    end
    return "misc", env.Theme.text
end

env.isMonster = function(obj)
    if not obj:IsA("Model") then return false end
    if not obj:FindFirstChildOfClass("Humanoid") then return false end
    if not obj:FindFirstChild("HumanoidRootPart") then return false end
    if env.player.Character == obj then return false end
    if Players:GetPlayerFromCharacter(obj) then return false end
    if env.shouldIgnoreMonster(obj) then return false end
    return true
end

env.removeMonsterESP = function(npc)
    local data = env.monsterTracked[npc]
    if data then
        if data.billboard then data.billboard:Destroy() end
        if data.highlight then data.highlight:Destroy() end
        env.monsterTracked[npc] = nil
    end
end

env.clearMonsters = function()
    for npc in pairs(env.monsterTracked) do env.removeMonsterESP(npc) end
end

env.applyMonsterESP = function(npc)
    if not env.State.monsterESP and not env.State.monsterTags then return end
    if not env.monsterContainer or not npc.Parent then return end
    if env.monsterTracked[npc] then return end
    if not env.isMonster(npc) then return end

    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cat, color = env.classifyMonster(npc)
    if cat == "boss" and not env.State.showBosses then return end
    if cat == "zombie" and not env.State.showZombies then return end

    local billboard = env.create("BillboardGui", {
        Name = "BCS_Billboard", Size = UDim2.fromOffset(160, 38), StudsOffset = Vector3.new(0, 3.5, 0),
        AlwaysOnTop = true, LightInfluence = 0, Adornee = hrp, Parent = env.monsterContainer,
        Enabled = env.State.monsterTags
    })
    local pill = env.create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = env.Theme.card, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = billboard}, {
        env.round(4), env.stroke(color, 1.5, 0.1),
    })
    local nameLabel = env.create("TextLabel", {Size = UDim2.new(1, 0, 0.55, 0), BackgroundTransparency = 1, Text = npc.Name, TextColor3 = color, TextSize = 13, Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd, Parent = pill})
    local infoLabel = env.create("TextLabel", {Size = UDim2.new(1, 0, 0.45, 0), Position = UDim2.fromScale(0, 0.55), BackgroundTransparency = 1, Text = "--", TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, Parent = pill})
    
    local highlight = env.createHighlight(npc, color, 0.6)
    if highlight then highlight.Enabled = env.State.monsterESP end

    env.monsterTracked[npc] = {billboard = billboard, nameLabel = nameLabel, infoLabel = infoLabel, hrp = hrp, color = color, highlight = highlight}
end

env.getNPCFolders = function()
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

env.scanMonsters = function()
    if not env.State.monsterESP and not env.State.monsterTags then return end
    for _, folder in ipairs(env.getNPCFolders()) do
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj:IsA("Model") and env.isMonster(obj) and not env.monsterTracked[obj] then
                env.applyMonsterESP(obj)
            end
        end
    end
    for npc in pairs(env.monsterTracked) do
        if not npc.Parent or env.shouldIgnoreMonster(npc) then
            env.removeMonsterESP(npc)
        end
    end
end

env.rescanAll = function()
    env.clearCrates(); env.clearBoxes(); env.clearMonsters()
    env.scanCrates(); env.scanBoxes(); env.scanMonsters()
end

-- WAYPOINTS & REDROOMS
env.buildWaypoints = function()
    for _, wp in ipairs(env.WAYPOINTS) do
        if env.wpStates[wp.name] == nil then env.wpStates[wp.name] = true end
        local anchor = env.create("Part", {
            Name = "Waypoint_" .. wp.name, Size = Vector3.new(0.1, 0.1, 0.1), Position = wp.pos,
            Anchored = true, CanCollide = false, Transparency = 1, Parent = Workspace.CurrentCamera,
        })
        env.waypointAnchors[wp.name] = anchor

        local billboard = env.create("BillboardGui", {
            Name = "WaypointBillboard_" .. wp.name, Size = UDim2.fromOffset(240, 34), StudsOffset = Vector3.new(0, 6, 0),
            AlwaysOnTop = true, LightInfluence = 0, Adornee = anchor,
            Enabled = env.State.waypoints and env.wpStates[wp.name], Parent = env.waypointContainer,
        })
        local pill = env.create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = env.Theme.card, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = billboard}, {
            env.round(4), env.stroke(env.Theme.accent2, 1.5, 0.15),
        })
        local label = env.create("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "📍 " .. wp.name, TextColor3 = env.Theme.accent2, TextSize = 14, Font = Enum.Font.GothamBold, Parent = pill})
        env.waypointUI[wp.name] = {billboard = billboard, label = label, stroke = pill:FindFirstChildOfClass("UIStroke")}
    end
end

env.IDLE_COLOR    = Color3.fromRGB(150, 70, 230)
env.ACTIVE_COLOR  = Color3.fromRGB(255, 60, 60)
env.UNKNOWN_COLOR = Color3.fromRGB(140, 140, 150)
env.EXIT_COLOR    = Color3.fromRGB(0, 255, 110)

env.stateColor = function(state)
    if state == "active" then return env.ACTIVE_COLOR end
    if state == "idle" then return env.IDLE_COLOR end
    return env.UNKNOWN_COLOR
end

env.buildRedroomsMarker = function(name, pos, color, text)
    local anchor = env.create("Part", {
        Name = "BCS_Anchor_" .. (name:gsub("%s", "_")), Size = Vector3.new(0.1, 0.1, 0.1), Position = pos,
        Anchored = true, CanCollide = false, Transparency = 1, Parent = Workspace.CurrentCamera,
    })
    local billboard = env.create("BillboardGui", {
        Name = "BCS_Billboard_Redrooms", Size = UDim2.fromOffset(250, 52), StudsOffset = Vector3.new(0, 5, 0),
        AlwaysOnTop = true, LightInfluence = 0, Adornee = anchor, Enabled = env.State.redroomsESP, Parent = env.billboardContainer,
    })
    local pill = env.create("Frame", {Size = UDim2.fromScale(1, 0.75), BackgroundColor3 = env.Theme.card, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = billboard}, {
        env.round(4), env.stroke(color, 1.5, 0.3),
    })
    local label = env.create("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextColor3 = color, TextSize = 15, Font = Enum.Font.GothamBold, Parent = pill})
    local distLabel = env.create("TextLabel", {Size = UDim2.new(1, 0, 0.25, 0), Position = UDim2.fromScale(0, 0.75), BackgroundTransparency = 1, Text = "-- studs", TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, Parent = billboard})
    return {
        anchor = anchor, billboard = billboard, label = label, distLabel = distLabel,
        stroke = pill:FindFirstChildOfClass("UIStroke"), pos = pos, name = name,
        prompt = nil, lastState = nil, state = "unknown",
    }
end

env.applyRedroomsState = function(marker, state)
    marker.state = state
    local col = env.stateColor(state)
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

env.buildRedrooms = function()
    for _, ent in ipairs(env.REDROOMS_ENTRANCES) do
        env.entranceMarkers[ent.name] = env.buildRedroomsMarker(ent.name, ent.pos, env.UNKNOWN_COLOR, "🚪 " .. ent.name .. " — ?")
    end
    for _, ent in ipairs(env.REDROOMS_EXTRA) do
        env.entranceMarkers[ent.name] = env.buildRedroomsMarker(ent.name, ent.pos, env.EXIT_COLOR, "🚪 " .. ent.name)
    end
    env.exitMarker = env.buildRedroomsMarker(env.REDROOMS_EXIT.name, env.REDROOMS_EXIT.pos, env.EXIT_COLOR, "🚪 EXIT")
    env.exitMarker.state = "exit"
end

env.registerPrompt = function(promptPart)
    if not promptPart:IsA("BasePart") then return end
    local prompt = promptPart:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return end

    local bestMarker, bestDist = nil, 50
    for _, marker in pairs(env.entranceMarkers) do
        local d = (promptPart.Position - marker.pos).Magnitude
        if d < bestDist then bestDist = d; bestMarker = marker end
    end
    if not bestMarker then return end

    bestMarker.prompt = prompt
    bestMarker.lastState = prompt.Enabled
    env.applyRedroomsState(bestMarker, prompt.Enabled and "active" or "idle")

    env.track(prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not bestMarker.prompt then return end
        if bestMarker.lastState ~= prompt.Enabled then
            bestMarker.lastState = prompt.Enabled
            env.applyRedroomsState(bestMarker, prompt.Enabled and "active" or "idle")
            if prompt.Enabled and env.State.redroomsNotify then
                env.notify("Redrooms entrance active", bestMarker.name, env.ACTIVE_COLOR, "🚪", 7)
            end
        end
    end))
    env.track(prompt.AncestryChanged:Connect(function()
        if not prompt:IsDescendantOf(Workspace) then
            bestMarker.prompt = nil
            bestMarker.lastState = nil
            env.applyRedroomsState(bestMarker, "unknown")
        end
    end))
end

env.redroomsWatching = false
env.setupRedroomsWatcher = function()
    if env.redroomsWatching then return true end
    local folder = env.getLevelFolder("CustomScripts")
    folder = folder and folder:FindFirstChild("Redrooms")
    local prompts = folder and folder:FindFirstChild("Prompts")
    if not prompts then return false end
    env.redroomsWatching = true
    for _, child in ipairs(prompts:GetChildren()) do env.registerPrompt(child) end
    env.track(prompts.ChildAdded:Connect(function(obj) task.wait(0.2); env.registerPrompt(obj) end))
    return true
end

-- CODE HUD & HEAVY DOOR
env.codeHUDGui, env.codeHUDLabel, env.codeHUDStroke = nil, nil, nil
env.cachedCode, env.codeLocked = nil, false
env.lastJobId = game.JobId

env.findCodeLabel = function()
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

env.findPasstextLabel = function()
    local node = Workspace:FindFirstChild("Game")
    node = node and node:FindFirstChild("Maps")
    node = node and node:FindFirstChild("Level0")
    node = node and node:FindFirstChild("Redrooms")
    node = node and node:FindFirstChild("Puzzles")
    node = node and node:FindFirstChild("HeavyDoorPuzzle")
    node = node and node:FindFirstChild("Keypad")
    node = node and node:FindFirstChild("Passtext")
    node = node and node:FindFirstChild("SurfaceGui")
    node = node and node:FindFirstChild("TextLabel")
    return node
end

env.ensureCodeHUD = function()
    if env.codeHUDGui and env.codeHUDGui.Parent then return end
    env.codeHUDGui = env.create("ScreenGui", {Name = "CodeHUD", ResetOnSpawn = false, DisplayOrder = 9999, Parent = env.playerGui})
    local frame = env.create("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(340, 60), BackgroundColor3 = env.Theme.bg, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = env.codeHUDGui}, {env.round(4)})
    env.codeHUDStroke = env.stroke(env.Theme.accent, 2, 0); env.codeHUDStroke.Parent = frame
    env.create("TextLabel", {Size = UDim2.new(1, 0, 0.4, 0), BackgroundTransparency = 1, Text = "🔐 HEAVY DOOR CODE", TextColor3 = env.Theme.subtext, TextSize = 12, Font = Enum.Font.GothamBold, Parent = frame})
    env.codeHUDLabel = env.create("TextLabel", {Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.fromScale(0, 0.4), BackgroundTransparency = 1, Text = "searching...", TextColor3 = env.Theme.text, TextSize = 26, Font = Enum.Font.Code, Parent = frame})
end

env.updateCodeHUD = function()
    if not env.State.codeHUD then
        if env.codeHUDGui then env.codeHUDGui.Enabled = false end
        return
    end
    env.ensureCodeHUD()
    env.codeHUDGui.Enabled = true
    if env.codeLocked and env.cachedCode then
        env.codeHUDLabel.Text = env.cachedCode
        env.codeHUDLabel.TextColor3 = env.Theme.good
        env.codeHUDStroke.Color = env.Theme.good
        env.Live.codeValue = env.cachedCode
        return
    end
    local tl = env.findCodeLabel()
    
    local passtext = env.findPasstextLabel()
    if passtext and passtext.Text ~= "" then
        if env.cachedCode then
            env.codeHUDLabel.Text = env.cachedCode .. " (typing...)"
            env.codeHUDLabel.TextColor3 = env.Theme.warn
            env.codeHUDStroke.Color = env.Theme.warn
        end
        return
    end

    if tl and tl.Text and tl.Text:match("^%d+$") then
        if #tl.Text >= 4 and #tl.Text <= 10 and tl.Text ~= env.cachedCode then
            env.cachedCode = tl.Text
            env.codeHUDLabel.Text = env.cachedCode
            env.codeHUDLabel.TextColor3 = env.Theme.good
            env.codeHUDStroke.Color = env.Theme.good
            env.Live.codeValue = env.cachedCode
            env.notify("Code captured", "Door code: " .. env.cachedCode, env.Theme.good)
            env.codeLocked = true
        end
    elseif env.cachedCode then
        env.codeHUDLabel.Text = env.cachedCode
        env.codeHUDLabel.TextColor3 = env.Theme.accent
        env.codeHUDStroke.Color = env.Theme.accent
    else
        env.codeHUDLabel.Text = "not seen yet"
        env.codeHUDLabel.TextColor3 = env.Theme.bad
        env.codeHUDStroke.Color = env.Theme.bad
    end
end

task.spawn(function()
    while env.running do
        task.wait(2)
        if game.JobId ~= env.lastJobId then
            env.lastJobId = game.JobId
            env.codeLocked = false
            env.cachedCode = nil
        end
    end
end)

env.heavyDoorFolder = nil
env.heavyDoorMarkers = {}

env.buildHeavyDoorMarkers = function()
    if env.heavyDoorFolder then return end
    env.heavyDoorFolder = env.create("Folder", {Name = "BCS_HeavyDoor", Parent = Workspace.CurrentCamera})
    local function makeMarker(pos, color, label)
        local part = env.create("Part", {
            Name = "HeavyDoorMarker", Size = Vector3.new(1, 1, 1), Position = pos,
            Anchored = true, CanCollide = false, Material = Enum.Material.Neon,
            Color = color, Shape = Enum.PartType.Ball, Transparency = 0.3, Parent = env.heavyDoorFolder,
        })
        local bb = env.create("BillboardGui", {Size = UDim2.fromOffset(260, 44), StudsOffset = Vector3.new(0, 3, 0), AlwaysOnTop = true, Parent = part})
        local frame = env.create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = env.Theme.bg, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = bb}, {env.round(4), env.stroke(color, 1.5, 0.1)})
        env.create("TextLabel", {Size = UDim2.new(1, 0, 0.6, 0), BackgroundTransparency = 1, Text = label, TextColor3 = color, TextSize = 13, Font = Enum.Font.GothamBold, Parent = frame})
        local info = env.create("TextLabel", {Size = UDim2.new(1, 0, 0.4, 0), Position = UDim2.fromScale(0, 0.6), BackgroundTransparency = 1, Text = "--", TextColor3 = env.Theme.subtext, TextSize = 11, Font = Enum.Font.Gotham, Parent = frame})
        table.insert(env.heavyDoorMarkers, {part = part, info = info})
    end
    makeMarker(env.HEAVY_DOOR_POS, env.Theme.bad, "🚪 HEAVY DOOR")
    makeMarker(env.HEAVY_KEYPAD_POS, env.Theme.accent, "⌨️ KEYPAD")
end

-- FULLBRIGHT & JUMPScare
env.fbBackup = nil
env.ccConnections = {}
env.jumpscareConnection = nil
env.mutedSounds = {}

env.enableFullbright = function()
    if env.fbBackup then return end
    env.fbBackup = { Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, FogEnd = Lighting.FogEnd, CC = {} }
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("ColorCorrectionEffect") then
            env.fbBackup.CC[effect] = {Enabled = effect.Enabled, Brightness = effect.Brightness, Contrast = effect.Contrast, TintColor = effect.TintColor}
            effect.Enabled = false
            effect.Brightness = 1
            effect.Contrast = 0
            effect.TintColor = Color3.new(1, 1, 1)
            table.insert(env.ccConnections, env.track(effect:GetPropertyChangedSignal("Enabled"):Connect(function()
                if env.fbBackup and effect.Enabled then effect.Enabled = false end
            end)))
        end
    end
    Lighting.Brightness = 3
    Lighting.Ambient = Color3.fromRGB(180, 180, 180)
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
    Lighting.FogEnd = 100000
end

env.disableFullbright = function()
    if not env.fbBackup then return end
    for _, conn in ipairs(env.ccConnections) do conn:Disconnect() end
    env.ccConnections = {}
    Lighting.Brightness = env.fbBackup.Brightness
    Lighting.Ambient = env.fbBackup.Ambient
    Lighting.OutdoorAmbient = env.fbBackup.OutdoorAmbient
    Lighting.FogEnd = env.fbBackup.FogEnd
    for effect, data in pairs(env.fbBackup.CC) do
        if effect and effect.Parent then
            effect.Enabled = data.Enabled
            effect.Brightness = data.Brightness
            effect.Contrast = data.Contrast
            effect.TintColor = data.TintColor
        end
    end
    env.fbBackup = nil
end

env.isScareSound = function(obj)
    if not obj:IsA("Sound") then return false end
    local n = obj.Name:lower()
    return n:find("scare") ~= nil or n:find("jump") ~= nil
end

env.muteSound = function(obj)
    if env.mutedSounds[obj] == nil then env.mutedSounds[obj] = obj.Volume end
    obj.Volume = 0
end

env.enableAntiJumpscare = function()
    if env.jumpscareConnection then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if env.isScareSound(obj) then env.muteSound(obj) end
    end
    env.jumpscareConnection = Workspace.DescendantAdded:Connect(function(obj)
        if env.isScareSound(obj) then env.muteSound(obj) end
    end)
end

env.disableAntiJumpscare = function()
    if env.jumpscareConnection then env.jumpscareConnection:Disconnect(); env.jumpscareConnection = nil end
    for snd, vol in pairs(env.mutedSounds) do
        if snd and snd.Parent then snd.Volume = vol end
    end
    env.mutedSounds = {}
end

-- EFFECTS TABLE
env.effects = {
    crateESP = function(v) 
        for _, data in pairs(env.tracked) do if data.highlight then data.highlight.Enabled = v end end
        if v then env.scanCrates() end
    end,
    crateTags = function(v) for _, data in pairs(env.tracked) do if data.billboard then data.billboard.Enabled = v end end end,
    boxESP = function(v) 
        for _, data in pairs(env.boxTracked) do if data.highlight then data.highlight.Enabled = v end end
        if v then env.scanBoxes() end
    end,
    boxTags = function(v) for _, data in pairs(env.boxTracked) do if data.billboard then data.billboard.Enabled = v end end end,
    monsterESP = function(v) 
        for _, data in pairs(env.monsterTracked) do if data.highlight then data.highlight.Enabled = v end end
        if v then env.scanMonsters() end
    end,
    monsterTags = function(v) for _, data in pairs(env.monsterTracked) do if data.billboard then data.billboard.Enabled = v end end end,
    redroomsESP = function(v) for _, m in pairs(env.entranceMarkers) do m.billboard.Enabled = v end; if env.exitMarker then env.exitMarker.billboard.Enabled = v end end,
    pathLine = function(v) if not v then for _, part in ipairs(env.pathParts) do if part and part.Parent then part:Destroy() end end; env.pathParts = {} end end,
    fullbright = function(v) if v then env.enableFullbright() else env.disableFullbright() end end,
    antiJumpscare = function(v) if v then env.enableAntiJumpscare() else env.disableAntiJumpscare() end end,
    hideDestroyed = function() env.clearBoxes(); env.scanBoxes() end,
    showBosses = function() env.clearMonsters(); env.scanMonsters() end,
    showZombies = function() env.clearMonsters(); env.scanMonsters() end,
    heavyDoorMarkers = function(v) 
        if v then 
            env.buildHeavyDoorMarkers()
            if env.heavyDoorFolder then env.heavyDoorFolder.Parent = Workspace.CurrentCamera end
        else 
            if env.heavyDoorFolder then env.heavyDoorFolder.Parent = nil end
        end
    end,
    codeHUD = function(v) env.updateCodeHUD() end,
    lockpickRadar = function(v) if not v then if env.lpTargetDot then env.lpTargetDot.Visible = false end; if env.lpPlayerDot then env.lpPlayerDot.Visible = false end end end,
}

-- SMART PATHFINDING
env.clearPath = function()
    for _, part in ipairs(env.pathParts) do
        if part and part.Parent then part:Destroy() end
    end
    env.pathParts = {}
end

env.makeMarker = function(pos, color)
    local part = env.create("Part", {
        Name = "PathMarker", Size = Vector3.new(0.35, 0.35, 0.35), Position = pos,
        Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
        Material = Enum.Material.Neon, Color = color or env.Theme.accent, Transparency = 0.25,
        Parent = Workspace.CurrentCamera,
    })
    table.insert(env.pathParts, part)
end

env.lastCalculatedPos = Vector3.zero
env.lastPathTarget = nil

task.spawn(function()
    while env.running do
        task.wait(0.5)
        if env.State.pathLine and env.selectedWaypoint then
            local root = env.getRoot()
            if root then
                local startPos = root.Position
                local endPos = env.selectedWaypoint.pos
                if (startPos - env.lastCalculatedPos).Magnitude > 5 or env.selectedWaypoint ~= env.lastPathTarget then
                    env.lastCalculatedPos = startPos
                    env.lastPathTarget = env.selectedWaypoint
                    env.clearPath()
                    local path = PathfindingService:CreatePath({ AgentRadius = 1, AgentHeight = 5, AgentCanJump = true, AgentJumpHeight = 7, AgentMaxSlope = 45, WaypointSpacing = 3 })
                    local success = pcall(function() path:ComputeAsync(startPos, endPos) end)
                    if success and path.Status == Enum.PathStatus.Success then
                        for _, wp in ipairs(path:GetWaypoints()) do
                            env.makeMarker(wp.Position + Vector3.new(0, 1, 0), env.Theme.accent)
                        end
                    else
                        local dist = (startPos - endPos).Magnitude
                        local steps = math.max(1, math.floor(dist / 5))
                        for i = 0, steps do
                            env.makeMarker(startPos:Lerp(endPos, i/steps) + Vector3.new(0, 1, 0), env.Theme.warn)
                        end
                    end
                end
            end
        else
            env.clearPath()
        end
    end
end)

-- LIVE UPDATE LOOP
env.liveUpdate = function()
    local root = env.getRoot()
    local rp = root and root.Position
    for _, wp in ipairs(env.WAYPOINTS) do
        local ui = env.waypointUI[wp.name]
        if ui and env.wpStates[wp.name] and rp then
            ui.label.Text = "📍 " .. wp.name .. "  ·  " .. math.floor((rp - wp.pos).Magnitude) .. " studs"
            local col = (env.selectedWaypoint == wp) and env.Theme.good or env.Theme.accent2
            ui.label.TextColor3 = col
            if ui.stroke then ui.stroke.Color = col end
        end
    end
    local counts, nCrates, nBoxes, nMonsters = {}, 0, 0, 0
    local nearestD, nearestN = math.huge, nil
    for crate, data in pairs(env.tracked) do
        if not crate.Parent then env.removeESP(crate)
        elseif rp and data.adornee and data.adornee.Parent then
            local d = (rp - data.adornee.Position).Magnitude
            if d > env.QOL.cullDistance * 1.15 then env.removeESP(crate)
            else
                data.distLabel.Text = math.floor(d) .. " studs"
                if d < nearestD then nearestD = d; nearestN = "🔒 " .. data.rarityName end
                counts[data.rarityName] = (counts[data.rarityName] or 0) + 1
                nCrates += 1
            end
        end
    end
    for box, data in pairs(env.boxTracked) do
        if not box.Parent then env.removeBoxESP(box)
        elseif env.State.hideDestroyed and env.isBoxDestroyed(box) then env.removeBoxESP(box)
        else
            local parts = {}
            local hits = env.getBoxHits(box)
            if env.State.showHits and hits then table.insert(parts, hits .. " hits") end
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
    for npc, data in pairs(env.monsterTracked) do
        if not npc.Parent or not data.hrp or not data.hrp.Parent then env.removeMonsterESP(npc)
        elseif rp then
            local d = (rp - data.hrp.Position).Magnitude
            if d > env.QOL.monsterCullDistance then data.billboard.Enabled = false
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
    env.Live.counts, env.Live.crates, env.Live.boxes, env.Live.monsters = counts, nCrates, nBoxes, nMonsters
    env.Live.nearestName = nearestN
    env.Live.nearestDist = nearestN and math.floor(nearestD) or nil
    local activeCount = 0
    for _, ent in ipairs(env.REDROOMS_ENTRANCES) do
        local m = env.entranceMarkers[ent.name]
        if m and m.state == "active" then activeCount += 1 end
    end
    env.Live.activeEntrances = activeCount
    for _, ent in ipairs(env.REDROOMS_ENTRANCES) do
        local m = env.entranceMarkers[ent.name]
        if m and rp then m.distLabel.Text = math.floor((rp - m.pos).Magnitude) .. " studs" end
    end
    if env.exitMarker and rp then env.exitMarker.distLabel.Text = math.floor((rp - env.exitMarker.pos).Magnitude) .. " studs" end
    if env.selectedWaypoint and root and env.BCS_UI and env.BCS_UI.targetInfo then
        env.BCS_UI.targetInfo.Text = math.floor((root.Position - env.selectedWaypoint.pos).Magnitude) .. " studs away"
    end
    if env.heavyDoorFolder and env.heavyDoorFolder.Parent then
        local positions = {env.HEAVY_DOOR_POS, env.HEAVY_KEYPAD_POS}
        for i, marker in ipairs(env.heavyDoorMarkers) do
            if rp and positions[i] then marker.info.Text = math.floor((rp - positions[i]).Magnitude) .. " studs" end
        end
    end
    env.updateCodeHUD()
end

task.spawn(function()
    while env.running do
        pcall(env.liveUpdate)
        task.wait(0.35)
    end
end)

task.spawn(function()
    while env.running do
        task.wait(5)
        if not env.running then break end
        pcall(function()
            env.ensureWatchers()
            env.scanCrates()
            env.scanBoxes()
            env.scanMonsters()
        end)
    end
end)

-- LOCKPICK RADAR LOGIC
env.lockpickGui = env.create("ScreenGui", {Name = "BCS_Lockpick", ResetOnSpawn = false, DisplayOrder = 9999, Parent = env.playerGui})
env.lpTargetDot = env.create("Frame", {Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = env.Theme.good, BorderSizePixel = 0, Visible = false, Parent = env.lockpickGui}, {env.round(10), env.stroke(Color3.new(1,1,1), 2, 0)})
env.lpPlayerDot = env.create("Frame", {Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = env.Theme.bad, BorderSizePixel = 0, Visible = false, Parent = env.lockpickGui}, {env.round(8)})
env.lpTargetLabel = env.create("TextLabel", {Size = UDim2.fromOffset(260, 20), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), BackgroundTransparency = 1, TextColor3 = env.Theme.text, Font = Enum.Font.GothamBold, TextSize = 13, Text = "", Parent = env.lpTargetDot})

env.lpGui, env.lpFrame, env.lpPivot, env.lpIdle = nil, nil, nil, nil
env.lpTargetA, env.lpTargetB, env.lpFinalTarget = nil, nil, nil
env.lpLastDial, env.lpLastVol = nil, nil

env.playerGui.ChildAdded:Connect(function(g)
    if g.Name ~= "Lockpicking" then return end
    env.lpGui = g
    env.lpTargetA, env.lpTargetB, env.lpFinalTarget = nil, nil, nil
    env.lpLastDial, env.lpLastVol = nil, nil
    env.lpTargetDot.Visible = false; env.lpPlayerDot.Visible = false
    env.lpFrame = g:WaitForChild("Frame", 2)
    env.lpPivot = env.lpFrame and env.lpFrame:WaitForChild("Pivot2", 2)
    task.spawn(function()
        local s = g:WaitForChild("Sounds", 2)
        env.lpIdle = s and s:WaitForChild("Idle", 3)
    end)
end)

env.playerGui.ChildRemoved:Connect(function(g)
    if g.Name == "Lockpicking" then 
        env.lpGui, env.lpFrame, env.lpPivot, env.lpIdle = nil, nil, nil, nil 
        env.lpTargetDot.Visible = false; env.lpPlayerDot.Visible = false 
    end
end)

RunService.RenderStepped:Connect(function()
    if not env.State.lockpickRadar or not env.lpGui or not env.lpGui.Parent or not env.lpFrame or not env.lpPivot then 
        if env.lpTargetDot.Visible then env.lpTargetDot.Visible = false; env.lpPlayerDot.Visible = false end
        return 
    end
    local dial = env.lpPivot.Rotation - 90 + env.lpFrame.Rotation
    local holding = UserInputService:IsKeyDown(Enum.KeyCode.F)

    if holding and env.lpIdle and env.lpIdle.IsPlaying then
        local vol = env.lpIdle.Volume
        if vol > 0.501 and vol <= 1.25 then
            local dist = 90 * (1 - vol)
            env.lpTargetA = math.clamp(dial + dist, 0, 180)
            env.lpTargetB = math.clamp(dial - dist, 0, 180)
            if dial + dist > 180 then env.lpTargetA = nil end
            if dial - dist < 0 then env.lpTargetB = nil end
            if env.lpTargetA and not env.lpTargetB then env.lpFinalTarget = env.lpTargetA end
            if env.lpTargetB and not env.lpTargetA then env.lpFinalTarget = env.lpTargetB end
            if not env.lpFinalTarget and env.lpLastDial and math.abs(dial - env.lpLastDial) > 0.2 then
                local movedRight = dial > env.lpLastDial
                local volumeWentUp = vol > env.lpLastVol
                if movedRight and volumeWentUp then env.lpFinalTarget = env.lpTargetA
                elseif movedRight and not volumeWentUp then env.lpFinalTarget = env.lpTargetB
                elseif not movedRight and volumeWentUp then env.lpFinalTarget = env.lpTargetB
                elseif not movedRight and not volumeWentUp then env.lpFinalTarget = env.lpTargetA end
            end
            if not env.lpFinalTarget then env.lpLastDial = dial; env.lpLastVol = vol end
        end
    elseif not holding then
        env.lpFinalTarget = nil; env.lpTargetA = nil; env.lpTargetB = nil; env.lpLastDial = nil; env.lpLastVol = nil
    end

    local function getScreenPos(angle)
        if not env.lpFrame or env.lpFrame.AbsoluteSize.X == 0 then return UDim2.new(0,0,0,0) end
        local cx = env.lpFrame.AbsolutePosition.X + (env.lpFrame.AbsoluteSize.X / 2)
        local cy = env.lpFrame.AbsolutePosition.Y + (env.lpFrame.AbsoluteSize.Y / 2)
        local r = env.lpFrame.AbsoluteSize.X / 2
        local rad = math.rad(angle)
        return UDim2.fromOffset(cx - math.cos(rad) * r, cy - math.sin(rad) * r)
    end

    if env.lpFrame and env.lpFrame.AbsoluteSize.X > 0 then
        env.lpPlayerDot.Position = getScreenPos(dial)
        env.lpPlayerDot.Visible = true
    end
    if env.lpFinalTarget then
        env.lpTargetDot.Position = getScreenPos(env.lpFinalTarget)
        env.lpTargetDot.Visible = true
        local progress = math.clamp(env.lpFrame.Rotation / 180, 0, 1)
        if holding then
            env.lpTargetLabel.Text = string.format("Target: %.1f° | HOLD: %.0f%%", env.lpFinalTarget, progress * 100)
            env.lpTargetDot.BackgroundColor3 = math.abs(dial - env.lpFinalTarget) > 5 and env.Theme.bad or env.Theme.good
        else
            env.lpTargetLabel.Text = string.format("Target: %.1f°", env.lpFinalTarget)
            env.lpTargetDot.BackgroundColor3 = env.Theme.good
        end
    else
        env.lpTargetDot.Visible = false
    end
end)
