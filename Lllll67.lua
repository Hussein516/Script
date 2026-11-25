--jsjsjsjsnsn
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local ScaleFactor = 3.4
local ContainerName = "7S_Replicas"
local Entries = {}
local Versions = {}

local function GetContainer()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local container = camera:FindFirstChild(ContainerName)
    if not container then
        container = Instance.new("Folder")
        container.Name = ContainerName
        container.Parent = camera
    end
    return container
end

local function GetTorso(character)
    return character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function IsAppearanceItem(child)
    return child:IsA("Shirt") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") or (child:IsA("CharacterMesh") and child.BodyPart == Enum.BodyPart.Torso)
end

local function Release(player)
    local entry = Entries[player]
    if not entry then return end
    Entries[player] = nil
    local torso = entry.Torso
    if torso and torso.Parent then
        torso.Size = entry.OriginalSize
        torso.Transparency = entry.OriginalTransparency
        torso.CanCollide = entry.OriginalCanCollide
        for _, child in ipairs(torso:GetChildren()) do
            if child:IsA("FaceInstance") then
                local saved = child:GetAttribute("HiddenBy7S")
                if typeof(saved) == "number" then
                    child.Transparency = saved
                    child:SetAttribute("HiddenBy7S", nil)
                end
            end
        end
    end
    if entry.Model then
        entry.Model:Destroy()
    end
end

local function Build(player, character)
    Release(player)
    if not character.Parent or player.Character ~= character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local torso = GetTorso(character)
    if not torso then return end

    local body = torso:Clone()
    if not body then return end
    for _, child in ipairs(body:GetChildren()) do
        if not (child:IsA("DataModelMesh") or child:IsA("FaceInstance") or child:IsA("SurfaceAppearance")) then
            child:Destroy()
        end
    end
    body.Anchored = true
    body.CanCollide = false
    body.CanTouch = false
    body.CanQuery = false
    body.Massless = true

    local model = Instance.new("Model")
    model.Name = player.Name

    local replicaHumanoid = Instance.new("Humanoid")
    replicaHumanoid.RigType = humanoid.RigType
    replicaHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    replicaHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    replicaHumanoid.BreakJointsOnDeath = false
    replicaHumanoid.RequiresNeck = false
    pcall(function()
        replicaHumanoid.EvaluateStateMachine = false
    end)
    replicaHumanoid.Parent = model

    body.Parent = model

    for _, child in ipairs(character:GetChildren()) do
        if IsAppearanceItem(child) then
            local clone = child:Clone()
            if clone then
                clone.Parent = model
            end
        end
    end

    model.PrimaryPart = body
    model.Parent = GetContainer() or workspace

    local entry = {
        Character = character,
        Torso = torso,
        Humanoid = humanoid,
        Model = model,
        Body = body,
        OriginalSize = torso.Size,
        OriginalTransparency = torso.Transparency,
        OriginalCanCollide = torso.CanCollide
    }
    Entries[player] = entry

    for _, child in ipairs(torso:GetChildren()) do
        if child:IsA("FaceInstance") and child.Transparency < 1 then
            child:SetAttribute("HiddenBy7S", child.Transparency)
            child.Transparency = 1
        end
    end

    torso.Size = entry.OriginalSize * ScaleFactor
    torso.Transparency = 1
    torso.CanCollide = false
    body.CFrame = torso.CFrame
end

local function WaitForAppearance(player, character)
    local waited = 0
    while waited < 5 and character.Parent do
        local ok, loaded = pcall(function()
            return player:HasAppearanceLoaded()
        end)
        if ok and loaded then break end
        task.wait(0.25)
        waited += 0.25
    end
end

local function Watch(player, character)
    if player == LocalPlayer then return end

    local torso = character:WaitForChild("Torso", 5) or character:WaitForChild("UpperTorso", 5)
    if not torso then return end

    WaitForAppearance(player, character)
    if not character.Parent then return end
    task.wait(0.25)

    Build(player, character)

    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.Died:Connect(function()
            Release(player)
        end)
    end

    local function Schedule()
        local token = (Versions[player] or 0) + 1
        Versions[player] = token
        task.delay(0.3, function()
            if Versions[player] == token and character.Parent and player.Character == character then
                Build(player, character)
            end
        end)
    end

    character.ChildAdded:Connect(function(child)
        if child.Name == "Torso" or child.Name == "UpperTorso" or IsAppearanceItem(child) then
            Schedule()
        end
    end)

    character.ChildRemoved:Connect(function(child)
        if child.Name == "Torso" or child.Name == "UpperTorso" then
            Release(player)
            Schedule()
        end
    end)

    character.AncestryChanged:Connect(function()
        if not character.Parent then
            Release(player)
        end
    end)
end

local function SetupPlayer(player)
    if player == LocalPlayer then return end
    if player.Character then
        task.spawn(Watch, player, player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        task.spawn(Watch, player, character)
    end)
end

RunService.RenderStepped:Connect(function()
    local container = GetContainer()
    for player, entry in pairs(Entries) do
        local torso = entry.Torso
        if not entry.Character.Parent or torso.Parent ~= entry.Character or entry.Humanoid.Health <= 0 then
            Release(player)
        else
            entry.Body.CFrame = torso.CFrame
            if container and entry.Model.Parent ~= container then
                entry.Model.Parent = container
            end
        end
    end
end)

RunService.Stepped:Connect(function()
    for _, entry in pairs(Entries) do
        entry.Torso.CanCollide = false
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    SetupPlayer(player)
end

Players.PlayerAdded:Connect(SetupPlayer)

Players.PlayerRemoving:Connect(function(player)
    Release(player)
    Versions[player] = nil
end)
