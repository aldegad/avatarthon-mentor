-- 떡볶이 가게 월드 짓기 (Edit 모드에서 한 번 실행, 다시 실행해도 같은 결과)
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")

for _, n in ipairs({"Shop", "Street", "Upgrades", "Customers", "QueuePoints"}) do
	local old = workspace:FindFirstChild(n)
	if old then old:Destroy() end
end
local oldSpawn = workspace:FindFirstChild("SpawnLocation")
if oldSpawn then oldSpawn:Destroy() end

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function signText(p, face, text, color, bg)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = bg or Color3.fromRGB(255, 248, 230)
	t.BackgroundTransparency = bg and 0 or 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.Parent = g
	return g
end

-- 바닥 색
local bp = workspace:FindFirstChild("Baseplate")
if bp then
	bp.Color = Color3.fromRGB(120, 170, 95)
	bp.Material = Enum.Material.Grass
	local tex = bp:FindFirstChildOfClass("Texture")
	if tex then tex:Destroy() end
end

---------------------------------------------------------------- 가게
local shop = model("Shop", workspace)
local WOOD = Color3.fromRGB(176, 120, 72)
local CREAM = Color3.fromRGB(255, 240, 214)
local RED = Color3.fromRGB(214, 48, 49)

part({Name = "Floor", Size = Vector3.new(44, 1, 30), Position = Vector3.new(0, 0.5, -11), Color = Color3.fromRGB(236, 214, 178), Material = Enum.Material.WoodPlanks}, shop)
part({Name = "BackWall", Size = Vector3.new(44, 14, 1), Position = Vector3.new(0, 8, -26.5), Color = CREAM}, shop)
part({Name = "WallL", Size = Vector3.new(1, 14, 30), Position = Vector3.new(-22.5, 8, -11), Color = CREAM}, shop)
part({Name = "WallR", Size = Vector3.new(1, 14, 30), Position = Vector3.new(22.5, 8, -11), Color = CREAM}, shop)
-- 벽 아래 띠
part({Name = "TrimBack", Size = Vector3.new(44, 3, 1.2), Position = Vector3.new(0, 2.5, -26.4), Color = RED}, shop)
part({Name = "TrimL", Size = Vector3.new(1.2, 3, 30), Position = Vector3.new(-22.4, 2.5, -11), Color = RED}, shop)
part({Name = "TrimR", Size = Vector3.new(1.2, 3, 30), Position = Vector3.new(22.4, 2.5, -11), Color = RED}, shop)

-- 앞 기둥과 간판
part({Name = "PostL", Size = Vector3.new(1.5, 16, 1.5), Position = Vector3.new(-22, 8.5, 4), Color = WOOD, Material = Enum.Material.Wood}, shop)
part({Name = "PostR", Size = Vector3.new(1.5, 16, 1.5), Position = Vector3.new(22, 8.5, 4), Color = WOOD, Material = Enum.Material.Wood}, shop)
local sign = part({Name = "Sign", Size = Vector3.new(30, 5, 1), Position = Vector3.new(0, 18, 4.2), Color = RED}, shop)
signText(sign, Enum.NormalId.Front, "동네 떡볶이", Color3.fromRGB(255, 244, 200))
signText(sign, Enum.NormalId.Back, "동네 떡볶이", Color3.fromRGB(255, 244, 200))

-- 줄무늬 차양
for i = 0, 10 do
	local x = -22 + i * 4.4
	part({
		Name = "Awning" .. i,
		Size = Vector3.new(4.4, 0.4, 8),
		CFrame = CFrame.new(x + 2.2, 13.2, 7.2) * CFrame.Angles(math.rad(-28), 0, 0),
		Color = (i % 2 == 0) and RED or Color3.fromRGB(255, 255, 255),
	}, shop)
end

-- 카운터
local counter = model("Counter", shop)
part({Name = "Body", Size = Vector3.new(26, 2.6, 4), Position = Vector3.new(0, 2.3, -6), Color = WOOD, Material = Enum.Material.Wood}, counter)
part({Name = "Top", Size = Vector3.new(27, 0.5, 5), Position = Vector3.new(0, 3.85, -6), Color = Color3.fromRGB(250, 250, 250), Material = Enum.Material.Marble}, counter)
local menuBoard = part({Name = "MenuBoard", Size = Vector3.new(16, 6, 0.5), Position = Vector3.new(0, 10, -26), Color = Color3.fromRGB(40, 45, 50)}, shop)
local mg = signText(menuBoard, Enum.NormalId.Back, "", Color3.new(1, 1, 1))
mg.Name = "MenuGui"
mg:FindFirstChildOfClass("TextLabel").Name = "MenuText"
mg.MenuText.Text = "메뉴\n떡볶이 3,000원"
mg.MenuText.Font = Enum.Font.GothamBold

-- 조리대(뒤쪽)
part({Name = "Stove", Size = Vector3.new(14, 3, 5), Position = Vector3.new(0, 2.5, -15), Color = Color3.fromRGB(150, 155, 160), Material = Enum.Material.Metal}, shop)
local griddleSpot = part({Name = "GriddleSpot", Size = Vector3.new(10, 0.4, 4), Position = Vector3.new(0, 4.2, -15), Color = Color3.fromRGB(60, 60, 60), Material = Enum.Material.Metal}, shop)
local fire = Instance.new("Fire")
fire.Heat = 2; fire.Size = 3; fire.Color = Color3.fromRGB(255, 120, 40); fire.SecondaryColor = Color3.fromRGB(255, 200, 80)
fire.Enabled = false
fire.Parent = griddleSpot
local steamAtt = Instance.new("Attachment", griddleSpot)
steamAtt.Name = "SteamAtt"
steamAtt.Position = Vector3.new(0, 1, 0)
local steam = Instance.new("ParticleEmitter")
steam.Name = "Steam"
steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
steam.Rate = 6
steam.Lifetime = NumberRange.new(1.5, 2.5)
steam.Speed = NumberRange.new(2, 4)
steam.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4)})
steam.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1)})
steam.Color = ColorSequence.new(Color3.new(1, 1, 1))
steam.Parent = steamAtt

-- 식탁과 의자
local tables = model("Tables", shop)
local function tableSet(x, z)
	part({Name = "TableTop", Size = Vector3.new(6, 0.5, 4), Position = Vector3.new(x, 4, z), Color = Color3.fromRGB(255, 255, 255)}, tables)
	part({Name = "TableLeg", Size = Vector3.new(0.6, 3, 0.6), Position = Vector3.new(x, 2.5, z), Color = Color3.fromRGB(90, 90, 90), Material = Enum.Material.Metal}, tables)
	for _, dx in ipairs({-3.6, 3.6}) do
		local s = Instance.new("Part")
		s.Shape = Enum.PartType.Cylinder
		s.Anchored = true
		s.Size = Vector3.new(0.6, 2.2, 2.2)
		s.CFrame = CFrame.new(x + dx, 2.6, z) * CFrame.Angles(0, 0, math.rad(90))
		s.Color = Color3.fromRGB(230, 60, 60)
		s.Material = Enum.Material.SmoothPlastic
		s.Name = "Stool"
		s.Parent = tables
		part({Name = "StoolLeg", Size = Vector3.new(0.4, 1.6, 0.4), Position = Vector3.new(x + dx, 1.5, z), Color = Color3.fromRGB(90, 90, 90)}, tables)
	end
end
tableSet(-15, -12)
tableSet(-15, -20)
tableSet(15, -12)
tableSet(15, -20)

-- 가게 조명
for _, x in ipairs({-12, 0, 12}) do
	local lamp = part({Name = "Lamp", Size = Vector3.new(2, 1, 2), Position = Vector3.new(x, 14.5, -11), Color = Color3.fromRGB(255, 236, 170), Material = Enum.Material.Neon}, shop)
	local l = Instance.new("PointLight", lamp)
	l.Brightness = 1.2; l.Range = 22; l.Color = Color3.fromRGB(255, 220, 160)
	part({Name = "LampCord", Size = Vector3.new(0.2, 3, 0.2), Position = Vector3.new(x, 16.5, -11), Color = Color3.fromRGB(40, 40, 40)}, shop)
end
part({Name = "Ceiling", Size = Vector3.new(46, 0.6, 31), Position = Vector3.new(0, 18.3, -11.5), Color = CREAM, Transparency = 1, CanCollide = false, CastShadow = false}, shop)

-- 요리사·알바·음식이 설 자리
local spots = folder("Spots", shop)
part({Name = "CookSpot", Size = Vector3.new(2, 0.2, 2), Position = Vector3.new(-3, 1.1, -11), Transparency = 1, CanCollide = false}, spots)
part({Name = "HelperSpot", Size = Vector3.new(2, 0.2, 2), Position = Vector3.new(6, 1.1, -11), Transparency = 1, CanCollide = false}, spots)
part({Name = "FoodSpot1", Size = Vector3.new(2, 0.2, 2), Position = Vector3.new(-7, 4.2, -6), Transparency = 1, CanCollide = false}, spots)
part({Name = "FoodSpot2", Size = Vector3.new(2, 0.2, 2), Position = Vector3.new(7, 4.2, -6), Transparency = 1, CanCollide = false}, spots)
part({Name = "FoodSpot3", Size = Vector3.new(2, 0.2, 2), Position = Vector3.new(0, 4.2, -6), Transparency = 1, CanCollide = false}, spots)
part({Name = "CatSpot", Size = Vector3.new(2, 0.2, 2), Position = Vector3.new(18, 1.1, 1), Transparency = 1, CanCollide = false}, spots)

---------------------------------------------------------------- 거리
local street = model("Street", workspace)
part({Name = "Sidewalk", Size = Vector3.new(160, 1, 14), Position = Vector3.new(0, 0.5, 11), Color = Color3.fromRGB(200, 196, 188), Material = Enum.Material.Concrete}, street)
part({Name = "Curb", Size = Vector3.new(160, 1.2, 1), Position = Vector3.new(0, 0.6, 18.5), Color = Color3.fromRGB(160, 160, 160), Material = Enum.Material.Concrete}, street)
part({Name = "Road", Size = Vector3.new(160, 0.4, 20), Position = Vector3.new(0, 0.2, 29), Color = Color3.fromRGB(60, 62, 66), Material = Enum.Material.Asphalt}, street)
for i = -7, 7 do
	part({Name = "Lane", Size = Vector3.new(5, 0.05, 0.6), Position = Vector3.new(i * 10, 0.42, 29), Color = Color3.fromRGB(250, 250, 250)}, street)
end
for _, x in ipairs({-40, 40}) do
	part({Name = "LampPost", Size = Vector3.new(0.8, 14, 0.8), Position = Vector3.new(x, 7.5, 16.5), Color = Color3.fromRGB(50, 55, 60), Material = Enum.Material.Metal}, street)
	local head = part({Name = "LampHead", Size = Vector3.new(2.5, 1, 2.5), Position = Vector3.new(x, 14.8, 16.5), Color = Color3.fromRGB(255, 240, 190), Material = Enum.Material.Neon}, street)
	local l = Instance.new("PointLight", head)
	l.Brightness = 1; l.Range = 30; l.Color = Color3.fromRGB(255, 225, 170)
end
local function tree(x, z)
	local trunk = Instance.new("Part")
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Anchored = true
	trunk.Size = Vector3.new(8, 1.6, 1.6)
	trunk.CFrame = CFrame.new(x, 5, z) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Color = Color3.fromRGB(110, 75, 45)
	trunk.Material = Enum.Material.Wood
	trunk.Name = "Trunk"
	trunk.Parent = street
	local leaves = Instance.new("Part")
	leaves.Shape = Enum.PartType.Ball
	leaves.Anchored = true
	leaves.Size = Vector3.new(8, 8, 8)
	leaves.Position = Vector3.new(x, 11, z)
	leaves.Color = Color3.fromRGB(90, 160, 80)
	leaves.Material = Enum.Material.Grass
	leaves.Name = "Leaves"
	leaves.Parent = street
end
tree(-32, 9); tree(32, 9); tree(-60, 9); tree(60, 9); tree(-36, -30); tree(36, -30)

-- 손님이 걷는 길 표시 점
local q = folder("QueuePoints", workspace)
local function pt(name, pos)
	part({Name = name, Size = Vector3.new(1, 0.2, 1), Position = pos, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false}, q)
end
pt("EnterL", Vector3.new(-70, 1.1, 12))
pt("EnterR", Vector3.new(70, 1.1, 12))
pt("Door", Vector3.new(0, 1.1, 8))
for i = 1, 6 do
	pt("Q" .. i, Vector3.new(0, 1.1, -1.5 + (i - 1) * 3.2))
end

folder("Customers", workspace)

---------------------------------------------------------------- 스폰
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(-12, 1.05, 11)
spawn.Color = Color3.fromRGB(255, 205, 80)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Duration = 0
spawn.Parent = workspace
local dec = spawn:FindFirstChildOfClass("Decal")
if dec then dec:Destroy() end

---------------------------------------------------------------- 업그레이드 발판
local ups = folder("Upgrades", workspace)
local UPGRADES = {
	{id = "Eomuk", label = "어묵 메뉴 추가", price = 15000},
	{id = "Griddle", label = "큰 철판으로 바꾸기", price = 30000},
	{id = "Helper", label = "알바 뽑기", price = 60000},
	{id = "Sundae", label = "순대 메뉴 추가", price = 120000},
	{id = "Cat", label = "가게 고양이 데려오기", price = 250000},
}
for i, u in ipairs(UPGRADES) do
	local x = -30 - ((i - 1) % 3) * 9
	local z = -2 - math.floor((i - 1) / 3) * 10
	local pad = part({
		Name = u.id,
		Size = Vector3.new(7, 1, 7),
		Position = Vector3.new(x, 0.6, z),
		Color = Color3.fromRGB(80, 200, 120),
		Material = Enum.Material.Neon,
	}, ups)
	pad:SetAttribute("Price", u.price)
	pad:SetAttribute("Label", u.label)
	pad:SetAttribute("Order", i)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Size = UDim2.fromOffset(220, 80)
	bb.StudsOffset = Vector3.new(0, 4.5, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	bb.Parent = pad
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	t.BackgroundTransparency = 0.25
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = string.format("%s\n%s원", u.label, tostring(u.price))
	t.Parent = bb
	local c = Instance.new("UICorner", t)
	c.CornerRadius = UDim.new(0, 10)
end
local upSign = part({Name = "UpgradeSign", Size = Vector3.new(26, 4, 0.6), Position = Vector3.new(-39, 6, 4.5), Color = Color3.fromRGB(40, 120, 70)}, ups)
signText(upSign, Enum.NormalId.Back, "가게 키우기 (밟으면 구매)", Color3.new(1, 1, 1))
part({Name = "UpgradeSignPostL", Size = Vector3.new(0.6, 4, 0.6), Position = Vector3.new(-51, 2, 4.5), Color = WOOD}, ups)
part({Name = "UpgradeSignPostR", Size = Vector3.new(0.6, 4, 0.6), Position = Vector3.new(-27, 2, 4.5), Color = WOOD}, ups)

---------------------------------------------------------------- 하늘과 빛
Lighting.ClockTime = 16.2
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(120, 110, 100)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 130)
local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
atm.Density = 0.25
atm.Haze = 1
atm.Color = Color3.fromRGB(255, 225, 190)

-- 공유 폴더
local shared = RS:FindFirstChild("Shared") or folder("Shared", RS)
if not shared:FindFirstChild("Popup") then
	local ev = Instance.new("RemoteEvent")
	ev.Name = "Popup"
	ev.Parent = shared
end

return "world built: " .. #shop:GetDescendants() .. " shop parts"
