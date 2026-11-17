local sounds = [[
https://files.catbox.moe/uyd6ry.mp3
https://files.catbox.moe/rz7a7h.mp3
]]

local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local function GetHui()
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    if ok and hui then return hui end
    return nil
end

local Hui = GetHui()
if not Hui then
    warn("gethui is not available in this executor")
    return
end

for _, child in ipairs(Hui:GetChildren()) do
    pcall(function() child:Destroy() end)
end

local ROOT = "XD_Executor"
local LEGACY = "MVAX"
local ASSETS = ROOT .. "/assets"
local C = Color3.fromRGB

local function RandName()
    local chars = {}
    for i = 1, 12 do
        chars[i] = string.char(math.random(97, 122))
    end
    return table.concat(chars)
end

local GUI_NAME = RandName()
local TOAST_NAME = RandName()
local AUDIO_NAME = RandName()

local function Protect(gui)
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
        elseif protectgui then
            protectgui(gui)
        elseif protect_gui then
            protect_gui(gui)
        end
    end)
end

local function New(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, child in ipairs(children or {}) do child.Parent = inst end
    return inst
end

local function Round(inst, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 2), Parent = inst })
end

local FONT_UI = Enum.Font.SourceSans
local FONT_UIB = Enum.Font.SourceSansSemibold
local FONT_MONO = Enum.Font.RobotoMono
local FONT_BTN = Enum.Font.SourceSansSemibold
local FONT_LOGO = Enum.Font.SourceSansBold
pcall(function()
    FONT_LOGO = Enum.Font.Bodoni
end)
pcall(function()
    FONT_BTN = Enum.Font.GothamMedium
end)

local function Req(opts)
    local fn = (syn and syn.request) or http_request or request or (http and http.request) or (fluxus and fluxus.request)
    if fn then
        local ok, res = pcall(fn, opts)
        if ok and type(res) == "table" then return res end
    end
    return nil
end

local function FsOk()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function NewFile(path, data)
    if type(writefile) ~= "function" then return false end
    local ok = pcall(function()
        local folder = path:match("^(.*)/[^/]+$")
        if folder and type(makefolder) == "function" and type(isfolder) == "function" then
            local acc = ""
            for part in folder:gmatch("[^/]+") do
                acc = acc == "" and part or (acc .. "/" .. part)
                if not isfolder(acc) then makefolder(acc) end
            end
        end
        writefile(path, data)
    end)
    return ok
end

local function Cached(path)
    if not FsOk() then return false end
    local ok, found = pcall(isfile, path)
    if ok and found then return true end
    local legacyPath = LEGACY .. path:sub(#ROOT + 1)
    local ok2, legacyFound = pcall(isfile, legacyPath)
    if ok2 and legacyFound then
        local ok3, content = pcall(readfile, legacyPath)
        if ok3 and type(content) == "string" and #content > 1024 then
            return NewFile(path, content)
        end
    end
    return false
end

local function BodyOf(res)
    if not res then return nil, nil end
    return res.Body or res.body, res.StatusCode or res.status_code
end

local function ValidBody(body, code)
    if code ~= nil and code ~= 200 then return false end
    if type(body) ~= "string" or #body <= 1024 then return false end
    local head = body:sub(1, 1)
    if head == "<" or head == "{" then return false end
    return true
end

local function ExtractLinks(src)
    local text = ""
    if type(src) == "table" then
        local parts = {}
        for _, v in pairs(src) do
            parts[#parts + 1] = tostring(v)
        end
        text = table.concat(parts, "\n")
    elseif src ~= nil then
        text = tostring(src)
    end
    text = text:gsub("([Hh][Tt][Tt][Pp][Ss]?)//:", "%1://")
    local links = {}
    for link in text:gmatch("[Hh][Tt][Tt][Pp][Ss]?://[^%s,;\"'<>%[%]]+") do
        link = link:gsub("[%.%)%}]+$", "")
        link = link:gsub("^(%a+)", string.lower)
        if #link > 10 then
            links[#links + 1] = link
        end
    end
    return links
end

local function HashString(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 4294967296
    end
    return string.format("%08x", h)
end

local BuiltinSounds = {
    "https://files.catbox.moe/7xuwet.mp3",
    "https://files.catbox.moe/7q04sm.mp3",
    "https://files.catbox.moe/jt70ep.mp3",
    "https://files.catbox.moe/mrm95x.mp3",
    "https://files.catbox.moe/7flnz4.mp3"
}

local SoundSources = {}
local SoundPaths = {}

for index, url in ipairs(BuiltinSounds) do
    SoundSources[index] = url
    SoundPaths[index] = ASSETS .. "/sound_" .. index .. ".mp3"
end

do
    local known = {}
    for _, url in ipairs(BuiltinSounds) do
        known[url] = true
    end
    for _, link in ipairs(ExtractLinks(sounds)) do
        if not known[link] then
            known[link] = true
            local clean = link:gsub("[%?#].*$", "")
            local ext = (clean:match("%.(%w+)$") or "mp3"):lower()
            if ext ~= "mp3" and ext ~= "ogg" and ext ~= "wav" then
                ext = "mp3"
            end
            local index = #SoundSources + 1
            SoundSources[index] = link
            SoundPaths[index] = ASSETS .. "/u_" .. HashString(link) .. "." .. ext
        end
    end
end

local PictureSource = "https://files.catbox.moe/006mvk.png"
local PicturePath = ASSETS .. "/picture_1.png"

local function ViewSize()
    local cam = workspace.CurrentCamera
    if cam then return cam.ViewportSize end
    return Vector2.new(800, 400)
end

local Themes = {}
local function P(name, bg, panel, card, accent, text, dim, line)
    Themes[name] = {
        Bg = bg, Panel = panel, Card = card, Accent = accent,
        Text = text, Dim = dim, Line = line,
        Ok = C(92, 190, 130), Err = C(214, 88, 80), Warn = C(214, 172, 80)
    }
end

P("Noir", C(11, 11, 12), C(17, 17, 19), C(26, 25, 27), C(201, 169, 110), C(230, 225, 215), C(138, 132, 122), C(44, 40, 34))
P("Onyx", C(10, 10, 10), C(16, 16, 16), C(25, 25, 25), C(210, 210, 210), C(245, 245, 245), C(140, 140, 140), C(40, 40, 40))
P("Emerald", C(9, 15, 13), C(14, 22, 19), C(21, 32, 28), C(86, 180, 140), C(226, 236, 231), C(126, 146, 138), C(30, 48, 42))
P("Bordeaux", C(15, 10, 11), C(22, 15, 17), C(33, 22, 25), C(178, 86, 94), C(238, 228, 228), C(150, 128, 130), C(54, 36, 40))
P("Sapphire", C(9, 12, 19), C(14, 19, 30), C(22, 29, 45), C(108, 148, 214), C(228, 233, 243), C(126, 136, 156), C(32, 42, 64))
P("Amethyst", C(13, 10, 18), C(20, 15, 28), C(30, 23, 42), C(160, 126, 206), C(236, 230, 244), C(140, 130, 158), C(46, 36, 66))
P("Copper", C(15, 11, 9), C(23, 17, 14), C(35, 26, 21), C(204, 128, 84), C(240, 230, 222), C(152, 134, 122), C(58, 42, 34))
P("Rose", C(15, 10, 13), C(23, 15, 20), C(35, 23, 31), C(206, 126, 156), C(242, 230, 236), C(152, 130, 142), C(58, 38, 50))
P("Obsidian", C(17, 18, 21), C(24, 25, 29), C(33, 35, 40), C(64, 156, 255), C(232, 234, 238), C(140, 146, 156), C(46, 49, 56))

local ThemeOrder = { "Noir", "Onyx", "Emerald", "Bordeaux", "Sapphire", "Amethyst", "Copper", "Rose", "Obsidian" }
local OP_MIN = 0.6

local State = {
    Version = "2.3",
    Theme = "Noir",
    Opacity = 0.95,
    ShowLineNumbers = true,
    AutoSave = true,
    LargeFont = false,
    Mirror = true,
    PlayOnStart = true,
    SoundSel = {},
    ActiveTab = 1,
    Tabs = {},
    Files = {}
}

local NextTabId = 1
local NextFileId = 1

do
    local function ReadData(name)
        if not FsOk() then return nil end
        for _, root in ipairs({ ROOT, LEGACY }) do
            local path = root .. "/" .. name
            local ok, data = pcall(function()
                if isfile(path) then
                    return HttpService:JSONDecode(readfile(path))
                end
            end)
            if ok and data ~= nil then return data end
        end
        return nil
    end

    local function Rebrand(s)
        return (s:gsub("MVAX", "XD"))
    end

    local savedSettings = ReadData("settings.json")
    if type(savedSettings) == "table" then
        if Themes[savedSettings.Theme] then State.Theme = savedSettings.Theme end
        if type(savedSettings.Opacity) == "number" then
            State.Opacity = math.clamp(savedSettings.Opacity, OP_MIN, 1)
        end
        for _, key in ipairs({ "ShowLineNumbers", "AutoSave", "LargeFont", "Mirror", "PlayOnStart" }) do
            if type(savedSettings[key]) == "boolean" then
                State[key] = savedSettings[key]
            end
        end
        if type(savedSettings.SoundSel) == "table" then
            local seen = {}
            for _, v in ipairs(savedSettings.SoundSel) do
                if type(v) == "number" and v >= 1 and v <= #SoundSources and not seen[v] and #State.SoundSel < 2 then
                    seen[v] = true
                    table.insert(State.SoundSel, v)
                end
            end
        end
    end

    local savedFiles = ReadData("files.json")
    local used = {}
    local function AddFile(id, name, code)
        if type(id) ~= "number" or used[id] then
            id = NextFileId
        end
        used[id] = true
        if id >= NextFileId then NextFileId = id + 1 end
        table.insert(State.Files, { id = id, name = name, code = code })
    end

    if type(savedFiles) == "table" then
        for _, f in ipairs(savedFiles) do
            if type(f) == "table" and type(f.name) == "string" and type(f.code) == "string" then
                AddFile(f.id, f.name, Rebrand(f.code))
            end
        end
    else
        local legacyScripts = ReadData("scripts.json")
        if type(legacyScripts) == "table" then
            for _, s in ipairs(legacyScripts) do
                if type(s) == "table" and type(s.name) == "string" and type(s.code) == "string" then
                    AddFile(nil, s.name, Rebrand(s.code))
                end
            end
        end
        if #State.Files == 0 then
            AddFile(nil, "hello.lua", "warn(\"Hello from XD\")")
            AddFile(nil, "math_test.lua", "local x = 10 * 25\nwarn(\"Result:\", x)")
        end
    end

    local savedTabs = ReadData("tabs.json")
    if type(savedTabs) == "table" and type(savedTabs.tabs) == "table" then
        for _, t in ipairs(savedTabs.tabs) do
            if type(t) == "table" and type(t.id) == "number" and type(t.name) == "string" and type(t.content) == "string" then
                local fileId = nil
                if type(t.fileId) == "number" and used[t.fileId] then
                    fileId = t.fileId
                end
                table.insert(State.Tabs, { id = t.id, name = t.name, content = Rebrand(t.content), fileId = fileId })
            end
        end
        if type(savedTabs.active) == "number" then
            State.ActiveTab = savedTabs.active
        end
    end

    if #State.Tabs == 0 then
        State.Tabs[1] = {
            id = 1,
            name = "script_1.lua",
            content = "local lp = game:GetService(\"Players\").LocalPlayer\nwarn(\"Hello \" .. lp.Name)\n\nfor i = 1, 3 do\n    warn(\"iteration\", i)\nend"
        }
        State.ActiveTab = 1
    end

    local activeFound = false
    for _, t in ipairs(State.Tabs) do
        if t.id >= NextTabId then NextTabId = t.id + 1 end
        if t.id == State.ActiveTab then activeFound = true end
    end
    if not activeFound then State.ActiveTab = State.Tabs[1].id end
end

local function WriteData(name, data)
    NewFile(ROOT .. "/" .. name, HttpService:JSONEncode(data))
end

local Dirty = false
local FilesDirty = false
local function MarkDirty() Dirty = true end
local function SaveTabs() WriteData("tabs.json", { tabs = State.Tabs, active = State.ActiveTab }) end
local function SaveFiles() WriteData("files.json", State.Files) end
local function SaveSettings()
    WriteData("settings.json", {
        Theme = State.Theme,
        Opacity = State.Opacity,
        ShowLineNumbers = State.ShowLineNumbers,
        AutoSave = State.AutoSave,
        LargeFont = State.LargeFont,
        Mirror = State.Mirror,
        PlayOnStart = State.PlayOnStart,
        SoundSel = State.SoundSel
    })
end

local function FindFile(id)
    for _, f in ipairs(State.Files) do
        if f.id == id then return f end
    end
    return nil
end

local function GetTheme() return Themes[State.Theme] end

local Bindings = {}
local ThemeHooks = {}

local function Bind(inst, fn)
    fn(GetTheme(), 1 - State.Opacity)
    table.insert(Bindings, { inst = inst, fn = fn })
    return inst
end

local function Surface(inst, key, translucent)
    Bind(inst, function(t, tr)
        inst.BackgroundColor3 = t[key]
        inst.BackgroundTransparency = translucent and tr or 0
    end)
end

local function Ink(inst, key)
    Bind(inst, function(t) inst.TextColor3 = t[key] end)
end

local function Outline(inst, key)
    local stroke = New("UIStroke", {
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = inst
    })
    Bind(stroke, function(t) stroke.Color = t[key or "Line"] end)
    return stroke
end

local function Divider(parent, props)
    local f = New("Frame", props)
    f.BorderSizePixel = 0
    f.Parent = parent
    Bind(f, function(t) f.BackgroundColor3 = t.Line end)
    return f
end

local function OnAccent(color)
    local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
    return lum > 0.6 and C(14, 14, 14) or C(255, 255, 255)
end

local function Button(parent, text, primary, props)
    local b = New("TextButton", {
        Text = text,
        Font = FONT_BTN,
        TextSize = 12,
        AutoButtonColor = true,
        BorderSizePixel = 0,
        Parent = parent
    })
    for k, v in pairs(props or {}) do b[k] = v end
    Round(b, 2)
    if primary then
        Bind(b, function(t)
            b.BackgroundColor3 = t.Accent
            b.BackgroundTransparency = 0
            b.TextColor3 = OnAccent(t.Accent)
        end)
    else
        Bind(b, function(t)
            b.BackgroundColor3 = t.Card
            b.BackgroundTransparency = 0
            b.TextColor3 = t.Text
        end)
        Outline(b, "Line")
    end
    return b
end

local function Draggable(handle, target, onEnd)
    local active, startPos, origin = nil, nil, nil
    handle.InputBegan:Connect(function(input)
        if active then return end
        local kind = input.UserInputType
        if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
            active = input
            startPos = input.Position
            origin = target.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not active then return end
        local follows
        if active.UserInputType == Enum.UserInputType.Touch then
            follows = input == active
        else
            follows = input.UserInputType == Enum.UserInputType.MouseMovement
        end
        if follows then
            local d = input.Position - startPos
            target.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if not active then return end
        local finished
        if active.UserInputType == Enum.UserInputType.Touch then
            finished = input == active
        else
            finished = input.UserInputType == Enum.UserInputType.MouseButton1
        end
        if finished then
            active = nil
            if onEnd then onEnd() end
        end
    end)
    return function()
        active = nil
    end
end

local function SetClip(text)
    local fn = setclipboard or toclipboard or (syn and syn.write_clipboard)
    if fn then
        return pcall(fn, text)
    end
    return false
end

local ClipBuffer = ""
local function GetClip()
    if type(getclipboard) == "function" then
        local ok, res = pcall(getclipboard)
        if ok and type(res) == "string" then return res end
    end
    return ClipBuffer
end

local function HttpFetch(url)
    local res = Req({ Url = url, Method = "GET" })
    local body = BodyOf(res)
    if type(body) == "string" then return true, body end
    local ok, got = pcall(function() return game:HttpGet(url) end)
    if ok then return true, got end
    return false, tostring(got)
end

local AssetFn = getcustomasset or getsynasset
local function AssetOf(path)
    if not AssetFn then return nil end
    local ok, id = pcall(AssetFn, path)
    if ok and id and id ~= "" then return id end
    return nil
end

local PictureAsset = nil
local SoundAvail = {}
for index = 1, #SoundSources do
    SoundAvail[index] = false
end

local SoundAssetCache = {}
local function SoundAsset(index)
    if SoundAssetCache[index] then return SoundAssetCache[index] end
    if not SoundAvail[index] then return nil end
    local id = AssetOf(SoundPaths[index])
    SoundAssetCache[index] = id
    return id
end

local Gui = New("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999
})
Gui:SetAttribute("xd", true)
Protect(Gui)
Gui.Parent = Hui

local SetOpen

local Launcher = New("TextButton", {
    Name = "Launcher",
    Size = UDim2.fromOffset(58, 58),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.25, 0),
    Text = "XD",
    Font = FONT_LOGO,
    TextSize = 24,
    AutoButtonColor = false,
    BorderSizePixel = 0,
    ZIndex = 50,
    Parent = Gui
})
Bind(Launcher, function(t)
    Launcher.BackgroundColor3 = t.Bg
    Launcher.TextColor3 = t.Accent
end)
Outline(Launcher, "Accent")

local LauncherInner = New("Frame", {
    Size = UDim2.new(1, -10, 1, -10),
    Position = UDim2.fromOffset(5, 5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 51,
    Parent = Launcher
})
local LauncherInnerStroke = Outline(LauncherInner, "Accent")
LauncherInnerStroke.Transparency = 0.6

local LauncherRule = New("Frame", {
    Size = UDim2.fromOffset(14, 1),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 1, -12),
    BorderSizePixel = 0,
    ZIndex = 52,
    Parent = Launcher
})
Bind(LauncherRule, function(t)
    LauncherRule.BackgroundColor3 = t.Accent
end)

Launcher.Activated:Connect(function()
    SetOpen(true)
end)

local function ClampFrame(frame)
    local vp = Gui.AbsoluteSize
    if vp.X <= 0 or vp.Y <= 0 then return end
    local sx, sy = frame.Size.X.Offset, frame.Size.Y.Offset
    local ax, ay = frame.AnchorPoint.X, frame.AnchorPoint.Y
    local px = frame.Position.X.Scale * vp.X + frame.Position.X.Offset
    local py = frame.Position.Y.Scale * vp.Y + frame.Position.Y.Offset
    local left = math.clamp(px - sx * ax, 4, math.max(4, vp.X - sx - 4))
    local top = math.clamp(py - sy * ay, 4, math.max(4, vp.Y - sy - 4))
    frame.Position = UDim2.fromOffset(left + sx * ax, top + sy * ay)
end

local Main = New("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(560, 340),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
    Parent = Gui
})
Round(Main, 3)
Surface(Main, "Bg", true)
Outline(Main, "Line")

local function Fit()
    local vp = Gui.AbsoluteSize
    if vp.X <= 0 or vp.Y <= 0 then vp = ViewSize() end
    local w = math.min(vp.X - 12, math.clamp(vp.X * 0.9, 300, 780))
    local h = math.min(vp.Y - 12, math.clamp(vp.Y * 0.86, 240, 500))
    Main.Size = UDim2.fromOffset(w, h)
    ClampFrame(Main)
end
Fit()
Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Fit)

local CancelWindowDrag = function() end
local HideModal = function() end
local SpinImage
local PictureFallback
local ApplyTheme
local RenderFiles
local ShowInfo
local OpenFile
local RefreshSoundStatus = function() end

do
    local TopBar = New("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BorderSizePixel = 0,
        Parent = Main
    })
    Surface(TopBar, "Panel", true)
    CancelWindowDrag = Draggable(TopBar, Main, function()
        ClampFrame(Main)
    end)

    local TopLine = New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = TopBar
    })
    Bind(TopLine, function(t) TopLine.BackgroundColor3 = t.Accent end)
    Divider(Main, { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 40) })

    local SpinHolder = New("Frame", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(0, 10, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Parent = TopBar
    })

    SpinImage = New("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "",
        ScaleType = Enum.ScaleType.Fit,
        Visible = false,
        Parent = SpinHolder
    })

    PictureFallback = New("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "XD",
        Font = FONT_LOGO,
        TextSize = 18,
        Parent = SpinHolder
    })
    Ink(PictureFallback, "Accent")

    local TitleBox = New("Frame", {
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.new(0, 50, 0, 0),
        BackgroundTransparency = 1,
        Parent = TopBar
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TitleBox
    })

    local Brand = New("TextLabel", {
        Size = UDim2.new(0, 0, 0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = "XD",
        Font = FONT_LOGO,
        TextSize = 22,
        LayoutOrder = 1,
        Parent = TitleBox
    })
    Ink(Brand, "Accent")

    local Word = New("TextLabel", {
        Size = UDim2.new(0, 0, 0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = "EXECUTOR",
        Font = FONT_BTN,
        TextSize = 11,
        LayoutOrder = 2,
        Parent = TitleBox
    })
    Ink(Word, "Dim")

    local ExitBtn = New("TextButton", {
        Size = UDim2.fromOffset(50, 24),
        Position = UDim2.new(1, -10, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Text = "EXIT",
        Font = FONT_BTN,
        TextSize = 11,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = TopBar
    })
    Round(ExitBtn, 2)
    Bind(ExitBtn, function(t)
        ExitBtn.BackgroundColor3 = t.Card
        ExitBtn.TextColor3 = t.Text
    end)
    Outline(ExitBtn, "Line")
    ExitBtn.Activated:Connect(function()
        SetOpen(false)
    end)
end

local function SetPicture(asset)
    PictureAsset = asset
    SpinImage.Image = asset or ""
    SpinImage.Visible = asset ~= nil
    PictureFallback.Visible = asset == nil
end

local Content = New("Frame", {
    Size = UDim2.new(1, -63, 1, -41),
    Position = UDim2.new(0, 63, 0, 41),
    BackgroundTransparency = 1,
    Parent = Main
})

local Pages = {}
local NavButtons = {}
local NavBars = {}
local CurrentPage = "Editor"

for _, name in ipairs({ "Editor", "Hub", "Files", "Log", "Setup", "Info" }) do
    Pages[name] = New("Frame", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = Content
    })
end

local function StyleNav()
    local t = GetTheme()
    for name, btn in pairs(NavButtons) do
        local selected = name == CurrentPage
        btn.TextColor3 = selected and t.Accent or t.Dim
        NavBars[name].Visible = selected
        NavBars[name].BackgroundColor3 = t.Accent
    end
end

local function SwitchPage(name)
    CurrentPage = name
    for pageName, page in pairs(Pages) do
        page.Visible = pageName == name
    end
    StyleNav()
    if name == "Files" and RenderFiles then RenderFiles() end
    if name == "Info" and ShowInfo then ShowInfo() end
end

do
    local Sidebar = New("Frame", {
        Size = UDim2.new(0, 62, 1, -41),
        Position = UDim2.new(0, 0, 0, 41),
        BorderSizePixel = 0,
        Parent = Main
    })
    Surface(Sidebar, "Panel", true)
    Divider(Main, { Size = UDim2.new(0, 1, 1, -41), Position = UDim2.new(0, 62, 0, 41) })
    New("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Sidebar
    })
    New("UIPadding", { PaddingTop = UDim.new(0, 8), Parent = Sidebar })

    for index, name in ipairs({ "Editor", "Hub", "Files", "Log", "Setup", "Info" }) do
        local btn = New("TextButton", {
            Name = name,
            Size = UDim2.new(1, 0, 0, 34),
            LayoutOrder = index,
            BackgroundTransparency = 1,
            Text = string.upper(name),
            Font = FONT_BTN,
            TextSize = 11,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Parent = Sidebar
        })
        local bar = New("Frame", {
            Size = UDim2.fromOffset(2, 16),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BorderSizePixel = 0,
            Visible = false,
            Parent = btn
        })
        NavButtons[name] = btn
        NavBars[name] = bar
        btn.Activated:Connect(function()
            SwitchPage(name)
        end)
    end
end
table.insert(ThemeHooks, StyleNav)

local Log

do
    local LogLines = {}
    local LogLabels = {}
    local LogSeq = 0

    local LogScroll = New("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -54),
        Position = UDim2.new(0, 10, 0, 10),
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        Parent = Pages.Log
    })
    Round(LogScroll, 2)
    Surface(LogScroll, "Panel")
    Outline(LogScroll, "Line")
    New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = LogScroll })
    New("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 6),
        Parent = LogScroll
    })

    Log = function(msg, kind)
        local t = GetTheme()
        local color, tag = t.Text, "INFO"
        if kind == "error" then
            color, tag = t.Err, "ERR "
        elseif kind == "warn" then
            color, tag = t.Warn, "WARN"
        elseif kind == "ok" then
            color, tag = t.Ok, "OK  "
        end
        local line = string.format("[%s] %s  %s", os.date("%H:%M:%S"), tag, tostring(msg))
        table.insert(LogLines, line)
        if #LogLines > 500 then table.remove(LogLines, 1) end
        LogSeq = LogSeq + 1
        local label = New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = LogSeq,
            Text = line,
            TextColor3 = color,
            Font = FONT_MONO,
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = LogScroll
        })
        table.insert(LogLabels, label)
        if #LogLabels > 500 then
            local first = table.remove(LogLabels, 1)
            first:Destroy()
        end
        task.defer(function()
            if LogScroll.Parent then
                LogScroll.CanvasPosition = Vector2.new(0, LogScroll.AbsoluteCanvasSize.Y)
            end
        end)
    end

    local LogBar = New("Frame", {
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.new(0, 10, 1, -38),
        BackgroundTransparency = 1,
        Parent = Pages.Log
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 6),
        Parent = LogBar
    })

    local LogCopyBtn = Button(LogBar, "COPY LOG", false, { Size = UDim2.new(0, 90, 1, 0) })
    local LogClearBtn = Button(LogBar, "CLEAR", false, { Size = UDim2.new(0, 80, 1, 0) })

    LogClearBtn.Activated:Connect(function()
        for _, l in ipairs(LogLabels) do l:Destroy() end
        LogLabels = {}
        LogLines = {}
    end)

    LogCopyBtn.Activated:Connect(function()
        if SetClip(table.concat(LogLines, "\n")) then
            Log("Log copied to clipboard", "info")
        else
            Log("Clipboard is not supported here", "warn")
        end
    end)

    local mirrorConn
    mirrorConn = LogService.MessageOut:Connect(function(message, messageType)
        if not Gui.Parent then
            mirrorConn:Disconnect()
            return
        end
        if not State.Mirror then return end
        local kind = "info"
        if messageType == Enum.MessageType.MessageWarning then
            kind = "warn"
        elseif messageType == Enum.MessageType.MessageError then
            kind = "error"
        end
        Log(message, kind)
    end)
    Gui.Destroying:Connect(function()
        if mirrorConn then mirrorConn:Disconnect() end
    end)
end

local RunCount = 0

local function Execute(source)
    if not source or source:match("^%s*$") then
        Log("Nothing to execute", "warn")
        return
    end
    if type(loadstring) ~= "function" then
        Log("loadstring is not available in this executor", "error")
        return
    end
    local fn, err = loadstring(source, "=XD")
    if not fn then
        Log("Syntax error: " .. tostring(err), "error")
        SwitchPage("Log")
        return
    end
    RunCount = RunCount + 1
    task.spawn(function()
        local ok, runtimeErr = pcall(fn)
        if ok then
            Log("Execution finished", "ok")
        else
            Log("Runtime error: " .. tostring(runtimeErr), "error")
            SwitchPage("Log")
        end
    end)
end

local BASE_VOLUME = 1
local Audio = New("Sound", {
    Name = AUDIO_NAME,
    Volume = BASE_VOLUME,
    Looped = false,
    Parent = Gui
})

local NowIndex = nil
local PlayToken = 0
local Stopping = false

local function MakeRng()
    local seed = 0
    local pieces = {
        tostring(tick()),
        tostring(os.clock()),
        tostring(os.time()),
        HttpService:GenerateGUID(false),
        tostring({}),
        tostring(workspace.DistributedGameTime)
    }
    for _, s in ipairs(pieces) do
        for i = 1, #s do
            seed = (seed * 31 + s:byte(i)) % 2147483647
        end
    end
    return Random.new(seed)
end

local Rng = MakeRng()

local function PlaySound(index)
    local asset = SoundAsset(index)
    if not asset then
        Log("Sound " .. index .. " is not available", "warn")
        return
    end
    PlayToken = PlayToken + 1
    local token = PlayToken
    Stopping = false
    Audio:Stop()
    Audio.SoundId = asset
    Audio.Volume = BASE_VOLUME
    Audio.TimePosition = 0
    NowIndex = index
    RefreshSoundStatus()
    task.spawn(function()
        local waited = 0
        while not Audio.IsLoaded and waited < 8 do
            task.wait(0.05)
            waited = waited + 0.05
        end
        if token ~= PlayToken then return end
        if not Audio.IsLoaded then
            Log("Sound " .. index .. " failed to load", "error")
            NowIndex = nil
            RefreshSoundStatus()
            return
        end
        Audio.Volume = BASE_VOLUME
        Audio:Play()
        RefreshSoundStatus()
    end)
end

local function StopSound()
    PlayToken = PlayToken + 1
    local token = PlayToken
    if not Audio.IsPlaying then
        Audio:Stop()
        NowIndex = nil
        RefreshSoundStatus()
        return
    end
    Stopping = true
    task.spawn(function()
        local startVolume = Audio.Volume
        for step = 1, 12 do
            if token ~= PlayToken then return end
            Audio.Volume = startVolume * (1 - step / 12)
            task.wait(0.04)
        end
        if token ~= PlayToken then return end
        Audio:Stop()
        Audio.Volume = BASE_VOLUME
        Stopping = false
        NowIndex = nil
        RefreshSoundStatus()
    end)
end

local function SoundPool()
    local pool = {}
    if #State.SoundSel > 0 then
        for _, i in ipairs(State.SoundSel) do
            if SoundAvail[i] then table.insert(pool, i) end
        end
    else
        for i = 1, #SoundSources do
            if SoundAvail[i] then table.insert(pool, i) end
        end
    end
    return pool
end

local function PlayChosen()
    local pool = SoundPool()
    if #pool == 0 then
        Log("No sound available to play", "warn")
        return
    end
    PlaySound(pool[Rng:NextInteger(1, #pool)])
end

local Highlight

do
    local Keywords = {}
    for _, w in ipairs({ "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue" }) do
        Keywords[w] = true
    end

    local Builtins = {}
    for _, w in ipairs({ "print", "warn", "error", "pairs", "ipairs", "next", "tostring", "tonumber", "math", "string", "table", "task", "wait", "tick", "time", "typeof", "type", "game", "workspace", "script", "require", "pcall", "xpcall", "select", "unpack", "setmetatable", "getmetatable", "Instance", "Vector3", "CFrame", "Color3", "UDim2", "Enum", "loadstring" }) do
        Builtins[w] = true
    end

    local Syntax = {
        Keyword = "#569CD6",
        Builtin = "#4EC9B0",
        String = "#CE9178",
        Number = "#B5CEA8",
        Comment = "#6A9955"
    }

    local function Escape(s)
        s = s:gsub("&", "&amp;")
        s = s:gsub("<", "&lt;")
        s = s:gsub(">", "&gt;")
        return s
    end

    Highlight = function(src)
        local out = {}
        local i, n = 1, #src
        local function push(color, text)
            text = Escape(text)
            if color then
                out[#out + 1] = '<font color="' .. color .. '">' .. text .. "</font>"
            else
                out[#out + 1] = text
            end
        end
        while i <= n do
            local c = src:sub(i, i)
            if src:sub(i, i + 1) == "--" then
                local level = src:match("^%-%-%[(=*)%[", i)
                local e
                if level then
                    local _, ce = src:find("]" .. level .. "]", i, true)
                    e = ce or n
                else
                    local nl = src:find("\n", i, true)
                    e = nl and nl - 1 or n
                end
                push(Syntax.Comment, src:sub(i, e))
                i = e + 1
            elseif c == '"' or c == "'" then
                local j = i + 1
                while j <= n do
                    local d = src:sub(j, j)
                    if d == "\\" then
                        j = j + 2
                    elseif d == c or d == "\n" then
                        break
                    else
                        j = j + 1
                    end
                end
                local e = math.min(j, n)
                push(Syntax.String, src:sub(i, e))
                i = e + 1
            elseif c == "[" and src:match("^%[=*%[", i) then
                local level = src:match("^%[(=*)%[", i)
                local _, ce = src:find("]" .. level .. "]", i, true)
                local e = ce or n
                push(Syntax.String, src:sub(i, e))
                i = e + 1
            elseif c:match("%d") then
                local s, e = src:find("^0[xX]%x+", i)
                if not s then s, e = src:find("^%d+%.?%d*", i) end
                push(Syntax.Number, src:sub(s, e))
                i = e + 1
            elseif c:match("[%a_]") then
                local s, e = src:find("^[%w_]+", i)
                local word = src:sub(s, e)
                if Keywords[word] then
                    push(Syntax.Keyword, word)
                elseif Builtins[word] then
                    push(Syntax.Builtin, word)
                else
                    push(nil, word)
                end
                i = e + 1
            else
                local s, e = src:find("^[^%w_\"'%-%[]+", i)
                if s then
                    push(nil, src:sub(s, e))
                    i = e + 1
                else
                    push(nil, c)
                    i = i + 1
                end
            end
        end
        return table.concat(out)
    end
end

local CodeInput, Overlay, LineNumbers
local ActiveTabData, RefreshEditor, RefreshTabs, LoadActive, NewTab

do
    local TabsBar = New("ScrollingFrame", {
        Size = UDim2.new(1, -20, 0, 28),
        Position = UDim2.new(0, 10, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 0,
        Parent = Pages.Editor
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabsBar
    })

    local EditorBox = New("Frame", {
        Size = UDim2.new(1, -20, 1, -90),
        Position = UDim2.new(0, 10, 0, 42),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = Pages.Editor
    })
    Round(EditorBox, 2)
    Surface(EditorBox, "Panel")
    Outline(EditorBox, "Line")

    local EditorScroll = New("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.XY,
        ScrollingDirection = Enum.ScrollingDirection.XY,
        ScrollBarThickness = 5,
        Parent = EditorBox
    })

    local CODE_SIZE = State.LargeFont and 17 or 14

    LineNumbers = New("TextLabel", {
        Size = UDim2.new(0, 38, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = "1",
        Font = FONT_MONO,
        TextSize = CODE_SIZE,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = EditorScroll
    })
    Ink(LineNumbers, "Dim")
    New("UIPadding", { PaddingTop = UDim.new(0, 8), Parent = LineNumbers })

    Overlay = New("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 46, 0, 0),
        BackgroundTransparency = 1,
        RichText = true,
        Text = "",
        Font = FONT_MONO,
        TextSize = CODE_SIZE,
        TextWrapped = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        AutomaticSize = Enum.AutomaticSize.XY,
        ZIndex = 2,
        Parent = EditorScroll
    })
    Ink(Overlay, "Text")
    New("UIPadding", { PaddingTop = UDim.new(0, 8), Parent = Overlay })

    CodeInput = New("TextBox", {
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 46, 0, 0),
        BackgroundTransparency = 1,
        MultiLine = true,
        ClearTextOnFocus = false,
        Text = "",
        TextTransparency = 1,
        Font = FONT_MONO,
        TextSize = CODE_SIZE,
        TextWrapped = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        AutomaticSize = Enum.AutomaticSize.XY,
        ZIndex = 3,
        Parent = EditorScroll
    })
    Ink(CodeInput, "Text")
    New("UIPadding", { PaddingTop = UDim.new(0, 8), Parent = CodeInput })

    ActiveTabData = function()
        for _, t in ipairs(State.Tabs) do
            if t.id == State.ActiveTab then return t end
        end
        return State.Tabs[1]
    end

    RefreshEditor = function()
        local text = CodeInput.Text
        local lineCount = select(2, text:gsub("\n", "\n")) + 1

        local highlighted
        if #text <= 12000 then
            highlighted = Highlight(text)
            if #highlighted > 16000 then highlighted = nil end
        end
        if highlighted then
            Overlay.Visible = true
            Overlay.Text = highlighted
            CodeInput.TextTransparency = 1
        else
            Overlay.Visible = false
            CodeInput.TextTransparency = 0
        end

        local showNumbers = State.ShowLineNumbers and lineCount <= 3000
        LineNumbers.Visible = showNumbers
        if showNumbers then
            local nums = table.create(lineCount)
            for i = 1, lineCount do nums[i] = tostring(i) end
            LineNumbers.Text = table.concat(nums, "\n")
        end

        local x = showNumbers and 46 or 10
        Overlay.Position = UDim2.new(0, x, 0, 0)
        CodeInput.Position = UDim2.new(0, x, 0, 0)
        Overlay.Size = UDim2.new(1, -(x + 4), 1, 0)
        CodeInput.Size = UDim2.new(1, -(x + 4), 1, 0)

        local tab = ActiveTabData()
        if tab and tab.content ~= text then
            tab.content = text
            MarkDirty()
            if tab.fileId then
                local file = FindFile(tab.fileId)
                if file then
                    file.code = text
                    FilesDirty = true
                end
            end
        end
    end

    CodeInput:GetPropertyChangedSignal("Text"):Connect(RefreshEditor)

    LoadActive = function()
        local tab = ActiveTabData()
        CodeInput.Text = tab.content
        RefreshEditor()
        RefreshTabs()
    end

    NewTab = function(name, content, fileId)
        local id = NextTabId
        NextTabId = NextTabId + 1
        table.insert(State.Tabs, {
            id = id,
            name = name or ("script_" .. id .. ".lua"),
            content = content or "",
            fileId = fileId
        })
        State.ActiveTab = id
        MarkDirty()
        LoadActive()
    end

    OpenFile = function(file)
        for _, t in ipairs(State.Tabs) do
            if t.fileId == file.id then
                State.ActiveTab = t.id
                MarkDirty()
                LoadActive()
                SwitchPage("Editor")
                return
            end
        end
        NewTab(file.name, file.code, file.id)
        SwitchPage("Editor")
    end

    RefreshTabs = function()
        for _, child in ipairs(TabsBar:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        local t = GetTheme()
        for index, tab in ipairs(State.Tabs) do
            local active = tab.id == State.ActiveTab
            local canClose = #State.Tabs > 1
            local holder = New("Frame", {
                Size = UDim2.new(0, 112, 1, 0),
                LayoutOrder = index,
                BackgroundColor3 = t.Card,
                BackgroundTransparency = active and 0 or 1,
                BorderSizePixel = 0,
                Parent = TabsBar
            })
            Round(holder, 2)
            local label = New("TextButton", {
                Size = UDim2.new(1, canClose and -22 or 0, 1, 0),
                BackgroundTransparency = 1,
                Text = tab.name,
                TextColor3 = active and t.Text or t.Dim,
                Font = FONT_UIB,
                TextSize = 13,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = holder
            })
            New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 4), Parent = label })
            if active then
                New("Frame", {
                    Size = UDim2.new(1, -8, 0, 1),
                    Position = UDim2.new(0, 4, 1, -1),
                    BackgroundColor3 = t.Accent,
                    BorderSizePixel = 0,
                    Parent = holder
                })
            end
            label.Activated:Connect(function()
                State.ActiveTab = tab.id
                MarkDirty()
                LoadActive()
            end)
            if canClose then
                local x = New("TextButton", {
                    Size = UDim2.fromOffset(20, 20),
                    Position = UDim2.new(1, -22, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Text = "x",
                    TextColor3 = t.Dim,
                    Font = FONT_UIB,
                    TextSize = 14,
                    Parent = holder
                })
                x.Activated:Connect(function()
                    for idx, tt in ipairs(State.Tabs) do
                        if tt.id == tab.id then
                            table.remove(State.Tabs, idx)
                            if State.ActiveTab == tab.id then
                                local neighbor = State.Tabs[math.min(idx, #State.Tabs)]
                                State.ActiveTab = neighbor.id
                            end
                            break
                        end
                    end
                    MarkDirty()
                    LoadActive()
                end)
            end
        end
    end
    table.insert(ThemeHooks, function() RefreshTabs() end)

    local Toolbar = New("Frame", {
        Size = UDim2.new(1, -20, 0, 32),
        Position = UDim2.new(0, 10, 1, -40),
        BackgroundTransparency = 1,
        Parent = Pages.Editor
    })
    New("UIGridLayout", {
        CellSize = UDim2.new(1 / 6, -4, 1, 0),
        CellPadding = UDim2.new(0, 4, 0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Toolbar
    })

    local ToolOrder = 0
    local function AddTool(text, primary, action)
        ToolOrder = ToolOrder + 1
        local b = Button(Toolbar, text, primary, { LayoutOrder = ToolOrder, TextSize = 11 })
        b.Activated:Connect(action)
        return b
    end

    AddTool("RUN", true, function()
        Execute(CodeInput.Text)
    end)

    AddTool("CLEAR", false, function()
        CodeInput.Text = ""
    end)

    AddTool("COPY", false, function()
        ClipBuffer = CodeInput.Text
        if SetClip(CodeInput.Text) then
            Log("Code copied to clipboard", "info")
        else
            Log("Clipboard is not supported here, kept in internal buffer", "warn")
        end
    end)

    AddTool("PASTE", false, function()
        local clip = GetClip()
        if clip == "" then return end
        if CodeInput.Text == "" then
            CodeInput.Text = clip
        else
            CodeInput.Text = CodeInput.Text .. "\n" .. clip
        end
    end)

    AddTool("SAVE", false, function()
        local tab = ActiveTabData()
        local file = tab.fileId and FindFile(tab.fileId)
        if file then
            file.code = CodeInput.Text
            SaveFiles()
            Log("Saved " .. file.name, "ok")
        else
            local id = NextFileId
            NextFileId = NextFileId + 1
            table.insert(State.Files, { id = id, name = tab.name, code = CodeInput.Text })
            tab.fileId = id
            SaveFiles()
            MarkDirty()
            Log("Saved " .. tab.name .. " to files", "ok")
        end
    end)

    AddTool("NEW", false, function()
        NewTab(nil, "", nil)
    end)
end

do
    local SearchHeader = New("Frame", {
        Size = UDim2.new(1, -20, 0, 34),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        Parent = Pages.Hub
    })

    local SearchBox = New("TextBox", {
        Size = UDim2.new(1, -86, 1, 0),
        PlaceholderText = "Search ScriptBlox",
        Text = "",
        Font = FONT_UI,
        TextSize = 15,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
        Parent = SearchHeader
    })
    Round(SearchBox, 2)
    Bind(SearchBox, function(t)
        SearchBox.BackgroundColor3 = t.Panel
        SearchBox.BackgroundTransparency = 0
        SearchBox.TextColor3 = t.Text
        SearchBox.PlaceholderColor3 = t.Dim
    end)
    Outline(SearchBox, "Line")
    New("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = SearchBox })

    local SearchBtn = Button(SearchHeader, "SEARCH", true, {
        Size = UDim2.new(0, 78, 1, 0),
        Position = UDim2.new(1, -78, 0, 0)
    })

    local Results = New("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -56),
        Position = UDim2.new(0, 10, 0, 50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        Parent = Pages.Hub
    })
    New("UIGridLayout", {
        CellSize = UDim2.new(0.5, -5, 0, 62),
        CellPadding = UDim2.new(0, 8, 0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Results
    })

    local Modal = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C(0, 0, 0),
        BackgroundTransparency = 0.5,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 20,
        Parent = Main
    })
    HideModal = function()
        Modal.Visible = false
    end

    local ModalCard = New("Frame", {
        Size = UDim2.new(0.86, 0, 0, 196),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 21,
        Parent = Modal
    }, {
        New("UISizeConstraint", { MaxSize = Vector2.new(320, 196) })
    })
    Round(ModalCard, 3)
    Surface(ModalCard, "Panel")
    Outline(ModalCard, "Line")

    local ModalTitle = New("TextLabel", {
        Size = UDim2.new(1, -24, 0, 34),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.SourceSansBold,
        TextSize = 15,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 22,
        Parent = ModalCard
    })
    Ink(ModalTitle, "Text")

    local Selected = nil

    local function ModalButton(text, primary, y)
        return Button(ModalCard, text, primary, {
            Size = UDim2.new(1, -24, 0, 30),
            Position = UDim2.new(0, 12, 0, y),
            ZIndex = 22
        })
    end

    local MRun = ModalButton("LOAD AND RUN", true, 44)
    local MLoad = ModalButton("LOAD IN EDITOR", false, 78)
    local MLink = ModalButton("COPY LINK", false, 112)
    local MSave = ModalButton("SAVE TO FILES", false, 146)

    Modal.Activated:Connect(function()
        Modal.Visible = false
    end)

    local function SelectedCode()
        if not Selected then return nil end
        local body = Selected.script
        if type(body) ~= "string" or body == "" then
            return nil
        end
        return body
    end

    local function SelectedFileName()
        local clean = tostring(Selected.title or "script"):gsub("[^%w_%-]", "_")
        return clean .. ".lua"
    end

    MRun.Activated:Connect(function()
        local body = SelectedCode()
        if not body then
            Log("This result has no script body", "warn")
            return
        end
        NewTab(SelectedFileName(), body, nil)
        Modal.Visible = false
        Execute(body)
    end)

    MLoad.Activated:Connect(function()
        local body = SelectedCode()
        if not body then
            Log("This result has no script body", "warn")
            return
        end
        NewTab(SelectedFileName(), body, nil)
        Modal.Visible = false
        SwitchPage("Editor")
    end)

    MLink.Activated:Connect(function()
        if not Selected then return end
        local link = "https://scriptblox.com/script/" .. tostring(Selected.slug or "")
        if SetClip(link) then
            Log("Link copied", "info")
        else
            Log(link, "info")
        end
        Modal.Visible = false
    end)

    MSave.Activated:Connect(function()
        local body = SelectedCode()
        if not body then
            Log("This result has no script body", "warn")
            return
        end
        local id = NextFileId
        NextFileId = NextFileId + 1
        table.insert(State.Files, { id = id, name = SelectedFileName(), code = body })
        SaveFiles()
        Log("Saved to files", "ok")
        Modal.Visible = false
    end)

    local function ResultNote(text, key)
        New("TextLabel", {
            Name = "Note",
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = GetTheme()[key or "Dim"],
            Font = FONT_UI,
            TextSize = 14,
            TextWrapped = true,
            Parent = Results
        })
    end

    local Searching = false

    local function ClearResults()
        for _, child in ipairs(Results:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
    end

    local function Search(query)
        if Searching then return end
        Searching = true
        ClearResults()
        ResultNote("Searching...", "Dim")
        task.spawn(function()
            local term = query ~= "" and query or "universal"
            local ok, body = HttpFetch("https://scriptblox.com/api/script/search?q=" .. HttpService:UrlEncode(term) .. "&page=1")
            ClearResults()
            Searching = false
            if not ok then
                ResultNote("Could not reach ScriptBlox", "Err")
                Log("ScriptBlox request failed: " .. tostring(body), "error")
                return
            end
            local parsed, data = pcall(function() return HttpService:JSONDecode(body) end)
            local list
            if parsed and type(data) == "table" then
                if type(data.result) == "table" and type(data.result.scripts) == "table" then
                    list = data.result.scripts
                elseif type(data.scripts) == "table" then
                    list = data.scripts
                end
            end
            if not list or #list == 0 then
                ResultNote("No scripts found", "Dim")
                return
            end
            local t = GetTheme()
            for index, item in ipairs(list) do
                local gameName = type(item.game) == "table" and item.game.name or "Universal"
                local card = New("TextButton", {
                    LayoutOrder = index,
                    BackgroundColor3 = t.Panel,
                    Text = "",
                    AutoButtonColor = true,
                    BorderSizePixel = 0,
                    Parent = Results
                })
                Round(card, 2)
                New("UIStroke", { Color = t.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
                New("TextLabel", {
                    Size = UDim2.new(1, -16, 0, 34),
                    Position = UDim2.new(0, 8, 0, 6),
                    BackgroundTransparency = 1,
                    Text = tostring(item.title or "Unnamed"),
                    TextColor3 = t.Text,
                    Font = FONT_UIB,
                    TextSize = 13,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Parent = card
                })
                New("TextLabel", {
                    Size = UDim2.new(1, -16, 0, 14),
                    Position = UDim2.new(0, 8, 1, -18),
                    BackgroundTransparency = 1,
                    Text = tostring(gameName),
                    TextColor3 = t.Dim,
                    Font = FONT_UI,
                    TextSize = 12,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = card
                })
                card.Activated:Connect(function()
                    Selected = item
                    ModalTitle.Text = tostring(item.title or "Script")
                    Modal.Visible = true
                end)
            end
        end)
    end

    SearchBtn.Activated:Connect(function()
        Search(SearchBox.Text)
    end)
    SearchBox.FocusLost:Connect(function(enter)
        if enter then Search(SearchBox.Text) end
    end)
end

SetOpen = function(value)
    Main.Visible = value
    Launcher.Visible = not value
    if value then
        Fit()
    else
        CancelWindowDrag()
        HideModal()
    end
end

do
    local ROW_H = 46
    local ROW_GAP = 6

    local Header = New("Frame", {
        Size = UDim2.new(1, -20, 0, 34),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        Parent = Pages.Files
    })

    local NameBox = New("TextBox", {
        Size = UDim2.new(1, -84, 1, 0),
        PlaceholderText = "File name",
        Text = "",
        Font = FONT_UI,
        TextSize = 15,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
        Parent = Header
    })
    Round(NameBox, 2)
    Bind(NameBox, function(t)
        NameBox.BackgroundColor3 = t.Panel
        NameBox.BackgroundTransparency = 0
        NameBox.TextColor3 = t.Text
        NameBox.PlaceholderColor3 = t.Dim
    end)
    Outline(NameBox, "Line")
    New("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = NameBox })

    local AddBtn = Button(Header, "ADD", true, {
        Size = UDim2.new(0, 76, 1, 0),
        Position = UDim2.new(1, -76, 0, 0)
    })

    local FileScroll = New("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -56),
        Position = UDim2.new(0, 10, 0, 50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 4,
        ElasticBehavior = Enum.ElasticBehavior.Always,
        Parent = Pages.Files
    })

    RenderFiles = function()
        for _, c in ipairs(FileScroll:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        local t = GetTheme()
        local count = #State.Files
        local padTop = 6 + count * 2
        local padBottom = 30 + count * 4
        FileScroll.CanvasSize = UDim2.fromOffset(0, padTop + count * (ROW_H + ROW_GAP) + padBottom)

        if count == 0 then
            New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 30),
                Position = UDim2.fromOffset(0, padTop),
                BackgroundTransparency = 1,
                Text = "No files yet",
                TextColor3 = t.Dim,
                Font = FONT_UI,
                TextSize = 14,
                Parent = FileScroll
            })
            return
        end

        for index, file in ipairs(State.Files) do
            local row = New("Frame", {
                Size = UDim2.new(1, -8, 0, ROW_H),
                Position = UDim2.fromOffset(0, padTop + (index - 1) * (ROW_H + ROW_GAP)),
                BackgroundColor3 = t.Panel,
                BorderSizePixel = 0,
                Parent = FileScroll
            })
            Round(row, 2)
            New("UIStroke", { Color = t.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = row })

            local nameBox = New("TextBox", {
                Size = UDim2.new(1, -186, 0, 28),
                Position = UDim2.new(0, 10, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Text = file.name,
                PlaceholderText = "name",
                TextColor3 = t.Text,
                PlaceholderColor3 = t.Dim,
                Font = FONT_UIB,
                TextSize = 14,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row
            })
            nameBox.FocusLost:Connect(function()
                local value = nameBox.Text:match("^%s*(.-)%s*$")
                if value == "" then
                    nameBox.Text = file.name
                    return
                end
                if value ~= file.name then
                    file.name = value
                    nameBox.Text = value
                    for _, tab in ipairs(State.Tabs) do
                        if tab.fileId == file.id then tab.name = value end
                    end
                    SaveFiles()
                    MarkDirty()
                    RefreshTabs()
                end
            end)

            local function RowBtn(text, offset, width, primary)
                local b = New("TextButton", {
                    Size = UDim2.fromOffset(width, 26),
                    Position = UDim2.new(1, offset, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = primary and t.Accent or t.Card,
                    Text = text,
                    TextColor3 = primary and OnAccent(t.Accent) or t.Text,
                    Font = FONT_BTN,
                    TextSize = 10,
                    BorderSizePixel = 0,
                    Parent = row
                })
                Round(b, 2)
                return b
            end

            local runBtn = RowBtn("EXECUTE", -104, 66, true)
            local editBtn = RowBtn("EDIT", -56, 44, false)
            local delBtn = RowBtn("DEL", -8, 44, false)
            delBtn.TextColor3 = t.Err

            runBtn.Activated:Connect(function()
                Execute(file.code)
            end)

            editBtn.Activated:Connect(function()
                OpenFile(file)
            end)

            local armed = false
            delBtn.Activated:Connect(function()
                if not armed then
                    armed = true
                    delBtn.Text = "SURE?"
                    task.delay(2, function()
                        if delBtn.Parent then
                            armed = false
                            delBtn.Text = "DEL"
                        end
                    end)
                    return
                end
                for idx, f in ipairs(State.Files) do
                    if f.id == file.id then
                        table.remove(State.Files, idx)
                        break
                    end
                end
                for _, tab in ipairs(State.Tabs) do
                    if tab.fileId == file.id then tab.fileId = nil end
                end
                SaveFiles()
                MarkDirty()
                RenderFiles()
            end)
        end
    end
    table.insert(ThemeHooks, function()
        if CurrentPage == "Files" then RenderFiles() end
    end)

    local function AddFromBox()
        local value = NameBox.Text:match("^%s*(.-)%s*$")
        local id = NextFileId
        NextFileId = NextFileId + 1
        if value == "" then
            value = "file " .. id
        end
        local file = { id = id, name = value, code = "" }
        table.insert(State.Files, file)
        SaveFiles()
        NameBox.Text = ""
        OpenFile(file)
    end

    AddBtn.Activated:Connect(AddFromBox)
    NameBox.FocusLost:Connect(function(enter)
        if enter then AddFromBox() end
    end)
end

do
    local SetupScroll = New("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        Parent = Pages.Setup
    })
    New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = SetupScroll })

    local SetupOrder = 0
    local function SetupRow(height)
        SetupOrder = SetupOrder + 1
        local row = New("Frame", {
            Size = UDim2.new(1, 0, 0, height or 0),
            AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
            LayoutOrder = SetupOrder,
            BorderSizePixel = 0,
            Parent = SetupScroll
        })
        Round(row, 2)
        Surface(row, "Panel")
        Outline(row, "Line")
        return row
    end

    local function RowLabel(row, text)
        local l = New("TextLabel", {
            Size = UDim2.new(0.5, 0, 0, 22),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = text,
            Font = FONT_UIB,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row
        })
        Ink(l, "Text")
        return l
    end

    local function PadRow(row)
        New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
        New("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            Parent = row
        })
    end

    do
        local OpacityRow = SetupRow(50)
        local OpacityLabel = RowLabel(OpacityRow, "Opacity")
        OpacityLabel.Size = UDim2.new(0.4, 0, 1, 0)
        local OpacityValue = New("TextLabel", {
            Size = UDim2.fromOffset(40, 50),
            Position = UDim2.new(1, -12, 0, 0),
            AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1,
            Text = "",
            Font = FONT_UI,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = OpacityRow
        })
        Ink(OpacityValue, "Dim")

        local Track = New("TextButton", {
            Size = UDim2.fromOffset(110, 24),
            Position = UDim2.new(1, -58, 0.5, 0),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = OpacityRow
        })
        local TrackBar = New("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            Position = UDim2.fromScale(0, 0.5),
            AnchorPoint = Vector2.new(0, 0.5),
            BorderSizePixel = 0,
            Parent = Track
        })
        Bind(TrackBar, function(t) TrackBar.BackgroundColor3 = t.Line end)
        local TrackFill = New("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            Parent = TrackBar
        })
        Bind(TrackFill, function(t) TrackFill.BackgroundColor3 = t.Accent end)
        local TrackKnob = New("Frame", {
            Size = UDim2.fromOffset(10, 10),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(1, 0.5),
            BorderSizePixel = 0,
            Parent = TrackBar
        })
        Bind(TrackKnob, function(t) TrackKnob.BackgroundColor3 = t.Accent end)

        local function SyncOpacityVisual()
            local frac = (State.Opacity - OP_MIN) / (1 - OP_MIN)
            TrackFill.Size = UDim2.new(frac, 0, 1, 0)
            TrackKnob.Position = UDim2.new(frac, 0, 0.5, 0)
            OpacityValue.Text = math.floor(State.Opacity * 100 + 0.5) .. "%"
        end
        SyncOpacityVisual()

        local activeInput = nil
        local function SetOpacityFromX(x)
            local rel = math.clamp((x - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
            State.Opacity = OP_MIN + rel * (1 - OP_MIN)
            SyncOpacityVisual()
            ApplyTheme()
        end

        Track.InputBegan:Connect(function(input)
            if activeInput then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                activeInput = input
                SetOpacityFromX(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not activeInput then return end
            local follows
            if activeInput.UserInputType == Enum.UserInputType.Touch then
                follows = input == activeInput
            else
                follows = input.UserInputType == Enum.UserInputType.MouseMovement
            end
            if follows then
                SetOpacityFromX(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if not activeInput then return end
            local finished
            if activeInput.UserInputType == Enum.UserInputType.Touch then
                finished = input == activeInput
            else
                finished = input.UserInputType == Enum.UserInputType.MouseButton1
            end
            if finished then
                activeInput = nil
                SaveSettings()
            end
        end)
    end

    do
        local ThemeRow = SetupRow(nil)
        PadRow(ThemeRow)
        RowLabel(ThemeRow, "Color theme").LayoutOrder = 1
        local SwatchHolder = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            Parent = ThemeRow
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Wraps = true,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = SwatchHolder
        })

        local Swatches = {}
        local function StyleSwatches()
            local t = GetTheme()
            for key, pack in pairs(Swatches) do
                pack.stroke.Color = t.Text
                pack.stroke.Enabled = key == State.Theme
            end
        end

        for index, key in ipairs(ThemeOrder) do
            local sw = New("TextButton", {
                Size = UDim2.fromOffset(28, 28),
                LayoutOrder = index,
                BackgroundColor3 = Themes[key].Accent,
                Text = "",
                AutoButtonColor = false,
                BorderSizePixel = 0,
                Parent = SwatchHolder
            })
            Round(sw, 2)
            local stroke = New("UIStroke", {
                Thickness = 2,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Enabled = false,
                Parent = sw
            })
            Swatches[key] = { button = sw, stroke = stroke }
            sw.Activated:Connect(function()
                State.Theme = key
                ApplyTheme()
                SaveSettings()
            end)
        end
        table.insert(ThemeHooks, StyleSwatches)
    end

    do
        local SoundRow = SetupRow(nil)
        PadRow(SoundRow)
        RowLabel(SoundRow, "Sounds").LayoutOrder = 1

        local SoundStatus = New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            Text = "",
            Font = FONT_UI,
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = 2,
            Parent = SoundRow
        })
        Ink(SoundStatus, "Dim")

        local SoundGrid = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = 3,
            Parent = SoundRow
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Wraps = true,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = SoundGrid
        })

        local SoundBtns = {}

        local function IsSelected(i)
            for _, v in ipairs(State.SoundSel) do
                if v == i then return true end
            end
            return false
        end

        local function StyleSounds()
            local t = GetTheme()
            for i, b in pairs(SoundBtns) do
                local available = SoundAvail[i]
                if IsSelected(i) then
                    b.BackgroundColor3 = t.Accent
                    b.TextColor3 = OnAccent(t.Accent)
                else
                    b.BackgroundColor3 = t.Card
                    b.TextColor3 = available and t.Text or t.Dim
                end
                b.BackgroundTransparency = available and 0 or 0.5
            end
        end
        table.insert(ThemeHooks, StyleSounds)

        RefreshSoundStatus = function()
            local sel = State.SoundSel
            local line
            if #sel == 0 then
                line = "Selection: all sounds, random"
            elseif #sel == 1 then
                line = "Selection: sound " .. sel[1]
            else
                line = "Selection: sound " .. sel[1] .. " or " .. sel[2] .. ", random"
            end
            local status = NowIndex and ("Playing: " .. NowIndex) or "Idle"
            SoundStatus.Text = line .. "\n" .. status
            StyleSounds()
        end

        for i = 1, #SoundSources do
            local b = New("TextButton", {
                Size = UDim2.fromOffset(34, 34),
                LayoutOrder = i,
                Text = tostring(i),
                Font = FONT_BTN,
                TextSize = 14,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                Parent = SoundGrid
            })
            Round(b, 2)
            SoundBtns[i] = b
            b.Activated:Connect(function()
                if not SoundAvail[i] then
                    Log("Sound " .. i .. " is not available", "warn")
                    return
                end
                if IsSelected(i) then
                    for idx, v in ipairs(State.SoundSel) do
                        if v == i then
                            table.remove(State.SoundSel, idx)
                            break
                        end
                    end
                else
                    if #State.SoundSel >= 2 then
                        table.remove(State.SoundSel, 1)
                    end
                    table.insert(State.SoundSel, i)
                end
                RefreshSoundStatus()
                SaveSettings()
            end)
        end

        local SoundActions = New("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            LayoutOrder = 4,
            Parent = SoundRow
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            Parent = SoundActions
        })
        local PlayBtn = Button(SoundActions, "PLAY", true, { Size = UDim2.new(0, 80, 1, 0) })
        local StopBtn = Button(SoundActions, "STOP", false, { Size = UDim2.new(0, 80, 1, 0) })
        PlayBtn.Activated:Connect(PlayChosen)
        StopBtn.Activated:Connect(StopSound)
    end

    do
        local function AddToggle(title, key, onChange)
            local row = SetupRow(42)
            local l = RowLabel(row, title)
            l.Size = UDim2.new(0.6, 0, 1, 0)
            local btn = New("TextButton", {
                Size = UDim2.fromOffset(58, 26),
                Position = UDim2.new(1, -12, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                Font = FONT_BTN,
                TextSize = 11,
                BorderSizePixel = 0,
                Parent = row
            })
            Round(btn, 2)
            local function Style()
                local t = GetTheme()
                local on = State[key]
                btn.Text = on and "ON" or "OFF"
                btn.BackgroundColor3 = on and t.Accent or t.Card
                btn.TextColor3 = on and OnAccent(t.Accent) or t.Dim
            end
            Style()
            table.insert(ThemeHooks, Style)
            btn.Activated:Connect(function()
                State[key] = not State[key]
                Style()
                if onChange then onChange(State[key]) end
                SaveSettings()
            end)
        end

        AddToggle("Play sound on start", "PlayOnStart")

        AddToggle("Line numbers", "ShowLineNumbers", function()
            RefreshEditor()
        end)

        AddToggle("Auto save tabs", "AutoSave", function(on)
            if on then MarkDirty() end
        end)

        AddToggle("Large code font", "LargeFont", function(on)
            local size = on and 17 or 14
            CodeInput.TextSize = size
            Overlay.TextSize = size
            LineNumbers.TextSize = size
        end)

        AddToggle("Mirror game output", "Mirror")
    end
end

do
    local InfoCard = New("Frame", {
        Size = UDim2.new(1, -20, 0, 196),
        Position = UDim2.new(0, 10, 0, 10),
        BorderSizePixel = 0,
        Parent = Pages.Info
    })
    Round(InfoCard, 2)
    Surface(InfoCard, "Panel")
    Outline(InfoCard, "Line")

    local InfoText = New("TextLabel", {
        Size = UDim2.new(1, -24, 1, -20),
        Position = UDim2.new(0, 12, 0, 10),
        BackgroundTransparency = 1,
        Text = "",
        Font = FONT_MONO,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = InfoCard
    })
    Ink(InfoText, "Text")

    ShowInfo = function()
        local function yn(v) return v and "yes" or "no" end
        local soundCount = 0
        for i = 1, #SoundSources do
            if SoundAvail[i] then soundCount = soundCount + 1 end
        end
        InfoText.Text = table.concat({
            "app            XD EXECUTOR " .. State.Version,
            "executor       XD EXECUTOR",
            "loadstring     " .. yn(type(loadstring) == "function"),
            "http request   " .. yn((syn and syn.request) or http_request or request or (http and http.request) or (fluxus and fluxus.request)),
            "file system    " .. yn(FsOk()),
            "clipboard      " .. yn(setclipboard or toclipboard or (syn and syn.write_clipboard)),
            "image          " .. yn(PictureAsset),
            "sounds         " .. soundCount .. " / " .. #SoundSources,
            "runs           " .. RunCount,
            "files          " .. #State.Files
        }, "\n")
    end

    local RecheckBtn = Button(Pages.Info, "REFRESH", false, {
        Size = UDim2.fromOffset(100, 32),
        Position = UDim2.new(0, 10, 0, 214)
    })
    RecheckBtn.Activated:Connect(ShowInfo)
end

ApplyTheme = function()
    local t = GetTheme()
    local tr = 1 - State.Opacity
    for i = #Bindings, 1, -1 do
        local b = Bindings[i]
        if b.inst and b.inst.Parent then
            b.fn(t, tr)
        else
            table.remove(Bindings, i)
        end
    end
    for _, hook in ipairs(ThemeHooks) do hook() end
end

ApplyTheme()
RefreshSoundStatus()
LoadActive()
SwitchPage("Editor")

do
    local spinSpeed = 75
    local spinRot = 0
    local lastPlaying = false
    local spinConn
    spinConn = RunService.Heartbeat:Connect(function(dt)
        if not Gui.Parent then
            spinConn:Disconnect()
            return
        end
        local playing = Audio.IsPlaying
        local target = playing and 520 or 75
        spinSpeed = spinSpeed + (target - spinSpeed) * math.min(1, dt * 3)
        spinRot = (spinRot + spinSpeed * dt) % 360
        SpinImage.Rotation = spinRot

        if playing and not Stopping then
            local len = Audio.TimeLength
            if len > 0 then
                local fade = math.clamp(len * 0.25, 0.5, 3)
                local remain = len - Audio.TimePosition
                if remain < fade then
                    Audio.Volume = BASE_VOLUME * math.max(remain, 0) / fade
                else
                    Audio.Volume = BASE_VOLUME
                end
            end
        end

        if playing ~= lastPlaying then
            lastPlaying = playing
            if not playing and not Stopping then
                NowIndex = nil
            end
            RefreshSoundStatus()
        end
    end)
end

task.spawn(function()
    while Gui.Parent do
        task.wait(1)
        if Dirty and State.AutoSave then
            Dirty = false
            SaveTabs()
        end
        if FilesDirty then
            FilesDirty = false
            SaveFiles()
        end
    end
end)

Log("XD EXECUTOR " .. State.Version .. " ready", "ok")

task.spawn(function()
    local function DownloadTo(url, path)
        for _ = 1, 3 do
            local res = Req({ Url = url, Method = "GET" })
            local body, code = BodyOf(res)
            if ValidBody(body, code) then
                if NewFile(path, body) then return true end
            end
            task.wait(0.5)
        end
        return false
    end

    local function MakeToast()
        local toast = {}
        local sg = New("ScreenGui", {
            Name = TOAST_NAME,
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            DisplayOrder = 1000,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        })
        sg:SetAttribute("xd", true)
        Protect(sg)
        sg.Parent = Hui
        local width = math.clamp(ViewSize().X - 32, 220, 310)
        local card = New("Frame", {
            Size = UDim2.fromOffset(width, 58),
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, width + 40, 1, -18),
            BackgroundColor3 = C(17, 17, 19),
            BorderSizePixel = 0,
            Parent = sg
        })
        Round(card, 3)
        New("UIStroke", { Color = C(201, 169, 110), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
        New("TextLabel", {
            Size = UDim2.new(1, -30, 0, 16),
            Position = UDim2.new(0, 14, 0, 8),
            BackgroundTransparency = 1,
            Text = "XD EXECUTOR",
            TextColor3 = C(201, 169, 110),
            Font = FONT_BTN,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })
        toast.text = New("TextLabel", {
            Size = UDim2.new(1, -24, 0, 22),
            Position = UDim2.new(0, 14, 0, 26),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = C(230, 225, 215),
            Font = Enum.Font.SourceSansBold,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })
        toast.gui = sg
        toast.card = card
        toast.width = width
        return toast
    end

    local function ToastIn(toast)
        TweenService:Create(toast.card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -16, 1, -18)
        }):Play()
    end

    local function ToastOut(toast)
        TweenService:Create(toast.card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, toast.width + 40, 1, -18)
        }):Play()
        task.wait(0.27)
    end

    local Jobs = {}
    if not Cached(PicturePath) then
        table.insert(Jobs, function()
            return DownloadTo(PictureSource, PicturePath)
        end)
    end
    for index, source in ipairs(SoundSources) do
        if not Cached(SoundPaths[index]) then
            table.insert(Jobs, function()
                return DownloadTo(source, SoundPaths[index])
            end)
        end
    end

    if #Jobs > 0 then
        local toast = MakeToast()
        toast.text.Text = "Downloading sounds and pictures"
        ToastIn(toast)

        local downloading = true
        task.spawn(function()
            local frames = { "", " .", " . .", " . . ." }
            local i = 0
            while downloading do
                toast.text.Text = "Downloading sounds and pictures" .. frames[i % 4 + 1]
                i = i + 1
                task.wait(0.4)
            end
        end)

        local pending = #Jobs
        local failed = 0
        for _, job in ipairs(Jobs) do
            task.spawn(function()
                local ok, res = pcall(job)
                if not (ok and res) then failed = failed + 1 end
                pending = pending - 1
            end)
        end

        local deadline = os.clock() + 120
        while pending > 0 and os.clock() < deadline do
            task.wait(0.05)
        end
        if pending > 0 then failed = failed + pending end

        downloading = false
        task.spawn(function()
            ToastOut(toast)
            if failed > 0 then
                toast.text.Text = "Download completed (" .. failed .. " failed)"
            else
                toast.text.Text = "Download completed"
            end
            ToastIn(toast)
            task.wait(2.6)
            ToastOut(toast)
            toast.gui:Destroy()
        end)
    end

    if Cached(PicturePath) then
        SetPicture(AssetOf(PicturePath))
    end

    for index = 1, #SoundSources do
        SoundAvail[index] = Cached(SoundPaths[index])
    end
    RefreshSoundStatus()

    if State.PlayOnStart then
        PlayChosen()
    end
end)
