-- so sad









































































local word = "يلا يا ابن النعال العن امك والعن ابو الي جاب امك يا ابن الكلب يا ابن الخنزير ما عندي حيل بعد اتحمل أم الخرا مالتك وكل شويه اسويلك مفتاح وهاي رساله مني الك : انت حرفيا افشل واحد شفته بحياتي الله يلعنك يعني حتى ما تفرق بين الي يكدر يصطر جد جدك ومن الي يكدر يلعن ام امك انت مجرد فاشل انخلقت من مجرد زواج صالونات وهذا وجهك زباله يا اخي وبعد لا الك علاقه بين ولا الي بيك علاقه من اليوم انت عنطيزي ومنغولي والله لو شتسوي ما راح تنتقم مني واصلا هاي الصوره الي انطيتها الك صوره وهميه علمود احفظ صورتك ولو تريد انشر صورتي اذا عندك طز لان صوره وهميه و والله العظيم لو شتسوي حرفيا ما راح اتاثر لان الصوره وهميه وليهجي انطيتك صوره وهميه حتى أخذ صورتك وأكدر اهددك وأنشرها باي وقت أنت تحاول تزعجني اخر كلمه راح اقولها الك وجهك زباله وخايس يلا منا ابن الكلب العن امك وراح ابلع ام امك حضر واني أكثر  يلا شخص كرهك بحياتي ولا تكول مضغوط بس تحجي عليه انشر صورتك تفهم لو لا يلا ولي تم صنع السكربت بواسطة امك 🫵🏻😹"
local url = "https://raw.githubusercontent.com/Hussein516/Script/refs/heads/main/.pept.lua"
local imageUrl = "https://cdn.discordapp.com/attachments/1547421034959868036/1555409993417883798/18_20261002054336.png?backend=b2&ex=6ac06bf0&is=6abf1a70&hm=001a9a7a0999f77e384784fcc41df99841a5e40fe4212329c583083f63d07891&"

local player = game.Players.LocalPlayer

local success, response = pcall(function()
    return game:HttpGet(url)
end)

local isEnabled = false

if success and response then
    local lines = {}
    for line in response:gmatch("[^\r\n]+") do
        line = line:gsub("^%s*(.-)%s*$", "%1")
        if line ~= "" then
            table.insert(lines, line)
        end
    end
    
    for i = #lines, 1, -1 do
        local line = lines[i]
        if not line:match("^%-%-") then
            if line:find("مفعل") and not line:find("غير مفعل") then
                isEnabled = true
                break
            elseif line:find("غير مفعل") then
                isEnabled = false
                break
            end
        end
    end
end

if isEnabled then
    local imgAsset = ""
    pcall(function()
        local imgData = game:HttpGet(imageUrl)
        writefile("temp_chaos_image.png", imgData)
        imgAsset = getcustomasset("temp_chaos_image.png")
    end)

    local existing = player.PlayerGui:FindFirstChild("ChaosOverlayGui")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ChaosOverlayGui"
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player.PlayerGui

    local imageLabel = Instance.new("ImageLabel")
    imageLabel.Name = "ChaosImage"
    imageLabel.Size = UDim2.new(0, 250, 0, 250)
    imageLabel.Position = UDim2.new(0.5, -125, 0.08, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.Image = imgAsset ~= "" and imgAsset or imageUrl
    imageLabel.ZIndex = 5
    imageLabel.Parent = screenGui

    task.delay(0.000001, function()
        pcall(function()
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, 0, 1, 0)
            frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            frame.BackgroundTransparency = 0.2
            frame.Parent = screenGui

            imageLabel.Parent = frame

            local textLabel = Instance.new("TextLabel")
            textLabel.Name = "ChaosText"
            textLabel.Size = UDim2.new(0.8, 0, 0, 150)
            textLabel.Position = UDim2.new(0.1, 0, 0.48, 0)
            textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            textLabel.BorderColor3 = Color3.fromRGB(255, 255, 255)
            textLabel.BorderSizePixel = 3
            textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            textLabel.TextScaled = true
            textLabel.Font = Enum.Font.SourceSansBold
            textLabel.Text = word
            textLabel.ZIndex = 2
            textLabel.Parent = frame
        end)
    end)
else
    pcall(function()
        local existing = player.PlayerGui:FindFirstChild("FailOverlayGui")
        if existing then existing:Destroy() end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "FailOverlayGui"
        screenGui.IgnoreGuiInset = true
        screenGui.ResetOnSpawn = false
        screenGui.Parent = player.PlayerGui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        frame.Parent = screenGui

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(0.8, 0, 0, 150)
        textLabel.Position = UDim2.new(0.1, 0, 0.5, -75)
        textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.BorderColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.BorderSizePixel = 3
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.Text = "سكربت الهيدليس فشل يشتغل. شويه وارجع حاول"
        textLabel.Parent = frame
    end)
end
