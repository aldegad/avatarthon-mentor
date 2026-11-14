-- 몬스터 물약 가게: 빈 땅의 작은 물약 가게에서 시작해, 옆 땅 칸을 사서 가게를 넓히고,
-- 넓힌 자리에 가구를 놓으면 몬스터 손님이 들어와 앉아 물약을 마시고 돈을 내는 방치형 게임의 서버 쪽.
-- 가게 주인은 플레이어 아바타다(주인 NPC 는 없다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")

local SOUND_IDS = {
	coin = "rbxassetid://133923128916164",
	upgrade = "rbxassetid://87563740971104",
	bell = "rbxassetid://80257527176602",
	serve = "rbxassetid://74080139169219",
	meow = "rbxassetid://88969735049407",
	bubble = "rbxassetid://80344334954333",
}

---------------------------------------------------------------- 땅 칸
local T = 16 -- 한 칸 크기(스터드)
local COL_MIN, COL_MAX = -2, 2
local ROW_MIN, ROW_MAX = -2, 0 -- 0 이 길가 줄, -2 가 가장 안쪽
local FLOOR_TOP = 1
-- 땅 조각(Workspace.Land.Plot) 윗면. 그 위에 까는 판은 이 높이보다 0.25 넘게 띄워 멀리서도 면이 겹쳐 깜빡이지 않게 한다
local LAND_TOP = 0.4
-- 가게 벽 꼭대기 높이(바닥 1 + 벽 6). 땅 팻말은 이보다 위에 띄워 벽에 걸려 잘리지 않게 한다
local WALL_TOP = FLOOR_TOP + 6

local function tileCenter(c: number, r: number): Vector3
	return Vector3.new(c * T, FLOOR_TOP, -5 + r * T)
end
local function key(c: number, r: number): string
	return c .. "," .. r
end

-- 넓히기 값: 몇 번째로 넓히는지에 따라 오른다
local TILE_PRICES = {3000, 6000, 12000, 22000, 40000, 70000, 120000, 200000, 330000, 550000, 900000, 1500000, 2500000, 4000000}

---------------------------------------------------------------- 가구
type Item = {id: string, short: string?, toast: string?, label: string, base: number, grow: number, max: number?}
local CATALOG: {Item} = {
	{id = "Table", short = "탁자", label = "탁자 (손님 2자리)", base = 1500, grow = 1.45},
	{id = "Herbs", short = "약초 선반", label = "약초 선반 (한 병 +2,000원)", base = 8000, grow = 1, max = 1},
	{id = "Cauldron", short = "솥", label = "솥 하나 더 (빨리 만들어요)", base = 12000, grow = 2, max = 2},
	{id = "Crystal", short = "수정 구슬", label = "수정 구슬 (한 병 +3,000원)", base = 30000, grow = 1, max = 1},
	{id = "Cat", short = "고양이 방석", label = "고양이 방석 (손님이 더 자주 와요)", base = 50000, grow = 1, max = 1},
	{id = "Sofa", short = "푹신 소파", label = "푹신 소파 (손님이 쉬고 팁을 내요)", base = 6000, grow = 1.5, max = 4},
}
local ITEM_BY_ID: {[string]: Item} = {}
for _, it in ipairs(CATALOG) do
	ITEM_BY_ID[it.id] = it
end

---------------------------------------------------------------- 방 종류(넓힐 때 고른다)
type Room = {id: string, name: string, label: string, items: {string}, color: Color3, material: Enum.Material, max: number?}
local ROOMS: {Room} = {
	{id = "Guest", name = "손님방", label = "손님방 (탁자, 고양이 방석)", items = {"Table", "Cat"}, color = Color3.fromRGB(200, 162, 120), material = Enum.Material.WoodPlanks},
	{id = "Brew", name = "조제실", label = "조제실 (솥, 약초 선반, 수정 구슬)", items = {"Cauldron", "Herbs", "Crystal"}, color = Color3.fromRGB(150, 128, 186), material = Enum.Material.Slate},
	{id = "Rest", name = "쉼터", label = "쉼터 (푹신 소파, 손님이 쉬어 가요)", items = {"Sofa", "Cat"}, color = Color3.fromRGB(132, 196, 150), material = Enum.Material.Fabric},
	{id = "Stage", name = "이벤트 무대", label = "이벤트 무대 (가끔 물약 시음회)", items = {}, color = Color3.fromRGB(196, 92, 110), material = Enum.Material.WoodPlanks, max = 1},
}
local ROOM_BY_ID: {[string]: Room} = {}
for _, rm in ipairs(ROOMS) do
	ROOM_BY_ID[rm.id] = rm
end

---------------------------------------------------------------- 직원(모두 임프, 한 명씩)
type StaffInfo = {id: string, name: string, job: string, price: number, color: Color3}
local STAFF: {StaffInfo} = {
	{id = "Cook", name = "요리 임프", job = "솥 옆에서 물약을 빨리 만들어요", price = 20000, color = Color3.fromRGB(226, 104, 60)},
	{id = "Server", name = "서빙 임프", job = "물약을 자리로 날라요. 손님이 빨리 마셔요", price = 15000, color = Color3.fromRGB(64, 140, 214)},
	{id = "Barker", name = "호객 임프", job = "길에서 손님을 불러와요. 손님이 더 자주 와요", price = 12000, color = Color3.fromRGB(232, 160, 30)},
	{id = "Cashier", name = "계산 임프", job = "손님이 흘린 동전을 주워 와요", price = 25000, color = Color3.fromRGB(52, 160, 96)},
}
local STAFF_BY_ID: {[string]: StaffInfo} = {}
for _, st in ipairs(STAFF) do
	STAFF_BY_ID[st.id] = st
end

---------------------------------------------------------------- 로벅스 상점(안 사도 다 즐길 수 있게 작게)
-- 게임 패스 번호와 개발자 상품 번호는 크리에이터 대시보드에서 만든 뒤 적는다(0 이면 아직 없음)
local PASS_DOUBLE = 2089400714 -- 금고 두 배
local PASS_FREE_STAFF = 2089358711 -- 직원 한 명 무료
local PRODUCT_TASTING = 3731048388 -- 시음회 바로 열기
local PRODUCT_RAINBOW = 3731048423 -- 무지개 솥 1분

---------------------------------------------------------------- 가게 상태(화면에 보이는 값)
local state = ReplicatedStorage:FindFirstChild("ShopState") or Instance.new("Folder")
state.Name = "ShopState"
state.Parent = ReplicatedStorage
local function value(className: string, name: string, initial: any)
	local v = state:FindFirstChild(name) or Instance.new(className)
	v.Name = name
	;(v :: any).Value = initial
	v.Parent = state
	return v
end
local money = value("NumberValue", "Money", 0)
local price = value("NumberValue", "Price", 3000)
local perMinute = value("NumberValue", "PerMinute", 0)
local seatsValue = value("IntValue", "Seats", 0)
local tilesValue = value("IntValue", "Tiles", 1)
local servedCount = value("IntValue", "Served", 0)
local lastEvent = value("StringValue", "LastEvent", "가게 문을 열었어요!")
local nextTilePrice = value("NumberValue", "NextTilePrice", TILE_PRICES[1])

local shared = ReplicatedStorage:FindFirstChild("Shared") or Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = ReplicatedStorage
local function remote(className: string, name: string)
	local r = shared:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = shared
	return r
end
local openMenu = remote("RemoteEvent", "OpenMenu") :: RemoteEvent
local placeItem = remote("RemoteFunction", "PlaceItem") :: RemoteFunction
local buildRoom = remote("RemoteFunction", "BuildRoom") :: RemoteFunction
local staffCall = remote("RemoteFunction", "Staff") :: RemoteFunction
local hiredEvent = remote("RemoteEvent", "Hired") :: RemoteEvent
local shopCall = remote("RemoteFunction", "RobuxShop") :: RemoteFunction

---------------------------------------------------------------- 공통 도구
local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

-- 받침이 있으면 withFinal(을, 은), 없으면 without(를, 는)을 붙인다
local function josa(word: string, withFinal: string, without: string): string
	local code = utf8.codepoint(word, utf8.offset(word, -1))
	local has = code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 ~= 0
	return word .. (has and withFinal or without)
end

local function part(props: {[string]: any}, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function playAt(parent: Instance, id: string, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.RollOffMaxDistance = 140
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 4)
end

local function popup(position: Vector3, text: string, color: Color3)
	local anchor = part({Size = Vector3.new(0.2, 0.2, 0.2), Position = position, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false}, workspace)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 50)
	bb.AlwaysOnTop = true
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	TweenService:Create(anchor, TweenInfo.new(1.4), {Position = position + Vector3.new(0, 4, 0)}):Play()
	TweenService:Create(t, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(anchor, 1.5)
end

local function billboard(parent: Instance, text: string, offsetY: number, bg: Color3, w: number?, h: number?, studs: boolean?): TextLabel
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	-- studs 면 크기를 스터드로 잡아 멀리서 보면 작아진다(여러 개가 겹치지 않게)
	bb.Size = if studs then UDim2.fromScale(w or 9, h or 2.8) else UDim2.fromOffset(w or 200, h or 64)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	-- 크기를 스터드로 잡아 멀리서는 작아지므로 거리로 끄지 않는다(카메라가 돌 때 켜졌다 꺼졌다 하지 않게)
	bb.MaxDistance = 1000
	-- 벽 위에 떠 있어도 가게 간판이나 나무 뒤로 반쯤 들어갔다 나왔다 하지 않게 늘 맨 앞에 그린다
	bb.AlwaysOnTop = true
	bb.Parent = parent
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = bg
	t.BackgroundTransparency = 0.15
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = text
	t.Parent = bb
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 10)
	local pad = Instance.new("UIPadding", t)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	return t
end

---------------------------------------------------------------- 충돌 그룹
pcall(function()
	PhysicsService:RegisterCollisionGroup("NPC")
	PhysicsService:RegisterCollisionGroup("Player")
	PhysicsService:RegisterCollisionGroup("Furniture")
	PhysicsService:RegisterCollisionGroup("Shell")
end)
PhysicsService:CollisionGroupSetCollidable("NPC", "NPC", false)
PhysicsService:CollisionGroupSetCollidable("NPC", "Player", false)
PhysicsService:CollisionGroupSetCollidable("NPC", "Furniture", false)
PhysicsService:CollisionGroupSetCollidable("NPC", "Shell", false)

local function setGroup(model: Instance, group: string)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
	if model:IsA("BasePart") then
		model.CollisionGroup = group
	end
end

Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local m = Instance.new("NumberValue")
	m.Name = "가게 돈"
	m.Value = money.Value
	m.Parent = ls
	ls.Parent = player
	money.Changed:Connect(function(v)
		m.Value = v
	end)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		setGroup(char, "Player")
		char.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.CollisionGroup = "Player"
			end
		end)
	end)
end)

---------------------------------------------------------------- 가게 폴더
local shop = workspace:WaitForChild("Shop")
local function sub(name: string): Folder
	local f = shop:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = shop
	return f :: Folder
end
local floorsF, shellF, saleF, slotsF, furnF = sub("Floors"), sub("Shell"), sub("ForSale"), sub("Slots"), sub("Furniture")
for _, f in ipairs({floorsF, shellF, saleF, slotsF, furnF}) do
	f:ClearAllChildren()
end
local props = ServerStorage:WaitForChild("Props")
local staff = ServerStorage:WaitForChild("Staff")
local templates = ServerStorage:WaitForChild("CustomerTemplates")
local customersF = workspace:FindFirstChild("Customers") or Instance.new("Folder")
customersF.Name = "Customers"
customersF.Parent = workspace

local WOOD = Color3.fromRGB(150, 98, 62)
local WALL = Color3.fromRGB(226, 212, 245)
local PURPLE = Color3.fromRGB(112, 64, 168)
local STOOL = Color3.fromRGB(220, 72, 84)
local FLOOR_COLOR = Color3.fromRGB(200, 162, 120)

---------------------------------------------------------------- 모델 놓기
local function anchorAll(m: Instance, anchored: boolean)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = anchored
		end
	end
end

-- 모델 바닥 가운데를 pos 에 맞추고 yaw(도)만큼 돌린다
local function placeModel(m: Model, pos: Vector3, yaw: number?)
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (pos + Vector3.new(0, size.Y / 2, 0) - cf.Position))
end

local function cloneProp(name: string, scale: number?): Model
	local m = (props:FindFirstChild(name) :: Model):Clone()
	if scale and scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	anchorAll(m, true)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- 직원을 제자리에 세운다(yaw 0 이면 뿌리가 보는 -Z 쪽을 본다)
local function placeStaff(m: Model, pos: Vector3, yaw: number)
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local y = pos.Y + hum.HipHeight + root.Size.Y / 2
	m:PivotTo(CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, math.rad(yaw), 0))
	root.Anchored = true
	setGroup(m, "Furniture")
end

---------------------------------------------------------------- 칸과 자리 기록
local owned: {[string]: boolean} = {}
local tilesBought = 0

type Seat = {pos: Vector3, look: Vector3, plateAt: Vector3, out: Vector3?, taken: any}
type Slot = {id: string, c: number, r: number, room: string, pos: Vector3, item: string?, marker: BasePart?}
local slots: {[string]: Slot} = {}
-- 칸마다 지은 방 종류와, 방 종류마다 지은 수
local roomOf: {[string]: string} = {}
local roomCount: {[string]: number} = {}
local seats: {Seat} = {}
local restSeats: {Seat} = {}
local counts: {[string]: number} = {}
local cauldronSpots: {BasePart} = {}
local menuBits = {"빨간 물약 3,000원"}

local function itemPrice(it: Item): number
	local n = counts[it.id] or 0
	return math.floor(it.base * (it.grow ^ n) / 100 + 0.5) * 100
end

---------------------------------------------------------------- 수입 계산(화면 표시용)
local cookTime = 3.6
local spawnInterval = 3.2
local stirBonus = 0
local drinkTime = 4.5 -- 서빙 임프가 있으면 줄어든다
local incomeMul = 1 -- 금고 두 배 패스가 있으면 2
local rainbowUntil = 0 -- 무지개 솥이 켜진 동안은 물약이 두 배 빨리 나온다

-- 돈이 들어오는 길은 모두 여기를 지난다(금고 두 배 패스를 한곳에서 적용)
local function earn(amount: number): number
	local got = amount * incomeMul
	money.Value += got
	return got
end

local function recompute()
	local seatRate = #seats * 60 / (drinkTime + 10.5)
	local cookRate = #cauldronSpots * 60 / cookTime
	local comeRate = 60 / spawnInterval
	perMinute.Value = math.floor(math.min(seatRate, cookRate, comeRate) * price.Value * incomeMul / 100) * 100
	seatsValue.Value = #seats
	-- 지금 가구 값(녹화 연출이 돈이 모일 때까지 기다리는 데 쓴다)
	for _, it in ipairs(CATALOG) do
		state:SetAttribute("Price_" .. it.id, itemPrice(it))
	end
end

---------------------------------------------------------------- 가게 껍데기(바닥, 벽, 간판)
local signLabel: TextLabel? = nil

local function frontDoors(): {number}
	local xs = {}
	for c = COL_MIN, COL_MAX do
		if owned[key(c, 0)] then
			table.insert(xs, c * T)
		end
	end
	return xs
end

local function rebuildShell()
	shellF:ClearAllChildren()
	for c = COL_MIN, COL_MAX do
		for r = ROW_MIN, ROW_MAX do
			if owned[key(c, r)] then
				local ctr = tileCenter(c, r)
				local edges = {
					{dc = 1, dr = 0, pos = ctr + Vector3.new(T / 2, 0, 0), size = Vector3.new(1, 0, T + 1)},
					{dc = -1, dr = 0, pos = ctr - Vector3.new(T / 2, 0, 0), size = Vector3.new(1, 0, T + 1)},
					{dc = 0, dr = -1, pos = ctr - Vector3.new(0, 0, T / 2), size = Vector3.new(T + 1, 0, 1)},
					{dc = 0, dr = 1, pos = ctr + Vector3.new(0, 0, T / 2), size = Vector3.new(T + 1, 0, 1)},
				}
				for _, e in ipairs(edges) do
					local nc, nr = c + e.dc, r + e.dr
					if not owned[key(nc, nr)] then
						local isFront = e.dr == 1 and r == ROW_MAX
						if isFront then
							-- 길가 쪽은 낮은 벽, 가운데 문
							local seg = (T - 6) / 2
							for _, s in ipairs({-1, 1}) do
								local p = part({Name = "FrontWall", Size = Vector3.new(seg, 2.4, 1), Position = e.pos + Vector3.new(s * (3 + seg / 2), 1.2, 0), Color = WOOD, Material = Enum.Material.Wood}, shellF)
								p.CollisionGroup = "Shell"
							end
						else
							local h = 6
							local w = part({Name = "Wall", Size = Vector3.new(e.size.X, h, e.size.Z), Position = e.pos + Vector3.new(0, h / 2, 0), Color = WALL}, shellF)
							w.CollisionGroup = "Shell"
							-- 보라 띠는 벽 면보다 0.3 밖으로 둘러 벽 면과 번갈아 그려지지 않게 한다
							local trim = part({Name = "Trim", Size = Vector3.new(e.size.X + 0.6, 1.6, e.size.Z + 0.6), Position = e.pos + Vector3.new(0, 0.8, 0), Color = PURPLE, CanCollide = false}, shellF)
							trim.CollisionGroup = "Shell"
						end
					end
				end
			end
		end
	end
	-- 처음 칸 앞 간판
	local start = tileCenter(0, 0)
	for _, s in ipairs({-1, 1}) do
		-- 기둥은 간판 두께(0.6)보다 얇게 해 간판 앞뒷면과 겹치지 않게 한다
		part({Name = "SignPost", Size = Vector3.new(0.8, 10, 0.4), Position = start + Vector3.new(s * 7.2, 5, T / 2 + 0.6), Color = WOOD, Material = Enum.Material.Wood}, shellF)
	end
	local sign = part({Name = "Sign", Size = Vector3.new(15.4, 3.2, 0.6), Position = start + Vector3.new(0, 10.2, T / 2 + 0.6), Color = PURPLE}, shellF)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 228, 140)
	t.RichText = true
	t.Parent = g
	signLabel = t
	t.Text = "몬스터 물약 가게\n<font size=\"14\">" .. table.concat(menuBits, " · ") .. "</font>"
end

local function refreshSign()
	if signLabel then
		signLabel.Text = "몬스터 물약 가게\n<font size=\"14\">" .. table.concat(menuBits, " · ") .. "</font>"
	end
end

---------------------------------------------------------------- 가구 놓을 자리
local function slotOffsets(c: number, r: number): {Vector3}
	if c == 0 and r == 0 then
		return {Vector3.new(0, 0, 4)} -- 처음 칸은 뒤쪽이 주방
	end
	return {Vector3.new(0, 0, -3.8), Vector3.new(0, 0, 3.8)}
end

local function makeMarker(s: Slot)
	-- 바닥(윗면 1)에서 0.2 띄워 깐다. 바짝 붙이면 멀리서 바닥과 번갈아 그려져 깜빡인다
	local m = part({Name = "Slot_" .. s.id, Size = Vector3.new(8.6, 0.1, 3.6), Position = s.pos + Vector3.new(0, 0.25, 0), Color = Color3.fromRGB(255, 214, 90), Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = true, CanTouch = false}, slotsF)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlacePrompt"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "가구 놓기"
	prompt.ObjectText = ROOM_BY_ID[s.room].name .. " 빈 자리"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = m
	prompt.Triggered:Connect(function(player)
		if s.item then
			return
		end
		local list = {}
		for _, id in ipairs(ROOM_BY_ID[s.room].items) do
			local it = ITEM_BY_ID[id]
			local n = counts[it.id] or 0
			table.insert(list, {id = it.id, label = it.label, price = itemPrice(it), soldOut = it.max ~= nil and n >= it.max})
		end
		openMenu:FireClient(player, s.id, list, money.Value, "slot", ROOM_BY_ID[s.room].name .. "에 무엇을 놓을까요?")
	end)
	s.marker = m
end

local function addSlotsFor(c: number, r: number)
	for i, off in ipairs(slotOffsets(c, r)) do
		local s: Slot = {id = key(c, r) .. "#" .. i, c = c, r = r, room = roomOf[key(c, r)] or "Guest", pos = tileCenter(c, r) + off, item = nil, marker = nil}
		slots[s.id] = s
		makeMarker(s)
	end
end

---------------------------------------------------------------- 가구 모양
local function tableAt(pos: Vector3, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Table"
	part({Name = "Top", Size = Vector3.new(4.4, 0.4, 3.2), Position = pos + Vector3.new(0, 2.8, 0), Color = Color3.fromRGB(176, 122, 80), Material = Enum.Material.Wood}, m)
	part({Name = "Leg", Size = Vector3.new(0.7, 2.6, 0.7), Position = pos + Vector3.new(0, 1.3, 0), Color = Color3.fromRGB(96, 62, 40), Material = Enum.Material.Wood}, m)
	for _, sx in ipairs({-1, 1}) do
		local stool = Instance.new("Part")
		stool.Shape = Enum.PartType.Cylinder
		stool.Anchored = true
		stool.CanCollide = false
		stool.Size = Vector3.new(0.5, 1.8, 1.8)
		stool.CFrame = CFrame.new(pos + Vector3.new(sx * 3.2, 1.65, 0)) * CFrame.Angles(0, 0, math.rad(90))
		stool.Color = STOOL
		stool.Material = Enum.Material.SmoothPlastic
		stool.Name = "Stool"
		stool.Parent = m
		part({Name = "StoolLeg", Size = Vector3.new(0.6, 1.4, 0.6), Position = pos + Vector3.new(sx * 3.2, 0.7, 0), Color = Color3.fromRGB(245, 236, 214), CanCollide = false}, m)
	end
	m.Parent = parent
	setGroup(m, "Furniture")
	return m
end

local catModel: Model? = nil

local BUILDERS: {[string]: (Slot, Model) -> ()} = {
	Table = function(s, holder)
		tableAt(s.pos, holder)
		for _, sx in ipairs({-1, 1}) do
			table.insert(seats, {
				pos = s.pos + Vector3.new(sx * 3.2, 0, 0),
				look = s.pos + Vector3.new(0, 0, 0),
				plateAt = s.pos + Vector3.new(sx * 1.1, 3.0, 0),
				taken = nil,
			})
		end
	end,
	Herbs = function(s, holder)
		local m = cloneProp("HerbShelf", 1)
		placeModel(m, s.pos + Vector3.new(-1.9, 0, 0), 180) -- 선반 앞면이 길 쪽(+Z)을 보게
		m.Parent = holder
		-- 옆 작은 탁자에 초록 물약을 늘어놓는다
		part({Name = "Stand", Size = Vector3.new(3.2, 2.4, 2.4), Position = s.pos + Vector3.new(2.2, 1.2, 0), Color = WOOD, Material = Enum.Material.Wood}, holder)
		for i, dx in ipairs({-0.9, 0, 0.9}) do
			local g = cloneProp("PotionGreen", 1)
			placeModel(g, s.pos + Vector3.new(2.2 + dx, 2.4, (i == 2) and -0.3 or 0.2), i * 40)
			g.Parent = holder
		end
		price.Value += 2000
		table.insert(menuBits, "초록 물약 +2,000원")
	end,
	Cauldron = function(s, holder)
		local m = cloneProp("Cauldron", 0.8)
		placeModel(m, s.pos, 0)
		m.Parent = holder
		local spot = part({Name = "CauldronSpot", Size = Vector3.new(3, 0.2, 3), Position = s.pos + Vector3.new(0, 2.8, 0), Transparency = 1, CanCollide = false}, holder)
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fx.Rate = 4
		fx.Lifetime = NumberRange.new(1, 1.6)
		fx.Speed = NumberRange.new(1.5, 2.5)
		fx.Size = NumberSequence.new(0.5, 0.1)
		fx.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255))
		fx.LightEmission = 0.8
		fx.Parent = spot
		table.insert(cauldronSpots, spot)
	end,
	Sofa = function(s, holder)
		-- 둘이 앉는 소파. 등받이는 방 뒤쪽(-Z), 앉은 손님은 길 쪽(+Z)을 본다
		local CUSHION = Color3.fromRGB(236, 150, 186)
		part({Name = "SofaBase", Size = Vector3.new(7, 1.3, 2.8), Position = s.pos + Vector3.new(0, 0.65, 0), Color = Color3.fromRGB(150, 98, 62), Material = Enum.Material.Wood}, holder)
		part({Name = "SofaSeat", Size = Vector3.new(6.2, 0.6, 2.6), Position = s.pos + Vector3.new(0, 1.6, 0.1), Color = CUSHION, Material = Enum.Material.Fabric}, holder)
		part({Name = "SofaBack", Size = Vector3.new(7, 2.6, 0.8), Position = s.pos + Vector3.new(0, 2.5, -1.2), Color = CUSHION, Material = Enum.Material.Fabric}, holder)
		for _, sx in ipairs({-1, 1}) do
			part({Name = "SofaArm", Size = Vector3.new(0.8, 2.2, 2.8), Position = s.pos + Vector3.new(sx * 3.5, 1.9, 0), Color = Color3.fromRGB(214, 120, 160), Material = Enum.Material.Fabric}, holder)
			local seatPos = s.pos + Vector3.new(sx * 1.6, 0, 0.2)
			table.insert(restSeats, {pos = seatPos, look = seatPos + Vector3.new(0, 0, 6), plateAt = seatPos, out = Vector3.new(0, 0, 1), taken = nil})
		end
		local pillow = part({Name = "Pillow", Size = Vector3.new(1.4, 1.1, 0.5), Position = s.pos + Vector3.new(-2.7, 2.3, -0.7), Color = Color3.fromRGB(255, 226, 120), Material = Enum.Material.Fabric}, holder)
		pillow.Orientation = Vector3.new(-10, 0, 8)
	end,
	Crystal = function(s, holder)
		-- 둥근 탁자 위 수정 구슬, 옆 받침에 파란 물약
		local top = Instance.new("Part")
		top.Shape = Enum.PartType.Cylinder
		top.Anchored = true
		top.Size = Vector3.new(0.4, 3.4, 3.4)
		top.CFrame = CFrame.new(s.pos + Vector3.new(-2, 2.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		top.Color = PURPLE
		top.Name = "CrystalTable"
		top.Parent = holder
		part({Name = "CrystalLeg", Size = Vector3.new(0.7, 2, 0.7), Position = s.pos + Vector3.new(-2, 1, 0), Color = WOOD, Material = Enum.Material.Wood}, holder)
		local m = cloneProp("Crystal", 1)
		placeModel(m, s.pos + Vector3.new(-2, 2.4, 0), 0)
		m.Parent = holder
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(190, 120, 255)
		glow.Brightness = 1.4
		glow.Range = 10
		glow.Parent = top
		part({Name = "Stand", Size = Vector3.new(3, 2.4, 2.4), Position = s.pos + Vector3.new(2.2, 1.2, 0), Color = WOOD, Material = Enum.Material.Wood}, holder)
		for i, dx in ipairs({-0.8, 0.8}) do
			local b = cloneProp("PotionBlue", 1)
			placeModel(b, s.pos + Vector3.new(2.2 + dx, 2.4, 0), i * 30)
			b.Parent = holder
		end
		price.Value += 3000
		table.insert(menuBits, "파란 물약 +3,000원")
	end,
	Cat = function(s, holder)
		local rug = Instance.new("Part")
		rug.Shape = Enum.PartType.Cylinder
		rug.Anchored = true
		rug.CanCollide = false
		rug.Size = Vector3.new(0.3, 4.2, 4.2)
		rug.CFrame = CFrame.new(s.pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		rug.Color = Color3.fromRGB(196, 150, 235)
		rug.Name = "Cushion"
		rug.Parent = holder
		local m = cloneProp("Cat", 1)
		placeModel(m, s.pos + Vector3.new(0, 0.3, 0), 200)
		m.Parent = holder
		catModel = m
		spawnInterval *= 0.65
	end,
}

local function placeOn(s: Slot, itemId: string, free: boolean?): (boolean, string)
	local it = ITEM_BY_ID[itemId]
	if not it or s.item then
		return false, "놓을 수 없어요"
	end
	if not table.find(ROOM_BY_ID[s.room].items, itemId) then
		return false, "이 방에는 놓을 수 없어요"
	end
	local n = counts[itemId] or 0
	if it.max and n >= it.max then
		return false, "더 놓을 수 없어요"
	end
	local cost = free and 0 or itemPrice(it)
	if money.Value < cost then
		return false, comma(cost - money.Value) .. "원 더 필요해요"
	end
	money.Value -= cost
	counts[itemId] = n + 1
	s.item = itemId
	if s.marker then
		s.marker:Destroy()
		s.marker = nil
	end
	local holder = Instance.new("Model")
	holder.Name = itemId .. "_" .. s.id
	holder.Parent = furnF
	BUILDERS[itemId](s, holder)
	setGroup(holder, "Furniture")
	refreshSign()
	recompute()
	if not free then
		local short = it.short or string.match(it.label, "^[^%(]+") or it.label
		short = string.gsub(short, "%s+$", "")
		local code = utf8.codepoint(short, utf8.offset(short, -1))
		local hasFinal = code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 ~= 0
		lastEvent.Value = it.toast or (short .. (hasFinal and "을" or "를") .. " 놓았어요!")
		playAt(holder:FindFirstChildWhichIsA("BasePart", true) or shop, SOUND_IDS.upgrade, 0.9)
		popup(s.pos + Vector3.new(0, 6, 0), short .. "!", Color3.fromRGB(120, 255, 160))
	end
	return true, "ok"
end

placeItem.OnServerInvoke = function(_player, slotId: string, itemId: string)
	local s = slots[slotId]
	if not s then
		return false, "자리가 없어요"
	end
	return placeOn(s, itemId)
end

---------------------------------------------------------------- 넓히기(옆 칸 사기)
local buyTile: (number, number, boolean?, string?) -> (boolean, string)
local buildStage: (number, number) -> ()

local function adjacentToOwned(c: number, r: number): (number?, number?)
	for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		if owned[key(c + d[1], r + d[2])] then
			return c + d[1], r + d[2]
		end
	end
	return nil, nil
end

local function rebuildForSale()
	saleF:ClearAllChildren()
	local cost = TILE_PRICES[tilesBought + 1]
	nextTilePrice.Value = cost or 0
	if not cost then
		return
	end
	for c = COL_MIN, COL_MAX do
		for r = ROW_MIN, ROW_MAX do
			if not owned[key(c, r)] then
				local oc, or_ = adjacentToOwned(c, r)
				if oc then
					local ctr = tileCenter(c, r)
					local plot = part({Name = "Plot_" .. key(c, r), Size = Vector3.new(T - 1.5, 0.1, T - 1.5), Position = Vector3.new(ctr.X, LAND_TOP + 0.3, ctr.Z), Color = Color3.fromRGB(110, 230, 140), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, CanQuery = false}, saleF)
					-- 팻말 아래 끝이 벽 꼭대기보다 0.6 위에 오게 띄운다(팻말 높이 2.9)
					billboard(plot, "가게 넓히기\n" .. comma(cost) .. "원", WALL_TOP + 0.6 + 1.45 - plot.Position.Y, Color3.fromRGB(40, 140, 80), 9, 2.9, true)
					-- 가게 쪽 벽 가운데에서 E 를 누르면 그 칸을 산다
					local edge = (tileCenter(oc :: number, or_ :: number) + ctr) / 2
					local trigger = part({Name = "Expand_" .. key(c, r), Size = Vector3.new(2, 2, 2), Position = Vector3.new(edge.X, 3, edge.Z), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false}, saleF)
					trigger:SetAttribute("C", c)
					trigger:SetAttribute("R", r)
					local prompt = Instance.new("ProximityPrompt")
					prompt.Name = "ExpandPrompt"
					prompt.Style = Enum.ProximityPromptStyle.Custom
					prompt.ActionText = "가게 넓히기"
					prompt.ObjectText = comma(cost) .. "원"
					prompt.KeyboardKeyCode = Enum.KeyCode.E
					prompt.HoldDuration = 0.4
					prompt.MaxActivationDistance = 6
					prompt.RequiresLineOfSight = false
					prompt.Parent = trigger
					prompt.Triggered:Connect(function(player)
						if money.Value < cost then
							popup(Vector3.new(edge.X, 5, edge.Z), comma(cost - money.Value) .. "원 더 필요해요", Color3.fromRGB(255, 220, 120))
							return
						end
						local list = {}
						for _, rm in ipairs(ROOMS) do
							local n = roomCount[rm.id] or 0
							table.insert(list, {id = rm.id, label = rm.label, price = cost, soldOut = rm.max ~= nil and n >= rm.max})
						end
						openMenu:FireClient(player, key(c, r), list, money.Value, "room", "어떤 방을 지을까요?")
					end)
				end
			end
		end
	end
end

local function addFloor(c: number, r: number, animate: boolean)
	local ctr = tileCenter(c, r)
	local rm = ROOM_BY_ID[roomOf[key(c, r)] or "Guest"]
	local f = part({Name = "Floor_" .. key(c, r), Size = Vector3.new(T, 1, T), Position = Vector3.new(ctr.X, FLOOR_TOP - 0.5, ctr.Z), Color = rm.color, Material = rm.material}, floorsF)
	if not (c == 0 and r == 0) then
		-- 방 이름 깔개(위에서 내려다보면 읽힌다). 바닥에 그대로 얹은 불투명 판이라 겹쳐 깜빡이지 않는다
		local mat = part({Name = "RoomMat", Size = Vector3.new(7, 0.2, 1.8), Position = ctr + Vector3.new(0, 0.1, -6.2), Color = Color3.fromRGB(70, 46, 110), CanCollide = false}, f)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Top
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.Parent = mat
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 232, 150)
		t.Text = rm.name
		t.Parent = g
	end
	local mat = f:FindFirstChild("RoomMat") :: BasePart?
	if mat then
		mat.Anchored = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = f
		w.Part1 = mat
		w.Parent = mat
	end
	if animate then
		f.Position = Vector3.new(ctr.X, FLOOR_TOP - 1.5, ctr.Z)
		TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = Vector3.new(ctr.X, FLOOR_TOP - 0.5, ctr.Z)}):Play()
	end
	-- 천장 조명 하나
	local lamp = part({Name = "Lamp", Size = Vector3.new(1.6, 0.6, 1.6), Position = ctr + Vector3.new(0, 9, 0), Color = Color3.fromRGB(255, 236, 170), Material = Enum.Material.Neon, CanCollide = false}, floorsF)
	local l = Instance.new("PointLight", lamp)
	l.Brightness = 0.8
	l.Range = 16
	l.Color = Color3.fromRGB(255, 220, 170)
end

buyTile = function(c: number, r: number, free: boolean?, roomId: string?): (boolean, string)
	if owned[key(c, r)] then
		return false, "이미 가게예요"
	end
	local rm = ROOM_BY_ID[roomId or "Guest"]
	if not rm then
		return false, "그런 방은 없어요"
	end
	if rm.max and (roomCount[rm.id] or 0) >= rm.max then
		return false, josa(rm.name, "은", "는") .. " 하나만 지을 수 있어요"
	end
	local cost = free and 0 or TILE_PRICES[tilesBought + 1]
	if not cost then
		return false, "더 넓힐 땅이 없어요"
	end
	if money.Value < cost then
		return false, comma(cost - money.Value) .. "원 더 필요해요"
	end
	money.Value -= cost
	owned[key(c, r)] = true
	roomOf[key(c, r)] = rm.id
	roomCount[rm.id] = (roomCount[rm.id] or 0) + 1
	if not free then
		tilesBought += 1
	end
	tilesValue.Value += free and 0 or 1
	addFloor(c, r, not free)
	rebuildShell()
	if rm.id == "Stage" then
		buildStage(c, r)
	else
		addSlotsFor(c, r)
	end
	rebuildForSale()
	recompute()
	if not free then
		lastEvent.Value = josa(rm.name, "을", "를") .. " 지었어요!"
		local ctr = tileCenter(c, r)
		playAt(floorsF:FindFirstChild("Floor_" .. key(c, r)) or shop, SOUND_IDS.upgrade, 0.9)
		popup(ctr + Vector3.new(0, 5, 0), rm.name .. "!", Color3.fromRGB(120, 255, 160))
	end
	return true, "ok"
end

buildRoom.OnServerInvoke = function(_player, tileKey: string, roomId: string)
	local c, r = string.match(tileKey, "^(%-?%d+),(%-?%d+)$")
	if not c then
		return false, "칸이 없어요"
	end
	return buyTile(tonumber(c) :: number, tonumber(r) :: number, false, roomId)
end

---------------------------------------------------------------- 처음 가게(한 칸, 솥, 탁자 하나)
owned[key(0, 0)] = true
roomOf[key(0, 0)] = "Guest"
addFloor(0, 0, false)
rebuildShell()
local kitchenCtr = tileCenter(0, 0)
local kitchen = Instance.new("Model")
kitchen.Name = "Kitchen"
kitchen.Parent = furnF
local mainCauldron = cloneProp("Cauldron", 1)
placeModel(mainCauldron, kitchenCtr + Vector3.new(0, 0, -3.4), 0)
mainCauldron.Parent = kitchen
local mainSpot = part({Name = "CauldronSpot", Size = Vector3.new(4, 0.2, 4), Position = kitchenCtr + Vector3.new(0, 3.4, -3.4), Transparency = 1, CanCollide = false}, kitchen)
table.insert(cauldronSpots, mainSpot)
-- 솥 뒤 벽 선반: 다 만든 빨간 물약이 놓여 있다(가게 주인은 플레이어라 여기엔 아무도 서 있지 않다)
part({Name = "BackShelf", Size = Vector3.new(9, 0.4, 1.6), Position = kitchenCtr + Vector3.new(0, 3.2, -7.2), Color = WOOD, Material = Enum.Material.Wood}, kitchen)
for i, dx in ipairs({-3, -1.5, 0, 1.5, 3}) do
	local r = cloneProp("PotionRed", 1)
	placeModel(r, kitchenCtr + Vector3.new(dx, 3.4, -7.2), i * 50)
	r.Parent = kitchen
end
setGroup(kitchen, "Furniture")

local bubble = Instance.new("Sound")
bubble.Name = "Bubble"
bubble.SoundId = SOUND_IDS.bubble
bubble.Looped = true
bubble.Volume = 0.5
bubble.RollOffMinDistance = 8
bubble.RollOffMaxDistance = 45
bubble.Parent = mainSpot
bubble:Play()
local fxAtt = Instance.new("Attachment", mainSpot)
local sparkle = Instance.new("ParticleEmitter")
sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkle.Rate = 8
sparkle.Lifetime = NumberRange.new(1.2, 2)
sparkle.Speed = NumberRange.new(1.5, 3)
sparkle.Size = NumberSequence.new(0.7, 0.1)
sparkle.Color = ColorSequence.new(Color3.fromRGB(205, 130, 255))
sparkle.LightEmission = 0.8
sparkle.Parent = fxAtt
local mist = Instance.new("ParticleEmitter")
mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
mist.Rate = 4
mist.Lifetime = NumberRange.new(1.2, 2)
mist.Speed = NumberRange.new(1.2, 2)
mist.Size = NumberSequence.new(1, 2.4)
mist.Color = ColorSequence.new(Color3.fromRGB(190, 140, 255))
mist.Transparency = NumberSequence.new(0.6, 1)
mist.Parent = fxAtt
local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(180, 110, 255)
glow.Brightness = 1.2
glow.Range = 12
glow.Parent = mainSpot

-- 솥 젓기: 주인(플레이어)이 직접 저으면 팁이 들어오고 다음 물약이 빨라진다
local stirPrompt = Instance.new("ProximityPrompt")
stirPrompt.Name = "StirPrompt"
stirPrompt.Style = Enum.ProximityPromptStyle.Custom
stirPrompt.ActionText = "물약 젓기"
stirPrompt.ObjectText = "팁 500원"
stirPrompt.KeyboardKeyCode = Enum.KeyCode.F
stirPrompt.HoldDuration = 0
stirPrompt.MaxActivationDistance = 9
stirPrompt.RequiresLineOfSight = false
stirPrompt.Parent = mainSpot
local lastStir = 0
stirPrompt.Triggered:Connect(function()
	if os.clock() - lastStir < 0.25 then
		return
	end
	lastStir = os.clock()
	local got = earn(500)
	stirBonus += 0.6
	sparkle:Emit(6)
	popup(mainSpot.Position + Vector3.new(math.random(-2, 2), 3, 0), "+" .. comma(got) .. "원 팁", Color3.fromRGB(255, 240, 120))
end)

addSlotsFor(0, 0)
placeOn(slots[key(0, 0) .. "#1"], "Table", true)
counts.Table = 0 -- 처음 탁자는 값에 치지 않는다
rebuildForSale()
recompute()

---------------------------------------------------------------- 손님
local STREET_Z = 11
local pathParams = {AgentRadius = 1.2, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 4}

type Customer = {model: Model, hum: Humanoid, root: BasePart, seat: Seat?}
local orders: {Customer} = {}

local function moveStep(c: Customer, target: Vector3, timeout: number): boolean
	c.hum:MoveTo(target)
	local t0 = os.clock()
	while os.clock() - t0 < timeout and c.model.Parent do
		task.wait(0.08)
		local flat = (c.root.Position - target) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 1.3 then
			return true
		end
	end
	return false
end

local function goTo(c: Customer, target: Vector3)
	local path = PathfindingService:CreatePath(pathParams)
	local ok = pcall(function()
		path:ComputeAsync(c.root.Position, target)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(path:GetWaypoints()) do
			if not c.model.Parent then
				return
			end
			moveStep(c, wp.Position, 3)
		end
	end
	moveStep(c, target, 4)
end

local function nearestDoor(x: number): number
	local best, bestD = 0, math.huge
	for _, dx in ipairs(frontDoors()) do
		local d = math.abs(dx - x)
		if d < bestD then
			best, bestD = dx, d
		end
	end
	return best
end

local function sit(c: Customer, seat: Seat)
	c.root.Anchored = true
	local look = Vector3.new(seat.look.X, 0, seat.look.Z)
	-- 몸집이 달라 앉는 높이는 손님 모델의 SitY 속성으로 맞춘다
	local p = Vector3.new(seat.pos.X, FLOOR_TOP + (c.model:GetAttribute("SitY") or 2.75), seat.pos.Z)
	c.root.CFrame = CFrame.lookAt(p, Vector3.new(look.X, p.Y, look.Z))
	c.model:SetAttribute("Sitting", true)
end

local function standUp(c: Customer)
	c.model:SetAttribute("Sitting", false)
	local seat = c.seat
	if seat then
		local out = seat.pos + (seat.out or (seat.pos - seat.look).Unit) * 1.6
		c.root.CFrame = CFrame.new(Vector3.new(out.X, c.root.Position.Y, out.Z)) * c.root.CFrame.Rotation
	end
	c.root.Anchored = false
end

local function freeSeats(): {Seat}
	local list = {}
	for _, s in ipairs(seats) do
		if not s.taken then
			table.insert(list, s)
		end
	end
	return list
end

local function leave(c: Customer)
	local doorX = nearestDoor(c.root.Position.X)
	goTo(c, Vector3.new(doorX, FLOOR_TOP, T / 2 - 5 + 3.5))
	local endX = (c.root.Position.X < 0) and -75 or 75
	moveStep(c, Vector3.new(doorX + (endX < 0 and -3 or 3), FLOOR_TOP, STREET_Z), 6)
	moveStep(c, Vector3.new(endX, FLOOR_TOP, STREET_Z), 14)
	c.model:Destroy()
end

local function spawnCustomer(seat: Seat)
	local list = templates:GetChildren()
	if #list == 0 then
		return
	end
	local m = (list[math.random(1, #list)] :: Model):Clone()
	local fromLeft = math.random() < 0.5
	local startX = fromLeft and -75 or 75
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
	m:PivotTo(CFrame.new(Vector3.new(startX, FLOOR_TOP + hum.HipHeight + root.Size.Y / 2, STREET_Z)) * CFrame.Angles(0, fromLeft and -math.pi / 2 or math.pi / 2, 0))
	m:SetAttribute("Seed", math.random() * 10)
	setGroup(m, "NPC")
	m.Parent = customersF
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			pcall(function()
				d:SetNetworkOwner(nil)
			end)
		end
	end
	hum.WalkSpeed = m:GetAttribute("WalkSpeed") or 13
	local c: Customer = {model = m, hum = hum, root = root, seat = seat}
	seat.taken = c
	task.spawn(function()
		local doorX = nearestDoor(seat.pos.X)
		moveStep(c, Vector3.new(doorX, FLOOR_TOP, STREET_Z), 16)
		playAt(root, SOUND_IDS.bell, 0.5)
		moveStep(c, Vector3.new(doorX, FLOOR_TOP, T / 2 - 5 + 3.5), 4)
		goTo(c, seat.pos + (seat.out or (seat.pos - seat.look).Unit) * 1.4)
		if not m.Parent then
			seat.taken = nil
			return
		end
		sit(c, seat)
		table.insert(orders, c)
	end)
end

---------------------------------------------------------------- 마법 물약 효과(무섭지 않게, 몇 초만)
-- 빨간 물약: 입에서 불꽃, 초록 물약: 잠깐 개구리, 파란 물약: 온몸이 번쩍번쩍
local FX_CHANCE = 0.3
local FX_TEXT = {fire = "불을 뿜어요!", frog = "개구리가 됐어요!", glow = "번쩍번쩍!"}

local function puff(at: Vector3, color: Color3)
	local a = part({Name = "Puff", Size = Vector3.new(0.2, 0.2, 0.2), Position = at, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false}, workspace)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(3, 5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(1.2, 2.4)
	e.Color = ColorSequence.new(color)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Parent = a
	e:Emit(14)
	Debris:AddItem(a, 1.2)
end

local function headOf(c: Customer): (Vector3, number)
	local head = c.model:FindFirstChild("Head") :: BasePart?
	if head then
		return head.Position, head.Size.Z
	end
	local _, size = c.model:GetBoundingBox()
	return c.root.Position + Vector3.new(0, size.Y * 0.3, 0), 1.6
end

local function fxFire(c: Customer, dur: number)
	local hp, depth = headOf(c)
	local look = c.root.CFrame.LookVector
	local mouth = part({Name = "FireMouth", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false}, c.model)
	mouth.CFrame = CFrame.lookAt(hp + look * (depth * 0.45) - Vector3.new(0, 0.3, 0), hp + look * 5)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/fire_main.dds"
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = 60
	e.Lifetime = NumberRange.new(0.35, 0.55)
	e.Speed = NumberRange.new(9, 13)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.4, 1.4), NumberSequenceKeypoint.new(1, 0.2)})
	e.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 110, 40))
	e.LightEmission = 1
	e.Parent = mouth
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 150, 60)
	l.Brightness = 3
	l.Range = 10
	l.Parent = mouth
	task.wait(dur)
	e.Enabled = false
	l.Enabled = false
	Debris:AddItem(mouth, 1)
end

local function fxGlow(c: Customer, dur: number)
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(140, 220, 255)
	h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.5
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = c.model
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(150, 220, 255)
	l.Brightness = 4
	l.Range = 14
	l.Parent = c.root
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 30
	e.Lifetime = NumberRange.new(0.6, 1)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.8, 0)
	e.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	e.LightEmission = 1
	e.Parent = c.root
	local t0 = os.clock()
	while os.clock() - t0 < dur do
		local on = math.floor((os.clock() - t0) / 0.18) % 2 == 0
		h.FillTransparency = on and 0.15 or 0.7
		l.Brightness = on and 5 or 1.5
		task.wait(0.06)
	end
	h:Destroy()
	l:Destroy()
	e.Enabled = false
	Debris:AddItem(e, 1)
end

-- 개구리: 손님 모습을 잠깐 감추고 로블록스 기본 부품으로 만든 개구리가 폴짝 뛴다
local function fxFrog(c: Customer, dur: number)
	local hidden = {}
	for _, d in ipairs(c.model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			hidden[d] = d.Transparency
			d.Transparency = 1
		elseif d:IsA("Decal") then
			hidden[d] = d.Transparency
			d.Transparency = 1
		end
	end
	local look = c.root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, 1)
	end
	look = look.Unit
	local baseY = if c.model:GetAttribute("Sitting") then FLOOR_TOP + 1.9 else FLOOR_TOP
	local base = CFrame.lookAt(Vector3.new(c.root.Position.X, baseY + 1, c.root.Position.Z), Vector3.new(c.root.Position.X, baseY + 1, c.root.Position.Z) + look)
	local frog = Instance.new("Model")
	frog.Name = "Frog"
	local GREEN, LIGHT = Color3.fromRGB(96, 196, 72), Color3.fromRGB(196, 236, 150)
	local root = part({Name = "FrogRoot", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CanCollide = false, CanQuery = false}, frog)
	root.CFrame = base
	local function blob(name: string, size: Vector3, offset: Vector3, color: Color3)
		local b = part({Name = name, Size = size, Color = color, CanCollide = false, CanQuery = false, Anchored = false}, frog)
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(1, 1, 1) * math.max(size.X, size.Y, size.Z)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Scale = size / b.Size.X
		m.Parent = b
		b.CFrame = base * CFrame.new(offset)
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = b
		w.Parent = b
		return b
	end
	blob("Body", Vector3.new(2.6, 1.7, 2.4), Vector3.new(0, 0, 0), GREEN)
	blob("Belly", Vector3.new(1.8, 1.2, 1.2), Vector3.new(0, -0.15, -0.75), LIGHT)
	for _, sx in ipairs({-1, 1}) do
		blob("Eye", Vector3.new(0.9, 0.9, 0.9), Vector3.new(sx * 0.65, 0.85, -0.55), Color3.new(1, 1, 1))
		blob("Pupil", Vector3.new(0.42, 0.42, 0.3), Vector3.new(sx * 0.65, 0.88, -0.98), Color3.fromRGB(30, 30, 30))
		blob("Leg", Vector3.new(0.9, 0.6, 1.5), Vector3.new(sx * 1.2, -0.55, 0.35), GREEN)
		blob("Cheek", Vector3.new(0.35, 0.25, 0.2), Vector3.new(sx * 0.85, 0.1, -1.08), Color3.fromRGB(255, 150, 170))
	end
	frog.Parent = workspace
	puff(base.Position, Color3.fromRGB(170, 255, 150))
	local hops = math.max(1, math.floor(dur / 0.7))
	for _ = 1, hops do
		TweenService:Create(root, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = base * CFrame.new(0, 1.3, 0)}):Play()
		task.wait(0.24)
		TweenService:Create(root, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = base}):Play()
		task.wait(0.46)
	end
	puff(base.Position, Color3.fromRGB(170, 255, 150))
	frog:Destroy()
	for d, tr in pairs(hidden) do
		if d.Parent then
			(d :: any).Transparency = tr
		end
	end
end

local FX_RUN = {fire = fxFire, frog = fxFrog, glow = fxGlow}

-- 물약 종류에 맞춰 효과 하나(초록, 파란 물약은 그 가구를 놓아야 나온다). forced 면 셋 가운데 아무거나
local function pickFx(forced: boolean?): string
	local kinds = {"fire"}
	if forced or (counts.Herbs or 0) > 0 then
		table.insert(kinds, "frog")
	end
	if forced or (counts.Crystal or 0) > 0 then
		table.insert(kinds, "glow")
	end
	return kinds[math.random(1, #kinds)]
end

local function playFx(c: Customer, kind: string, dur: number)
	if not c.model.Parent then
		return
	end
	c.model:SetAttribute("Fx", kind)
	state:SetAttribute("LastFx", kind .. "@" .. string.format("%.3f", DateTime.now().UnixTimestampMillis / 1000))
	popup(c.root.Position + Vector3.new(0, 5, 0), FX_TEXT[kind], Color3.fromRGB(255, 255, 255))
	FX_RUN[kind](c, dur)
	if c.model.Parent then
		c.model:SetAttribute("Fx", nil)
	end
end

---------------------------------------------------------------- 흘린 동전(계산 임프가 줍는다. 안 주우면 12초 뒤 사라진다)
local coinsF = sub("Coins")
coinsF:ClearAllChildren()
local function collectCoin(coin: BasePart)
	if not coin.Parent or coin:GetAttribute("Taken") then
		return
	end
	coin:SetAttribute("Taken", true)
	local got = earn(coin:GetAttribute("Value") or 500)
	playAt(coin, SOUND_IDS.coin, 0.7)
	popup(coin.Position + Vector3.new(0, 3, 0), "+" .. comma(got) .. "원 주웠어요", Color3.fromRGB(255, 225, 90))
	coin:Destroy()
end
local function dropCoin(at: Vector3)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.3, 1.5, 1.5)
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.Color = Color3.fromRGB(255, 200, 40)
	coin.Material = Enum.Material.Neon
	coin.CFrame = CFrame.new(at.X, FLOOR_TOP + 0.85, at.Z) * CFrame.Angles(0, math.random() * math.pi, 0)
	coin:SetAttribute("Value", math.max(500, math.floor(price.Value * 0.5 / 100) * 100))
	coin.Parent = coinsF
	TweenService:Create(coin, TweenInfo.new(1.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {CFrame = coin.CFrame * CFrame.Angles(0, math.pi, 0)}):Play()
	coin.Touched:Connect(function(hit)
		local m = hit:FindFirstAncestorOfClass("Model")
		if m and Players:GetPlayerFromCharacter(m) then
			collectCoin(coin)
		end
	end)
	task.delay(12, function()
		if coin.Parent and not coin:GetAttribute("Taken") then
			TweenService:Create(coin, TweenInfo.new(0.6), {Transparency = 1}):Play()
			Debris:AddItem(coin, 0.7)
		end
	end)
end

-- 쉼터 소파: 물약을 마신 손님이 앉아 쉬었다가 팁을 남긴다
local REST_TIP = 1000
local function freeRestSeat(): Seat?
	local list = {}
	for _, s in ipairs(restSeats) do
		if not s.taken then
			table.insert(list, s)
		end
	end
	return if #list > 0 then list[math.random(1, #list)] else nil
end

local function restThenLeave(c: Customer)
	local rest = freeRestSeat()
	if not rest or math.random() > 0.7 then
		leave(c)
		return
	end
	rest.taken = c
	c.seat = rest
	goTo(c, rest.pos + (rest.out :: Vector3) * 1.6)
	if not c.model.Parent then
		rest.taken = nil
		return
	end
	sit(c, rest)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(4, 1.2)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = c.root
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.new(1, 1, 1)
	t.BackgroundTransparency = 0.1
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.fromRGB(110, 80, 160)
	t.Text = "푹 쉬어요 Zz"
	t.Parent = bb
	Instance.new("UICorner", t).CornerRadius = UDim.new(0.4, 0)
	task.wait(4)
	bb:Destroy()
	if not c.model.Parent then
		rest.taken = nil
		return
	end
	local got = earn(REST_TIP)
	playAt(c.root, SOUND_IDS.coin, 0.7)
	popup(c.root.Position + Vector3.new(0, 4, 0), "+" .. comma(got) .. "원 팁", Color3.fromRGB(255, 225, 90))
	standUp(c)
	rest.taken = nil
	leave(c)
end

-- 물약이 나오면 마시고(가끔 마법 효과), 돈을 내고 나간다
local function serve(c: Customer, at: BasePart)
	local seat = c.seat
	if not seat or not c.model.Parent then
		return
	end
	playAt(at, SOUND_IDS.serve, 0.6)
	local plate = cloneProp("PotionRed", 1)
	placeModel(plate, seat.plateAt, math.random(0, 359))
	plate.Parent = furnF
	local extras = {}
	if (counts.Herbs or 0) > 0 then
		local g = cloneProp("PotionGreen", 1)
		placeModel(g, seat.plateAt + Vector3.new(0, 0, 0.95), math.random(0, 359))
		g.Parent = furnF
		table.insert(extras, g)
	end
	if (counts.Crystal or 0) > 0 then
		local b = cloneProp("PotionBlue", 1)
		placeModel(b, seat.plateAt + Vector3.new(0, 0, -0.95), math.random(0, 359))
		b.Parent = furnF
		table.insert(extras, b)
	end
	task.spawn(function()
		task.wait(drinkTime)
		if c.model.Parent and math.random() < FX_CHANCE then
			playFx(c, pickFx(), 2.8)
		end
		plate:Destroy()
		for _, e in ipairs(extras) do
			e:Destroy()
		end
		if not c.model.Parent then
			seat.taken = nil
			return
		end
		local got = earn(price.Value)
		servedCount.Value += 1
		playAt(c.root, SOUND_IDS.coin, 0.8)
		popup(c.root.Position + Vector3.new(0, 4, 0), "+" .. comma(got) .. "원", Color3.fromRGB(255, 225, 90))
		standUp(c)
		seat.taken = nil
		if math.random() < 0.3 then
			dropCoin(seat.pos + (seat.pos - seat.look).Unit * 1.2 + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5))
		end
		restThenLeave(c)
	end)
end

-- 솥마다 한 병씩 만든다
local workers = 0
local function cookLoop(index: number)
	while true do
		local spot = cauldronSpots[index]
		local c = table.remove(orders, 1)
		if c then
			local t = 0
			if index == 1 then
				stirBonus = 0
			end
			while t + (index == 1 and stirBonus or 0) < cookTime do
				task.wait(0.1)
				t += if os.clock() < rainbowUntil then 0.2 else 0.1
			end
			serve(c, spot)
		else
			task.wait(0.15)
		end
	end
end
task.spawn(function()
	while true do
		while workers < #cauldronSpots do
			workers += 1
			task.spawn(cookLoop, workers)
		end
		task.wait(0.5)
	end
end)

-- 빈자리가 있으면 손님이 온다
task.spawn(function()
	task.wait(1)
	while true do
		local free = freeSeats()
		if #free > 0 then
			spawnCustomer(free[math.random(1, #free)])
		end
		task.wait(spawnInterval * (0.8 + math.random() * 0.4))
	end
end)

---------------------------------------------------------------- 직원(임프 넷, 고용하면 그 자리에서 일하는 게 보인다)
local staffF = sub("Staff")
staffF:ClearAllChildren()
local hired: {[string]: Model} = {}
local freeStaffLeft = 0 -- 직원 한 명 무료 패스
for _, st in ipairs(STAFF) do
	state:SetAttribute("StaffPrice_" .. st.id, st.price)
end

local function weldTo(p: BasePart, to: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
end

local function newImp(st: StaffInfo): (Model, Humanoid, BasePart, BasePart)
	local m = (staff:FindFirstChild("Helper") :: Model):Clone()
	m.Name = st.id
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = (m:FindFirstChild("Head") or root) :: BasePart
	-- 머리 위 이름 띠(직원마다 색이 다르다)
	local bb = Instance.new("BillboardGui")
	bb.Name = "NameTag"
	bb.Size = UDim2.fromScale(4.4, 1.1)
	bb.StudsOffset = Vector3.new(0, 4.4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 1000
	bb.Parent = root
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = st.color
	t.BackgroundTransparency = 0.05
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.Text = st.name
	t.Parent = bb
	Instance.new("UICorner", t).CornerRadius = UDim.new(0.3, 0)
	local pad = Instance.new("UIPadding", t)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	-- 몸 앞쪽 띠 색으로 앞치마
	local apron = part({Name = "Apron", Size = Vector3.new(1.6, 1.2, 0.15), Color = st.color, CanCollide = false}, m)
	apron.CFrame = root.CFrame * CFrame.new(0, -0.45, -0.86)
	weldTo(apron, root)
	return m, hum, root, head
end

local function walker(m: Model, hum: Humanoid, root: BasePart, at: Vector3, speed: number): Customer
	m:PivotTo(CFrame.new(at + Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)))
	setGroup(m, "NPC")
	m.Parent = staffF
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			if d ~= root and not d:FindFirstChildOfClass("WeldConstraint") then
				d.Anchored = false
			end
			pcall(function()
				d:SetNetworkOwner(nil)
			end)
		end
	end
	root.Anchored = false
	hum.WalkSpeed = speed
	return {model = m, hum = hum, root = root, seat = nil}
end

local SPAWN: {[string]: (StaffInfo) -> Model} = {}

-- 요리 임프: 처음 솥 왼쪽에서 솥을 보며 젓는다
SPAWN.Cook = function(st)
	local m, _, root, head = newImp(st)
	local hat = Instance.new("Part")
	hat.Shape = Enum.PartType.Cylinder
	hat.Size = Vector3.new(1.3, 1.7, 1.7)
	hat.Color = Color3.new(1, 1, 1)
	hat.Material = Enum.Material.SmoothPlastic
	hat.CFrame = CFrame.new(head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
	hat.Parent = m
	weldTo(hat, head)
	local ladle = part({Name = "Ladle", Size = Vector3.new(0.25, 3, 0.25), Color = Color3.fromRGB(120, 80, 50), CanCollide = false}, m)
	ladle.CFrame = root.CFrame * CFrame.new(0.9, 0.2, -1.2) * CFrame.Angles(math.rad(-35), 0, 0)
	weldTo(ladle, root)
	m.Parent = staffF
	placeStaff(m, kitchenCtr + Vector3.new(-3.9, 0, -3.4), -90)
	-- 솥을 젓듯이 몸을 좌우로 살짝 돌린다
	local base = root.CFrame
	task.spawn(function()
		while m.Parent do
			TweenService:Create(root, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {CFrame = base * CFrame.Angles(0, math.rad(14), 0)}):Play()
			task.wait(0.5)
			TweenService:Create(root, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {CFrame = base * CFrame.Angles(0, math.rad(-14), 0)}):Play()
			task.wait(0.5)
		end
	end)
	cookTime *= 0.65
	return m
end

-- 서빙 임프: 쟁반에 물약을 올려 손님이 앉은 탁자로 나른다
SPAWN.Server = function(st)
	local m, hum, root = newImp(st)
	local post = kitchenCtr + Vector3.new(3.6, 0, -1.2)
	local c = walker(m, hum, root, post, 13)
	local tray = Instance.new("Part")
	tray.Shape = Enum.PartType.Cylinder
	tray.Size = Vector3.new(0.18, 2.2, 2.2)
	tray.Color = Color3.fromRGB(205, 205, 215)
	tray.Material = Enum.Material.Metal
	tray.CFrame = root.CFrame * CFrame.new(0, 0.1, -1.5) * CFrame.Angles(0, 0, math.rad(90))
	tray.Parent = m
	weldTo(tray, root)
	local potion = cloneProp("PotionRed", 1)
	placeModel(potion, (root.CFrame * CFrame.new(0, 0.2, -1.5)).Position, 0)
	potion.Parent = m
	local pparts = {}
	for _, d in ipairs(potion:GetDescendants()) do
		if d:IsA("BasePart") then
			weldTo(d, tray)
			table.insert(pparts, d)
		end
	end
	local function showPotion(on: boolean)
		for _, d in ipairs(pparts) do
			d.LocalTransparencyModifier = 0
			d.Transparency = on and 0 or 1
		end
	end
	task.spawn(function()
		while m.Parent do
			local busy = {}
			for _, s in ipairs(seats) do
				local who = s.taken
				if who and who.model and who.model:GetAttribute("Sitting") then
					table.insert(busy, s)
				end
			end
			if #busy > 0 then
				local s = busy[math.random(1, #busy)]
				showPotion(true)
				local tableCtr = s.look
				goTo(c, Vector3.new(tableCtr.X, FLOOR_TOP, tableCtr.Z + 2.4))
				root.CFrame = CFrame.lookAt(root.Position, Vector3.new(tableCtr.X, root.Position.Y, tableCtr.Z))
				task.wait(0.7)
				showPotion(false)
				playAt(root, SOUND_IDS.serve, 0.4)
				goTo(c, post)
			else
				task.wait(0.5)
			end
		end
	end)
	drinkTime = 3.0
	return m
end

-- 호객 임프: 가게 앞 길에서 "물약 있어요!" 팻말을 흔든다
SPAWN.Barker = function(st)
	local m, _, root = newImp(st)
	m.Parent = staffF
	placeStaff(m, Vector3.new(7.5, FLOOR_TOP, 8.2), 200)
	local stick = part({Name = "SignStick", Size = Vector3.new(0.3, 3.4, 0.3), Color = Color3.fromRGB(120, 80, 50), CanCollide = false, Anchored = false}, m)
	local board = part({Name = "SignBoard", Size = Vector3.new(5.2, 2.4, 0.3), Color = Color3.fromRGB(255, 236, 160), CanCollide = false, Anchored = false}, m)
	local frame = Instance.new("SelectionBox")
	frame.Adornee = board
	frame.Color3 = Color3.fromRGB(150, 60, 160)
	frame.LineThickness = 0.08
	frame.Parent = board
	local w = Instance.new("Weld")
	w.Part0 = root
	w.Part1 = stick
	w.C1 = CFrame.new(0, -1.5, 0)
	w.C0 = CFrame.new(1.5, 0.2, -0.3)
	w.Parent = stick
	board.CFrame = stick.CFrame * CFrame.new(0, 2.4, 0)
	local bw = Instance.new("Weld")
	bw.Part0 = stick
	bw.Part1 = board
	bw.C0 = CFrame.new(0, 2.4, 0)
	bw.Parent = board
	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 50
		g.Parent = board
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.GothamBlack
		tl.TextScaled = true
		tl.TextColor3 = Color3.fromRGB(150, 60, 160)
		tl.Text = "물약 있어요!"
		tl.Parent = g
	end
	local c0 = w.C0
	TweenService:Create(w, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {C0 = c0 * CFrame.Angles(0, 0, math.rad(-22))}):Play()
	-- 가끔 말풍선
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(5, 1.3)
	bb.StudsOffset = Vector3.new(-1, 6, 0)
	bb.AlwaysOnTop = true
	bb.Enabled = false
	bb.Parent = root
	local say = Instance.new("TextLabel")
	say.Size = UDim2.fromScale(1, 1)
	say.BackgroundColor3 = Color3.new(1, 1, 1)
	say.TextScaled = true
	say.Font = Enum.Font.GothamBold
	say.TextColor3 = Color3.fromRGB(60, 60, 60)
	say.Parent = bb
	Instance.new("UICorner", say).CornerRadius = UDim.new(0.4, 0)
	task.spawn(function()
		local lines = {"어서 오세요!", "마법 물약 있어요!", "한 병 마셔 봐요!"}
		local i = 0
		while m.Parent do
			i = i % #lines + 1
			say.Text = lines[i]
			bb.Enabled = true
			task.wait(1.8)
			bb.Enabled = false
			task.wait(1.6)
		end
	end)
	spawnInterval *= 0.7
	return m
end

-- 계산 임프: 바닥에 떨어진 동전을 주우러 다닌다
SPAWN.Cashier = function(st)
	local m, hum, root = newImp(st)
	local post = kitchenCtr + Vector3.new(-4.6, 0, 1.5)
	local c = walker(m, hum, root, post, 15)
	local bag = part({Name = "CoinBag", Size = Vector3.new(1.1, 1.1, 1.1), Color = Color3.fromRGB(140, 96, 60), CanCollide = false}, m)
	bag.Shape = Enum.PartType.Ball
	bag.CFrame = root.CFrame * CFrame.new(1.2, -0.7, -0.3)
	weldTo(bag, root)
	local coinTop = Instance.new("Part")
	coinTop.Shape = Enum.PartType.Cylinder
	coinTop.Size = Vector3.new(0.18, 0.7, 0.7)
	coinTop.Color = Color3.fromRGB(255, 200, 40)
	coinTop.Material = Enum.Material.Neon
	coinTop.CFrame = bag.CFrame * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90))
	coinTop.Parent = m
	weldTo(coinTop, bag)
	task.spawn(function()
		while m.Parent do
			local best, bd = nil, math.huge
			for _, coin in ipairs(coinsF:GetChildren()) do
				if coin:IsA("BasePart") and not coin:GetAttribute("Taken") then
					local d = (coin.Position - root.Position).Magnitude
					if d < bd then
						best, bd = coin, d
					end
				end
			end
			if best then
				goTo(c, Vector3.new(best.Position.X, FLOOR_TOP, best.Position.Z))
				if best.Parent then
					collectCoin(best)
				end
			else
				if ((root.Position - post) * Vector3.new(1, 0, 1)).Magnitude > 2 then
					goTo(c, post)
				end
				task.wait(0.4)
			end
		end
	end)
	return m
end

local function hire(id: string): (boolean, string)
	local st = STAFF_BY_ID[id]
	if not st then
		return false, "그런 직원은 없어요"
	end
	if hired[id] then
		return false, "이미 일하고 있어요"
	end
	local cost = if freeStaffLeft > 0 then 0 else st.price
	if money.Value < cost then
		return false, comma(cost - money.Value) .. "원 더 필요해요"
	end
	if cost == 0 then
		freeStaffLeft -= 1
	end
	money.Value -= cost
	local m = SPAWN[id](st)
	hired[id] = m
	state:SetAttribute("Hired_" .. id, true)
	recompute()
	lastEvent.Value = josa(st.name, "을", "를") .. " 고용했어요!"
	playAt(m:FindFirstChild("HumanoidRootPart") or shop, SOUND_IDS.upgrade, 0.9)
	hiredEvent:FireAllClients(id, st.name, st.job, st.color)
	return true, "ok"
end

staffCall.OnServerInvoke = function(_player, cmd: string, id: string?)
	if cmd == "list" then
		local list = {}
		for _, st in ipairs(STAFF) do
			table.insert(list, {id = st.id, name = st.name, job = st.job, price = if freeStaffLeft > 0 then 0 else st.price, hired = hired[st.id] ~= nil, color = st.color})
		end
		return list, money.Value
	elseif cmd == "hire" and id then
		return hire(id)
	end
	return false, "알 수 없어요"
end

---------------------------------------------------------------- 이벤트 무대와 물약 시음회
type StageInfo = {center: Vector3, spots: {Vector3}, platform: BasePart, confetti: ParticleEmitter}
local stage: StageInfo? = nil
local nextTasting = math.huge
local tastingOn = false

buildStage = function(c: number, r: number)
	local ctr = tileCenter(c, r)
	local center = ctr + Vector3.new(0, 0, -1.5)
	local m = Instance.new("Model")
	m.Name = "Stage"
	m.Parent = furnF
	local function cyl(name: string, height: number, dia: number, at: Vector3, color: Color3, mat: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.Size = Vector3.new(height, dia, dia)
		p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	cyl("Rim", 0.6, 9.4, center + Vector3.new(0, 0.3, 0), PURPLE, Enum.Material.Neon)
	local plat = cyl("Platform", 1.4, 8.4, center + Vector3.new(0, 0.7, 0), Color3.fromRGB(214, 150, 84), Enum.Material.WoodPlanks)
	cyl("Pedestal", 2.2, 2.4, center + Vector3.new(0, 1.4 + 1.1, 0), Color3.fromRGB(176, 140, 214))
	local big = cloneProp("PotionRed", 3.2)
	placeModel(big, center + Vector3.new(0, 3.6, 0), 20)
	big.Parent = m
	for i, a in ipairs({45, 135, 225, 315}) do
		local rr = math.rad(a)
		local at = center + Vector3.new(math.sin(rr) * 4.6, 0, math.cos(rr) * 4.6)
		local colors = {Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 200, 255), Color3.fromRGB(170, 255, 140), Color3.fromRGB(255, 220, 110)}
		part({Name = "LightPost", Size = Vector3.new(0.5, 4.5, 0.5), Position = at + Vector3.new(0, 2.25, 0), Color = Color3.fromRGB(90, 60, 120)}, m)
		local bulb = part({Name = "Bulb", Size = Vector3.new(1, 1, 1), Position = at + Vector3.new(0, 4.9, 0), Color = colors[i], Material = Enum.Material.Neon, CanCollide = false}, m)
		bulb.Shape = Enum.PartType.Ball
		local l = Instance.new("PointLight")
		l.Color = colors[i]
		l.Brightness = 0.6
		l.Range = 8
		l.Parent = bulb
	end
	-- 뒤쪽 현수막
	for _, sx in ipairs({-1, 1}) do
		part({Name = "BannerPost", Size = Vector3.new(0.5, 7.5, 0.5), Position = ctr + Vector3.new(sx * 5.2, 3.75, -6.6), Color = WOOD, Material = Enum.Material.Wood}, m)
	end
	local banner = part({Name = "Banner", Size = Vector3.new(10, 2.6, 0.3), Position = ctr + Vector3.new(0, 6.3, -6.4), Color = Color3.fromRGB(196, 60, 110)}, m)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.Parent = banner
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBlack
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(255, 240, 200)
	tl.Text = "물약 시음회"
	tl.Parent = g
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 0, 0)
	local fxPart = part({Name = "Confetti", Size = Vector3.new(6, 0.2, 6), Position = center + Vector3.new(0, 9, 0), Transparency = 1, CanCollide = false, CanQuery = false}, m)
	att.Parent = fxPart
	local confetti = Instance.new("ParticleEmitter")
	confetti.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	confetti.Rate = 45
	confetti.Lifetime = NumberRange.new(1.6, 2.4)
	confetti.Speed = NumberRange.new(2, 5)
	confetti.SpreadAngle = Vector2.new(60, 60)
	confetti.Acceleration = Vector3.new(0, -6, 0)
	confetti.Size = NumberSequence.new(0.7, 0.3)
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 150)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 90)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(120, 230, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 180, 255)),
	})
	confetti.LightEmission = 0.7
	confetti.Enabled = false
	confetti.Parent = att
	setGroup(m, "Furniture")
	local spots = {}
	for _, a in ipairs({-105, -72, -40, -12, 12, 40, 72, 105}) do
		local rr = math.rad(a)
		table.insert(spots, center + Vector3.new(math.sin(rr) * 6.1, 0, math.cos(rr) * 6.1))
	end
	stage = {center = center, spots = spots, platform = plat, confetti = confetti}
	state:SetAttribute("HasStage", true)
	nextTasting = os.clock() + 10
end

local function spawnTaster(spot: Vector3, center: Vector3)
	local list = templates:GetChildren()
	local m = (list[math.random(1, #list)] :: Model):Clone()
	local fromLeft = spot.X < 0 or (spot.X == 0 and math.random() < 0.5)
	local startX = fromLeft and -75 or 75
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
	m:PivotTo(CFrame.new(Vector3.new(startX, FLOOR_TOP + hum.HipHeight + root.Size.Y / 2, STREET_Z)) * CFrame.Angles(0, fromLeft and -math.pi / 2 or math.pi / 2, 0))
	m:SetAttribute("Seed", math.random() * 10)
	m:SetAttribute("Taster", true)
	setGroup(m, "NPC")
	m.Parent = customersF
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			pcall(function()
				d:SetNetworkOwner(nil)
			end)
		end
	end
	hum.WalkSpeed = (m:GetAttribute("WalkSpeed") or 13) + 3 -- 몰려오니 조금 빠르게
	local c: Customer = {model = m, hum = hum, root = root, seat = nil}
	task.spawn(function()
		local doorX = nearestDoor(spot.X)
		moveStep(c, Vector3.new(doorX, FLOOR_TOP, STREET_Z), 16)
		moveStep(c, Vector3.new(doorX, FLOOR_TOP, T / 2 - 5 + 3.5), 4)
		goTo(c, spot)
		if not m.Parent then
			return
		end
		root.Anchored = true
		root.CFrame = CFrame.lookAt(Vector3.new(spot.X, root.Position.Y, spot.Z), Vector3.new(center.X, root.Position.Y, center.Z))
		task.wait(0.5 + math.random() * 1.5)
		playFx(c, pickFx(true), 2.6)
		if not m.Parent then
			return
		end
		local got = earn(price.Value)
		playAt(root, SOUND_IDS.coin, 0.7)
		popup(root.Position + Vector3.new(0, 4, 0), "+" .. comma(got) .. "원", Color3.fromRGB(255, 225, 90))
		task.wait(0.5)
		root.Anchored = false
		leave(c)
	end)
end

local function runTasting(): boolean
	local st = stage
	if not st or tastingOn then
		return false
	end
	tastingOn = true
	state:SetAttribute("EventOn", true)
	lastEvent.Value = "물약 시음회가 열렸어요! 손님이 몰려와요"
	playAt(st.platform, SOUND_IDS.bell, 1)
	st.confetti.Enabled = true
	task.spawn(function()
		for _, spot in ipairs(st.spots) do
			spawnTaster(spot, st.center)
			task.wait(0.35)
		end
	end)
	task.delay(22, function()
		st.confetti.Enabled = false
		tastingOn = false
		state:SetAttribute("EventOn", false)
		nextTasting = os.clock() + 40
	end)
	return true
end

task.spawn(function()
	while true do
		task.wait(1)
		if stage and not tastingOn and os.clock() >= nextTasting then
			runTasting()
		end
	end
end)

---------------------------------------------------------------- 로벅스 상점(시험은 Studio 시험 구매로만)
local MarketplaceService = game:GetService("MarketplaceService")
type ShopItem = {id: string, kind: string, assetId: number, name: string, desc: string, robux: number}
local SHOP_ITEMS: {ShopItem} = {
	{id = "Double", kind = "pass", assetId = PASS_DOUBLE, name = "금고 두 배", desc = "버는 돈이 늘 두 배가 돼요", robux = 25},
	{id = "FreeStaff", kind = "pass", assetId = PASS_FREE_STAFF, name = "직원 한 명 무료", desc = "임프 한 명을 공짜로 고용해요", robux = 15},
	{id = "Tasting", kind = "product", assetId = PRODUCT_TASTING, name = "시음회 바로 열기", desc = "이벤트 무대에서 바로 시음회가 열려요", robux = 5},
	{id = "Rainbow", kind = "product", assetId = PRODUCT_RAINBOW, name = "무지개 솥 1분", desc = "1분 동안 물약이 두 배 빨리 나와요", robux = 5},
}
local ownedPass: {[string]: boolean} = {}

local function grantPass(id: string)
	if ownedPass[id] then
		return
	end
	ownedPass[id] = true
	state:SetAttribute("Owns_" .. id, true)
	if id == "Double" then
		incomeMul = 2
		lastEvent.Value = "금고 두 배! 버는 돈이 두 배가 돼요"
	elseif id == "FreeStaff" then
		freeStaffLeft += 1
		lastEvent.Value = "직원 한 명을 공짜로 고용할 수 있어요"
	end
	recompute()
end

local function rainbowCauldrons()
	rainbowUntil = os.clock() + 60
	lastEvent.Value = "무지개 솥! 1분 동안 물약이 두 배 빨리 나와요"
	for _, spot in ipairs(cauldronSpots) do
		local e = Instance.new("ParticleEmitter")
		e.Name = "Rainbow"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 25
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(3, 5)
		e.Size = NumberSequence.new(0.9, 0.2)
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 230, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 110, 255)),
		})
		e.LightEmission = 1
		e.Parent = spot
		Debris:AddItem(e, 60)
	end
end

local function checkPasses(player: Player)
	-- 만든 사람 계정은 패스를 늘 가진 것으로 나온다. Studio 시험에서는 시험 구매로만 켠다
	if game:GetService("RunService"):IsStudio() then
		return
	end
	for _, it in ipairs(SHOP_ITEMS) do
		if it.kind == "pass" and it.assetId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, it.assetId)
			end)
			if ok and owns then
				grantPass(it.id)
			end
		end
	end
end
Players.PlayerAdded:Connect(checkPasses)
for _, pl in ipairs(Players:GetPlayers()) do
	task.spawn(checkPasses, pl)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_player, passId, purchased)
	if not purchased then
		return
	end
	for _, it in ipairs(SHOP_ITEMS) do
		if it.kind == "pass" and it.assetId == passId then
			grantPass(it.id)
		end
	end
end)

MarketplaceService.ProcessReceipt = function(info)
	for _, it in ipairs(SHOP_ITEMS) do
		if it.kind == "product" and it.assetId == info.ProductId then
			if it.id == "Tasting" then
				if not stage then
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				if not runTasting() then
					nextTasting = os.clock() -- 지금 열려 있으면 끝나자마자 한 번 더
				end
			elseif it.id == "Rainbow" then
				rainbowCauldrons()
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

shopCall.OnServerInvoke = function(_player, cmd: string)
	if cmd == "list" then
		local list = {}
		for _, it in ipairs(SHOP_ITEMS) do
			table.insert(list, {id = it.id, kind = it.kind, assetId = it.assetId, name = it.name, desc = it.desc, robux = it.robux, owned = ownedPass[it.id] == true, usable = it.id ~= "Tasting" or stage ~= nil})
		end
		return list
	end
	return nil
end

-- 고양이는 가끔 운다
task.spawn(function()
	while true do
		task.wait(10 + math.random() * 6)
		if catModel and catModel.Parent then
			local p = catModel:FindFirstChildWhichIsA("BasePart", true)
			if p then
				playAt(p, SOUND_IDS.meow, 0.7)
			end
		end
	end
end)

-- 녹화와 시험용: 서버 쪽에서 칸과 가구를 바로 다룰 수 있게 열어 둔다
-- 시험과 녹화용 손잡이(ServerStorage.ShopDebug 를 Invoke 한다)
local debugFn = Instance.new("BindableFunction")
debugFn.Name = "ShopDebug"
debugFn.OnInvoke = function(cmd: string, a: any, b: any, ...)
	if cmd == "buyTile" then
		return buyTile(a, b)
	elseif cmd == "place" then
		return placeOn(slots[a], b)
	elseif cmd == "addMoney" then
		money.Value += a
		return money.Value
	elseif cmd == "room" then
		return buyTile(a, b, false, select(1, ...))
	elseif cmd == "hire" then
		return hire(a)
	elseif cmd == "tasting" then
		return runTasting()
	elseif cmd == "fx" then
		for _, m in ipairs(customersF:GetChildren()) do
			if m:GetAttribute("Sitting") and not m:GetAttribute("Fx") then
				local c = {model = m, hum = m:FindFirstChildOfClass("Humanoid"), root = m:FindFirstChild("HumanoidRootPart"), seat = nil}
				task.spawn(playFx, c, a, 2.8)
				return true
			end
		end
		return false
	elseif cmd == "fxOn" then
		local m = a :: Model
		if m and m.Parent then
			local c = {model = m, hum = m:FindFirstChildOfClass("Humanoid"), root = m:FindFirstChild("HumanoidRootPart"), seat = nil}
			task.spawn(playFx, c, b, 3)
			return true
		end
		return false
	elseif cmd == "grant" then
		grantPass(a)
		return true
	elseif cmd == "rainbow" then
		rainbowCauldrons()
		return true
	elseif cmd == "slots" then
		local ids = {}
		for id in pairs(slots) do
			table.insert(ids, id)
		end
		table.sort(ids)
		return table.concat(ids, " ")
	end
	return "unknown " .. tostring(cmd)
end
debugFn.Parent = game:GetService("ServerStorage")
