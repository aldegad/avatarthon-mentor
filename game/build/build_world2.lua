-- 타일 확장판 월드 정리(Edit 모드에서 실행, 다시 실행해도 같은 결과)
-- 1) 만들어 둔 VARCO 모델과 직원을 ServerStorage.Props / Staff 로 모은다
-- 2) 옛 가게와 업그레이드 발판을 지우고, 빈 땅 칸(5 x 3)을 깐다
local SS = game:GetService("ServerStorage")
local T = 16

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
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

-- 1) 모델 모으기(이미 모았으면 그대로 둔다)
local propsF = folder("Props", SS)
local staffF = folder("Staff", SS)
local oldShop = workspace:FindFirstChild("Shop")
local unlock = SS:FindFirstChild("Unlockables")
local function take(src, newName, dest)
	if dest:FindFirstChild(newName) or not src then return end
	local m = src:Clone()
	m.Name = newName
	m.Parent = dest
end
take(oldShop and oldShop:FindFirstChild("GriddleModel"), "Griddle", propsF)
take(oldShop and oldShop:FindFirstChild("TteokbokkiPlate"), "Plate", propsF)
take(SS:FindFirstChild("TakeoutFood"), "SmallPlate", propsF)
take(unlock and unlock:FindFirstChild("Eomuk"), "Eomuk", propsF)
take(unlock and unlock:FindFirstChild("Sundae"), "Sundae", propsF)
take(unlock and unlock:FindFirstChild("Cat"), "Cat", propsF)
take(oldShop and oldShop:FindFirstChild("CookNPC"), "Cook", staffF)
take(unlock and unlock:FindFirstChild("Helper"), "Helper", staffF)
for _, m in ipairs(propsF:GetChildren()) do
	local f = m:FindFirstChildWhichIsA("Fire", true)
	if f then f:Destroy() end
end

-- 2) 옛 것 지우기
for _, n in ipairs({"Shop", "Upgrades", "QueuePoints", "Customers", "SpawnLocation", "Land"}) do
	local o = workspace:FindFirstChild(n)
	if o then o:Destroy() end
end
for _, n in ipairs({"Unlockables", "TakeoutFood"}) do
	local o = SS:FindFirstChild(n)
	if o then o:Destroy() end
end

-- 거리: 땅 칸 위에 있던 나무를 빼고 바깥에 다시 심는다
local street = workspace:FindFirstChild("Street")
if street then
	for _, p in ipairs(street:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "Trunk" or p.Name == "Leaves") and math.abs(p.Position.X) < 46 and p.Position.Z < 4 then
			p:Destroy()
		end
	end
	local function tree(x, z)
		local trunk = Instance.new("Part")
		trunk.Shape = Enum.PartType.Cylinder
		trunk.Anchored = true
		trunk.Size = Vector3.new(8, 1.6, 1.6)
		trunk.CFrame = CFrame.new(x, 4, z) * CFrame.Angles(0, 0, math.rad(90))
		trunk.Color = Color3.fromRGB(110, 75, 45)
		trunk.Material = Enum.Material.Wood
		trunk.Name = "Trunk"
		trunk.Parent = street
		local leaves = Instance.new("Part")
		leaves.Shape = Enum.PartType.Ball
		leaves.Anchored = true
		leaves.Size = Vector3.new(8, 8, 8)
		leaves.Position = Vector3.new(x, 10, z)
		leaves.Color = Color3.fromRGB(90, 160, 80)
		leaves.Material = Enum.Material.Grass
		leaves.Name = "Leaves"
		leaves.Parent = street
	end
	local have = {}
	for _, p in ipairs(street:GetChildren()) do
		if p.Name == "Leaves" then have[math.floor(p.Position.X) .. "," .. math.floor(p.Position.Z)] = true end
	end
	for _, xz in ipairs({{-54, -14}, {54, -14}, {-54, -38}, {54, -38}, {-20, -58}, {20, -58}}) do
		if not have[xz[1] .. "," .. xz[2]] then tree(xz[1], xz[2]) end
	end
end

-- 빈 땅 칸
local land = Instance.new("Model")
land.Name = "Land"
land.Parent = workspace
for c = -2, 2 do
	for r = -2, 0 do
		local ctr = Vector3.new(c * T, 0, -5 + r * T)
		local shade = ((c + r) % 2 == 0) and Color3.fromRGB(132, 182, 100) or Color3.fromRGB(124, 174, 94)
		part({Name = "Plot", Size = Vector3.new(T - 0.6, 0.4, T - 0.6), Position = ctr + Vector3.new(0, 0.2, 0), Color = shade, Material = Enum.Material.Grass, CanCollide = false}, land)
	end
end
-- 땅 둘레 낮은 울타리 말뚝
for i = -2, 2 do
	for _, z in ipairs({-45.5}) do
		part({Name = "Fence", Size = Vector3.new(T, 1.2, 0.4), Position = Vector3.new(i * T, 0.6, z), Color = Color3.fromRGB(200, 170, 120), Material = Enum.Material.Wood}, land)
	end
end
for _, x in ipairs({-40.5, 40.5}) do
	part({Name = "Fence", Size = Vector3.new(0.4, 1.2, 48), Position = Vector3.new(x, 0.6, -21), Color = Color3.fromRGB(200, 170, 120), Material = Enum.Material.Wood}, land)
end

local shop = Instance.new("Model")
shop.Name = "Shop"
shop.Parent = workspace
folder("Customers", workspace)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(-14, 1.05, 11)
spawn.Color = Color3.fromRGB(255, 205, 80)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Duration = 0
spawn.Parent = workspace
local dec = spawn:FindFirstChildOfClass("Decal")
if dec then dec:Destroy() end

local names = {}
for _, m in ipairs(propsF:GetChildren()) do table.insert(names, m.Name) end
for _, m in ipairs(staffF:GetChildren()) do table.insert(names, m.Name) end
return "world2 ok; props/staff=" .. table.concat(names, ",") .. "; customers=" .. #SS.CustomerTemplates:GetChildren()
