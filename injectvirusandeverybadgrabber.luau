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

if _G.morphCleanup then
    pcall(_G.morphCleanup)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local camera = workspace.CurrentCamera

local Humanoid = Character:WaitForChild("Humanoid", 5) or Character:FindFirstChildOfClass("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart", 5) or Character:FindFirstChild("HumanoidRootPart")

if not Humanoid or not RootPart then
    warn("Groundskeeper Morph: Could not find Humanoid or HumanoidRootPart!")
    return
end

writefile(fileName, game:HttpGet(modelUrl))

local rawModel = getcustomasset(fileName)
local morphModel = game:GetObjects(rawModel)[1]

if morphModel then
    morphModel.Name = modelName
    morphModel.Parent = Character

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

    local morphRoot = findPartRecursive(morphModel, "HumanoidRootPart") or morphModel.PrimaryPart or findPartRecursive(morphModel, "UpperTorso")
    local morphHeadPart = findPartRecursive(morphModel, "Head")
    local morphRightHand = findPartRecursive(morphModel, "RightHand")

    local rootWeld
    if morphRoot then
        morphModel:PivotTo(RootPart.CFrame * CFrame.new(0, heightOffset, forwardOffset))

        rootWeld = Instance.new("Weld")
        rootWeld.Part0 = RootPart
        rootWeld.Part1 = morphRoot
        rootWeld.C0 = CFrame.new(0, heightOffset, forwardOffset)
        rootWeld.Parent = morphRoot
    end

    for _, part in ipairs(morphModel:GetDescendants()) do
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

    local morphController = morphModel:FindFirstChildOfClass("AnimationController") or morphModel:FindFirstChildOfClass("Humanoid")
    if not morphController then
        morphController = Instance.new("AnimationController", morphModel)
    end

    local animator = morphController:FindFirstChildOfClass("Animator") or Instance.new("Animator", morphController)
    local loadedTracks = {}

    for name, id in pairs(animIds) do
        local anim = Instance.new("Animation")
        anim.AnimationId = id
        loadedTracks[name] = animator:LoadAnimation(anim)
    end

    local currentAnim = nil
    local function playAnim(name)
        if currentAnim == name then return end

        for animName, track in pairs(loadedTracks) do
            if animName ~= name and track.IsPlaying then
                track:Stop(0.15)
            end
        end

        if loadedTracks[name] and not loadedTracks[name].IsPlaying then
            loadedTracks[name]:Play(0.15)
            currentAnim = name
        end
    end

    local animConnection
    animConnection = RunService.Heartbeat:Connect(function()
        if not Character or not Humanoid or not Humanoid.Parent then
            if animConnection then animConnection:Disconnect() end
            return
        end

        local isMoving = Humanoid.MoveDirection.Magnitude > 0.05
        local currentSpeed = RootPart.AssemblyLinearVelocity.Magnitude

        if isMoving and currentSpeed > 0.5 then
            if currentSpeed > 18 then
                playAnim("Run")
            else
                playAnim("Walk")
            end
        else
            playAnim("Idle")
        end
    end)

    local BIND_NAME = "GroundskeeperMorphRender"
    RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
        if not Character or not Character.Parent or not morphModel.Parent then
            RunService:UnbindFromRenderStep(BIND_NAME)
            if animConnection then animConnection:Disconnect() end
            return
        end

        if rootWeld and rootWeld.Parent then
            rootWeld.C0 = CFrame.new(0, heightOffset, forwardOffset)
        end

        for _, child in ipairs(Character:GetChildren()) do
            if child ~= morphModel then
                if child:IsA("BasePart") then
                    child.LocalTransparencyModifier = 1
                elseif child:IsA("Accessory") then
                    local h = child:FindFirstChild("Handle")
                    if h then h.LocalTransparencyModifier = 1 end
                end
            end
        end

        for _, part in ipairs(morphModel:GetDescendants()) do
            if part:IsA("BasePart") then
                part.LocalTransparencyModifier = (part.Name == "HumanoidRootPart") and 1 or 0
            end
        end

        if camera and morphHeadPart and morphHeadPart:IsDescendantOf(workspace) then
            local lookVector = camera.CFrame.LookVector
            local upVector = camera.CFrame.UpVector
            local headPos = morphHeadPart.Position
            local isThirdPerson = (camera.CFrame.Position - camera.Focus.Position).Magnitude > 1

            if isThirdPerson then
                local camPos = headPos - (lookVector * thirdPersonDistance) + Vector3.new(0, 2, 0)
                camera.CFrame = CFrame.lookAt(camPos, headPos, upVector)
            else
                local targetPosition = morphHeadPart.CFrame:PointToWorldSpace(firstPersonOffset)
                camera.CFrame = CFrame.lookAt(targetPosition, targetPosition + lookVector, upVector)
            end
        end

        if morphRightHand then
            for _, tool in ipairs(Character:GetChildren()) do
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
                            morphWeld.Part0 = morphRightHand
                            morphWeld.Part1 = handle
                            morphWeld.C0 = toolGripOffset
                            morphWeld.Parent = handle
                        elseif morphWeld.Part0 ~= morphRightHand then
                            morphWeld.Part0 = morphRightHand
                        end
                    end
                end
            end
        end
    end)

    _G.morphCleanup = function()
        pcall(function() RunService:UnbindFromRenderStep(BIND_NAME) end)
        if animConnection then animConnection:Disconnect() end
        if morphModel then morphModel:Destroy() end
    end
end
