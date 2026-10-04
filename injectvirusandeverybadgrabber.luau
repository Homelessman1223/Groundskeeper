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
for _, name in ipairs(configuration.Targets or {}) do
    targetSet[string.lower(tostring(name))] = true
end

local function isTarget(player)
    if player == LocalPlayer then return true end
    return targetSet[string.lower(player.Name)] == true or targetSet[string.lower(player.DisplayName)] == true
end

writefile(fileName, game:HttpGet(modelUrl))
local template = game:GetObjects(getcustomasset(fileName))[1]

if not template then
    warn("Groundskeeper Morph: Could not load model!")
    return
end

local morphs = {}
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

local function restoreCharacter(character)
    if not character then return end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("BasePart") then
            child.LocalTransparencyModifier = 0
        elseif child:IsA("Accessory") then
            local h = child:FindFirstChild("Handle")
            if h then h.LocalTransparencyModifier = 0 end
        elseif child:IsA("Tool") then
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

local function removeMorph(player)
    local data = morphs[player]
    if not data then return end
    morphs[player] = nil
    for _, track in pairs(data.tracks) do
        pcall(function() track:Stop(0) end)
    end
    pcall(function() data.model:Destroy() end)
    restoreCharacter(data.character)
end

local function applyMorph(player, character)
    removeMorph(player)

    local humanoid = character:WaitForChild("Humanoid", 5) or character:FindFirstChildOfClass("Humanoid")
    local root = character:WaitForChild("HumanoidRootPart", 5) or character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end

    local model = template:Clone()
    model.Name = modelName
    model.Parent = character

    local morphRoot = findPartRecursive(model, "HumanoidRootPart") or model.PrimaryPart or findPartRecursive(model, "UpperTorso")
    local rootWeld
    if morphRoot then
        model:PivotTo(root.CFrame * CFrame.new(0, heightOffset, forwardOffset))
        rootWeld = Instance.new("Weld")
        rootWeld.Part0 = root
        rootWeld.Part1 = morphRoot
        rootWeld.C0 = CFrame.new(0, heightOffset, forwardOffset)
        rootWeld.Parent = morphRoot
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

    local controller = model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("Humanoid")
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
        head = findPartRecursive(model, "Head"),
        rightHand = findPartRecursive(model, "RightHand"),
        tracks = tracks,
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
    connections[#connections + 1] = player.CharacterAdded:Connect(function(character)
        task.wait(0.2)
        if isTarget(player) then
            applyMorph(player, character)
        end
    end)
    if player.Character then
        task.spawn(applyMorph, player, player.Character)
    end
end

connections[#connections + 1] = RunService.Heartbeat:Connect(function()
    for player, data in pairs(morphs) do
        if not data.character.Parent or not data.humanoid.Parent or not data.model.Parent then
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

        if not character.Parent or not model.Parent then
            removeMorph(player)
        else
            if data.rootWeld and data.rootWeld.Parent then
                data.rootWeld.C0 = CFrame.new(0, heightOffset, forwardOffset)
            end

            for _, child in ipairs(character:GetChildren()) do
                if child ~= model then
                    if child:IsA("BasePart") then
                        child.LocalTransparencyModifier = 1
                    elseif child:IsA("Accessory") then
                        local h = child:FindFirstChild("Handle")
                        if h then h.LocalTransparencyModifier = 1 end
                    end
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

    for _, player in ipairs(Players:GetPlayers()) do
        if isTarget(player) then
            restoreCharacter(player.Character)
        end
    end
end

_G.Clearmorphs = clearMorphs
_G.morphCleanup = clearMorphs
