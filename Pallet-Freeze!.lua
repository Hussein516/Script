--LastMLT1 all is g0OD
--شفيك انت داخل 
-- امزح معك لا تزعل السكربت بدون تشفير
--خذه وانقلع
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local char, hrp, humanoid
local lockedPart = nil
local lockedLocalPos = nil
local lockedRotation = nil
local awaitingLanding = false

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.IgnoreWater = true

local function setup(c)
    lockedPart = nil
    lockedLocalPos = nil
    lockedRotation = nil
    awaitingLanding = false
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
    humanoid = c:WaitForChild("Humanoid")
end
if player.Character then setup(player.Character) end
player.CharacterAdded:Connect(setup)

local function getGrabbedPart()
    local gp = Workspace:FindFirstChild("GrabParts")
    if not gp then return nil end
    local grabPart = gp:FindFirstChild("GrabPart")
    if not grabPart then return nil end

    for _, c in ipairs(grabPart:GetChildren()) do
        if c:IsA("WeldConstraint") then
            local other
            if c.Part0 == grabPart then other = c.Part1
            elseif c.Part1 == grabPart then other = c.Part0
            else other = c.Part1 end

            if other and other:FindFirstAncestor("PalletLightBrown") then
                return other
            end
        end
    end
    return nil
end

local function getStandLocalY(part)
    local hip = humanoid.HipHeight
    if not hip or hip <= 0 then hip = 2 end
    return part.Size.Y * 0.5 + hip + hrp.Size.Y * 0.5
end

local function unlock()
    if lockedPart and hrp and hrp.Parent and humanoid and humanoid.Health > 0 then
        hrp.AssemblyLinearVelocity = lockedPart.AssemblyLinearVelocity + Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    end
    lockedPart = nil
    lockedLocalPos = nil
    lockedRotation = nil
end

local function lockAt(part)
    lockedPart = part
    local lp = part.CFrame:PointToObjectSpace(hrp.Position)
    lockedLocalPos = Vector3.new(lp.X, getStandLocalY(part), lp.Z)
    lockedRotation = part.CFrame:ToObjectSpace(hrp.CFrame).Rotation
end

local function isStandingOnTop(part)
    if humanoid.FloorMaterial == Enum.Material.Air then return false end

    rayParams.FilterDescendantsInstances = {part}
    local result = Workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rayParams)
    if not result or result.Instance ~= part then return false end

    local topY = part.Position.Y + part.Size.Y * 0.5
    if math.abs(result.Position.Y - topY) > 0.3 then return false end

    local lp = part.CFrame:PointToObjectSpace(hrp.Position)
    local standY = getStandLocalY(part)
    if math.abs(lp.Y - standY) > 0.5 then return false end

    return true
end

RunService.Heartbeat:Connect(function(dt)
    if not hrp or not hrp.Parent or not humanoid or humanoid.Health <= 0 then return end

    local part = getGrabbedPart()

    if not part then
        if lockedPart then unlock() end
        return
    end

    if lockedPart and lockedPart ~= part then
        unlock()
        return
    end

    if lockedPart and lockedLocalPos then
        if humanoid:GetState() == Enum.HumanoidStateType.Jumping then
            unlock()
            awaitingLanding = true
            return
        end

        local half = lockedPart.Size * 0.5
        local move = humanoid.MoveDirection
        if move.Magnitude > 0 then
            local localMove = lockedPart.CFrame:VectorToObjectSpace(move * humanoid.WalkSpeed * dt)
            local newX = lockedLocalPos.X + localMove.X
            local newZ = lockedLocalPos.Z + localMove.Z

            if math.abs(newX) > half.X or math.abs(newZ) > half.Z then
                unlock()
                return
            end

            lockedLocalPos = Vector3.new(newX, lockedLocalPos.Y, newZ)
        end

        hrp.CFrame = lockedPart.CFrame * CFrame.new(lockedLocalPos) * lockedRotation

        local v = hrp.AssemblyLinearVelocity
        hrp.AssemblyLinearVelocity = Vector3.new(0, math.max(v.Y, 0), 0)
        hrp.AssemblyAngularVelocity = Vector3.zero
        return
    end

    if awaitingLanding then
        if humanoid.FloorMaterial == Enum.Material.Air then return end
        awaitingLanding = false
    end

    if isStandingOnTop(part) then
        lockAt(part)
    end
end)
