-- 물약 가게판 월드 정리(Edit 모드에서 실행, 다시 실행해도 같은 결과)
-- 1) VARCO 물약 가게 모델을 크기 맞춰 ServerStorage.Props 로 모은다(옛 떡볶이 소품은 뺀다)
-- 2) 리깅한 임프를 알바로, 리깅한 몬스터 셋과 슬라임을 손님 틀로 만든다(가게 주인 NPC 는 없다)
-- 3) 거리를 판타지 마을 길로 바꾸고 큰 버섯을 심는다
local SS = game:GetService("ServerStorage")
local lib = SS:WaitForChild("VarcoLib2")
local rigs = SS:WaitForChild("RigSources")
local out = {}

local function folder(name, parent)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function scaleToHeight(m, h)
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * (h / size.Y))
end

---------------------------------------------------------------- 1) 소품
local propsF = folder("Props", SS)
for _, n in ipairs({"Griddle", "Plate", "SmallPlate", "Eomuk", "Sundae", "Tteokbokki"}) do
	local o = propsF:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end
local PROP_HEIGHT = {Cauldron = 5.2, HerbShelf = 6.4, Crystal = 2.4, PotionRed = 1.3, PotionGreen = 1.5, PotionBlue = 1.2}
for name, h in pairs(PROP_HEIGHT) do
	local old = propsF:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local m = lib[name]:Clone()
	scaleToHeight(m, h)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	m.Parent = propsF
end

---------------------------------------------------------------- 2) 알바와 손님
local staffF = folder("Staff", SS)
local templates = folder("CustomerTemplates", SS)
local animSrc = SS:FindFirstChild("NpcAnimateSource") or (function()
	-- 옛 손님 틀에서 걷기, 앉기 스크립트 하나를 원본으로 남겨 둔다
	for _, m in ipairs(templates:GetChildren()) do
		local a = m:FindFirstChild("NpcAnimate")
		if a then
			local c = a:Clone()
			c.Name = "NpcAnimateSource"
			c.Enabled = false
			c.Parent = SS
			return c
		end
	end
	return nil
end)()
assert(animSrc, "NpcAnimate 원본이 없다")

local function prepRig(src, newName, height)
	local m = src:Clone()
	m.Name = newName
	scaleToHeight(m, height)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local old = m:FindFirstChild("NpcAnimate")
	if old then
		old:Destroy()
	end
	local a = animSrc:Clone()
	a.Name = "NpcAnimate"
	a.Enabled = true
	a.Parent = m
	return m
end

for _, n in ipairs({"Cook", "Helper"}) do
	local o = staffF:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end
local imp = prepRig(rigs.Rig_Imp_autosetup, "Helper", 4.6)
imp.Parent = staffF

templates:ClearAllChildren()
local MONSTERS = {{"Goblin", 5.2, 13}, {"Dragon", 5.3, 12}, {"Mushroom", 4.8, 12}}
for _, s in ipairs(MONSTERS) do
	local m = prepRig(rigs["Rig_" .. s[1] .. "_autosetup"], s[1], s[2])
	m:SetAttribute("WalkSpeed", s[3])
	m.Parent = templates
end

-- 슬라임: 다리가 없으니 투명한 몸통 뿌리에 모델을 붙이고, 걸을 때는 통통 튄다(SlimeHop)
do
	local m = lib.Slime:Clone()
	m.Name = "Slime"
	scaleToHeight(m, 3)
	local cf, size = m:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2.4, 2.4, 2.4)
	root.Transparency = 1
	root.CanCollide = false
	root.CFrame = CFrame.new(cf.Position)
	root.Parent = m
	local first = nil
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
			if not first then
				first = d
				local j = Instance.new("Motor6D")
				j.Name = "Body"
				j.Part0 = root
				j.Part1 = d
				j.C0 = root.CFrame:Inverse() * d.CFrame
				j.Parent = root
			else
				local w = Instance.new("WeldConstraint")
				w.Part0 = first
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	m.PrimaryPart = root
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = size.Y / 2 - root.Size.Y / 2
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = m
	m:SetAttribute("Hop", true)
	m:SetAttribute("WalkSpeed", 10)
	m:SetAttribute("SitY", 1.9 + size.Y / 2)
	m.Parent = templates
end

for _, m in ipairs(templates:GetChildren()) do
	local _, size = m:GetBoundingBox()
	local hum = m:FindFirstChildOfClass("Humanoid")
	table.insert(out, string.format("%s h=%.2f hip=%.2f", m.Name, size.Y, hum.HipHeight))
end

---------------------------------------------------------------- 3) 거리를 마을 길로
local street = workspace:FindFirstChild("Street")
if street then
	for _, p in ipairs(street:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Name == "Road" then
				p.Material = Enum.Material.Cobblestone
				p.Color = Color3.fromRGB(176, 160, 140)
			elseif p.Name == "Lane" then
				p:Destroy()
			elseif p.Name == "Sidewalk" then
				p.Material = Enum.Material.Ground
				p.Color = Color3.fromRGB(150, 128, 96)
			elseif p.Name == "Curb" then
				p.Material = Enum.Material.Slate
				p.Color = Color3.fromRGB(120, 112, 104)
			elseif p.Name == "LampPost" then
				p.Material = Enum.Material.Wood
				p.Color = Color3.fromRGB(92, 60, 40)
			elseif p.Name == "LampHead" then
				p.Color = Color3.fromRGB(210, 170, 255)
			elseif p.Name == "Leaves" then
				p.Color = Color3.fromRGB(96, 176, 92)
			end
		end
	end
	-- 큰 버섯(이미 있으면 다시 만든다)
	for _, p in ipairs(street:GetChildren()) do
		if p.Name == "MushStem" or p.Name == "MushCap" or p.Name == "MushDot" then
			p:Destroy()
		end
	end
	local CAPS = {Color3.fromRGB(220, 70, 80), Color3.fromRGB(150, 90, 210), Color3.fromRGB(230, 120, 60)}
	local spots = {{-48, -4, 1.0}, {48, -6, 1.2}, {-46, -30, 0.8}, {46, -26, 0.9}, {-30, -52, 1.1}, {30, -52, 0.8}, {-62, 20, 1.2}, {60, 22, 1.0}}
	for i, s in ipairs(spots) do
		local k = s[3]
		local x, z = s[1], s[2]
		local stem = Instance.new("Part")
		stem.Name = "MushStem"
		stem.Shape = Enum.PartType.Cylinder
		stem.Anchored = true
		stem.Size = Vector3.new(5 * k, 1.8 * k, 1.8 * k)
		stem.CFrame = CFrame.new(x, 2.5 * k, z) * CFrame.Angles(0, 0, math.rad(90))
		stem.Color = Color3.fromRGB(245, 236, 214)
		stem.Material = Enum.Material.SmoothPlastic
		stem.Parent = street
		local cap = Instance.new("Part")
		cap.Name = "MushCap"
		cap.Shape = Enum.PartType.Ball
		cap.Anchored = true
		cap.Size = Vector3.new(6 * k, 6 * k, 6 * k)
		cap.Position = Vector3.new(x, 5 * k, z)
		cap.Color = CAPS[(i % #CAPS) + 1]
		cap.Material = Enum.Material.SmoothPlastic
		cap.Parent = street
		-- 아래 반을 줄기 쪽으로 눌러 갓 모양을 낸다
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 0.55, 1)
		mesh.Parent = cap
	end
end

local names = {}
for _, m in ipairs(propsF:GetChildren()) do
	table.insert(names, m.Name)
end
table.insert(out, "props=" .. table.concat(names, ","))
local sn = {}
for _, m in ipairs(staffF:GetChildren()) do
	table.insert(sn, m.Name)
end
table.insert(out, "staff=" .. table.concat(sn, ","))
return table.concat(out, "\n")
