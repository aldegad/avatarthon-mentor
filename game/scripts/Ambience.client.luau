-- 배경음악과 숲 소리(각자 화면에서 튼다)
local SoundService = game:GetService("SoundService")

local function loop(name, id, volume)
	local s = SoundService:FindFirstChild(name) or Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume
	s.Looped = true
	s.Parent = SoundService
	s:Play()
end

loop("BGM", "rbxassetid://136001951028964", 0.35)
loop("Forest", "rbxassetid://110236513497336", 0.3)
