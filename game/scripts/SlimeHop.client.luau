-- 슬라임 손님은 다리가 없어 걷는 대신 통통 튄다(각자 화면에서 몸통 이음새만 움직인다)
local RunService = game:GetService("RunService")
local customers = workspace:WaitForChild("Customers")

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, m in ipairs(customers:GetChildren()) do
		if m:GetAttribute("Hop") then
			local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			local joint = root and root:FindFirstChild("Body") :: Motor6D?
			if root and joint then
				local base = joint:GetAttribute("BaseC0") or joint.C0
				if not joint:GetAttribute("BaseC0") then
					joint:SetAttribute("BaseC0", base)
				end
				local v = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
				local phase = t * 2 + (m:GetAttribute("Seed") or 0)
				local y
				if v.Magnitude > 1 and not m:GetAttribute("Sitting") then
					y = math.abs(math.sin(phase * 4.5)) * 0.9
				else
					y = math.sin(phase * 1.5) * 0.08
				end
				joint.C0 = base * CFrame.new(0, y, 0)
			end
		end
	end
end)
