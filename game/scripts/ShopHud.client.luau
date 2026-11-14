-- 화면 위 가게 정보(돈, 자리, 한 병 값, 1분 수입), 가구와 방 고르기 창, 직원 고용, 시음회 띠, 로벅스 상점
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local state = ReplicatedStorage:WaitForChild("ShopState")
local money = state:WaitForChild("Money")
local perMinute = state:WaitForChild("PerMinute")
local price = state:WaitForChild("Price")
local seats = state:WaitForChild("Seats")
local tiles = state:WaitForChild("Tiles")
local lastEvent = state:WaitForChild("LastEvent")
local shared = ReplicatedStorage:WaitForChild("Shared")
local openMenu = shared:WaitForChild("OpenMenu") :: RemoteEvent
local placeItem = shared:WaitForChild("PlaceItem") :: RemoteFunction
local buildRoom = shared:WaitForChild("BuildRoom") :: RemoteFunction
local staffCall = shared:WaitForChild("Staff") :: RemoteFunction
local hiredEvent = shared:WaitForChild("Hired") :: RemoteEvent
local shopCall = shared:WaitForChild("RobuxShop") :: RemoteFunction
local MarketplaceService = game:GetService("MarketplaceService")

local function comma(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "ShopHud"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextScaled = true
	for k, v in pairs(props) do
		t[k] = v
	end
	t.Parent = parent
	return t
end

---------------------------------------------------------------- 금고
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 8)
panel.Size = UDim2.fromOffset(440, 92)
panel.BackgroundColor3 = Color3.fromRGB(112, 64, 168)
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = Color3.fromRGB(255, 240, 210)
stroke.Thickness = 3
label(panel, {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 240, 210), Text = "몬스터 물약 가게 금고"})
local moneyLabel = label(panel, {Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 38), Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1)})
local subLabel = label(panel, {Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 0, 20), Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(255, 235, 200)})

local help = label(gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(620, 30), BackgroundTransparency = 0.35, BackgroundColor3 = Color3.fromRGB(30, 30, 30), Font = Enum.Font.GothamMedium, TextColor3 = Color3.new(1, 1, 1), Text = "초록 땅 옆 벽에서 E: 방 짓기   노란 빈자리에서 E: 가구 놓기   솥 앞 F: 팁"})
Instance.new("UICorner", help).CornerRadius = UDim.new(0, 10)

local toast = label(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(360, 34), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(40, 160, 90), Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), Visible = false})
Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

local shown = money.Value
local function refresh()
	moneyLabel.Text = comma(shown) .. "원"
	subLabel.Text = string.format("가게 %d칸 · 자리 %d개 · 한 병 %s원 · 1분에 약 %s원", tiles.Value, seats.Value, comma(price.Value), comma(perMinute.Value))
end
money.Changed:Connect(function(v)
	local from = shown
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < 0.35 do
			shown = from + (v - from) * ((os.clock() - start) / 0.35)
			refresh()
			task.wait()
		end
		shown = v
		refresh()
	end)
	if v > from then
		panel.Size = UDim2.fromOffset(452, 96)
		TweenService:Create(panel, TweenInfo.new(0.25), {Size = UDim2.fromOffset(440, 92)}):Play()
	end
end)
for _, v in ipairs({perMinute, price, seats, tiles}) do
	v.Changed:Connect(refresh)
end
lastEvent.Changed:Connect(function(text)
	toast.Text = text
	toast.Visible = true
	task.delay(2.5, function()
		if toast.Text == text then
			toast.Visible = false
		end
	end)
end)
refresh()

---------------------------------------------------------------- 가구 고르기 창
local menu = Instance.new("Frame")
menu.Name = "FurnitureMenu"
menu.AnchorPoint = Vector2.new(1, 0.5)
menu.Position = UDim2.new(1, -24, 0.5, 0)
menu.Size = UDim2.fromOffset(330, 0)
menu.AutomaticSize = Enum.AutomaticSize.Y
menu.BackgroundColor3 = Color3.fromRGB(248, 242, 255)
menu.Visible = false
menu.Parent = gui
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 14)
local mstroke = Instance.new("UIStroke", menu)
mstroke.Color = Color3.fromRGB(112, 64, 168)
mstroke.Thickness = 3
local list = Instance.new("UIListLayout", menu)
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
local mpad = Instance.new("UIPadding", menu)
for _, side in ipairs({"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"}) do
	mpad[side] = UDim.new(0, 10)
end

local currentSlot = nil
local currentKind = "slot"
local buttons = {}

local function closeMenu()
	menu.Visible = false
	currentSlot = nil
end

local function say(msg)
	toast.Text = msg
	toast.Visible = true
	task.delay(2, function()
		if toast.Text == msg then
			toast.Visible = false
		end
	end)
end

local function choose(id)
	if not currentSlot then
		return
	end
	local b = buttons[id]
	if b then
		b.BackgroundColor3 = Color3.fromRGB(255, 205, 80)
		task.wait(0.5)
	end
	local slotId = currentSlot
	local kind = currentKind
	closeMenu()
	local ok, msg
	if kind == "room" then
		ok, msg = buildRoom:InvokeServer(slotId, id)
	else
		ok, msg = placeItem:InvokeServer(slotId, id)
	end
	if not ok then
		say(msg)
	end
end

openMenu.OnClientEvent:Connect(function(slotId, items, have, kind, titleText)
	for _, ch in ipairs(menu:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	buttons = {}
	currentSlot = slotId
	currentKind = kind or "slot"
	local title = label(menu, {Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(112, 64, 168), Text = titleText or "무엇을 놓을까요?", LayoutOrder = 0})
	title.TextXAlignment = Enum.TextXAlignment.Left
	for i, it in ipairs(items) do
		local b = Instance.new("TextButton")
		b.Name = it.id
		b.LayoutOrder = i
		b.Size = UDim2.new(1, 0, 0, 40)
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.AutoButtonColor = true
		local can = (not it.soldOut) and have >= it.price
		b.BackgroundColor3 = can and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(225, 220, 210)
		b.TextColor3 = can and Color3.fromRGB(40, 40, 40) or Color3.fromRGB(150, 145, 140)
		b.Text = it.soldOut and (it.label .. (currentKind == "room" and "  하나만 지어요" or "  다 놓았어요")) or (it.label .. "  " .. comma(it.price) .. "원")
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		local bp = Instance.new("UIPadding", b)
		bp.PaddingLeft = UDim.new(0, 10)
		bp.PaddingRight = UDim.new(0, 10)
		bp.PaddingTop = UDim.new(0, 6)
		bp.PaddingBottom = UDim.new(0, 6)
		b.Parent = menu
		buttons[it.id] = b
		b.Activated:Connect(function()
			if it.soldOut then
				return
			end
			choose(it.id)
		end)
	end
	local cancel = Instance.new("TextButton")
	cancel.LayoutOrder = 99
	cancel.Size = UDim2.new(1, 0, 0, 30)
	cancel.Font = Enum.Font.GothamMedium
	cancel.TextScaled = true
	cancel.Text = "닫기"
	cancel.BackgroundColor3 = Color3.fromRGB(240, 235, 225)
	cancel.TextColor3 = Color3.fromRGB(90, 90, 90)
	Instance.new("UICorner", cancel).CornerRadius = UDim.new(0, 8)
	cancel.Parent = menu
	cancel.Activated:Connect(closeMenu)
	menu.Visible = true
end)

-- 녹화할 때 창의 단추를 대신 누른다(사람이 누르는 것과 같은 길로 간다)
local pick = gui:FindFirstChild("Pick") or Instance.new("BindableEvent")
pick.Name = "Pick"
pick.Parent = gui
pick.Event:Connect(function(id)
	choose(id)
end)

---------------------------------------------------------------- 오른쪽 아래 단추 둘: 직원 고용, 로벅스 상점
local function sideButton(text, color, y)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, -16, 1, y)
	b.Size = UDim2.fromOffset(170, 46)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.Text = text
	b.Parent = gui
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	local st = Instance.new("UIStroke", b)
	st.Color = Color3.fromRGB(255, 240, 210)
	st.Thickness = 2.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local bp = Instance.new("UIPadding", b)
	bp.PaddingTop = UDim.new(0, 8)
	bp.PaddingBottom = UDim.new(0, 8)
	return b
end
local staffButton = sideButton("직원 고용", Color3.fromRGB(226, 120, 50), -112)
local shopButton = sideButton("로벅스 상점", Color3.fromRGB(40, 150, 90), -56)

-- 목록 창(직원, 로벅스 상점이 같이 쓴다)
local panel2 = Instance.new("Frame")
panel2.Name = "ListPanel"
panel2.AnchorPoint = Vector2.new(1, 1)
panel2.Position = UDim2.new(1, -16, 1, -128)
panel2.Size = UDim2.fromOffset(360, 0)
panel2.AutomaticSize = Enum.AutomaticSize.Y
panel2.BackgroundColor3 = Color3.fromRGB(255, 248, 238)
panel2.Visible = false
panel2.Parent = gui
Instance.new("UICorner", panel2).CornerRadius = UDim.new(0, 14)
local p2stroke = Instance.new("UIStroke", panel2)
p2stroke.Thickness = 3
local p2list = Instance.new("UIListLayout", panel2)
p2list.Padding = UDim.new(0, 6)
p2list.SortOrder = Enum.SortOrder.LayoutOrder
local p2pad = Instance.new("UIPadding", panel2)
for _, side in ipairs({"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"}) do
	p2pad[side] = UDim.new(0, 10)
end
local panelKind = nil
local rowButtons = {}
local rowActions = {}

local function closePanel()
	panel2.Visible = false
	panelKind = nil
end

local function clearPanel()
	for _, ch in ipairs(panel2:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	rowButtons = {}
	rowActions = {}
end

local function panelRow(order, id, title, right, desc, enabled, accent, onClick)
	local b = Instance.new("TextButton")
	b.Name = id
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, 58)
	b.Text = ""
	b.AutoButtonColor = enabled
	b.BackgroundColor3 = enabled and Color3.new(1, 1, 1) or Color3.fromRGB(228, 222, 212)
	b.Parent = panel2
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 8, 1, 0)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = b
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)
	local t = label(b, {Position = UDim2.fromOffset(16, 5), Size = UDim2.new(0.62, -16, 0, 26), Font = Enum.Font.GothamBlack, TextColor3 = enabled and Color3.fromRGB(40, 40, 40) or Color3.fromRGB(140, 135, 128), Text = title})
	t.TextXAlignment = Enum.TextXAlignment.Left
	local r = label(b, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 5), Size = UDim2.new(0.38, -10, 0, 26), Font = Enum.Font.GothamBold, TextColor3 = enabled and Color3.fromRGB(190, 90, 30) or Color3.fromRGB(140, 135, 128), Text = right})
	r.TextXAlignment = Enum.TextXAlignment.Right
	local d = label(b, {Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -26, 0, 20), Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(100, 96, 90), Text = desc})
	d.TextXAlignment = Enum.TextXAlignment.Left
	rowButtons[id] = b
	rowActions[id] = enabled and onClick or nil
	b.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
	return b
end

local function panelTitle(text, color)
	local t = label(panel2, {Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.GothamBlack, TextColor3 = color, Text = text, LayoutOrder = 0})
	t.TextXAlignment = Enum.TextXAlignment.Left
	p2stroke.Color = color
end

local function closeRow()
	local cancel = Instance.new("TextButton")
	cancel.LayoutOrder = 99
	cancel.Size = UDim2.new(1, 0, 0, 30)
	cancel.Font = Enum.Font.GothamMedium
	cancel.TextScaled = true
	cancel.Text = "닫기"
	cancel.BackgroundColor3 = Color3.fromRGB(240, 235, 225)
	cancel.TextColor3 = Color3.fromRGB(90, 90, 90)
	Instance.new("UICorner", cancel).CornerRadius = UDim.new(0, 8)
	cancel.Parent = panel2
	cancel.Activated:Connect(closePanel)
end

local function flashRow(id)
	local b = rowButtons[id]
	if b then
		b.BackgroundColor3 = Color3.fromRGB(255, 205, 80)
		task.wait(0.5)
	end
end

local hireStaff

local function openStaff()
	closeMenu()
	clearPanel()
	panelKind = "staff"
	panelTitle("직원 고용", Color3.fromRGB(226, 120, 50))
	local list, have = staffCall:InvokeServer("list")
	for i, st in ipairs(list) do
		local right = st.hired and "일하는 중" or (st.price == 0 and "무료" or (comma(st.price) .. "원"))
		local can = (not st.hired) and have >= st.price
		panelRow(i, st.id, st.name, right, st.job, can, st.color, function()
			hireStaff(st.id)
		end)
	end
	closeRow()
	panel2.Visible = true
end

hireStaff = function(id)
	flashRow(id)
	closePanel()
	local ok, msg = staffCall:InvokeServer("hire", id)
	if not ok then
		say(msg)
	end
end

local function openShop()
	closeMenu()
	clearPanel()
	panelKind = "shop"
	panelTitle("로벅스 상점", Color3.fromRGB(40, 150, 90))
	local list = shopCall:InvokeServer("list") or {}
	for i, it in ipairs(list) do
		local ready = it.assetId and it.assetId > 0
		local right = it.owned and "가지고 있어요" or ("R$ " .. it.robux)
		local desc = it.desc
		if not it.usable then
			desc = "이벤트 무대를 지으면 살 수 있어요"
		elseif not ready then
			desc = it.desc .. " (준비 중)"
		end
		local enabled = ready and it.usable and not it.owned
		panelRow(i, it.id, it.name, right, desc, enabled, Color3.fromRGB(40, 150, 90), function()
			flashRow(it.id)
			closePanel()
			if it.kind == "pass" then
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, it.assetId)
			else
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, it.assetId)
			end
		end)
	end
	local note = label(panel2, {Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(120, 115, 108), Text = "안 사도 게임은 다 할 수 있어요", LayoutOrder = 98})
	note.TextXAlignment = Enum.TextXAlignment.Left
	closeRow()
	panel2.Visible = true
end

staffButton.Activated:Connect(function()
	if panel2.Visible and panelKind == "staff" then
		closePanel()
	else
		openStaff()
	end
end)
shopButton.Activated:Connect(function()
	if panel2.Visible and panelKind == "shop" then
		closePanel()
	else
		openShop()
	end
end)

---------------------------------------------------------------- 고용 컷인: 얼굴과 이름 띠가 화면을 가로질러 지나간다
hiredEvent.OnClientEvent:Connect(function(id, name, job, color)
	local band = Instance.new("Frame")
	band.Name = "HireCutIn"
	band.AnchorPoint = Vector2.new(0, 0.5)
	band.Position = UDim2.new(-1, 0, 0.5, 0)
	band.Size = UDim2.new(1, 0, 0, 150)
	band.BackgroundColor3 = color
	band.BorderSizePixel = 0
	band.ZIndex = 20
	band.Parent = gui
	local edge = Instance.new("UIStroke", band)
	edge.Color = Color3.fromRGB(255, 244, 214)
	edge.Thickness = 4
	local vp = Instance.new("ViewportFrame")
	vp.AnchorPoint = Vector2.new(0, 0.5)
	vp.Position = UDim2.new(0.2, 0, 0.5, 0)
	vp.Size = UDim2.fromOffset(170, 170)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(210, 210, 210)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.ZIndex = 21
	vp.Parent = band
	local big = label(band, {Position = UDim2.new(0.2, 190, 0, 22), Size = UDim2.new(0.6, -190, 0, 62), Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), Text = name .. " 고용!", ZIndex = 21})
	big.TextXAlignment = Enum.TextXAlignment.Left
	big.TextStrokeTransparency = 0.6
	local small = label(band, {Position = UDim2.new(0.2, 192, 0, 90), Size = UDim2.new(0.6, -190, 0, 34), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 246, 220), Text = job, ZIndex = 21})
	small.TextXAlignment = Enum.TextXAlignment.Left
	task.spawn(function()
		local src = workspace:WaitForChild("Shop"):WaitForChild("Staff"):WaitForChild(id, 3)
		if src then
			local ok, clone = pcall(function()
				src.Archivable = true
				return src:Clone()
			end)
			if ok and clone then
				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") then
						d:Destroy()
					end
				end
				clone.Parent = vp
				local pivot = clone:GetPivot()
				local head = clone:FindFirstChild("Head")
				local hp = head and head.Position or pivot.Position + Vector3.new(0, 1.5, 0)
				local fwd = pivot.LookVector * Vector3.new(1, 0, 1)
				fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, -1)
				local cam = Instance.new("Camera")
				cam.FieldOfView = 40
				cam.CFrame = CFrame.lookAt(hp + fwd * 7 + Vector3.new(0, 0.6, 0), hp - Vector3.new(0, 1.1, 0))
				cam.Parent = vp
				vp.CurrentCamera = cam
			end
		end
	end)
	TweenService:Create(band, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0.5, 0)}):Play()
	task.delay(1.9, function()
		TweenService:Create(band, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 0, 0.5, 0)}):Play()
		task.wait(0.35)
		band:Destroy()
	end)
end)

---------------------------------------------------------------- 물약 시음회 띠
local eventBanner = label(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(460, 46), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(232, 92, 120), Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), Text = "물약 시음회! 손님이 몰려와요", Visible = false})
Instance.new("UICorner", eventBanner).CornerRadius = UDim.new(0, 12)
local ebStroke = Instance.new("UIStroke", eventBanner)
ebStroke.Color = Color3.fromRGB(255, 240, 210)
ebStroke.Thickness = 3
ebStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local ebPad = Instance.new("UIPadding", eventBanner)
ebPad.PaddingTop = UDim.new(0, 6)
ebPad.PaddingBottom = UDim.new(0, 6)
state:GetAttributeChangedSignal("EventOn"):Connect(function()
	eventBanner.Visible = state:GetAttribute("EventOn") == true
end)

-- 녹화할 때 단추를 대신 누른다(사람이 누르는 것과 같은 길로 간다)
local function bindable(name, fn)
	local b = gui:FindFirstChild(name) or Instance.new("BindableEvent")
	b.Name = name
	b.Parent = gui
	b.Event:Connect(fn)
end
bindable("OpenStaff", openStaff)
bindable("Hire", function(id)
	hireStaff(id)
end)
bindable("OpenShop", openShop)
bindable("ClosePanel", closePanel)
-- 열린 목록 창의 한 줄을 누른다(직원 고용, 로벅스 상점 같은 길)
bindable("PanelPick", function(id)
	local act = rowActions[id]
	if act then
		act()
	end
end)

---------------------------------------------------------------- 상호작용 표시(키 글자를 자판 배열과 상관없이 E, F 로 보여 준다)
local PPS = game:GetService("ProximityPromptService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

PPS.PromptShown:Connect(function(prompt: ProximityPrompt)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "PromptUI"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(250, 66)
	bb.StudsOffset = Vector3.new(0, 1.2, 0)
	bb.Adornee = prompt.Parent :: PVInstance
	bb.ResetOnSpawn = false
	local box = Instance.new("Frame")
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
	box.BackgroundTransparency = 0.2
	box.Parent = bb
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
	local key = Instance.new("TextLabel")
	key.Size = UDim2.fromOffset(46, 46)
	key.Position = UDim2.fromOffset(10, 10)
	key.BackgroundColor3 = Color3.new(1, 1, 1)
	key.Font = Enum.Font.GothamBlack
	key.TextColor3 = Color3.fromRGB(30, 30, 30)
	key.TextSize = 28
	key.Text = prompt.KeyboardKeyCode.Name
	key.Parent = box
	Instance.new("UICorner", key).CornerRadius = UDim.new(0, 9)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 0, 1, 0)
	bar.Size = UDim2.new(0, 0, 0, 5)
	bar.BackgroundColor3 = Color3.fromRGB(255, 205, 80)
	bar.BorderSizePixel = 0
	bar.Parent = key
	local action = label(box, {Position = UDim2.fromOffset(66, 9), Size = UDim2.new(1, -76, 0, 28), Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), Text = prompt.ActionText})
	action.TextXAlignment = Enum.TextXAlignment.Left
	local obj = label(box, {Position = UDim2.fromOffset(66, 38), Size = UDim2.new(1, -76, 0, 20), Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(255, 225, 160), Text = prompt.ObjectText})
	obj.TextXAlignment = Enum.TextXAlignment.Left
	bb.Parent = playerGui

	local conns = {}
	local fill: Tween? = nil
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			bar.Size = UDim2.new(0, 0, 0, 5)
			fill = TweenService:Create(bar, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 0, 5)})
			fill:Play()
		end
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if fill then
			fill:Cancel()
		end
		bar.Size = UDim2.new(0, 0, 0, 5)
	end))
	table.insert(conns, prompt.Triggered:Connect(function()
		key.BackgroundColor3 = Color3.fromRGB(255, 205, 80)
		task.delay(0.25, function()
			key.BackgroundColor3 = Color3.new(1, 1, 1)
		end)
	end))
	table.insert(conns, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		obj.Text = prompt.ObjectText
	end))
	local hidden
	hidden = prompt.PromptHidden:Connect(function()
		hidden:Disconnect()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		bb:Destroy()
	end)
end)
