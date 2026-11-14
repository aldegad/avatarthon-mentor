-- 리깅 원본을 workspace 에서 치운다: autosetup 결과는 ServerStorage.RigSources 로 옮기고, 리깅 전 원본은 지운다
local SS = game:GetService("ServerStorage")
local src = SS:FindFirstChild("RigSources") or Instance.new("Folder")
src.Name = "RigSources"
src.Parent = SS
local moved, removed = {}, {}
for _, m in ipairs(workspace:GetChildren()) do
	if m:IsA("Model") and (m.Name:match("^Rig") ~= nil) then
		if m.Name:match("_autosetup$") then
			local old = src:FindFirstChild(m.Name); if old then old:Destroy() end
			m.Parent = src
			table.insert(moved, m.Name)
		else
			m:Destroy()
			table.insert(removed, m.Name)
		end
	end
end
return "moved=" .. table.concat(moved, ",") .. " removed=" .. table.concat(removed, ",")
