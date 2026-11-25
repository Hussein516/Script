local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local SavedTorsos = {}
local ReplicaName = "7S_TorsoReplica"
local NoColName = "7S_NoCol"
local ScaleFactor = 3.4

local function GetTorso(character)
    return character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function IsAppearanceItem(child)
    return child:IsA("Shirt") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") or (child:IsA("CharacterMesh") and child.BodyPart == Enum.BodyPart.Torso)
end

local function ApplyNoCollisionWithLocal(targetPart)
    if not targetPart or not targetPart:IsA("BasePart") then return end
    for _, child in ipairs(targetPart:GetChildren()) do
        if child.Name == NoColName then
            child:Destroy()
        end
    end
    local localChar = LocalPlayer.Character
    if not localChar then return end
    for _, part in ipairs(localChar:GetDescendants()) do
        if part:IsA("BasePart") then
            local ncc = Instance.new("NoCollisionConstraint")
            ncc.Name = NoColName
            ncc.Part0 = targetPart
            ncc.Part1 = part
            ncc.Parent = targetPart
        end
    end
end

local function RemoveReplica(character)
    local existing = character:FindFirstChild(ReplicaName)
    if existing then
        existing:Destroy()
    end
end

local function DestroyData(data)
    if not data then return end
    if data.Body then
        data.Body:Destroy()
    end
    if data.Appearance then
        for _, item in ipairs(data.Appearance) do
            item:Destroy()
        end
    end
end

local function ResetCharacterState(player, character)
    RemoveReplica(character)
    local torso = GetTorso(character)
    local data = SavedTorsos[player.UserId]
    if torso and data and data.OriginalSize then
        torso.Size = data.OriginalSize
        torso.Transparency = data.OriginalTransparency
        torso.CanCollide = data.OriginalCanCollide
        torso.Massless = data.OriginalMassless
        for _, child in ipairs(torso:GetChildren()) do
            if child:IsA("FaceInstance") and child:GetAttribute("HiddenBy7S") then
                child.Transparency = 0
                child:SetAttribute("HiddenBy7S", nil)
            end
        end
    end
end

local function CaptureAppearance(player, character)
    local data = SavedTorsos[player.UserId]
    if not data then return end
    if data.Appearance then
        for _, item in ipairs(data.Appearance) do
            item:Destroy()
        end
    end
    local list = {}
    for _, child in ipairs(character:GetChildren()) do
        if IsAppearanceItem(child) then
            local clone = child:Clone()
            if clone then
                table.insert(list, clone)
            end
        end
    end
    data.Appearance = list
end

local function CaptureTorso(player, character)
    local torso = GetTorso(character)
    if not torso then return end

    DestroyData(SavedTorsos[player.UserId])

    local body = torso:Clone()
    if not body then return end
    for _, child in ipairs(body:GetChildren()) do
        if not (child:IsA("DataModelMesh") or child:IsA("FaceInstance") or child:IsA("SurfaceAppearance")) then
            child:Destroy()
        end
    end
    body.Anchored = false
    body.CanCollide = false
    body.CanTouch = false
    body.CanQuery = false
    body.Massless = true

    local humanoid = character:FindFirstChildOfClass("Humanoid")

    SavedTorsos[player.UserId] = {
        OriginalSize = torso.Size,
        OriginalTransparency = torso.Transparency,
        OriginalCanCollide = torso.CanCollide,
        OriginalMassless = torso.Massless,
        RigType = humanoid and humanoid.RigType or Enum.HumanoidRigType.R6,
        Body = body,
        Appearance = {}
    }

    CaptureAppearance(player, character)
end

local function BuildReplicaTorso(player, character, realTorso)
    RemoveReplica(character)
    local data = SavedTorsos[player.UserId]
    if not data or not data.Body then return end

    local model = Instance.new("Model")
    model.Name = ReplicaName

    local humanoid = Instance.new("Humanoid")
    humanoid.RigType = data.RigType
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = false
    humanoid.Parent = model

    local replica = data.Body:Clone()
    replica.Size = data.OriginalSize
    replica.Transparency = data.OriginalTransparency
    replica.CFrame = realTorso.CFrame
    replica.Parent = model

    for _, item in ipairs(data.Appearance) do
        local clone = item:Clone()
        if clone then
            clone.Parent = model
        end
    end

    model.PrimaryPart = replica

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = realTorso
    weld.Part1 = replica
    weld.Parent = replica

    local selfNoCol = Instance.new("NoCollisionConstraint")
    selfNoCol.Part0 = realTorso
    selfNoCol.Part1 = replica
    selfNoCol.Parent = replica

    model.Parent = character
    ApplyNoCollisionWithLocal(realTorso)
    ApplyNoCollisionWithLocal(replica)
end

local function ApplyHitboxAndReplica(player, character)
    local data = SavedTorsos[player.UserId]
    if not data or not data.OriginalSize then return end

    local torso = GetTorso(character)
    if not torso then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then
        ResetCharacterState(player, character)
        return
    end

    for _, child in ipairs(torso:GetChildren()) do
        if child:IsA("FaceInstance") and child.Transparency < 1 then
            child:SetAttribute("HiddenBy7S", true)
            child.Transparency = 1
        end
    end

    torso.Size = data.OriginalSize * ScaleFactor
    torso.Transparency = 1
    torso.CanCollide = false
    torso.Massless = true

    BuildReplicaTorso(player, character, torso)
end

local function WaitForAppearance(player, character)
    local waited = 0
    while waited < 6 and character.Parent do
        local ok, loaded = pcall(function()
            return player:HasAppearanceLoaded()
        end)
        if ok and loaded then break end
        task.wait(0.25)
        waited += 0.25
    end
end

local function WatchCharacter(player, character)
    if player == LocalPlayer then return end

    local torso = character:WaitForChild("Torso", 5) or character:WaitForChild("UpperTorso", 5)
    if not torso then return end

    WaitForAppearance(player, character)
    if not character.Parent then return end
    task.wait(0.25)

    CaptureTorso(player, character)
    ApplyHitboxAndReplica(player, character)

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Died:Connect(function()
            ResetCharacterState(player, character)
        end)
    end

    character.ChildAdded:Connect(function(child)
        if child.Name == "Torso" or child.Name == "UpperTorso" then
            task.defer(function()
                CaptureTorso(player, character)
                ApplyHitboxAndReplica(player, character)
            end)
        elseif child:IsA("Humanoid") then
            child.Died:Connect(function()
                ResetCharacterState(player, character)
            end)
        elseif IsAppearanceItem(child) then
            task.defer(function()
                CaptureAppearance(player, character)
                local currentTorso = GetTorso(character)
                if currentTorso and SavedTorsos[player.UserId] then
                    BuildReplicaTorso(player, character, currentTorso)
                end
            end)
        end
    end)

    character.ChildRemoved:Connect(function(child)
        if child.Name == "Torso" or child.Name == "UpperTorso" then
            task.defer(function()
                local restored = GetTorso(character)
                if restored then
                    CaptureTorso(player, character)
                    ApplyHitboxAndReplica(player, character)
                end
            end)
        end
    end)
end

local function SetupPlayer(player)
    if player == LocalPlayer then return end
    if player.Character then
        task.spawn(WatchCharacter, player, player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        task.spawn(WatchCharacter, player, character)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    SetupPlayer(player)
end

Players.PlayerAdded:Connect(SetupPlayer)

Players.PlayerRemoving:Connect(function(player)
    DestroyData(SavedTorsos[player.UserId])
    SavedTorsos[player.UserId] = nil
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if player ~= LocalPlayer and character then
            local torso = GetTorso(character)
            local replicaModel = character:FindFirstChild(ReplicaName)
            ApplyNoCollisionWithLocal(torso)
            if replicaModel and replicaModel.PrimaryPart then
                ApplyNoCollisionWithLocal(replicaModel.PrimaryPart)
            end
        end
    end
end)
