-- 손님·직원 걷기, 서 있기, 앉기 애니메이션(로블록스 기본 R15 애니메이션을 서버에서 튼다)
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)

local function load(id)
	local a = Instance.new("Animation")
	a.AnimationId = id
	local track = animator:LoadAnimation(a)
	track.Looped = true
	return track
end

local walkTrack = load("rbxassetid://16562332340")
local idleTrack = load("rbxassetid://16562317918")
local sitTrack = load("rbxassetid://2506281703")
idleTrack:Play()

local function sitting()
	return char:GetAttribute("Sitting") == true
end

hum.Running:Connect(function(speed)
	if sitting() then
		return
	end
	if speed > 0.5 then
		if not walkTrack.IsPlaying then
			idleTrack:Stop(0.2)
			walkTrack:Play(0.2)
		end
		walkTrack:AdjustSpeed(math.clamp(speed / 10, 0.6, 1.6))
	else
		if walkTrack.IsPlaying then
			walkTrack:Stop(0.2)
		end
		if not idleTrack.IsPlaying then
			idleTrack:Play(0.2)
		end
	end
end)

char:GetAttributeChangedSignal("Sitting"):Connect(function()
	if sitting() then
		walkTrack:Stop(0.1)
		idleTrack:Stop(0.1)
		sitTrack:Play(0.15)
	else
		sitTrack:Stop(0.15)
		idleTrack:Play(0.2)
	end
end)
