local configuration = getgenv().ConfigurationGroundsKeeper or {}

local modelName = "Groundskeeper"
local modelUrl = "https://github.com/Homelessman1223/Groundskeeper/raw/refs/heads/main/Groundskeeper.rbxm?v=" .. tostring(os.time())
local fileName = "GroundskeeperModel.rbxm"

local animIds = {
    Idle = "rbxassetid://87364105526050",
    Walk = "rbxassetid://95687628996174",
    Run  = "rbxassetid://86672306590660",
}
local heightOffset = 0
local autoGround = true
local forwardOffset = 0.5
local toolGripOffset = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
local firstPersonOffset = Vector3.new(0, 0.2, -1)
local thirdPersonDistance = 12

if _G.Clearmorphs then
    pcall(_G.Clearmorphs)
end
if _G.morphCleanup then
    pcall(_G.morphCleanup)
end

if configuration.Credits == true then
    print("Loaded groundskeeper morph")
    print("Made by Homeless, Lolcat!")
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local targetSet = {}
local excluded = {}
for _, name in ipairs(configuration.Targets or {}) do
    targetSet[string.lower(tostring(name))] = true
end

local function isTarget(player)
    if excluded[string.lower(player.Name)] or excluded[string.lower(player.DisplayName)] then return false end
    if player == LocalPlayer then return true end
    return targetSet[string.lower(player.Name)] == true or targetSet[string.lower(player.DisplayName)] == true
end

writefile(fileName, game:HttpGet(modelUrl))
local template = game:GetObjects(getcustomasset(fileName))[1]

if not template then
    warn("Groundskeeper Morph: Could not load model!")
    return
end

local active = true
local morphs = {}
local tokens = {}
local hooked = {}
local connections = {}
local BIND_NAME = "GroundskeeperMorphRender"

local function findPartRecursive(parent, targetName)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("BasePart") and child.Name == targetName then
            return child
        end
        local found = findPartRecursive(child, targetName)
        if found then return found end
    end
    return nil
end

local function restoreCharacter(data)
    if not data then return end

    for part, saved in pairs(data.saved) do
        if part.Parent then
            part.Transparency = saved.Transparency
            part.CanCollide = saved.CanCollide
            part.LocalTransparencyModifier = 0
        end
    end

    local character = data.character
    if character and character.Parent then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") then
                local handle = child:FindFirstChild("Handle")
                if handle then
                    local morphWeld = handle:FindFirstChild("MorphWeld")
                    if morphWeld then morphWeld:Destroy() end
                    for _, gripName in ipairs({"RightGrip", "LeftGrip"}) do
                        local grip = handle:FindFirstChild(gripName)
                        if grip and grip:IsA("Motor6D") then
                            grip.Enabled = true
                        end
                    end
                end
            end
        end
    end
end

local function removeMorph(player)
    tokens[player] = nil
    local data = morphs[player]
    if not data then return end
    morphs[player] = nil

    for _, track in pairs(data.tracks) do
        pcall(function() track:Stop(0) end)
    end
    pcall(function()
        if data.rootWeld then data.rootWeld:Destroy() end
    end)
    pcall(function() data.model:Destroy() end)
    pcall(restoreCharacter, data)
end

local function applyMorph(player, character)
    removeMorph(player)

    local token = {}
    tokens[player] = token

    local humanoid = character:WaitForChild("Humanoid", 5)
    local root = character:WaitForChild("HumanoidRootPart", 5)

    if not active or tokens[player] ~= token or not character.Parent or not player.Parent or not humanoid or not root then
        return
    end

    local model = template:Clone()
    model.Name = modelName

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("Humanoid") then
            descendant:Destroy()
        end
    end

    local saved = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            saved[part] = {Transparency = part.Transparency, CanCollide = part.CanCollide}
            part.Transparency = 1
            part.CanCollide = false
        end
    end

    local morphRoot = findPartRecursive(model, "HumanoidRootPart") or model.PrimaryPart or findPartRecursive(model, "UpperTorso")
    if morphRoot then
        model.PrimaryPart = morphRoot
    end

    local groundOffset = 0
    if autoGround and morphRoot then
        local ok, result = pcall(function()
            local charCF, charSize = character:GetBoundingBox()
            local charBottom = root.CFrame:PointToObjectSpace(charCF.Position).Y - charSize.Y / 2
            local morphCF, morphSize = model:GetBoundingBox()
            local morphBottom = morphRoot.CFrame:PointToObjectSpace(morphCF.Position).Y - morphSize.Y / 2
            return charBottom - morphBottom
        end)
        if ok and type(result) == "number" then
            groundOffset = result
        end
    end

    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Massless = true
            if part.Name == "HumanoidRootPart" then
                part.Transparency = 1
                part.CastShadow = false
            end
        end
    end

    if morphRoot then
        model:PivotTo(root.CFrame * CFrame.new(0, groundOffset + heightOffset, forwardOffset))
    end

    model.Parent = workspace

    local rootWeld
    if morphRoot then
        rootWeld = Instance.new("Weld")
        rootWeld.Part0 = root
        rootWeld.Part1 = morphRoot
        rootWeld.C0 = CFrame.new(0, groundOffset + heightOffset, forwardOffset)
        rootWeld.Parent = root
    end

    local controller = model:FindFirstChildOfClass("AnimationController")
    if not controller then
        controller = Instance.new("AnimationController", model)
    end
    local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)

    local tracks = {}
    for name, id in pairs(animIds) do
        local anim = Instance.new("Animation")
        anim.AnimationId = id
        tracks[name] = animator:LoadAnimation(anim)
    end

    morphs[player] = {
        player = player,
        character = character,
        humanoid = humanoid,
        root = root,
        model = model,
        rootWeld = rootWeld,
        groundOffset = groundOffset,
        head = findPartRecursive(model, "Head"),
        rightHand = findPartRecursive(model, "RightHand"),
        tracks = tracks,
        saved = saved,
        currentAnim = nil,
    }
end

local function playAnim(data, name)
    if data.currentAnim == name then return end
    for animName, track in pairs(data.tracks) do
        if animName ~= name and track.IsPlaying then
            track:Stop(0.15)
        end
    end
    local track = data.tracks[name]
    if track and not track.IsPlaying then
        track:Play(0.15)
        data.currentAnim = name
    end
end

local function hookPlayer(player)
    hooked[player] = true
    connections[#connections + 1] = player.CharacterAdded:Connect(function(character)
        task.wait(0.2)
        if active and isTarget(player) and player.Parent then
            applyMorph(player, character)
        end
    end)
    if player.Character then
        task.spawn(applyMorph, player, player.Character)
    end
end

connections[#connections + 1] = Players.PlayerRemoving:Connect(function(player)
    removeMorph(player)
    hooked[player] = nil
end)

connections[#connections + 1] = RunService.Heartbeat:Connect(function()
    for player, data in pairs(morphs) do
        if not player.Parent or not data.character.Parent or not data.humanoid.Parent or not data.root.Parent or not data.model.Parent then
            removeMorph(player)
        else
            local isMoving = data.humanoid.MoveDirection.Magnitude > 0.05
            local speed = data.root.AssemblyLinearVelocity.Magnitude
            if isMoving and speed > 0.5 then
                playAnim(data, speed > 18 and "Run" or "Walk")
            else
                playAnim(data, "Idle")
            end
        end
    end
end)

RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
    for player, data in pairs(morphs) do
        local character = data.character
        local model = data.model

        if not player.Parent or not character.Parent or not model.Parent then
            removeMorph(player)
        else
            if data.rootWeld and data.rootWeld.Parent then
                data.rootWeld.C0 = CFrame.new(0, data.groundOffset + heightOffset, forwardOffset)
            end

            for _, child in ipairs(character:GetChildren()) do
                if child:IsA("BasePart") then
                    child.LocalTransparencyModifier = 1
                elseif child:IsA("Accessory") then
                    local h = child:FindFirstChild("Handle")
                    if h then h.LocalTransparencyModifier = 1 end
                end
            end

            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.LocalTransparencyModifier = (part.Name == "HumanoidRootPart") and 1 or 0
                end
            end

            local camera = workspace.CurrentCamera
            if player == LocalPlayer and camera and data.head and data.head:IsDescendantOf(workspace) then
                local lookVector = camera.CFrame.LookVector
                local upVector = camera.CFrame.UpVector
                local headPos = data.head.Position
                local isThirdPerson = (camera.CFrame.Position - camera.Focus.Position).Magnitude > 1

                if isThirdPerson then
                    local camPos = headPos - (lookVector * thirdPersonDistance) + Vector3.new(0, 2, 0)
                    camera.CFrame = CFrame.lookAt(camPos, headPos, upVector)
                else
                    local targetPosition = data.head.CFrame:PointToWorldSpace(firstPersonOffset)
                    camera.CFrame = CFrame.lookAt(targetPosition, targetPosition + lookVector, upVector)
                end
            end

            if data.rightHand then
                for _, tool in ipairs(character:GetChildren()) do
                    if tool:IsA("Tool") then
                        local handle = tool:FindFirstChild("Handle")
                        if handle then
                            for _, gripName in ipairs({"RightGrip", "LeftGrip"}) do
                                local grip = handle:FindFirstChild(gripName)
                                if grip then
                                    if grip:IsA("Motor6D") then
                                        grip.Enabled = false
                                    else
                                        grip:Destroy()
                                    end
                                end
                            end

                            handle.Massless = true
                            local morphWeld = handle:FindFirstChild("MorphWeld")
                            if not morphWeld then
                                morphWeld = Instance.new("Weld")
                                morphWeld.Name = "MorphWeld"
                                morphWeld.Part0 = data.rightHand
                                morphWeld.Part1 = handle
                                morphWeld.C0 = toolGripOffset
                                morphWeld.Parent = handle
                            elseif morphWeld.Part0 ~= data.rightHand then
                                morphWeld.Part0 = data.rightHand
                            end
                        end
                    end
                end
            end
        end
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    if isTarget(player) then
        hookPlayer(player)
    end
end

connections[#connections + 1] = Players.PlayerAdded:Connect(function(player)
    if isTarget(player) then
        hookPlayer(player)
    end
end)

local function clearMorphs()
    active = false

    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)
    pcall(function() RunService:UnbindFromRenderStep(BIND_NAME) end)

    local list = {}
    for player in pairs(morphs) do
        list[#list + 1] = player
    end
    for _, player in ipairs(list) do
        removeMorph(player)
    end
    table.clear(tokens)
end

local function matchPlayers(username)
    local lowered = string.lower(tostring(username))
    local found = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if string.lower(player.Name) == lowered or string.lower(player.DisplayName) == lowered then
            found[#found + 1] = player
        end
    end
    return found
end

_G.Clearmorphs = clearMorphs
_G.morphCleanup = clearMorphs
_G.morphCleanupAll = clearMorphs

_G.morphAdd = function(username)
    if not active then
        warn("Groundskeeper Morph: cleared, run the script again first")
        return
    end
    local lowered = string.lower(tostring(username))
    excluded[lowered] = nil
    targetSet[lowered] = true
    for _, player in ipairs(matchPlayers(username)) do
        if not hooked[player] then
            hookPlayer(player)
        elseif not morphs[player] and player.Character then
            task.spawn(applyMorph, player, player.Character)
        end
    end
end

_G.morphRemove = function(username)
    local lowered = string.lower(tostring(username))
    targetSet[lowered] = nil
    excluded[lowered] = true
    for _, player in ipairs(matchPlayers(username)) do
        removeMorph(player)
    end
end


--loadstring(game:HttpGet("https://raw.githubusercontent.com/Homelessman1223/Groundskeeper/refs/heads/main/injectvirusandeverybadgrabber.luau"))()
