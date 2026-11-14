-- 녹화용 연출 4(방, 직원, 시음회, 물약 효과, 로벅스 상점판. Client 에서 실행)
-- 주인인 아바타가 가게로 걸어 들어가 솥을 젓고, 돈이 모일 때마다 칸을 사고 가구를 놓는다.
-- 게임 값은 건드리지 않는다. 돈은 손님과 젓기로만 모이고, 값이 모였을 때만 산다.
-- 장면마다 벽시계 시각을 _G.noeuriLog 에 남긴다(편집이 이 시각으로 자른다).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local PFS = game:GetService("PathfindingService")

local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid") :: Humanoid
local root = char:WaitForChild("HumanoidRootPart") :: BasePart
local cam = workspace.CurrentCamera
local state = RS:WaitForChild("ShopState")
local money = state:WaitForChild("Money")
local nextTile = state:WaitForChild("NextTilePrice")
local shop = workspace:WaitForChild("Shop")
local hud = plr:WaitForChild("PlayerGui"):WaitForChild("ShopHud")
local V = Vector3.new
local T = 16

-- 녹화 화면에 마우스 화살표와 채팅 안내가 남지 않게 한다
game:GetService("UserInputService").MouseIconEnabled = false
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)

_G.noeuriLog = {}
_G.noeuriPhase = "start"
local function mark(name)
	table.insert(_G.noeuriLog, string.format("%.3f %s money=%d", DateTime.now().UnixTimestampMillis / 1000, name, money.Value))
	_G.noeuriPhase = name
end

local function tileCenter(c, r)
	return V(c * T, 1, -5 + r * T)
end
local function flat(v)
	return V(v.X, 0, v.Z)
end
local function ease(t)
	return t * t * (3 - 2 * t)
end

---------------------------------------------------------------- 카메라: 목표 위치로 부드럽게 따라간다
local camPos, camLook = V(-34, 26, 40), V(0, 2, -6)
local followPart = nil
local followOffset = V(0, 9, 12)
local goalPos, goalLook = camPos, camLook
local mode = "fixed"
local chaseOffset = V(0, 15, 19)
local rate = 2.2
cam.CameraType = Enum.CameraType.Scriptable
RunService:BindToRenderStep("noeuriCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if mode == "chase" then
		goalPos = root.Position + chaseOffset
		goalLook = root.Position + V(0, 2, 0)
	elseif mode == "follow" and followPart and followPart.Parent then
		goalPos = followPart.Position + followOffset
		goalLook = followPart.Position + V(0, 1, 0)
	end
	if mode ~= "direct" then
		local a = 1 - math.exp(-rate * dt)
		camPos = camPos:Lerp(goalPos, a)
		camLook = camLook:Lerp(goalLook, a)
	end
	cam.CFrame = CFrame.lookAt(camPos, camLook)
end)

local function setCam(p, l)
	mode = "fixed"
	goalPos, goalLook = p, l
end
local function chaseCam(offset)
	chaseOffset = offset or V(0, 15, 19)
	mode = "chase"
end
local function dolly(p0, l0, p1, l1, dur)
	mode = "direct"
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = ease(a)
		camPos, camLook = p0:Lerp(p1, e), l0:Lerp(l1, e)
		if a >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	goalPos, goalLook = camPos, camLook
	mode = "fixed"
end

-- 지금 가게 전체가 보이는 자리(바닥 칸들의 가운데와 크기로 정한다)
local function overview()
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, f in ipairs(shop.Floors:GetChildren()) do
		if f:IsA("BasePart") and f.Name:sub(1, 6) == "Floor_" then
			minX = math.min(minX, f.Position.X - T / 2)
			maxX = math.max(maxX, f.Position.X + T / 2)
			minZ = math.min(minZ, f.Position.Z - T / 2)
			maxZ = math.max(maxZ, f.Position.Z + T / 2)
		end
	end
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local span = math.max(maxX - minX, maxZ - minZ)
	local d = 14 + span * 0.75
	return V(cx + d * 0.22, d * 0.8, maxZ + d * 0.75), V(cx, 1, cz - 1), cx, cz, span
end

---------------------------------------------------------------- 걷기
local function walkTo(goal)
	local path = PFS:CreatePath({AgentRadius = 1.4, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 3})
	local ok = pcall(function()
		path:ComputeAsync(root.Position, goal)
	end)
	local pts = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for _, w in ipairs(path:GetWaypoints()) do
			table.insert(pts, w.Position)
		end
	else
		pts = {goal}
	end
	for _, p in ipairs(pts) do
		hum:MoveTo(p)
		local t0 = os.clock()
		while os.clock() - t0 < 4 do
			task.wait(0.05)
			if (flat(root.Position) - flat(p)).Magnitude < 1.3 then
				break
			end
		end
	end
	hum:MoveTo(root.Position)
end

local function face(target)
	root.CFrame = CFrame.lookAt(root.Position, V(target.X, root.Position.Y, target.Z))
end

local function onlyPrompt(keep)
	local off = {}
	for _, d in ipairs(shop:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d ~= keep and d.Enabled then
			d.Enabled = false
			table.insert(off, d)
		end
	end
	return function()
		for _, d in ipairs(off) do
			d.Enabled = true
		end
	end
end

local function press(prompt)
	local restore = onlyPrompt(prompt)
	task.wait(0.1)
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.25)
	prompt:InputHoldEnd()
	restore()
end

-- 돈이 need() 만큼 모일 때까지 가게 전체를 보며 기다린다
local function waitMoney(tag, need)
	if money.Value >= need() then
		return
	end
	mark("wait_" .. tag)
	local p, l = overview()
	setCam(p, l)
	while money.Value < need() do
		task.wait(0.2)
	end
end

---------------------------------------------------------------- 칸 사기, 가구 놓기
local function buyTile(c, r)
	local tag = "tile_" .. c .. "_" .. r
	waitMoney(tag, function()
		return nextTile.Value
	end)
	local tr = shop.ForSale:WaitForChild("Expand_" .. c .. "," .. r, 5)
	if not tr then
		mark("skip_" .. tag)
		return
	end
	local target = tileCenter(c, r)
	local tp = tr.Position
	local dir = flat(target - tp).Unit
	local stand = V(tp.X, 1, tp.Z) - dir * 3.2
	mark("go_" .. tag)
	chaseCam()
	walkTo(stand)
	face(target)
	local mid = (V(tp.X, 1, tp.Z) + target) / 2
	setCam(mid + V(dir.Z * 6, 22, 24), mid)
	task.wait(1.6)
	mark("buy_" .. tag)
	press(tr:FindFirstChild("ExpandPrompt"))
	task.wait(3.2)
	mark("seen_" .. tag)
end

local function place(slotId, itemId)
	local tag = itemId .. "_" .. slotId:gsub(",", "_"):gsub("#", "_")
	waitMoney(tag, function()
		return (state:GetAttribute("Price_" .. itemId) or 0) + 200
	end)
	local marker = shop.Slots:FindFirstChild("Slot_" .. slotId)
	if not marker then
		mark("skip_" .. tag)
		return
	end
	local c, r = slotId:match("^(%-?%d+),(%-?%d+)#")
	local ctr = tileCenter(tonumber(c), tonumber(r))
	local sp = V(marker.Position.X, 1, marker.Position.Z)
	local stand = ctr + (sp - ctr).Unit * 0.6
	mark("go_" .. tag)
	chaseCam()
	walkTo(stand)
	face(sp)
	-- 가구 창이 화면 오른쪽에 뜨니 아바타와 자리는 왼쪽에 오게 잡는다
	local subj = (sp + stand) / 2 + V(0, 1.5, 0)
	setCam(subj + V(-1, 12, 16), subj + V(4.5, 0, 0))
	task.wait(1.4)
	mark("menu_" .. tag)
	press(marker:FindFirstChild("PlacePrompt"))
	task.wait(1.8)
	mark("pick_" .. tag)
	hud.Pick:Fire(itemId)
	task.wait(3.2)
	mark("placed_" .. tag)
end

local function cut(p, l)
	mode = "direct"
	camPos, camLook = p, l
	goalPos, goalLook = p, l
	RunService.RenderStepped:Wait()
	mode = "fixed"
end
local function follow(part, offset)
	followPart = part
	followOffset = offset or V(0, 9, 12)
	mode = "follow"
end

-- 칸을 사면서 방 종류를 고른다(창이 오른쪽에 뜨니 아바타는 왼쪽에)
local function buildRoom(c, r, roomId)
	local tag = "room_" .. roomId .. "_" .. c .. "_" .. r
	waitMoney(tag, function()
		return nextTile.Value
	end)
	local tr = shop.ForSale:WaitForChild("Expand_" .. c .. "," .. r, 5)
	if not tr then
		mark("skip_" .. tag)
		return
	end
	local target = tileCenter(c, r)
	local tp = tr.Position
	local dir = flat(target - tp).Unit
	local stand = V(tp.X, 1, tp.Z) - dir * 3.2
	mark("go_" .. tag)
	chaseCam()
	walkTo(stand)
	face(target)
	local subj = V(tp.X, 2.5, tp.Z) - dir * 1.5
	setCam(subj + V(-1, 12, 16), subj + V(4.5, 0, 0))
	task.wait(1.4)
	mark("menu_" .. tag)
	press(tr:FindFirstChild("ExpandPrompt"))
	task.wait(2.0)
	mark("pick_" .. tag)
	hud.Pick:Fire(roomId)
	task.wait(0.4)
	local mid = (V(tp.X, 1, tp.Z) + target) / 2
	setCam(mid + V(dir.Z * 6, 22, 24), mid)
	task.wait(3.0)
	mark("seen_" .. tag)
end

-- 직원 고용: 직원 단추 목록에서 골라 컷인을 보고, 일하는 모습을 가까이서 본다
local STAFF_VIEW = {
	Barker = {V(12, 6.5, 17), V(7.2, 4.5, 8)},
	Cook = {V(-0.5, 8, 0.5), V(-3.9, 3.5, -8.4)},
}
local function hire(id)
	local tag = "staff_" .. id
	waitMoney(tag, function()
		return (state:GetAttribute("StaffPrice_" .. id) or 0) + 200
	end)
	local p, l = overview()
	setCam(p, l)
	task.wait(1.0)
	mark("menu_" .. tag)
	hud.OpenStaff:Fire()
	task.wait(2.0)
	mark("pick_" .. tag)
	hud.PanelPick:Fire(id)
	task.wait(2.6)
	mark("work_" .. tag)
	local m = shop:WaitForChild("Staff"):WaitForChild(id, 5)
	local v = STAFF_VIEW[id]
	if v then
		cut(v[1], v[2])
	elseif m and m:FindFirstChild("HumanoidRootPart") then
		local rp = m.HumanoidRootPart
		cut(rp.Position + V(0, 13, 9), rp.Position + V(0, 1, 0))
		follow(rp, V(0, 13, 9))
	end
	task.wait(5.5)
	mode = "fixed"
	mark("end_" .. tag)
end

local function clearShot(m, rp)
	local look = flat(rp.CFrame.LookVector)
	look = look.Magnitude > 0.1 and look.Unit or V(0, 0, 1)
	local right = look:Cross(V(0, 1, 0)).Unit
	local aim = rp.Position + V(0, 1.2, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = {m, char}
	local frog = workspace:FindFirstChild("Frog", true)
	if frog then
		table.insert(ex, frog)
	end
	params.FilterDescendantsInstances = ex
	local cands = {
		look * 6 + V(0, 5, 0), look * 5 + right * 3 + V(0, 6, 0), look * 5 - right * 3 + V(0, 6, 0),
		right * 6 + look * 2 + V(0, 5, 0), -right * 6 + look * 2 + V(0, 5, 0), look * 3 + V(0, 10, 0),
	}
	for _, off in ipairs(cands) do
		local pos = aim + off
		local a = workspace:Raycast(pos, aim - pos, params)
		local b = workspace:Raycast(aim, pos - aim, params)
		if not a and not b then
			return pos, aim
		end
	end
	return aim + look * 3 + V(0, 10, 0), aim
end

-- 물약 효과 셋을 한 번씩: 손님이 마시다 효과가 나면 그 손님 앞으로 바로 옮긴다
local function fxHunt(limit)
	local seen = {}
	local count = 0
	local t0 = os.clock()
	local p, l = overview()
	cut(p, l)
	while count < 3 and os.clock() - t0 < limit do
		local found = nil
		for _, m in ipairs(workspace.Customers:GetChildren()) do
			local k = m:GetAttribute("Fx")
			if k and not seen[k] and not m:GetAttribute("Taster") and m:FindFirstChild("HumanoidRootPart") then
				found = m
				break
			end
		end
		if found then
			local k = found:GetAttribute("Fx")
			seen[k] = true
			count += 1
			local cp, cl = clearShot(found, found.HumanoidRootPart)
			cut(cp, cl)
			mark("fx_" .. k)
			task.wait(3.0)
			cut(p, l)
		else
			task.wait(0.05)
		end
	end
	mark("fx_done_" .. count)
end

---------------------------------------------------------------- 1. 빈 땅 위 작은 가게
mark("s1_open")
dolly(V(-36, 28, 42), V(0, 2, -6), V(18, 15, 26), V(0, 2, -6), 13)

-- 2. 아바타가 거리에서 가게로 들어간다
mark("s2_walk")
chaseCam(V(4, 12, 16))
walkTo(V(0, 1, 6))
walkTo(V(4.8, 1, -4.2))
walkTo(V(0.6, 1, -4.4))
face(V(0, 1, -9))

mark("s2_eat")
setCam(V(0, 9.5, 9), V(0, 3.4, -1.5))
task.wait(6)

-- 3. 솥 앞에서 물약 젓기(팁)
mark("s3_stir")
setCam(V(-6, 9.5, 1.5), V(0.5, 3.6, -7.5))
task.wait(1.2)
local stir = shop:FindFirstChild("StirPrompt", true)
for _ = 1, 6 do
	if stir then
		press(stir)
	end
	task.wait(0.7)
end
mark("s3_stir_end")
task.wait(1)

-- 4. 방 짓기와 방마다 다른 가구
mark("s4_rooms")
buildRoom(1, 0, "Guest")
place("1,0#2", "Table")
buildRoom(-1, 0, "Brew")
place("-1,0#2", "Herbs")
buildRoom(0, -1, "Rest")
place("0,-1#2", "Sofa")
place("-1,0#1", "Crystal")
place("1,0#1", "Table")

-- 쉼터 소파에서 쉬는 손님
mark("s4_rest")
cut(V(0, 11, -9), V(0, 2, -21.5))
task.wait(5)

-- 물약 효과 셋
mark("s4_fx")
fxHunt(150)

-- 5. 직원 넷
mark("s5_staff")
hire("Barker")
hire("Server")
hire("Cook")
hire("Cashier")

-- 6. 방을 더 짓고 이벤트 무대
mark("s6_more")
buildRoom(1, -1, "Brew")
place("1,-1#2", "Cauldron")
buildRoom(-1, -1, "Guest")
place("-1,-1#1", "Table")
place("-1,-1#2", "Cat")
buildRoom(-2, 0, "Stage")

-- 물약 시음회
mark("s6_wait_event")
local sc = tileCenter(-2, 0) + V(0, 0, -1.5)
setCam(sc + V(9, 13, 20), sc + V(0, 1, 0))
local tw = os.clock()
while not state:GetAttribute("EventOn") and os.clock() - tw < 30 do
	task.wait(0.1)
end
mark("s6_event")
task.wait(6.5)
setCam(sc + V(4, 8, 12), sc + V(0, 2, 0))
task.wait(8)
mark("s6_event_end")

-- 로벅스 상점 창(시험 구매 창이 한 번 보이고 닫힌다. 사지 않는다)
mark("s6_shop")
local p0, l0 = overview()
setCam(p0, l0)
task.wait(1.5)
hud.OpenShop:Fire()
task.wait(2.6)
mark("shop_pick")
local closed = false
local conn = game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function()
	closed = true
end)
hud.PanelPick:Fire("Tasting")
task.wait(1.0)
-- 녹화 도우미가 이 표시를 보고 시험 구매 창의 X 를 누른다(사지 않는다)
mark("shop_prompt")
local tc = os.clock()
while not closed and os.clock() - tc < 30 do
	task.wait(0.05)
end
conn:Disconnect()
mark("shop_closed")
task.wait(1.5)
mark("shop_end")

-- 7. 가만히 둬도 손님이 꽉 차고 돈이 쌓인다
mark("s7_idle")
local p, l, cx, cz, span = overview()
setCam(p, l)
task.wait(16)

mark("s7_tour")
dolly(V(cx - span * 0.5, 15, cz + 17), V(cx - span * 0.25, 2, cz - 5), V(cx + span * 0.5, 15, cz + 17), V(cx + span * 0.25, 2, cz - 5), 15)

-- 8. 다 키운 가게를 한 바퀴
mark("s8_orbit")
local center = V(cx, 2, cz)
local radius = 18 + span * 0.7
local function orbitPos(deg)
	local rr = math.rad(deg)
	return center + V(math.sin(rr) * radius, radius * 0.55, math.cos(rr) * radius)
end
mode = "direct"
local tA = os.clock()
while true do
	local a = math.clamp((os.clock() - tA) / 18, 0, 1)
	camPos, camLook = orbitPos(-50 + 100 * ease(a)), center
	if a >= 1 then
		break
	end
	RunService.RenderStepped:Wait()
end
goalPos, goalLook = camPos, camLook
mode = "fixed"
task.wait(2)
mark("end")
