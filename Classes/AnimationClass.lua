local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages

local Signal = require(Packages.signal)

local animation = {}
local animationPrototype = {}
local animationPrivate = {}

function animation.new(id: number, isUrl: boolean, fadeTime: number, weight:number, speed: number)
	assert(id, "Attempt to index nil with id.")

	local self = {}
	local private = {}

	self.ended = Signal.new()

	private.animation = Instance.new("Animation")
	private.animation.AnimationId = not isUrl and "http://www.roblox.com/asset/?id=" .. id or id
	
	private.fadeTime = fadeTime
	private.weight = weight
	private.speed = speed

	private.track = nil
	private.shutdown = nil
	
	animationPrivate[self] = private

	return setmetatable(self, animationPrototype)
end

function animationPrototype:setTrack(player, priority)
	local private = animationPrivate[self]

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local function trackEnded()
		self.ended:Fire()
	end

	local track = animator:LoadAnimation(private.animation)
	track.Priority = priority
	track.Ended:Connect(trackEnded)

	private.track = track
end

function animationPrototype:play(isLooped: boolean)
	local private = animationPrivate[self]

	local track = private.track
	track:Play(private.fadeTime, private.weight, private.speed)

	if isLooped then
		private.task = task.spawn(function()
			while track do
				track:Play()
				track.Ended:Wait()
			end
		end)
	end
end

function animationPrototype:stop()
	local private = animationPrivate[self]

	if private.track then
		if private.task then
			task.cancel(private.task)
			private.task = nil
		end
		
		private.track:Stop()
		-- private.track:Destroy()
	end
end

function animationPrototype:isPlaying()
	local private = animationPrivate[self]
	return private.track.IsPlaying
end

function animationPrototype:destroy()
	local private = animationPrivate[self]

	private.ended:Destroy()

	self = nil
end

animationPrototype.__index = animationPrototype

return animation