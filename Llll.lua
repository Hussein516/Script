--ياخييي 67676767 بسسسس
--// Aim Training Dummy: Clone / Record / Replay / Scale (Client-side)
--// Scale levels: 1 (very small) .. 5 (normal) .. 10 (very large)

local env = (getgenv and getgenv()) or _G
if env.__AimDummyCleanup then pcall(env.__AimDummyCleanup) end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local lp = Players.LocalPlayer

------------------------------------------------------------------
-- State
------------------------------------------------------------------
local State = { recording = false, playing = false, loop = false, level = 5, trainer = false, trainScale = nil }
local MAX_FRAMES = 12000

local list = {}          -- { orig, clone, size, meshes }
local origRoot, cloneModel, cloneBase, staticFrame
local feetOff = 3
local folder
local frames = {}
local display            -- { f0, f1, a }
local recT0, playT, idx = 0, 0, 1
local conns = {}

local function getScale()
	if State.trainer and State.trainScale then return State.trainScale end
	return State.level / 5
end

------------------------------------------------------------------
-- Clone building
------------------------------------------------------------------
local function walk(a, b)
	if a:IsA("BasePart") and b:IsA("BasePart") then
		if not a:FindFirstAncestorWhichIsA("Tool") then
			table.insert(list, { orig = a, clone = b })
		end
	end
	local ca, cb = a:GetChildren(), b:GetChildren()
	for i = 1, math.min(#ca, #cb) do
		if ca[i].Name == cb[i].Name and ca[i].ClassName == cb[i].ClassName then
			walk(ca[i], cb[i])
		end
	end
end

local function applySizes()
	local s = getScale()
	for _, p in ipairs(list) do
		if p.clone.Parent then
			p.clone.Size = p.size * s
			for _, m in ipairs(p.meshes) do
				m.m.Scale = m.s * s
			end
		end
	end
end

local cfCache = {}

-- Places the dummy exactly where it was recorded (world position).
-- Scaling is done around the feet (lowest point of the body), so the
-- dummy never rises or sinks and stays at the same spot on the ground.
local function applyFrame(f0, f1, a)
	local s = getScale()
	local rw = (a == 0 or f0 == f1) and f0.root or f0.root:Lerp(f1.root, a)

	local minY = math.huge
	for i, p in ipairs(list) do
		local r0 = f0.rel[i]
		if r0 and p.clone.Parent then
			local r = r0
			local r1 = f1.rel[i]
			if a > 0 and r1 then r = r0:Lerp(r1, a) end
			local cf = rw * r
			cfCache[i] = cf
			if p.body then
				local S = p.size
				local half = 0.5 * (math.abs(cf.RightVector.Y) * S.X
					+ math.abs(cf.UpVector.Y) * S.Y
					+ math.abs(cf.LookVector.Y) * S.Z)
				local bottom = cf.Position.Y - half
				if bottom < minY then minY = bottom end
			end
		else
			cfCache[i] = nil
		end
	end
	if minY == math.huge then minY = rw.Position.Y - 3 end

	local pivot = Vector3.new(rw.Position.X, minY, rw.Position.Z)
	for i, p in ipairs(list) do
		local cf = cfCache[i]
		if cf then
			local pos = pivot + (cf.Position - pivot) * s
			p.clone.CFrame = CFrame.new(pos) * cf.Rotation
		end
	end
end

local function refresh()
	applySizes()
	if display then applyFrame(display[1], display[2], display[3]) end
end

local function buildClone()
	if cloneModel then cloneModel:Destroy() cloneModel = nil end
	list, frames, display = {}, {}, nil
	State.recording, State.playing = false, false

	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	pcall(function() char.Archivable = true end)
	for _, d in ipairs(char:GetDescendants()) do
		pcall(function() d.Archivable = true end)
	end
	local c = char:Clone()
	if not c then return false end

	walk(char, c) -- pair parts BEFORE cleaning the clone

	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("JointInstance") or d:IsA("Constraint")
			or d:IsA("WeldConstraint") or d:IsA("Animator") or d:IsA("Tool") or d:IsA("Sound") then
			pcall(function() d:Destroy() end)
		end
	end

	for _, p in ipairs(list) do
		local part = p.clone
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		p.size = part.Size
		p.body = part.Transparency < 1 and part.Name ~= "HumanoidRootPart"
			and not part:FindFirstAncestorWhichIsA("Accessory")
		p.meshes = {}
		for _, m in ipairs(part:GetChildren()) do
			if m:IsA("SpecialMesh") and m.MeshType == Enum.MeshType.FileMesh then
				table.insert(p.meshes, { m = m, s = m.Scale })
			end
		end
	end

	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
		hum.DisplayName = lp.DisplayName
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
	end
	c.Name = lp.Name

	-- spawn position: 8 studs in front of me, facing me
	local rp = root.Position
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
	local pos = rp + flat.Unit * 8
	cloneBase = CFrame.lookAt(pos, Vector3.new(rp.X, pos.Y, rp.Z))

	origRoot = root
	local rel = {}
	for i, p in ipairs(list) do
		rel[i] = root.CFrame:ToObjectSpace(p.orig.CFrame)
	end
	staticFrame = { t = 0, root = cloneBase, rel = rel }
	display = { staticFrame, staticFrame, 0 }

	-- distance from root center down to the feet (used by the trainer)
	local minB = math.huge
	for i, p in ipairs(list) do
		if p.body then
			local cf = root.CFrame * rel[i]
			local S = p.size
			local half = 0.5 * (math.abs(cf.RightVector.Y) * S.X
				+ math.abs(cf.UpVector.Y) * S.Y
				+ math.abs(cf.LookVector.Y) * S.Z)
			minB = math.min(minB, cf.Position.Y - half)
		end
	end
	feetOff = (minB == math.huge) and 3 or (root.Position.Y - minB)

	folder = folder or Instance.new("Folder")
	folder.Name = "AimDummyFolder"
	folder.Parent = Workspace
	c.Parent = folder
	cloneModel = c

	refresh()
	return true
end

------------------------------------------------------------------
-- Recording / Playback
------------------------------------------------------------------
local function capture()
	local rr = origRoot
	if not (rr and rr.Parent) then return end
	local t = os.clock() - recT0
	local last = frames[#frames]
	if last and t - last.t < 1 / 62 then return end
	local rc = rr.CFrame
	local rel = table.create(#list)
	for i, p in ipairs(list) do
		rel[i] = p.orig.Parent and rc:ToObjectSpace(p.orig.CFrame) or false
	end
	table.insert(frames, { t = t, root = rc, rel = rel })
end

------------------------------------------------------------------
-- GUI
------------------------------------------------------------------
------------------------------------------------------------------
-- Aim Trainer (tracking + flick, adaptive difficulty)
------------------------------------------------------------------
local hud, levelBox
local PHASE_TIME = 20
local SAVE_FILE = "AimDummyProgress.txt"
local tr = {
	phase = "break", timer = 0, D = 3, nextPhase = "tracking", lastMsg = "",
	theta = 0, omega = 0, dir = 1, flipT = 0, dist = 22, yaw = 0,
	jumpT = -1, nextJump = 3, onTime = 0, headTime = 0, total = 0,
	hits = 0, misses = 0, rtSum = 0, dwell = 0, spawnT = 0, clicked = false,
	bestTrack = 0, bestRT = nil, hudT = 0, auto = true,
}
local tframe = { t = 0, root = CFrame.new(), rel = {} }
local trayParams = RaycastParams.new()
trayParams.FilterType = Enum.RaycastFilterType.Exclude

local function rnd(x) return math.floor(x + 0.5) end

pcall(function()
	if isfile and readfile and isfile(SAVE_FILE) then
		local d = tonumber(readfile(SAVE_FILE))
		if d then tr.D = math.clamp(d, 1, 10) end
	end
end)
local function saveProgress()
	pcall(function()
		if writefile then writefile(SAVE_FILE, string.format("%.1f", tr.D)) end
	end)
end

local function scaleForD(D) return math.clamp(1.05 - (D - 1) * 0.075, 0.35, 1.05) end

local function lookYaw()
	local cam = Workspace.CurrentCamera
	local l = cam.CFrame.LookVector
	return math.atan2(-l.X, -l.Z)
end

local function groundAt(x, z, refY)
	trayParams.FilterDescendantsInstances = { lp.Character, folder }
	local hit = Workspace:Raycast(Vector3.new(x, refY + 25, z), Vector3.new(0, -90, 0), trayParams)
	return hit and hit.Position.Y or (refY - 3)
end

local function placeDummy(theta, dist, jumpH)
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (root and staticFrame) then return end
	local c = root.Position
	local dv = CFrame.Angles(0, tr.yaw + theta, 0).LookVector
	local pos = c + dv * dist
	local gy = groundAt(pos.X, pos.Z, c.Y)
	local p = Vector3.new(pos.X, gy + feetOff + jumpH, pos.Z)
	tframe.root = CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z))
	tframe.rel = staticFrame.rel
	display = { tframe, tframe, 0 }
	applyFrame(tframe, tframe, 0)
end

local function crosshair()
	local cam = Workspace.CurrentCamera
	trayParams.FilterDescendantsInstances = { lp.Character }
	local r = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 600, trayParams)
	if r and cloneModel and r.Instance:IsDescendantOf(cloneModel) then
		return true, r.Instance.Name == "Head"
	end
	return false, false
end

local function relocate()
	local old = tr.theta
	local new = old
	for _ = 1, 10 do
		new = math.rad((math.random() * 2 - 1) * 60)
		if math.abs(new - old) >= math.rad(25) then break end
	end
	tr.theta = new
	tr.dist = 14 + math.random() * 20
	tr.spawnT = 0
	tr.dwell = 0
end

local function startPhase(name)
	tr.phase, tr.timer = name, 0
	tr.onTime, tr.headTime, tr.total = 0, 0, 0
	tr.hits, tr.misses, tr.rtSum, tr.dwell, tr.clicked = 0, 0, 0, 0, false
	tr.yaw = lookYaw()
	State.trainScale = scaleForD(tr.D)
	applySizes()
	if name == "tracking" then
		tr.theta, tr.omega, tr.dir, tr.flipT = 0, 0, (math.random() < 0.5) and -1 or 1, 0
		tr.jumpT, tr.nextJump = -1, 2 + math.random() * 2
	else
		tr.theta = 0
		relocate()
	end
end

local function endPhase()
	local prev = tr.phase
	local score, msg
	if prev == "tracking" then
		score = tr.total > 0 and tr.onTime / tr.total or 0
		local head = tr.total > 0 and tr.headTime / tr.total or 0
		tr.bestTrack = math.max(tr.bestTrack, score)
		msg = string.format("Tracking done: %d%% on target, head %d%% (best %d%%)",
			rnd(score * 100), rnd(head * 100), rnd(tr.bestTrack * 100))
	else
		local n = tr.hits + tr.misses
		score = n > 0 and tr.hits / n or 0
		local avg = tr.hits > 0 and tr.rtSum / tr.hits or nil
		if avg and (not tr.bestRT or avg < tr.bestRT) then tr.bestRT = avg end
		msg = string.format("Flick done: %d/%d hits, avg %d ms (best %d ms)",
			tr.hits, n, rnd((avg or 0) * 1000), rnd((tr.bestRT or 0) * 1000))
	end
	if not tr.auto then
		msg = msg .. "  (level fixed)"
	elseif score >= 0.7 then
		tr.D = math.min(10, tr.D + 0.7)
		msg = msg .. "  -> harder"
	elseif score < 0.4 then
		tr.D = math.max(1, tr.D - 0.7)
		msg = msg .. "  -> easier"
	end
	saveProgress()
	tr.lastMsg = msg
	tr.nextPhase = (prev == "tracking") and "flick" or "tracking"
	tr.phase, tr.timer = "break", 0
end

local function updateHud()
	if not hud then return end
	if levelBox and not levelBox:IsFocused() then levelBox.Text = string.format("%.1f", tr.D) end
	local t
	if tr.phase == "tracking" then
		local p = tr.total > 0 and tr.onTime / tr.total * 100 or 0
		local h = tr.total > 0 and tr.headTime / tr.total * 100 or 0
		t = string.format("TRACKING  %ds\nOn target %d%%  |  Head %d%%  |  Level %.1f",
			rnd(PHASE_TIME - tr.timer), rnd(p), rnd(h), tr.D)
	elseif tr.phase == "flick" then
		local avg = tr.hits > 0 and tr.rtSum / tr.hits * 1000 or 0
		t = string.format("FLICK  %ds\nHits %d  Miss %d  |  Avg %d ms  |  Level %.1f",
			rnd(PHASE_TIME - tr.timer), tr.hits, tr.misses, rnd(avg), tr.D)
	else
		t = tr.lastMsg .. "\nNext: " .. string.upper(tr.nextPhase) .. string.format("  |  Level %.1f", tr.D)
	end
	hud.Text = t
end

local function trainerStep(dt)
	local cam = Workspace.CurrentCamera
	if not (cam and cloneModel and lp.Character) then return end
	tr.timer += dt
	tr.hudT += dt
	local click = tr.clicked
	tr.clicked = false

	if tr.phase == "break" then
		if tr.timer >= 2.5 then startPhase(tr.nextPhase) end
	elseif tr.phase == "tracking" then
		local onT, head = crosshair()
		tr.total += dt
		if onT then
			tr.onTime += dt
			if head then tr.headTime += dt end
		end
		-- unpredictable strafing
		tr.flipT -= dt
		if tr.flipT <= 0 then
			tr.dir = (math.random() < 0.5) and -1 or 1
			if math.random() < 0.15 then tr.dir = 0 end
			tr.flipT = math.max(0.25, 0.25 + math.random() * (1.4 - 0.08 * tr.D))
		end
		local speed = 25 + 9 * tr.D
		tr.omega += (tr.dir * speed - tr.omega) * math.min(1, dt * 8)
		tr.theta += math.rad(tr.omega) * dt
		local lim = math.rad(65)
		if math.abs(tr.theta) > lim then
			tr.theta = math.sign(tr.theta) * lim
			tr.omega = -tr.omega * 0.5
			tr.dir = -math.sign(tr.theta)
		end
		tr.dist = 18 + 4.5 * (1 + math.sin(tr.timer * 0.9))
		-- random jumps
		local jh = 0
		tr.nextJump -= dt
		if tr.jumpT >= 0 then
			tr.jumpT += dt
			local u = tr.jumpT / 0.8
			if u >= 1 then tr.jumpT = -1 else jh = 4 * u * (1 - u) * 3.5 end
		elseif tr.nextJump <= 0 then
			tr.jumpT = 0
			tr.nextJump = math.max(1.2, 4 - 0.25 * tr.D) + math.random() * 2
		end
		placeDummy(tr.theta, tr.dist, jh)
		if tr.timer >= PHASE_TIME then endPhase() end
	else -- flick
		local onT = crosshair()
		tr.spawnT += dt
		if onT then tr.dwell += dt else tr.dwell = 0 end
		local timeout = math.max(0.9, 2.2 - 0.12 * tr.D)
		if tr.dwell >= 0.08 or (click and onT) then
			tr.hits += 1
			tr.rtSum += tr.spawnT
			relocate()
		elseif tr.spawnT >= timeout then
			tr.misses += 1
			relocate()
		end
		placeDummy(tr.theta, tr.dist, 0)
		if tr.timer >= PHASE_TIME then endPhase() end
	end

	if tr.hudT >= 0.1 then
		tr.hudT = 0
		updateHud()
	end
end

local function startTrainer()
	if not (cloneModel and staticFrame) then return false end
	State.recording, State.playing = false, false
	State.trainer = true
	tr.phase, tr.timer, tr.nextPhase = "break", 1.5, "tracking"
	tr.lastMsg = "Get ready... keep your crosshair on the dummy"
	if hud then hud.Visible = true end
	updateHud()
	return true
end

local function stopTrainer()
	State.trainer = false
	State.trainScale = nil
	if staticFrame then display = { staticFrame, staticFrame, 0 } end
	refresh()
	if hud then hud.Visible = false end
end

table.insert(conns, UIS.InputBegan:Connect(function(i)
	if State.trainer and i.UserInputType == Enum.UserInputType.MouseButton1 then
		tr.clicked = true
	end
end))

local function guiParent()
	if gethui then
		local ok, g = pcall(gethui)
		if ok and g then return g end
	end
	local ok = pcall(function() return game:GetService("CoreGui"):GetChildren() end)
	if ok then return game:GetService("CoreGui") end
	return lp:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "AimDummyGui"
gui.ResetOnSpawn = false
gui.Parent = guiParent()

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 210, 0, 385)
frame.Position = UDim2.new(0, 20, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 56)
title.BorderSizePixel = 0
title.Text = "Aim Dummy (drag)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = frame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local holder = Instance.new("Frame")
holder.Size = UDim2.new(1, -16, 1, -40)
holder.Position = UDim2.new(0, 8, 0, 36)
holder.BackgroundTransparency = 1
holder.Parent = frame
local layout = Instance.new("UIListLayout", holder)
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local function mkButton(text, order, parent)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.LayoutOrder = order
	b.AutoButtonColor = true
	b.Parent = parent or holder
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local ON, OFF = Color3.fromRGB(46, 160, 90), Color3.fromRGB(60, 60, 75)
local RED = Color3.fromRGB(190, 55, 55)

local recBtn = mkButton("Record: OFF", 1)
local playBtn = mkButton("Play: OFF", 2)
local loopBtn = mkButton("Loop: OFF", 3)
local cloneBtn = mkButton("Re-Clone (me)", 4)
local trainBtn = mkButton("Aim Trainer: OFF", 8)

hud = Instance.new("TextLabel")
hud.Size = UDim2.new(0.6, 0, 0, 54)
hud.Position = UDim2.new(0.2, 0, 0, 8)
hud.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
hud.BackgroundTransparency = 0.35
hud.BorderSizePixel = 0
hud.TextColor3 = Color3.new(1, 1, 1)
hud.Font = Enum.Font.GothamBold
hud.TextSize = 14
hud.TextWrapped = true
hud.Text = ""
hud.Visible = false
hud.Parent = gui
Instance.new("UICorner", hud).CornerRadius = UDim.new(0, 8)

-- manual trainer level (type e.g. 5.5, range 1.0 - 10.0)
local lvlRow = Instance.new("Frame")
lvlRow.Size = UDim2.new(1, 0, 0, 30)
lvlRow.BackgroundTransparency = 1
lvlRow.LayoutOrder = 9
lvlRow.Parent = holder
local lvlLayout = Instance.new("UIListLayout", lvlRow)
lvlLayout.FillDirection = Enum.FillDirection.Horizontal
lvlLayout.Padding = UDim.new(0, 6)
lvlLayout.SortOrder = Enum.SortOrder.LayoutOrder

local lvlLbl = Instance.new("TextLabel")
lvlLbl.Size = UDim2.new(0, 44, 1, 0)
lvlLbl.BackgroundTransparency = 1
lvlLbl.Text = "Level:"
lvlLbl.TextColor3 = Color3.new(1, 1, 1)
lvlLbl.Font = Enum.Font.GothamMedium
lvlLbl.TextSize = 13
lvlLbl.LayoutOrder = 1
lvlLbl.Parent = lvlRow

levelBox = Instance.new("TextBox")
levelBox.Size = UDim2.new(0, 56, 1, 0)
levelBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
levelBox.BorderSizePixel = 0
levelBox.TextColor3 = Color3.new(1, 1, 1)
levelBox.Font = Enum.Font.GothamBold
levelBox.TextSize = 13
levelBox.ClearTextOnFocus = false
levelBox.Text = string.format("%.1f", tr.D)
levelBox.LayoutOrder = 2
levelBox.Parent = lvlRow
Instance.new("UICorner", levelBox).CornerRadius = UDim.new(0, 6)

local autoBtn = mkButton("Auto: ON", 3, lvlRow)
autoBtn.Size = UDim2.new(0, 78, 1, 0)
autoBtn.BackgroundColor3 = Color3.fromRGB(46, 160, 90)

local function setTrainerLevel(n)
	n = math.clamp(math.floor(n * 10 + 0.5) / 10, 1, 10)
	tr.D = n
	levelBox.Text = string.format("%.1f", n)
	saveProgress()
	if State.trainer then
		State.trainScale = scaleForD(tr.D)
		applySizes()
	end
end

levelBox.FocusLost:Connect(function()
	local n = tonumber(levelBox.Text)
	if n then setTrainerLevel(n) else levelBox.Text = string.format("%.1f", tr.D) end
end)

autoBtn.Activated:Connect(function()
	tr.auto = not tr.auto
	autoBtn.Text = "Auto: " .. (tr.auto and "ON" or "OFF")
	autoBtn.BackgroundColor3 = tr.auto and Color3.fromRGB(46, 160, 90) or Color3.fromRGB(60, 60, 75)
end)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 18)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(190, 190, 200)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.Text = "Frames: 0"
status.LayoutOrder = 5
status.Parent = holder

local row = Instance.new("Frame")
row.Size = UDim2.new(1, 0, 0, 30)
row.BackgroundTransparency = 1
row.LayoutOrder = 6
row.Parent = holder
local rl = Instance.new("UIListLayout", row)
rl.FillDirection = Enum.FillDirection.Horizontal
rl.Padding = UDim.new(0, 6)
rl.SortOrder = Enum.SortOrder.LayoutOrder

local function smallBtn(text, w)
	local b = mkButton(text, 0, row)
	b.Size = UDim2.new(0, w, 1, 0)
	return b
end
local minus = smallBtn("-", 50)
local sizeLbl = Instance.new("TextLabel")
sizeLbl.Size = UDim2.new(0, 76, 1, 0)
sizeLbl.BackgroundTransparency = 1
sizeLbl.TextColor3 = Color3.new(1, 1, 1)
sizeLbl.Font = Enum.Font.GothamBold
sizeLbl.TextSize = 13
sizeLbl.Text = "Size: 5"
sizeLbl.Parent = row
local plus = smallBtn("+", 50)
minus.LayoutOrder, sizeLbl.LayoutOrder, plus.LayoutOrder = 1, 2, 3

local normalBtn = mkButton("Normal Size (5)", 7)

local function refreshUI()
	recBtn.Text = "Record: " .. (State.recording and "ON" or "OFF")
	recBtn.BackgroundColor3 = State.recording and RED or OFF
	playBtn.Text = "Play: " .. (State.playing and "ON" or "OFF")
	playBtn.BackgroundColor3 = State.playing and ON or OFF
	loopBtn.Text = "Loop: " .. (State.loop and "ON" or "OFF")
	loopBtn.BackgroundColor3 = State.loop and ON or OFF
	trainBtn.Text = "Aim Trainer: " .. (State.trainer and "ON" or "OFF")
	trainBtn.BackgroundColor3 = State.trainer and RED or OFF
	sizeLbl.Text = "Size: " .. State.level
	status.Text = "Frames: " .. #frames
end
refreshUI()

recBtn.Activated:Connect(function()
	if State.trainer then status.Text = "Stop trainer first" return end
	if State.recording then
		State.recording = false
	else
		State.playing = false
		frames = {}
		recT0 = os.clock()
		State.recording = true
	end
	refreshUI()
end)

playBtn.Activated:Connect(function()
	if State.trainer then status.Text = "Stop trainer first" return end
	if State.playing then
		State.playing = false
	else
		if #frames < 2 then status.Text = "Record something first" return end
		State.recording = false
		playT, idx = 0, 1
		display = { frames[1], frames[1], 0 }
		applyFrame(frames[1], frames[1], 0)
		State.playing = true
	end
	refreshUI()
end)

loopBtn.Activated:Connect(function()
	State.loop = not State.loop
	refreshUI()
end)

cloneBtn.Activated:Connect(function()
	if State.trainer then status.Text = "Stop trainer first" return end
	if not buildClone() then status.Text = "Character not found" end
	refreshUI()
end)

local function setLevel(n)
	State.level = math.clamp(n, 1, 10)
	refresh()
	refreshUI()
end
minus.Activated:Connect(function() setLevel(State.level - 1) end)
plus.Activated:Connect(function() setLevel(State.level + 1) end)
normalBtn.Activated:Connect(function() setLevel(5) end)

trainBtn.Activated:Connect(function()
	if State.trainer then
		stopTrainer()
	elseif not startTrainer() then
		status.Text = "Clone not ready"
	end
	refreshUI()
end)

-- dragging
local dragging, dragStart, startPos
title.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging, dragStart, startPos = true, i.Position, frame.Position
		i.Changed:Connect(function()
			if i.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
table.insert(conns, UIS.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end))

------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------
table.insert(conns, RunService.RenderStepped:Connect(function(dt)
	if State.trainer then
		trainerStep(dt)
	elseif State.recording then
		capture()
		if #frames >= MAX_FRAMES then
			State.recording = false
			refreshUI()
		end
		status.Text = "Frames: " .. #frames
	elseif State.playing and #frames > 1 then
		local last = frames[#frames].t
		playT += dt
		if playT >= last then
			if State.loop and last > 0 then
				playT = playT % last
				idx = 1
			else
				playT = last
				State.playing = false
				refreshUI()
			end
		end
		while idx < #frames - 1 and frames[idx + 1].t <= playT do idx += 1 end
		local f0 = frames[idx]
		local f1 = frames[idx + 1] or f0
		local span = f1.t - f0.t
		local a = span > 0 and math.clamp((playT - f0.t) / span, 0, 1) or 0
		display = { f0, f1, a }
		applyFrame(f0, f1, a)
	end
end))

------------------------------------------------------------------
-- Cleanup + start
------------------------------------------------------------------
env.__AimDummyCleanup = function()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
	pcall(function() if folder then folder:Destroy() end end)
end

if not buildClone() then status.Text = "Character not found" end
refreshUI()
