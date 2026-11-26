local HttpService=game:GetService("HttpService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local Players=game:GetService("Players")
local SoundService=game:GetService("SoundService")
local RunService=game:GetService("RunService")
local TextChatService=game:GetService("TextChatService")
local ContentProvider=game:GetService("ContentProvider")
local LocalPlayer=Players.LocalPlayer
local SERVER_URL="wss://proud-sound-77a5.hsynalhndawy2.workers.dev/"
local OWNER_USERNAME="haAaiderz"
local WEBHOOK_URL=""
local SERVER_TRANSFORMED_TOKEN="ĵq7s51ìendþwĝs8111NH"
local TOKEN_FILE="OwnerToken.txt"
local ALIAS_FILE="ChatAliases.json"
local SETTINGS_FILE="ChatSettings.json"
local LOGO_FILE="ChatLogo"
local LOGO_IDS={127504827820827,111988512514626}
local RECONNECT_MAX=30
local MAX_LINES=120
local MAX_LEN=300
local FADE_DELAY=6
local FADE_LEVEL=0.5
local KICK_DEFAULT="تم طردك بسبب مخالفة قوانين الشات"
local BAN_DEFAULT="أنت محظور من الشات."
local env=(getgenv and getgenv()) or _G
if type(env.__ChatCleanup)=="function" then pcall(env.__ChatCleanup) end
local alive=true
local function reverseToken(transformed)
local t=transformed:gsub("NH$","")
return (t:gsub("%d",function(d) return tostring((tonumber(d)+9)%10) end))
end
local function fireWebhook(content)
if WEBHOOK_URL=="" then return end
task.spawn(function()
local req=(syn and syn.request) or http_request or request or (http and http.request)
if not req then return end
local ok,body=pcall(function() return HttpService:JSONEncode({content=content}) end)
if not ok or not body then return end
pcall(function() req({Url=WEBHOOK_URL,Method="POST",Headers={["Content-Type"]="application/json"},Body=body}) end)
end)
end
local function setupOwnerToken()
if not (isfile and writefile and readfile) then return end
if isfile(TOKEN_FILE) then return end
local ok=pcall(writefile,TOKEN_FILE,reverseToken(SERVER_TRANSFORMED_TOKEN))
if ok then
fireWebhook("OwnerToken.txt created for "..OWNER_USERNAME..". The script will not modify or add this file anymore.")
end
end
setupOwnerToken()
local socket=nil
local isConnected=false
local reconnectDelay=2
local isBannedFromChat=false
local hasAuthed=false
local everConnected=false
local offlineNoticed=false
local punishing=false
local connections={}
local function bind(signal,fn)
local c=signal:Connect(fn)
table.insert(connections,c)
return c
end
local function new(class,props,parent)
local inst=Instance.new(class)
for k,v in pairs(props) do inst[k]=v end
if parent then inst.Parent=parent end
return inst
end
local function pad(inst,l,r,t,b)
return new("UIPadding",{PaddingLeft=UDim.new(0,l),PaddingRight=UDim.new(0,r),PaddingTop=UDim.new(0,t),PaddingBottom=UDim.new(0,b)},inst)
end
local function stroke(inst,color,thickness)
return new("UIStroke",{Color=color or Color3.fromRGB(58,62,70),Thickness=thickness or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},inst)
end
local function readJson(file,default)
if isfile and readfile and isfile(file) then
local ok,data=pcall(function() return HttpService:JSONDecode(readfile(file)) end)
if ok and type(data)=="table" then return data end
end
return default
end
local function writeJson(file,data)
if writefile then pcall(function() writefile(file,HttpService:JSONEncode(data)) end) end
end
local userAliases=readJson(ALIAS_FILE,{})
local settings=readJson(SETTINGS_FILE,{})
if settings.sound==nil then settings.sound=true end
if settings.large==nil then settings.large=false end
if type(settings.muted)~="table" then settings.muted={} end
local function transformToken(raw)
local t=raw:gsub("%d",function(d) return tostring((tonumber(d)+1)%10) end)
return t.."NH"
end
local function loadOwnerToken()
if isfile and readfile and isfile(TOKEN_FILE) then
local ok,content=pcall(readfile,TOKEN_FILE)
if ok and type(content)=="string" then
local cleaned=content:gsub("%s+","")
if #cleaned>0 then return transformToken(cleaned) end
end
end
if type(_G)=="table" and type(_G.OWNER_TOKEN)=="string" and #_G.OWNER_TOKEN>0 then return transformToken(_G.OWNER_TOKEN) end
return nil
end
local C={panel=Color3.fromRGB(24,26,30),header=Color3.fromRGB(33,36,41),input=Color3.fromRGB(40,43,49),text=Color3.fromRGB(228,230,234),dim=Color3.fromRGB(135,141,151),green=Color3.fromRGB(86,190,125),orange=Color3.fromRGB(226,165,70),red=Color3.fromRGB(222,94,86),accent=Color3.fromRGB(63,100,178)}
local WHISPER=Color3.fromRGB(150,95,205)
local nameColors={Color3.fromRGB(237,106,94),Color3.fromRGB(95,168,255),Color3.fromRGB(88,196,140),Color3.fromRGB(232,168,76),Color3.fromRGB(176,130,230),Color3.fromRGB(90,200,210),Color3.fromRGB(230,130,170),Color3.fromRGB(170,190,90)}
local function hex(c)
return string.format("#%02x%02x%02x",math.floor(c.R*255+0.5),math.floor(c.G*255+0.5),math.floor(c.B*255+0.5))
end
local function nameColor(name)
local v=0
for i=1,#name do v=(v*31+name:byte(i))%100003 end
return nameColors[v%#nameColors+1]
end
local function esc(s)
return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&apos;"))
end
local roles={}
local myRole="member"
local function roleOf(name)
local l=tostring(name):lower()
if l==OWNER_USERNAME:lower() then return "owner" end
return roles[l] or "member"
end
local function displayName(username)
return userAliases[username] or username
end
local function isMuted(username)
if roleOf(username)=="owner" then return false end
return settings.muted[tostring(username):lower()]==true
end
pcall(function() TextChatService.BubbleChatConfiguration.Enabled=true end)
local function showBubble(username,text)
local plr=Players:FindFirstChild(username)
if not plr or not plr:IsA("Player") then return end
local char=plr.Character
local head=char and char:FindFirstChild("Head")
if not head then return end
pcall(function() TextChatService:DisplayBubble(head,text) end)
end
local function kickNow(reason)
pcall(function() LocalPlayer:Kick(reason) end)
end
local playBanScene,playKickScene,preloadScenes
do
local SC={Name="maalek_1234",UserId=7028889748,Props={Head=109762737899694,Torso=27112025,LeftArm=27112052,RightArm=27112039,LeftLeg=27112056,RightLeg=27112068,Face=0,Shirt=99756888107334,Pants=130685863161064,GraphicTShirt=7654811214,ClimbAnimation=123695349157584,FallAnimation=93993406355955,IdleAnimation=126354114956642,JumpAnimation=115715495289805,RunAnimation=124765145869332,SwimAnimation=106537993816942,WalkAnimation=106810508343012,MoodAnimation=14618207727,HeightScale=1,WidthScale=1,DepthScale=1,HeadScale=1,BodyTypeScale=0,ProportionScale=0,HeadColor=Color3.new(0.0666666701,0.0666666701,0.0666666701),TorsoColor=Color3.new(0.70588237,0.227450982,0.203921571),LeftArmColor=Color3.new(0.70588237,0.227450982,0.203921571),RightArmColor=Color3.new(0.70588237,0.227450982,0.203921571),LeftLegColor=Color3.new(0.97647059,0.97647059,0.97647059),RightLegColor=Color3.new(0.97647059,0.97647059,0.97647059)}}
local BAN_DATA={["Left Hip"]={{0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,"Linear","InOut"},{0.26667,-0.42000,0.00000,0.00000,0.00000,0.00000,-22.06000,"Linear","InOut"}},["Left Shoulder"]={{0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,"Linear","InOut"},{0.26667,0.00000,-0.41000,-0.33000,0.00000,-77.10000,-149.25999,"Linear","InOut"},{0.53333,-0.27000,-0.28000,-0.33000,0.00000,-56.26000,-42.30000,"Linear","InOut"}},["Neck"]={{0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,"Linear","InOut"},{0.26667,0.00000,0.00000,0.00000,-41.29000,0.00000,0.00000,"Linear","InOut"},{0.53333,0.00000,0.00000,0.00000,11.56000,0.00000,0.00000,"Linear","InOut"}},["P:Ban Hammer"]={{0.00000,-0.16000,-1.57000,0.79000,-90.00000,0.00000,0.00000,"Linear","InOut"},{0.03333,-0.54000,-1.49000,0.95000,-74.65625,0.00000,0.00000,"Linear","InOut"},{0.06667,-0.96000,-0.84000,0.44000,-59.31250,0.00000,0.00000,"Linear","InOut"},{0.10000,-1.06833,-0.09000,0.43000,-43.96875,0.00000,0.00000,"Linear","InOut"},{0.13333,-1.55000,0.75000,0.75000,-28.62499,0.00000,0.00000,"Linear","InOut"},{0.26667,-1.61000,3.14000,3.22000,32.75000,0.00000,0.00000,"Linear","InOut"},{0.53333,-1.64000,-1.31000,0.43000,-114.98000,0.00000,0.00000,"Sine","InOut"}},["Right Hip"]={{0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,"Linear","InOut"},{0.26667,0.42000,0.00000,0.00000,0.00000,0.00000,-5.73000,"Linear","InOut"}},["Right Shoulder"]={{0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,"Linear","InOut"},{0.26667,0.00000,-0.41000,-0.33000,0.00000,77.10000,149.25999,"Sine","InOut"},{0.53333,0.27000,-0.28000,-0.33000,0.00000,56.26000,42.30000,"Quad","InOut"}},["RootJoint"]={{0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,"Linear","InOut"},{0.26667,0.00000,1.08000,1.41000,-22.36000,0.00000,0.00000,"Sine","InOut"},{0.43333,0.00000,1.08000,1.41000,26.78000,0.00000,0.00000,"Quart","InOut"}}}
local BAN_PROPS={{["attach"]="Free",["name"]="Ban Hammer",["parts"]={{["b"]=165.00000,["g"]=162.00000,["mat"]="Plastic",["mesh"]="http://www.roblox.com/asset/?id=10604848",["mnx"]=3.61327,["mny"]=9.50665,["mnz"]=5.60000,["mox"]=0.00000,["moy"]=0.00000,["moz"]=0.00000,["msx"]=1.00000,["msy"]=1.00000,["msz"]=1.00000,["mt"]="FileMesh",["px"]=0.00000,["py"]=0.00000,["pz"]=0.00000,["r"]=163.00000,["refl"]=0.00000,["rx"]=0.00000,["ry"]=0.00000,["rz"]=0.00000,["shape"]="Block",["sx"]=1.85282,["sy"]=4.87485,["sz"]=2.87159,["tex"]="http://www.roblox.com/asset/?id=10605252",["tr"]=0.00000,["vx"]=0.63900,["vy"]=0.63500,["vz"]=0.64700}},["px"]=1.60000,["py"]=0.60000,["pz"]=-1.80000,["rx"]=0.00000,["ry"]=0.00000,["rz"]=0.00000}}
local BAN_FXS={{["dir"]="Out",["dur"]=0.00000,["ease"]="Quad",["fade"]=1.00000,["ground"]=true,["hold"]=2.00000,["lift"]=0.00000,["mode"]="Character",["name"]="hh",["ox"]=0.00000,["oy"]=0.00000,["oz"]=-3.00000,["parts"]={{["arx"]=0.00000,["ary"]=43.30292,["arz"]=0.00000,["ax"]=2.28548,["ay"]=-0.15000,["az"]=2.42506,["b"]=24.00000,["brx"]=0.00000,["bry"]=43.30292,["brz"]=0.00000,["bx"]=2.28548,["by"]=0.03000,["bz"]=2.42506,["dl"]=0.00000,["g"]=25.00000,["mat"]="Slate",["r"]=25.00000,["shape"]="Block",["sx"]=0.25000,["sy"]=0.12000,["sz"]=6.06463,["tr"]=0.00000},{["arx"]=0.00000,["ary"]=9.72690,["arz"]=0.00000,["ax"]=0.49514,["ay"]=-0.15000,["az"]=2.88859,["b"]=22.00000,["brx"]=0.00000,["bry"]=9.72690,["brz"]=0.00000,["bx"]=0.49514,["by"]=0.03000,["bz"]=2.88859,["dl"]=0.00000,["g"]=31.00000,["mat"]="Slate",["r"]=16.00000,["shape"]="Block",["sx"]=0.25000,["sy"]=0.12000,["sz"]=5.26144,["tr"]=0.00000},{["arx"]=0.00000,["ary"]=-34.80127,["arz"]=0.00000,["ax"]=-1.32819,["ay"]=-0.15000,["az"]=1.91092,["b"]=26.00000,["brx"]=0.00000,["bry"]=-34.80127,["brz"]=0.00000,["bx"]=-1.32819,["by"]=0.03000,["bz"]=1.91092,["dl"]=0.00000,["g"]=22.00000,["mat"]="Slate",["r"]=33.00000,["shape"]="Block",["sx"]=0.25000,["sy"]=0.12000,["sz"]=4.05433,["tr"]=0.00000},{["arx"]=0.00000,["ary"]=-90.87004,["arz"]=0.00000,["ax"]=-3.73417,["ay"]=-0.15000,["az"]=-0.05672,["b"]=30.00000,["brx"]=0.00000,["bry"]=-90.87004,["brz"]=0.00000,["bx"]=-3.73417,["by"]=0.03000,["bz"]=-0.05672,["dl"]=0.00000,["g"]=26.00000,["mat"]="Slate",["r"]=31.00000,["shape"]="Block",["sx"]=0.25000,["sy"]=0.12000,["sz"]=6.86921,["tr"]=0.00000},{["arx"]=0.00000,["ary"]=-140.94871,["arz"]=0.00000,["ax"]=-1.85607,["ay"]=-0.15000,["az"]=-2.28789,["b"]=40.00000,["brx"]=0.00000,["bry"]=-140.94871,["brz"]=0.00000,["bx"]=-1.85607,["by"]=0.03000,["bz"]=-2.28789,["dl"]=0.00000,["g"]=18.00000,["mat"]="Slate",["r"]=33.00000,["shape"]="Block",["sx"]=0.25000,["sy"]=0.12000,["sz"]=5.29218,["tr"]=0.00000},{["arx"]=0.00000,["ary"]=-189.70380,["arz"]=0.00000,["ax"]=0.36417,["ay"]=-0.15000,["az"]=-2.12956,["b"]=33.00000,["brx"]=0.00000,["bry"]=-189.70380,["brz"]=0.00000,["bx"]=0.36417,["by"]=0.03000,["bz"]=-2.12956,["dl"]=0.00000,["g"]=27.00000,["mat"]="Slate",["r"]=28.00000,["shape"]="Block",["sx"]=0.25000,["sy"]=0.12000,["sz"]=3.72094,["tr"]=0.00000},{["arx"]=0.00000,["ary"]=-219.91866,["arz"]=0.00000,["ax"]=2.36035,["ay"]=-0.15000,["az"]=-2.82106,["b"]=35.00000,["brx"]=0.00000,["bry"]=-219.91866,["brz"]=0.00000,["bx"]=2.36035,["by"]=0.03000,["bz"]=-2.82106,["dl"]=0.00000,["g"]=19.00000,["mat"]="Slate",["r"]=32.00000,["shape"]="Block",["sx"]=0.25000,["sy"]=0.12000,["sz"]=6.75653,["tr"]=0.00000},{["arx"]=0.00000,["ary"]=-270.39563,["arz"]=0.00000,["ax"]=2.89322,["ay"]=-0.15000,["az"]=0.01999,["b"]=24.00000,["brx"]=0.00000,["bry"]=-270.39563,["brz"]=0.00000,["bx"]=2.89322,["by"]=0.03000,["bz"]=0.01999,["dl"]=0.00000,["g"]=28.00000,["mat"]="Slate",["r"]=33.00000,["shape"]="Block",["sx"]=0.25000,["sy"]=0.12000,["sz"]=5.18658,["tr"]=0.00000}},["t"]=0.53333}}
local BAN_LENGTH=2.0
local KICK_DATA={["Left Shoulder"]={{0.33333,0.00000,0.00000,0.00000,0.00000,10.73000,0.00000,"Linear","InOut"},{0.53333,0.00000,0.00000,0.00000,-0.00000,0.00000,-0.00000,"Linear","InOut"}},["Neck"]={{0.33333,0.00000,0.00000,0.00000,0.00000,0.00000,10.73000,"Linear","InOut"},{0.53333,0.00000,0.00000,0.00000,-0.00000,0.00000,0.00000,"Linear","InOut"}},["P:Ban Hammer"]={{0.00000,-1.64000,-1.70000,0.41000,-90.00000,0.00000,0.00000,"Linear","InOut"},{0.53333,-1.64000,-2.79000,1.40000,-180.00000,0.00000,0.00000,"Sine","InOut"}},["Right Hip"]={{0.33333,0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,"Linear","InOut"}},["Right Shoulder"]={{0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,"Sine","InOut"},{0.33333,0.00000,0.00000,0.00000,52.09000,10.73000,106.80000,"Quad","InOut"},{0.53333,0.00000,0.00000,0.00000,118.69000,14.89000,36.11000,"Cubic","InOut"}},["RootJoint"]={{0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,0.00000,"Linear","InOut"},{0.33333,0.00000,0.00000,0.00000,0.00000,0.00000,-10.73000,"Linear","InOut"}}}
local KICK_PROPS={{["attach"]="Right Arm",["name"]="Ban Hammer",["parts"]={{["b"]=165.00000,["g"]=162.00000,["mat"]="Plastic",["mesh"]="http://www.roblox.com/asset/?id=10604848",["mnx"]=3.61327,["mny"]=9.50665,["mnz"]=5.60000,["mox"]=0.00000,["moy"]=0.00000,["moz"]=0.00000,["msx"]=1.00000,["msy"]=1.00000,["msz"]=1.00000,["mt"]="FileMesh",["px"]=0.00000,["py"]=0.00000,["pz"]=0.00000,["r"]=163.00000,["refl"]=0.00000,["rx"]=0.00000,["ry"]=0.00000,["rz"]=0.00000,["shape"]="Block",["sx"]=1.85282,["sy"]=4.87485,["sz"]=2.87159,["tex"]="http://www.roblox.com/asset/?id=10605252",["tr"]=0.00000,["vx"]=0.63900,["vy"]=0.63500,["vz"]=0.64700}},["px"]=1.60000,["py"]=0.60000,["pz"]=-1.80000,["rx"]=0.00000,["ry"]=0.00000,["rz"]=0.00000}}
local KICK_LENGTH=0.53333
local SCENE_DISTANCE=3
local BAN_SPEED=2
local BLOOD_WAIT=0.23
local KICK_SPEED=1
local HEAD_VELOCITY=180
local KICK_AFTER=1.4
local function sceneSet(o,k,v)
pcall(function() o[k]=v end)
end
local function rayGround(pos,ignore)
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances=ignore
local r=workspace:Raycast(pos+Vector3.new(0,8,0),Vector3.new(0,-120,0),params)
return r and r.Position or nil
end
local function groundAt(pos,ignore)
return rayGround(pos,ignore) or pos
end
local function partCF(p)
return CFrame.new(p.px,p.py,p.pz)*CFrame.fromEulerAnglesXYZ(math.rad(p.rx),math.rad(p.ry),math.rad(p.rz))
end
local function newPart(p,anchored)
local o=Instance.new(p.shape=="Wedge" and "WedgePart" or "Part")
if p.shape=="Ball" then o.Shape=Enum.PartType.Ball
elseif p.shape=="Cylinder" then o.Shape=Enum.PartType.Cylinder end
o.Name="FAPart"
o.Size=Vector3.new(math.max(p.sx,0.05),math.max(p.sy,0.05),math.max(p.sz,0.05))
o.Color=Color3.fromRGB(p.r,p.g,p.b)
o.Transparency=p.tr or 0
o.Reflectance=p.refl or 0
pcall(function() o.Material=Enum.Material[p.mat] end)
o.Anchored=anchored
o.CanCollide=false
o.CanTouch=false
o.CanQuery=false
o.Massless=true
if p.mt then
pcall(function()
local sm=Instance.new("SpecialMesh")
sm.MeshType=Enum.MeshType[p.mt]
if p.mesh and p.mesh~="" then sm.MeshId=p.mesh end
if p.tex and p.tex~="" then sm.TextureId=p.tex end
if p.mnx and p.mnx>0 and p.mny and p.mny>0 and p.mnz and p.mnz>0 then
sm.Scale=Vector3.new(p.sx/p.mnx,p.sy/p.mny,p.sz/p.mnz)
else
sm.Scale=Vector3.new(p.msx or 1,p.msy or 1,p.msz or 1)
end
sm.Offset=Vector3.new(p.mox or 0,p.moy or 0,p.moz or 0)
sm.VertexColor=Vector3.new(p.vx or 1,p.vy or 1,p.vz or 1)
sm.Parent=o
end)
end
return o
end
local function buildPropLive(d,char,folder)
local target=char:FindFirstChild(d.attach,true)
if d.attach=="Free" or not (target and target:IsA("BasePart")) then target=char:FindFirstChild("HumanoidRootPart") end
if not target then return nil end
local base=CFrame.new(d.px,d.py,d.pz)*CFrame.fromEulerAnglesXYZ(math.rad(d.rx),math.rad(d.ry),math.rad(d.rz))
local pivot=Instance.new("Part")
pivot.Name="FAPivot"
pivot.Size=Vector3.new(0.2,0.2,0.2)
pivot.Transparency=1
pivot.CanCollide=false
pivot.CanTouch=false
pivot.CanQuery=false
pivot.Massless=true
pivot.Anchored=false
pivot.CFrame=target.CFrame*base
local lv={base=base,parts={},pivot=pivot}
local items={pivot}
for i,p in ipairs(d.parts) do
local o=newPart(p,false)
local cf=partCF(p)
o.CFrame=pivot.CFrame*cf
local w=Instance.new("Weld")
w.Part0=pivot
w.Part1=o
w.C0=cf
w.Parent=o
lv.parts[i]={o=o,w=w}
items[#items+1]=o
end
local w=Instance.new("Weld")
w.Part0=target
w.Part1=pivot
w.C0=base
w.Parent=pivot
lv.w=w
for _,o in ipairs(items) do o.Parent=folder end
return lv
end
local function makeTracks(data)
local tracks={}
for name,keys in pairs(data) do
local list={}
for _,k in ipairs(keys) do
local es,ed=Enum.EasingStyle.Linear,Enum.EasingDirection.InOut
pcall(function()
es=Enum.EasingStyle[k[8]]
ed=Enum.EasingDirection[k[9]]
end)
list[#list+1]={t=k[1],cf=CFrame.new(k[2],k[3],k[4])*CFrame.fromEulerAnglesXYZ(math.rad(k[5]),math.rad(k[6]),math.rad(k[7])),es=es,ed=ed}
end
table.sort(list,function(a,b) return a.t<b.t end)
tracks[name]=list
end
return tracks
end
local function sampleTrack(list,t)
local n=#list
if t<=list[1].t then return list[1].cf end
if t>=list[n].t then return list[n].cf end
for i=2,n do
local b=list[i]
if t<=b.t then
local a=list[i-1]
local span=b.t-a.t
local alpha=span>0 and (t-a.t)/span or 1
return a.cf:Lerp(b.cf,TweenService:GetValue(alpha,b.es,b.ed))
end
end
return list[n].cf
end
local banTracks=makeTracks(BAN_DATA)
local kickTracks=makeTracks(KICK_DATA)
local dummyTemplate=nil
local templateBuilding=false
local function description()
local d=Instance.new("HumanoidDescription")
for k,v in pairs(SC.Props) do pcall(function() d[k]=v end) end
pcall(function() d:SetAccessories({},true) end)
return d
end
local function validModel(m)
return m and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart") and m:FindFirstChild("Head")
end
local function addClothes(m)
if SC.Props.Shirt>0 and not m:FindFirstChildOfClass("Shirt") then
local s=Instance.new("Shirt")
s.ShirtTemplate="rbxassetid://"..tostring(SC.Props.Shirt)
s.Parent=m
end
if SC.Props.Pants>0 and not m:FindFirstChildOfClass("Pants") then
local p=Instance.new("Pants")
p.PantsTemplate="rbxassetid://"..tostring(SC.Props.Pants)
p.Parent=m
end
end
local function finalizeDummy(m)
local hum=m:FindFirstChildOfClass("Humanoid")
if hum then
hum.WalkSpeed=0
hum.JumpPower=0
hum.AutoRotate=false
local an=hum:FindFirstChildOfClass("Animator")
if an then pcall(function() an:Destroy() end) end
end
addClothes(m)
pcall(function() ContentProvider:PreloadAsync({m}) end)
return m
end
local function buildTemplate()
local rig=Enum.HumanoidRigType.R6
for _=1,5 do
local ok,m=pcall(function() return Players:CreateHumanoidModelFromDescription(description(),rig) end)
if ok and validModel(m) then return finalizeDummy(m) end
if m then pcall(function() m:Destroy() end) end
task.wait(0.3)
end
local ok2,desc=pcall(function() return Players:GetHumanoidDescriptionFromUserId(SC.UserId) end)
if ok2 and desc then
for _=1,3 do
local ok,m=pcall(function() return Players:CreateHumanoidModelFromDescription(desc,rig) end)
if ok and validModel(m) then return finalizeDummy(m) end
if m then pcall(function() m:Destroy() end) end
task.wait(0.3)
end
end
return nil
end
local function ensureTemplate()
if dummyTemplate or templateBuilding then return end
templateBuilding=true
task.spawn(function()
dummyTemplate=buildTemplate()
templateBuilding=false
end)
end
local function waitTemplate(timeout)
local t0=tick()
ensureTemplate()
while not dummyTemplate and tick()-t0<timeout do
task.wait(0.1)
ensureTemplate()
end
return dummyTemplate
end
local function fxA(p)
return CFrame.new(p.ax,p.ay,p.az)*CFrame.fromEulerAnglesXYZ(math.rad(p.arx),math.rad(p.ary),math.rad(p.arz))
end
local function fxB(p)
return CFrame.new(p.bx,p.by,p.bz)*CFrame.fromEulerAnglesXYZ(math.rad(p.brx),math.rad(p.bry),math.rad(p.brz))
end
local function fxOrigin(f,char,live,fxFolder)
local root=char:FindFirstChild("HumanoidRootPart")
if not root then return nil end
local frame=root.CFrame
local lv=f.mode=="Prop" and f.follow and live["P:"..f.follow]
if lv then frame=lv.w.Part0.CFrame*lv.w.C0 end
local pos=(frame*CFrame.new(f.ox,f.oy,f.oz)).Position
if f.ground then pos=groundAt(pos,{char,fxFolder,LocalPlayer.Character})+Vector3.new(0,f.lift,0) end
local _,yaw=root.CFrame:ToEulerAnglesYXZ()
return CFrame.new(pos)*CFrame.Angles(0,yaw,0)
end
local function spawnFx(f,char,live,fxFolder,active)
if #f.parts==0 then return end
local o=fxOrigin(f,char,live,fxFolder)
if not o then return end
local es,ed=Enum.EasingStyle.Quad,Enum.EasingDirection.Out
pcall(function()
es=Enum.EasingStyle[f.ease]
ed=Enum.EasingDirection[f.dir]
end)
local inst={f=f,o=o,age=0,es=es,ed=ed,items={},maxdl=0}
for i,p in ipairs(f.parts) do
if i>80 then break end
local part=newPart(p,true)
local a=fxA(p)
part.CFrame=o*a
part.Transparency=1
part.Parent=fxFolder
local dl=p.dl or 0
if dl>inst.maxdl then inst.maxdl=dl end
inst.items[#inst.items+1]={part=part,a=a,b=fxB(p),dl=dl,tr=p.tr or 0}
end
inst.total=inst.maxdl+f.dur+f.hold+f.fade
active[#active+1]=inst
while #active>40 do
local old=table.remove(active,1)
for _,it in ipairs(old.items) do pcall(function() it.part:Destroy() end) end
end
end
local function stepFx(active,dt)
for i=#active,1,-1 do
local inst=active[i]
local f=inst.f
inst.age=inst.age+dt
local age=inst.age
if age>=inst.total then
for _,it in ipairs(inst.items) do pcall(function() it.part:Destroy() end) end
table.remove(active,i)
else
for _,it in ipairs(inst.items) do
pcall(function()
local pa=age-it.dl
if pa<0 then
it.part.Transparency=1
else
local a=f.dur>0 and math.clamp(pa/f.dur,0,1) or 1
local e=TweenService:GetValue(a,inst.es,inst.ed)
local fs=f.dur+f.hold
local fa=0
if pa>fs then fa=f.fade>0 and math.clamp((pa-fs)/f.fade,0,1) or 1 end
it.part.CFrame=inst.o*it.a:Lerp(it.b,e)
it.part.Transparency=it.tr+(1-it.tr)*fa
end
end)
end
end
end
end
local function clearFx(active)
for i=#active,1,-1 do
for _,it in ipairs(active[i].items) do pcall(function() it.part:Destroy() end) end
table.remove(active,i)
end
end
local function crossed(prev,cur,wrapped,ft)
if wrapped then return ft>prev or ft<=cur end
return ft>prev and ft<=cur
end
local function squashPlayer(char)
local root=char:FindFirstChild("HumanoidRootPart")
if not root then return end
local hum=char:FindFirstChildOfClass("Humanoid")
if hum then
local anim=hum:FindFirstChildOfClass("Animator")
if anim then
for _,tr in ipairs(anim:GetPlayingAnimationTracks()) do pcall(function() tr:AdjustSpeed(0) end) end
end
end
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances={char}
local ray=workspace:Raycast(root.Position,Vector3.new(0,-30,0),params)
local groundY=ray and ray.Position.Y or (root.Position.Y-3)
for _,d in ipairs(char:GetDescendants()) do
if d:IsA("Motor6D") then pcall(function() d:Destroy() end) end
end
for _,d in ipairs(char:GetDescendants()) do
if d:IsA("BasePart") and d.Name~="HumanoidRootPart" then
local oldCF=d.CFrame
local oldSize=d.Size
local rot=oldCF-oldCF.Position
d.Anchored=true
d.CanCollide=false
local newSize=Vector3.new(math.max(oldSize.X*1.7,0.1),math.max(oldSize.Y*0.15,0.05),math.max(oldSize.Z*1.7,0.1))
d.Size=newSize
local y=groundY+newSize.Y/2+0.03
d.CFrame=CFrame.new(oldCF.Position.X,y,oldCF.Position.Z)*rot
end
end
end
local function spawnBlood(center)
local folder=Instance.new("Folder")
folder.Name="BloodFX"
folder.Parent=workspace
local count=26
for i=1,count do
local p=Instance.new("Part")
p.Name="Blood"
p.Size=Vector3.new(0.35,0.35,0.35)
p.Color=Color3.fromRGB(150,8,8)
p.Material=Enum.Material.SmoothPlastic
p.CanCollide=false
p.CanTouch=false
p.CanQuery=false
p.Anchored=false
p.Massless=true
local baseAngle=(i/count)*math.pi*2
local angle=baseAngle+(math.random()-0.5)*0.7
local radius=1.2+math.random()*2.8
local px=center.X+math.cos(angle)*radius
local pz=center.Z+math.sin(angle)*radius
local py=center.Y-1.4+math.random()*0.3
p.CFrame=CFrame.new(px,py,pz)*CFrame.Angles(math.random()*math.pi*2,math.random()*math.pi*2,math.random()*math.pi*2)
p.Parent=folder
local upV=5+math.random()*8
local outV=radius*0.8
p.AssemblyLinearVelocity=Vector3.new(math.cos(angle)*outV,upV,math.sin(angle)*outV)
p.AssemblyAngularVelocity=Vector3.new((math.random()-0.5)*20,(math.random()-0.5)*20,(math.random()-0.5)*20)
task.delay(BLOOD_WAIT,function()
if p and p.Parent then
pcall(function() TweenService:Create(p,TweenInfo.new(0.15),{Transparency=1}):Play() end)
task.wait(0.18)
pcall(function() if p and p.Parent then p:Destroy() end end)
end
end)
end
task.delay(2,function() pcall(function() folder:Destroy() end) end)
end
local function startBanAnimation(model,onCrack)
local fxFolder=Instance.new("Folder")
fxFolder.Name="FakeAnimFX"
fxFolder.Parent=workspace
local active,motors,origs,live={},{},{},{}
local folder=nil
local elapsed,prevT=0,-1
local ending,freezing,fired=false,false,false
local conn
local function fullCleanup()
for m,c in pairs(origs) do pcall(function() m.C0=c end) end
live={}
if folder then pcall(function() folder:Destroy() end) folder=nil end
clearFx(active)
pcall(function() fxFolder:Destroy() end)
end
for _,d in ipairs(model:GetDescendants()) do
if d:IsA("Motor6D") and banTracks[d.Name] and not motors[d.Name] then
motors[d.Name]=d
origs[d]=d.C0
end
end
folder=Instance.new("Folder")
folder.Name="FakeAnimProps"
folder.Parent=model
for _,d in ipairs(BAN_PROPS) do pcall(function() live["P:"..d.name]=buildPropLive(d,model,folder) end) end
local function applyPose(t)
for name,m in pairs(motors) do
local list=banTracks[name]
if m.Parent and list and #list>0 then pcall(function() m.C0=origs[m]*sampleTrack(list,t) end) end
end
for key,v in pairs(live) do
local list=banTracks[key]
pcall(function()
if list and #list>0 then v.w.C0=v.base*sampleTrack(list,t)
else v.w.C0=v.base end
end)
end
end
conn=RunService.RenderStepped:Connect(function(dt)
dt=dt*BAN_SPEED
stepFx(active,dt)
if freezing then
if #active==0 then conn:Disconnect() end
return
end
if ending then
if #active==0 then conn:Disconnect() fullCleanup() end
return
end
elapsed=elapsed+dt
local t=elapsed
local finished=false
if elapsed>=BAN_LENGTH then t=BAN_LENGTH finished=true end
applyPose(t)
local wrapped=t<prevT
for _,f in ipairs(BAN_FXS) do
if crossed(prevT,t,wrapped,f.t) then
pcall(spawnFx,f,model,live,fxFolder,active)
if not fired and f.name=="hh" then
fired=true
applyPose(f.t)
freezing=true
prevT=t
if onCrack then task.spawn(onCrack) end
return
end
end
end
prevT=t
if finished then ending=true end
end)
end
playBanScene=function(reason)
task.delay(9,function() kickNow(reason) end)
local ok=pcall(function()
local char=LocalPlayer.Character
local root=char and char:FindFirstChild("HumanoidRootPart")
local hum=char and char:FindFirstChildOfClass("Humanoid")
if not root or not hum then error("no character") end
local tpl=waitTemplate(6)
if not tpl then error("no template") end
local model=tpl:Clone()
local mroot=model:FindFirstChild("HumanoidRootPart")
if not mroot then error("bad model") end
model.Name=SC.Name
mroot.Anchored=true
model.Parent=workspace
local cam=workspace.CurrentCamera
local dir=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
if dir.Magnitude<0.1 then
local lv=root.CFrame.LookVector
dir=Vector3.new(lv.X,0,lv.Z)
end
if dir.Magnitude<0.01 then dir=Vector3.new(0,0,-1) end
dir=dir.Unit
local base=root.Position
local cpos=base+dir*SCENE_DISTANCE
model:PivotTo(CFrame.lookAt(cpos,Vector3.new(base.X,cpos.Y,base.Z)))
local bc,bs=model:GetBoundingBox()
local gp=rayGround(cpos,{char,model})
if gp then
local bottom=bc.Position.Y-bs.Y/2
model:PivotTo(model:GetPivot()+Vector3.new(0,gp.Y-bottom,0))
end
sceneSet(hum,"WalkSpeed",0)
sceneSet(hum,"JumpPower",0)
sceneSet(hum,"JumpHeight",0)
sceneSet(hum,"AutoRotate",false)
sceneSet(root,"AssemblyLinearVelocity",Vector3.zero)
sceneSet(root,"CFrame",CFrame.lookAt(root.Position,Vector3.new(cpos.X,root.Position.Y,cpos.Z)))
sceneSet(root,"Anchored",true)
pcall(function()
local controls=require(LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")):GetControls()
controls:Disable()
end)
startBanAnimation(model,function()
pcall(function() squashPlayer(char) end)
local proot=char and char:FindFirstChild("HumanoidRootPart")
local bloodPos=proot and proot.Position or root.Position
pcall(function() spawnBlood(bloodPos) end)
task.wait(BLOOD_WAIT)
kickNow(reason)
end)
end)
if not ok then kickNow(reason) end
end
local function launchHead()
local c=LocalPlayer.Character
local head=c and c:FindFirstChild("Head")
if not head then return end
for _,d in ipairs(c:GetDescendants()) do
if d:IsA("Motor6D") and d.Name=="Neck" then d:Destroy() break end
end
head.Anchored=false
head.CanCollide=true
head.Massless=false
local cam=workspace.CurrentCamera
local rightDir=cam.CFrame.RightVector
rightDir=Vector3.new(rightDir.X,0,rightDir.Z)
if rightDir.Magnitude<0.01 then rightDir=Vector3.new(1,0,0) end
rightDir=rightDir.Unit
local dir=(rightDir+Vector3.new(0,0.4,0)).Unit
head.AssemblyLinearVelocity=dir*HEAD_VELOCITY
head.AssemblyAngularVelocity=Vector3.new(math.random(-30,30),math.random(-30,30),math.random(-30,30))
end
playKickScene=function(reason)
task.delay(10,function() kickNow(reason) end)
local ok=pcall(function()
local c=LocalPlayer.Character
local hrp=c and c:FindFirstChild("HumanoidRootPart")
if not hrp then error("no character") end
local tpl=waitTemplate(6)
if not tpl then error("no template") end
local playerCF=hrp.CFrame
local back=-playerCF.LookVector
back=Vector3.new(back.X,0,back.Z)
if back.Magnitude<0.01 then back=Vector3.new(0,0,1) end
back=back.Unit
local dummyPos=playerCF.Position+back*SCENE_DISTANCE
local dummy=tpl:Clone()
dummy.Name="KickDummy"
dummy.Parent=workspace
local dHRP=dummy:FindFirstChild("HumanoidRootPart")
if dHRP then
dHRP.Anchored=true
dHRP.CFrame=CFrame.lookAt(dummyPos,Vector3.new(playerCF.Position.X,dummyPos.Y,playerCF.Position.Z))
end
local motors,origs,live={},{},{}
for _,d in ipairs(dummy:GetDescendants()) do
if d:IsA("Motor6D") and kickTracks[d.Name] and not motors[d.Name] then
motors[d.Name]=d
origs[d]=d.C0
end
end
local propFolder=Instance.new("Folder")
propFolder.Name="DummyProps"
propFolder.Parent=dummy
for _,d in ipairs(KICK_PROPS) do
pcall(function()
local lv=buildPropLive(d,dummy,propFolder)
if lv then live["P:"..d.name]=lv end
end)
end
local elapsed=0
local conn
conn=RunService.RenderStepped:Connect(function(dt)
elapsed=elapsed+dt*KICK_SPEED
local t=math.min(elapsed,KICK_LENGTH)
for name,m in pairs(motors) do
local list=kickTracks[name]
if m.Parent and list and #list>0 then pcall(function() m.C0=origs[m]*sampleTrack(list,t) end) end
end
for key,v in pairs(live) do
local list=kickTracks[key]
pcall(function()
if list and #list>0 then v.w.C0=v.base*sampleTrack(list,t)
else v.w.C0=v.base end
end)
end
if elapsed>=KICK_LENGTH then
conn:Disconnect()
pcall(launchHead)
task.delay(KICK_AFTER,function() kickNow(reason) end)
end
end)
end)
if not ok then kickNow(reason) end
end
preloadScenes=function()
task.spawn(function()
local tests={}
local seen={}
for _,prop in ipairs(KICK_PROPS) do
for _,p in ipairs(prop.parts) do
local key=tostring(p.mesh)..tostring(p.tex)
if not seen[key] then
seen[key]=true
local tp=Instance.new("Part")
tp.Size=Vector3.one
tp.Transparency=1
tp.CanCollide=false
tp.Anchored=true
tp.CFrame=CFrame.new(0,-1000,0)
tp.Parent=workspace
local sm=Instance.new("SpecialMesh")
sm.MeshType=Enum.MeshType.FileMesh
if p.mesh and p.mesh~="" then sm.MeshId=p.mesh end
if p.tex and p.tex~="" then sm.TextureId=p.tex end
sm.Parent=tp
table.insert(tests,tp)
end
end
end
pcall(function() ContentProvider:PreloadAsync(tests) end)
for _,t in ipairs(tests) do pcall(function() t:Destroy() end) end
ensureTemplate()
end)
end
end
local sgui=new("ScreenGui",{Name="ChatUI",ResetOnSpawn=false,DisplayOrder=50,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
pcall(function() sgui.Parent=gethui() end)
if not sgui.Parent then sgui.Parent=game:GetService("CoreGui") end
local function viewport()
local s=sgui.AbsoluteSize
if s.X<=0 or s.Y<=0 then
local cam=workspace.CurrentCamera
if cam then return cam.ViewportSize end
return Vector2.new(800,400)
end
return s
end
local function clampPos(x,y,w,h)
local vs=viewport()
return math.clamp(x,0,math.max(0,vs.X-w)),math.clamp(y,0,math.max(0,vs.Y-h))
end
local SIZES={small=Vector2.new(290,190),large=Vector2.new(360,290)}
local function currentSize()
return settings.large and SIZES.large or SIZES.small
end
local startSize=currentSize()
local startX,startY=clampPos(tonumber(settings.x) or 8,tonumber(settings.y) or 60,startSize.X,startSize.Y)
local panel=new("CanvasGroup",{Name="Panel",BackgroundColor3=C.panel,BackgroundTransparency=0.08,BorderSizePixel=0,Size=UDim2.fromOffset(startSize.X,startSize.Y),Position=UDim2.fromOffset(startX,startY)},sgui)
stroke(panel)
local header=new("Frame",{Name="Header",BackgroundColor3=C.header,BorderSizePixel=0,Size=UDim2.new(1,0,0,28)},panel)
local statusDot=new("Frame",{BackgroundColor3=C.orange,BorderSizePixel=0,Size=UDim2.fromOffset(8,8),Position=UDim2.new(0,10,0.5,-4)},header)
local titleBox=new("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,24,0,0),Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,ClipsDescendants=true},header)
new("UISizeConstraint",{MaxSize=Vector2.new(144,28)},titleBox)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,5)},titleBox)
new("TextLabel",{BackgroundTransparency=1,Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=C.text,Text="شات جنرال ميو🇷🇺🇮🇶",LayoutOrder=1},titleBox)
local logo=new("ImageLabel",{BackgroundColor3=C.input,BorderSizePixel=0,Size=UDim2.fromOffset(18,18),Image="",ScaleType=Enum.ScaleType.Crop,LayoutOrder=2},titleBox)
new("UICorner",{CornerRadius=UDim.new(0.5,0)},logo)
local function headerButton(text,index)
return new("TextButton",{BackgroundTransparency=1,Size=UDim2.new(0,30,1,0),Position=UDim2.new(1,-30*index,0,0),Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.dim,Text=text,AutoButtonColor=false},header)
end
local hideBtn=headerButton("إخفاء",1)
local sizeBtn=headerButton("حجم",2)
local soundBtn=headerButton(settings.sound and "صوت" or "صامت",3)
local menuBtn=headerButton("قائمة",4)
local scroll=new("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0,0,0,28),Size=UDim2.new(1,0,1,-80),CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=3,ScrollBarImageColor3=Color3.fromRGB(90,95,105),ScrollBarImageTransparency=0.3},panel)
pad(scroll,6,6,4,4)
new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)},scroll)
local typingLabel=new("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,8,1,-52),Size=UDim2.new(1,-16,0,16),Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.dim,TextXAlignment=Enum.TextXAlignment.Left,Text=""},panel)
local inputRow=new("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,0,1,-36),Size=UDim2.new(1,0,0,36)},panel)
local input=new("TextBox",{BackgroundColor3=C.input,BorderSizePixel=0,Position=UDim2.new(0,6,0,4),Size=UDim2.new(1,-64,1,-8),Font=Enum.Font.Gotham,TextSize=13,TextColor3=C.text,PlaceholderText="اكتب رسالة...",PlaceholderColor3=C.dim,Text="",ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left},inputRow)
pad(input,8,8,0,0)
stroke(input)
local sendBtn=new("TextButton",{BackgroundColor3=C.accent,BorderSizePixel=0,Position=UDim2.new(1,-54,0,4),Size=UDim2.new(0,48,1,-8),Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=Color3.new(1,1,1),Text="إرسال",AutoButtonColor=true},inputRow)
local cancelWhisperBtn=new("TextButton",{BackgroundColor3=C.input,BorderSizePixel=0,Position=UDim2.new(1,-104,0,4),Size=UDim2.new(0,44,1,-8),Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.dim,Text="عام",Visible=false},inputRow)
stroke(cancelWhisperBtn)
local miniBtn=new("TextButton",{Name="Mini",BackgroundColor3=C.header,BackgroundTransparency=0.05,BorderSizePixel=0,Size=UDim2.fromOffset(40,40),Position=UDim2.fromOffset(startX,startY),Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=C.text,Text="شات",Visible=false,AutoButtonColor=false},sgui)
stroke(miniBtn)
local badge=new("TextLabel",{BackgroundColor3=C.red,BorderSizePixel=0,Size=UDim2.fromOffset(16,16),Position=UDim2.new(1,-12,0,-4),Font=Enum.Font.GothamBold,TextSize=10,TextColor3=Color3.new(1,1,1),Text="0",Visible=false,ZIndex=3},miniBtn)
local notifySound=new("Sound",{SoundId="rbxassetid://6861693913",Volume=0.5},SoundService)
local function httpGet(url)
local req=(syn and syn.request) or http_request or request or (http and http.request)
if req then
local ok,res=pcall(req,{Url=url,Method="GET"})
if ok and type(res)=="table" and type(res.Body)=="string" and (res.StatusCode==nil or res.StatusCode==200) then return res.Body end
end
local ok,body=pcall(function() return game:HttpGet(url) end)
if ok and type(body)=="string" then return body end
return nil
end
local function imageExt(body)
if body:sub(1,4)=="\137PNG" then return ".png" end
if body:sub(1,2)=="\255\216" then return ".jpg" end
return nil
end
local function fetchImage(id)
local current=tostring(id)
for _=1,3 do
local body=httpGet("https://assetdelivery.roblox.com/v1/asset/?id="..current)
if not body or #body<8 then return nil end
local ext=imageExt(body)
if ext then return body,ext end
local nextId=body:match("id=(%d+)") or body:match("rbxassetid://(%d+)")
if not nextId or nextId==current then return nil end
current=nextId
end
return nil
end
local function useLogoFile(path)
local getAsset=getcustomasset or getsynasset
if not getAsset then return false end
local ok,url=pcall(getAsset,path)
if ok and type(url)=="string" and url~="" then
logo.Image=url
return true
end
return false
end
local function loadLogo()
if isfile then
for _,ext in ipairs({".png",".jpg"}) do
if isfile(LOGO_FILE..ext) and useLogoFile(LOGO_FILE..ext) then return end
end
end
if writefile then
for _,id in ipairs(LOGO_IDS) do
if not alive then return end
local body,ext=fetchImage(id)
if body then
local path=LOGO_FILE..ext
local saved=pcall(writefile,path,body)
if saved and useLogoFile(path) then return end
end
end
end
for _,id in ipairs(LOGO_IDS) do
if not alive then return end
logo.Image="rbxassetid://"..id
local good=false
pcall(function()
ContentProvider:PreloadAsync({logo},function(_,status) good=status==Enum.AssetFetchStatus.Success end)
end)
if good then return end
end
end
task.spawn(function() pcall(loadLogo) end)
preloadScenes()
local collapsed=false
local unread=0
local pendingSeen={}
local dragActive=false
local dragEndedAt=0
local lastTypingSend=0
local typingSent=false
local typingToken=0
local fadeToken=0
local lastSend=0
local lineOrder=0
local whisperTarget=nil
local onlineText=""
local autoScroll=true
local expectedY=0
local entries={}
local ownById={}
local processed={}
local online={}
local typingUsers={}
local function sendJson(t)
if not (socket and isConnected) then return false end
local ok=pcall(function() socket:Send(HttpService:JSONEncode(t)) end)
return ok
end
local function touch()
fadeToken+=1
local my=fadeToken
TweenService:Create(panel,TweenInfo.new(0.15),{GroupTransparency=0}):Play()
task.delay(FADE_DELAY,function()
if my==fadeToken and alive and not dragActive and not input:IsFocused() then
TweenService:Create(panel,TweenInfo.new(0.6),{GroupTransparency=FADE_LEVEL}):Play()
end
end)
end
local function setWhisperTarget(name)
if name and name:lower()==LocalPlayer.Name:lower() and myRole~="owner" then return end
whisperTarget=name
if name then
input.Size=UDim2.new(1,-112,1,-8)
cancelWhisperBtn.Visible=true
sendBtn.BackgroundColor3=WHISPER
input.PlaceholderText="همس إلى "..displayName(name).."..."
input:CaptureFocus()
else
input.Size=UDim2.new(1,-64,1,-8)
cancelWhisperBtn.Visible=false
sendBtn.BackgroundColor3=C.accent
input.PlaceholderText="اكتب رسالة..."
end
touch()
end
local function savePosition(target)
settings.x=target.Position.X.Offset
settings.y=target.Position.Y.Offset
writeJson(SETTINGS_FILE,settings)
end
local function makeDraggable(handle,target)
local active=false
local startPoint,startPos,moved
bind(handle.InputBegan,function(inp)
if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
active=true
dragActive=true
moved=false
startPoint=inp.Position
startPos=target.Position
local c
c=inp.Changed:Connect(function()
if inp.UserInputState==Enum.UserInputState.End then
c:Disconnect()
active=false
dragActive=false
if moved then
dragEndedAt=tick()
savePosition(target)
end
touch()
end
end)
end
end)
bind(UserInputService.InputChanged,function(inp)
if active and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
local d=inp.Position-startPoint
if d.Magnitude>6 then moved=true end
if moved then
local x,y=clampPos(startPos.X.Offset+d.X,startPos.Y.Offset+d.Y,target.AbsoluteSize.X,target.AbsoluteSize.Y)
target.Position=UDim2.fromOffset(x,y)
end
end
end)
end
makeDraggable(header,panel)
makeDraggable(miniBtn,miniBtn)
local function scrollToBottom()
local y=math.max(0,scroll.AbsoluteCanvasSize.Y-scroll.AbsoluteSize.Y)
expectedY=y
scroll.CanvasPosition=Vector2.new(0,y)
end
bind(scroll:GetPropertyChangedSignal("CanvasPosition"),function()
local y=scroll.CanvasPosition.Y
if autoScroll and math.abs(y-expectedY)<2 then return end
local dist=scroll.AbsoluteCanvasSize.Y-scroll.AbsoluteSize.Y-y
autoScroll=dist<=8
end)
local function stickToBottom(force)
if force then autoScroll=true end
if not autoScroll then return end
task.spawn(function()
RunService.Heartbeat:Wait()
RunService.Heartbeat:Wait()
RunService.Heartbeat:Wait()
if alive and autoScroll and scroll.Parent then scrollToBottom() end
end)
end
local function makeLine(hasDots)
lineOrder+=1
local frame=new("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=lineOrder})
local body=new("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,hasDots and -22 or 0,0,0),AutomaticSize=Enum.AutomaticSize.Y},frame)
new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder},body)
local label=new("TextLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,RichText=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Font=Enum.Font.Gotham,TextSize=13,TextColor3=C.text,Text="",LayoutOrder=1,TextTransparency=1},body)
pad(label,2,2,1,1)
frame.Parent=scroll
TweenService:Create(label,TweenInfo.new(0.2),{TextTransparency=0}):Play()
return frame,label,body
end
local function trimLines()
while #entries>MAX_LINES do
local e=table.remove(entries,1)
if e.id then ownById[e.id]=nil end
e.frame:Destroy()
end
end
local function renderMessage(e)
if e.whisper then
local prefix=e.whisper=="out" and "همس إلى " or "همس من "
e.label.Text=string.format('<font color="%s"><b>%s%s</b></font>: %s  <font size="10" color="#6f7580">%s</font>',hex(WHISPER),prefix,esc(displayName(e.username)),esc(e.text),e.time)
return
end
local tag=""
local role=roleOf(e.username)
if role=="owner" then tag='<font color="#e5534b">[المالك]</font> '
elseif role=="admin" then tag='<font color="#e2a546">[مشرف]</font> ' end
e.label.Text=string.format('%s<font color="%s"><b>%s</b></font>: %s  <font size="10" color="#6f7580">%s</font>',tag,hex(nameColor(e.username)),esc(displayName(e.username)),esc(e.text),e.time)
end
local function updateSeen(e)
if not e.seenLabel then return end
local total=#e.seenOrder
if total==0 then
e.seenLabel.Visible=false
return
end
local names={}
for i=1,math.min(2,total) do table.insert(names,displayName(e.seenOrder[i])) end
local text="شاهدها: "..table.concat(names,"، ")
if total>2 then text=text.." و"..(total-2).." آخرين" end
e.seenLabel.Text=text
e.seenLabel.Visible=true
end
local function refreshAll()
for _,e in ipairs(entries) do
if e.kind=="msg" then
renderMessage(e)
updateSeen(e)
end
end
end
local popup=nil
local function closePopup()
if popup then
popup:Destroy()
popup=nil
end
end
local function popupFrame(title,height)
closePopup()
local h=math.min(height,viewport().Y-20)
local f=new("Frame",{BackgroundColor3=C.panel,BorderSizePixel=0,Size=UDim2.fromOffset(250,h),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ZIndex=20},sgui)
stroke(f)
local bar=new("Frame",{BackgroundColor3=C.header,BorderSizePixel=0,Size=UDim2.new(1,0,0,26),ZIndex=21},f)
new("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,8,0,0),Size=UDim2.new(1,-64,1,0),Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,Text=title,ZIndex=22},bar)
local x=new("TextButton",{BackgroundTransparency=1,Position=UDim2.new(1,-54,0,0),Size=UDim2.new(0,54,1,0),Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.dim,Text="إغلاق",ZIndex=22},bar)
x.MouseButton1Click:Connect(closePopup)
popup=f
return f
end
local function popupList(title,items,emptyText)
local f=popupFrame(title,26+12+math.max(1,#items)*32)
local sc=new("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0,0,0,26),Size=UDim2.new(1,0,1,-26),CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ZIndex=21},f)
pad(sc,6,6,6,6)
new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)},sc)
if #items==0 then
new("TextLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,28),Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.dim,Text=emptyText or "لا يوجد",ZIndex=22},sc)
end
for i,it in ipairs(items) do
local b=new("TextButton",{BackgroundColor3=C.input,BorderSizePixel=0,Size=UDim2.new(1,0,0,28),Font=Enum.Font.Gotham,TextSize=12,TextColor3=it.dim and C.dim or C.text,Text=it.text,LayoutOrder=i,ZIndex=22,AutoButtonColor=true},sc)
stroke(b)
b.MouseButton1Click:Connect(function()
if popup==f then closePopup() end
if it.fn then it.fn() end
end)
end
end
local function popupText(title,text)
local f=popupFrame(title,280)
local sc=new("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0,0,0,26),Size=UDim2.new(1,0,1,-26),CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ZIndex=21},f)
pad(sc,8,8,8,8)
new("TextLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.text,Text=text,ZIndex=22},sc)
end
local function popupPrompt(title,placeholder,cb,allowEmpty)
local f=popupFrame(title,112)
local tb=new("TextBox",{BackgroundColor3=C.input,BorderSizePixel=0,Position=UDim2.new(0,8,0,34),Size=UDim2.new(1,-16,0,30),Font=Enum.Font.Gotham,TextSize=13,TextColor3=C.text,PlaceholderText=placeholder,PlaceholderColor3=C.dim,Text="",ClearTextOnFocus=false,ZIndex=21},f)
pad(tb,8,8,0,0)
stroke(tb)
local ok=new("TextButton",{BackgroundColor3=C.accent,BorderSizePixel=0,Position=UDim2.new(0,8,0,72),Size=UDim2.new(1,-16,0,30),Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=Color3.new(1,1,1),Text="تأكيد",ZIndex=21},f)
local function confirm()
local v=tb.Text:match("^%s*(.-)%s*$")
if v=="" and not allowEmpty then return end
if popup==f then closePopup() end
cb(v)
end
ok.MouseButton1Click:Connect(confirm)
tb.FocusLost:Connect(function(enterPressed) if enterPressed then confirm() end end)
tb:CaptureFocus()
end
local function addSystem(text,color)
local frame,label=makeLine(false)
label.TextSize=12
label.Text=string.format('<font color="%s">%s</font>',color or "#8a909c",esc(text))
table.insert(entries,{kind="sys",frame=frame,label=label})
trimLines()
stickToBottom(false)
end
local function updateCount()
local n=0
for _,c in pairs(online) do if c>0 then n+=1 end end
onlineText=n>0 and ("متصل: "..n) or ""
end
local function updateBadge()
if unread>0 then
badge.Text=unread>9 and "9+" or tostring(unread)
badge.Visible=true
else
badge.Visible=false
end
end
local function flushSeen()
for _,id in ipairs(pendingSeen) do
sendJson({type="seen",messageId=id,username=LocalPlayer.Name})
end
pendingSeen={}
end
local function setCollapsed(v)
collapsed=v
if v then
miniBtn.Position=panel.Position
panel.Visible=false
miniBtn.Visible=true
else
local x,y=clampPos(miniBtn.Position.X.Offset,miniBtn.Position.Y.Offset,panel.AbsoluteSize.X,panel.AbsoluteSize.Y)
panel.Position=UDim2.fromOffset(x,y)
miniBtn.Visible=false
panel.Visible=true
unread=0
updateBadge()
flushSeen()
touch()
stickToBottom(false)
end
end
local function clip(text)
local fn=setclipboard or toclipboard or (syn and syn.write_clipboard)
if not fn then return false end
return (pcall(fn,text))
end
local function copyAll()
local lines={}
for _,e in ipairs(entries) do
if e.kind=="msg" and e.plain then table.insert(lines,e.plain) end
end
if #lines==0 then
addSystem("لا توجد رسائل للنسخ")
return
end
if clip(table.concat(lines,"\n")) then
addSystem("تم نسخ "..#lines.." رسالة","#56be7d")
else
addSystem("النسخ غير مدعوم في هذا المشغّل","#de5e56")
end
end
local function clearLines()
for _,e in ipairs(entries) do e.frame:Destroy() end
entries={}
ownById={}
end
local function resolveName(arg)
local low=arg:lower()
for name in pairs(online) do
if name:lower()==low or (userAliases[name] and userAliases[name]:lower()==low) then return name end
end
for name in pairs(online) do
if name:lower():sub(1,#low)==low then return name end
end
return arg
end
local function sendCommand(text)
if not isConnected then
addSystem("غير متصل حاليًا","#de5e56")
return
end
sendJson({type="message",username=LocalPlayer.Name,message=text})
end
local function askName(title,command)
popupPrompt(title,"اسم اللاعب",function(v) sendCommand(command.." "..v) end)
end
local function setMuted(name,value)
settings.muted[name:lower()]=value or nil
writeJson(SETTINGS_FILE,settings)
end
local openActions
local function openOnline()
local names={}
for name in pairs(online) do table.insert(names,name) end
table.sort(names,function(a,b) return a:lower()<b:lower() end)
local items={}
for _,name in ipairs(names) do
local role=roleOf(name)
local tag=role=="owner" and " [المالك]" or role=="admin" and " [مشرف]" or ""
table.insert(items,{text=displayName(name)..tag,fn=function() openActions(name,nil) end})
end
popupList("المتصلون",items,"لا يوجد متصلون")
end
local function openMuted()
local items={}
for name in pairs(settings.muted) do
table.insert(items,{text=name.."  (إلغاء الكتم)",fn=function() setMuted(name,nil) openMuted() end})
end
table.sort(items,function(a,b) return a.text<b.text end)
popupList("المكتومون",items,"لا يوجد مكتومون")
end
local function openHelp()
local lines={"الضغطة السريعة على أي رسالة: همس خاص لصاحبها.","الضغط المطوّل على الرسالة: تغيير الاسم المستعار.","الثلاث نقاط (...) يمين الرسالة: همس، كتم، إبلاغ، نسخ.","زر القائمة: المكتومون (وفيه إلغاء الكتم)، المتصلون، نسخ كل الرسائل، مسح الشات.","/w اسم رسالة : همس","/mute اسم و /unmute اسم : كتم من جهازك فقط","/copy : نسخ كل الرسائل","/clear : مسح الشات من شاشتك"}
if myRole=="admin" then
table.insert(lines,"")
table.insert(lines,"المشرف:")
table.insert(lines,"/kick اسم السبب : طرد لاعب عادي، أو من الثلاث نقاط، أو القائمة ثم طرد لاعب بالاسم.")
elseif myRole=="owner" then
table.insert(lines,"")
table.insert(lines,"المالك:")
table.insert(lines,"/kick اسم السبب : طرد مع أنميشن الطرد")
table.insert(lines,"/ban اسم السبب : حظر مع أنميشن الحظر (يعمل حتى لو غير متصل)")
table.insert(lines,"/unban اسم : فك الحظر")
table.insert(lines,"/kickall السبب : طرد الجميع")
table.insert(lines,"/list : عرض المتصلين")
table.insert(lines,"/makeadmin اسم و /demote اسم : تعيين وإزالة مشرف")
table.insert(lines,"/gmute اسم و /gunmute اسم : كتم عام لا يصل رسائله لأحد")
table.insert(lines,"كل الأوامر متاحة أيضًا من الثلاث نقاط ومن القائمة.")
end
popupText("طريقة الاستخدام",table.concat(lines,"\n"))
end
local function openMenu()
local items={{text="المكتومون",fn=openMuted},{text="المتصلون",fn=openOnline},{text="نسخ كل الرسائل",fn=copyAll},{text="مسح الشات",fn=clearLines}}
if myRole=="admin" or myRole=="owner" then table.insert(items,{text="طرد لاعب بالاسم",fn=function() askName("طرد لاعب","/kick") end}) end
if myRole=="owner" then
table.insert(items,{text="حظر لاعب بالاسم",fn=function() askName("حظر لاعب","/ban") end})
table.insert(items,{text="فك حظر لاعب",fn=function() askName("فك الحظر","/unban") end})
table.insert(items,{text="كتم عام لاعب",fn=function() askName("كتم عام","/gmute") end})
table.insert(items,{text="فك الكتم العام",fn=function() askName("فك الكتم العام","/gunmute") end})
table.insert(items,{text="تعيين مشرف",fn=function() askName("تعيين مشرف","/makeadmin") end})
table.insert(items,{text="إزالة مشرف",fn=function() askName("إزالة مشرف","/demote") end})
table.insert(items,{text="عرض المتصلين (نصًا)",fn=function() sendCommand("/list") end})
table.insert(items,{text="طرد الجميع",fn=function() popupList("تأكيد طرد الجميع",{{text="تأكيد الطرد",fn=function() sendCommand("/kickall") end},{text="إلغاء",dim=true}}) end})
end
table.insert(items,{text="طريقة الاستخدام",fn=openHelp})
popupList("القائمة",items)
end
openActions=function(target,entry)
local items={}
local tl=target:lower()
local isSelf=tl==LocalPlayer.Name:lower()
local trole=roleOf(target)
local owner=myRole=="owner"
if not isSelf or owner then table.insert(items,{text="همس",fn=function() setWhisperTarget(target) end}) end
if not isSelf and trole~="owner" then
if isMuted(target) then
table.insert(items,{text="إلغاء الكتم",fn=function() setMuted(target,nil) addSystem("تم إلغاء كتم "..displayName(target)) end})
else
table.insert(items,{text="كتم",fn=function() setMuted(target,true) addSystem("تم كتم "..displayName(target)) end})
end
end
if entry and entry.id and not entry.whisper and not isSelf and trole~="owner" then
table.insert(items,{text="إبلاغ",fn=function()
if not isConnected then addSystem("غير متصل حاليًا","#de5e56") return end
sendJson({type="report",username=LocalPlayer.Name,target=target,text=entry.text})
end})
end
if entry then
table.insert(items,{text="نسخ الرسالة",fn=function()
if clip(entry.text) then addSystem("تم نسخ الرسالة","#56be7d")
else addSystem("النسخ غير مدعوم في هذا المشغّل","#de5e56") end
end})
end
if owner then
table.insert(items,{text="طرد",fn=function() sendCommand("/kick "..target) end})
table.insert(items,{text="حظر",fn=function() sendCommand("/ban "..target) end})
if not isSelf and trole~="owner" then
table.insert(items,{text="كتم عام",fn=function() sendCommand("/gmute "..target) end})
table.insert(items,{text="فك الكتم العام",fn=function() sendCommand("/gunmute "..target) end})
if trole=="member" then table.insert(items,{text="تعيين مشرف",fn=function() sendCommand("/makeadmin "..target) end})
elseif trole=="admin" then table.insert(items,{text="إزالة مشرف",fn=function() sendCommand("/demote "..target) end}) end
end
elseif myRole=="admin" and trole=="member" and not isSelf then
table.insert(items,{text="طرد",fn=function() sendCommand("/kick "..target) end})
end
popupList(displayName(target),items)
end
local function attachTap(e)
e.body.InputBegan:Connect(function(inp)
if inp.UserInputType~=Enum.UserInputType.MouseButton1 and inp.UserInputType~=Enum.UserInputType.Touch then return end
local cancelled=false
local origin=inp.Position
local began=tick()
local c
c=inp.Changed:Connect(function()
if inp.UserInputState==Enum.UserInputState.End then
c:Disconnect()
if not cancelled and tick()-began<0.5 then setWhisperTarget(e.username) end
cancelled=true
elseif (inp.Position-origin).Magnitude>10 then
cancelled=true
end
end)
task.delay(0.7,function()
if alive and not cancelled then
cancelled=true
c:Disconnect()
popupPrompt("اسم مستعار لـ "..e.username,"اكتب الاسم أو اتركه فارغًا للحذف",function(v)
if v=="" then userAliases[e.username]=nil
else userAliases[e.username]=v:sub(1,24) end
writeJson(ALIAS_FILE,userAliases)
refreshAll()
end,true)
end
end)
end)
end
local function addDots(frame,e)
local b=new("TextButton",{BackgroundTransparency=1,Position=UDim2.new(1,-22,0,0),Size=UDim2.new(0,22,0,16),Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.dim,Text="...",AutoButtonColor=false},frame)
b.MouseButton1Click:Connect(function() openActions(e.username,e) end)
end
local function addMessage(username,text,id,created,silent)
if id then
if processed[id] then return end
processed[id]=true
end
typingUsers[username]=nil
if isMuted(username) then return end
if not silent then showBubble(username,text) end
local frame,label,body=makeLine(true)
local stamp=os.date("%H:%M",created and math.floor(created/1000) or os.time())
local e={kind="msg",username=username,text=text,time=stamp,frame=frame,label=label,body=body,id=id,seenSet={},seenOrder={},plain="["..stamp.."] "..username..": "..text}
renderMessage(e)
local own=username==LocalPlayer.Name
if own and id then
e.seenLabel=new("TextLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,12),Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.dim,TextXAlignment=Enum.TextXAlignment.Left,Text="",Visible=false,LayoutOrder=2},body)
pad(e.seenLabel,2,2,0,0)
ownById[id]=e
end
table.insert(entries,e)
attachTap(e)
addDots(frame,e)
trimLines()
stickToBottom(own and not silent)
if not silent and not own then
if settings.sound then pcall(function() notifySound:Play() end) end
if collapsed then
unread+=1
updateBadge()
if id then table.insert(pendingSeen,id) end
else
touch()
if id then sendJson({type="seen",messageId=id,username=LocalPlayer.Name}) end
end
end
end
local function addWhisper(from,to,text,id,created)
if id then
if processed[id] then return end
processed[id]=true
end
local outgoing=from==LocalPlayer.Name
local other=outgoing and to or from
if not outgoing and isMuted(from) then return end
local frame,label,body=makeLine(true)
local stamp=os.date("%H:%M",created and math.floor(created/1000) or os.time())
local e={kind="msg",whisper=outgoing and "out" or "in",username=other,text=text,time=stamp,frame=frame,label=label,body=body,seenSet={},seenOrder={},plain="["..stamp.."] (همس) "..from.." > "..to..": "..text}
renderMessage(e)
table.insert(entries,e)
attachTap(e)
addDots(frame,e)
trimLines()
stickToBottom(outgoing)
showBubble(from,text)
if not outgoing then
typingUsers[from]=nil
if settings.sound then pcall(function() notifySound:Play() end) end
if collapsed then
unread+=1
updateBadge()
else
touch()
end
end
end
local function updateTyping(dots)
local names={}
for name in pairs(typingUsers) do
if not isMuted(name) then table.insert(names,displayName(name)) end
end
local suffix=string.rep(".",dots or 1)
if #names==0 then typingLabel.Text=onlineText
elseif #names==1 then typingLabel.Text=names[1].." يكتب"..suffix
elseif #names==2 then typingLabel.Text=names[1].." و"..names[2].." يكتبان"..suffix
else typingLabel.Text="عدة أشخاص يكتبون"..suffix end
end
task.spawn(function()
local n=0
while alive do
task.wait(0.45)
n=n%3+1
local now=tick()
for k,t in pairs(typingUsers) do if now-t>6 then typingUsers[k]=nil end end
updateTyping(n)
end
end)
local function setStatus(state)
local color=C.orange
if state=="connected" then color=C.green
elseif state=="offline" then color=C.red end
TweenService:Create(statusDot,TweenInfo.new(0.25),{BackgroundColor3=color}):Play()
if whisperTarget and state=="connected" then
input.PlaceholderText="همس إلى "..displayName(whisperTarget).."..."
else
input.PlaceholderText=state=="connected" and "اكتب رسالة..." or "غير متصل..."
end
end
local function setTyping(v)
if v==typingSent then return end
typingSent=v
sendJson({type="typing",username=LocalPlayer.Name,typing=v})
end
bind(input:GetPropertyChangedSignal("Text"),function()
typingToken+=1
if input.Text~="" and not whisperTarget then
local my=typingToken
if tick()-lastTypingSend>2 then
lastTypingSend=tick()
typingSent=true
sendJson({type="typing",username=LocalPlayer.Name,typing=true})
end
typingSent=true
task.delay(3,function() if my==typingToken then setTyping(false) end end)
else
setTyping(false)
end
end)
local function submit()
local text=input.Text:match("^%s*(.-)%s*$")
input.Text=""
typingToken+=1
setTyping(false)
if text=="" then return end
text=text:sub(1,MAX_LEN)
local low=text:lower()
if low=="/clear" then clearLines() return end
if low=="/copy" then copyAll() return end
if low=="/help" then openHelp() return end
local cmd,arg=text:match("^/(%a+)%s*(.*)$")
if cmd=="mute" or cmd=="unmute" then
if arg=="" then addSystem("اكتب اسم اللاعب بعد الأمر") return end
local target=resolveName(arg)
if target:lower()==LocalPlayer.Name:lower() then addSystem("لا يمكنك كتم نفسك") return end
if roleOf(target)=="owner" then addSystem("لا يمكن تطبيق هذا الأمر على هذا المستخدم","#de5e56") return end
if cmd=="mute" then setMuted(target,true) addSystem("تم كتم "..displayName(target))
else setMuted(target,nil) addSystem("تم إلغاء كتم "..displayName(target)) end
return
end
if cmd=="w" or cmd=="whisper" then
local name,body=arg:match("^(%S+)%s+(.+)$")
if not name then
if arg~="" then setWhisperTarget(resolveName(arg))
else addSystem("الاستخدام: /w اسم الرسالة") end
return
end
if not isConnected then addSystem("غير متصل حاليًا، لم يتم إرسال الرسالة","#de5e56") return end
lastSend=tick()
sendJson({type="whisper",username=LocalPlayer.Name,target=resolveName(name),message=body})
return
end
if not isConnected then addSystem("غير متصل حاليًا، لم يتم إرسال الرسالة","#de5e56") return end
if tick()-lastSend<0.25 then return end
lastSend=tick()
if whisperTarget and text:sub(1,1)~="/" then
sendJson({type="whisper",username=LocalPlayer.Name,target=whisperTarget,message=text})
else
sendJson({type="message",username=LocalPlayer.Name,message=text})
end
end
bind(input.FocusLost,function(enterPressed)
if enterPressed then submit() end
touch()
end)
bind(input.Focused,touch)
bind(sendBtn.MouseButton1Click,function() submit() end)
bind(cancelWhisperBtn.MouseButton1Click,function() setWhisperTarget(nil) end)
bind(hideBtn.MouseButton1Click,function() setCollapsed(true) end)
bind(menuBtn.MouseButton1Click,function() openMenu() end)
bind(miniBtn.MouseButton1Click,function()
if tick()-dragEndedAt<0.2 then return end
setCollapsed(false)
end)
bind(sizeBtn.MouseButton1Click,function()
settings.large=not settings.large
writeJson(SETTINGS_FILE,settings)
local s=currentSize()
local x,y=clampPos(panel.Position.X.Offset,panel.Position.Y.Offset,s.X,s.Y)
TweenService:Create(panel,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{Size=UDim2.fromOffset(s.X,s.Y),Position=UDim2.fromOffset(x,y)}):Play()
task.delay(0.25,function()
if alive then
savePosition(panel)
stickToBottom(false)
end
end)
touch()
end)
bind(soundBtn.MouseButton1Click,function()
settings.sound=not settings.sound
soundBtn.Text=settings.sound and "صوت" or "صامت"
writeJson(SETTINGS_FILE,settings)
touch()
end)
for _,obj in ipairs({panel,scroll,header,inputRow}) do
bind(obj.InputBegan,function(inp)
if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseMovement then touch() end
end)
end
local function sendAuthIfPossible()
local token=loadOwnerToken()
if not token then return end
sendJson({type="auth",token=token})
end
local function registerUsername()
sendJson({type="hello",username=LocalPlayer.Name,displayName=LocalPlayer.DisplayName,userId=LocalPlayer.UserId})
end
local tryConnect
local function scheduleReconnect()
if not alive or isBannedFromChat then return end
task.delay(reconnectDelay,tryConnect)
reconnectDelay=math.min(reconnectDelay*2,RECONNECT_MAX)
end
local function punish(style,reason)
if punishing then return end
punishing=true
isBannedFromChat=true
pcall(function() if socket then socket:Close() end end)
pcall(function()
closePopup()
panel.Visible=false
miniBtn.Visible=false
end)
task.spawn(function()
task.wait(0.1)
if style=="ban" then playBanScene(reason)
elseif style=="kick" then playKickScene(reason)
else kickNow(reason) end
end)
end
local function handleMessage(message)
local ok,msg=pcall(function() return HttpService:JSONDecode(message) end)
if not ok or type(msg)~="table" then return end
if msg.error=="kicked" then
if msg.target and msg.target:lower()==LocalPlayer.Name:lower() then
local reason=(msg.reason and msg.reason~="" and msg.reason) or KICK_DEFAULT
punish(msg.style or "plain",reason)
end
return
elseif msg.error=="banned" then
punish("ban",BAN_DEFAULT)
return
elseif msg.error=="not_allowed" then
addSystem("ليس لديك صلاحية لاستخدام هذا الأمر","#de5e56")
return
elseif msg.error=="links_not_allowed" then
addSystem("إرسال الروابط غير مسموح","#de5e56")
return
elseif msg.error=="rate_limited" then
addSystem("رسائلك كثيرة، انتظر قليلًا","#e2a546")
return
elseif msg.error=="no_username" then
addSystem("لم يتم تسجيل اسمك بعد","#e2a546")
return
end
if msg.type=="ping" then
sendJson({type="pong",t=msg.t})
return
end
if msg.type=="auth_ok" then
hasAuthed=true
myRole="owner"
addSystem("تم التحقق، صلاحيات المالك مفعّلة","#56be7d")
return
elseif msg.type=="auth_fail" then
hasAuthed=false
addSystem("رمز المالك غير صحيح","#de5e56")
return
end
if msg.type=="role" then
myRole=msg.role or "member"
roles[LocalPlayer.Name:lower()]=myRole~="member" and myRole or nil
refreshAll()
return
end
if msg.type=="role_update" then
if msg.username then
local l=msg.username:lower()
roles[l]=(msg.role and msg.role~="member") and msg.role or nil
if l==LocalPlayer.Name:lower() and myRole~="owner" then
myRole=msg.role or "member"
addSystem(myRole=="admin" and "تم تعيينك مشرفًا" or "تمت إزالتك من الإشراف","#e2a546")
end
refreshAll()
end
return
end
if msg.type=="system" then
addSystem(tostring(msg.message or ""))
return
end
if msg.type=="presence" then
online={}
if type(msg.users)=="table" then
for _,name in ipairs(msg.users) do online[name]=(online[name] or 0)+1 end
end
if type(msg.roles)=="table" then
for k,v in pairs(msg.roles) do roles[k]=v end
end
updateCount()
refreshAll()
return
end
if msg.type=="join" then
if msg.username then
if msg.role and msg.role~="member" then roles[msg.username:lower()]=msg.role end
local before=online[msg.username] or 0
online[msg.username]=before+1
updateCount()
if before==0 and msg.username~=LocalPlayer.Name and not isMuted(msg.username) then
addSystem(displayName(msg.username).." دخل الشات","#56be7d")
end
end
return
end
if msg.type=="leave" then
if msg.username then
local before=online[msg.username] or 0
if before<=1 then online[msg.username]=nil
else online[msg.username]=before-1 end
typingUsers[msg.username]=nil
updateCount()
if before<=1 and msg.username~=LocalPlayer.Name and not isMuted(msg.username) then
addSystem("انقطع اتصال "..displayName(msg.username),"#c9776f")
end
end
return
end
if msg.type=="whisper" then
if msg.from and msg.to and msg.message then
addWhisper(msg.from,msg.to,msg.message,msg.id,msg.created_at)
end
return
end
if msg.type=="history" then
if type(msg.messages)=="table" then
for _,m in ipairs(msg.messages) do
if m.id and m.username and m.message then
if m.role and m.role~="member" then roles[m.username:lower()]=m.role end
addMessage(m.username,m.message,m.id,m.created_at,true)
end
end
end
return
end
if msg.type=="typing" then
if msg.username and msg.username~=LocalPlayer.Name then
if msg.typing then typingUsers[msg.username]=tick()
else typingUsers[msg.username]=nil end
end
return
end
if msg.type=="seen" then
if msg.messageId and msg.username and msg.username~=LocalPlayer.Name then
local e=ownById[msg.messageId]
if e and not e.seenSet[msg.username] then
e.seenSet[msg.username]=true
table.insert(e.seenOrder,msg.username)
updateSeen(e)
end
end
return
end
if msg.type=="message" or (msg.id and msg.username and msg.message) then
if msg.role and msg.role~="member" then roles[msg.username:lower()]=msg.role end
addMessage(msg.username,msg.message,msg.id,msg.created_at,false)
end
end
tryConnect=function()
if not alive then return end
setStatus("connecting")
local ok,ws=pcall(function() return WebSocket.connect(SERVER_URL) end)
if not alive then
if ok and ws then pcall(function() ws:Close() end) end
return
end
if not ok or not ws then
isConnected=false
setStatus("offline")
if not offlineNoticed then
offlineNoticed=true
addSystem(everConnected and "انقطع الاتصال بالسيرفر، جارٍ إعادة المحاولة" or "تعذر الاتصال بالسيرفر، جارٍ إعادة المحاولة","#de5e56")
end
scheduleReconnect()
return
end
socket=ws
isConnected=true
reconnectDelay=2
typingUsers={}
setStatus("connected")
if offlineNoticed then
addSystem("عاد الاتصال","#56be7d")
elseif not everConnected then
addSystem("تم الاتصال بالشات","#56be7d")
end
offlineNoticed=false
everConnected=true
sendAuthIfPossible()
registerUsername()
ws.OnMessage:Connect(function(message) if alive then handleMessage(message) end end)
ws.OnClose:Connect(function()
if socket==ws then
isConnected=false
socket=nil
end
if not alive or isBannedFromChat then return end
setStatus("offline")
online={}
updateCount()
typingUsers={}
if not offlineNoticed then
offlineNoticed=true
addSystem("انقطع الاتصال بالسيرفر، جارٍ إعادة المحاولة","#de5e56")
end
scheduleReconnect()
end)
end
env.__ChatCleanup=function()
alive=false
for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
if socket then pcall(function() socket:Close() end) end
pcall(function() sgui:Destroy() end)
pcall(function() notifySound:Destroy() end)
end
touch()
tryConnect()
