local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Classes = ReplicatedStorage:WaitForChild("Classes")

local AnimationClass = require(Classes:WaitForChild("AnimationClass"))

local LEFT_ID, RIGHT_ID = 16042944839, 16042947925
local SLIDING_ID = 15986675012
local UP_WALL_ID = 16022710146
local BACKFLIP_ID = 16022784702
local RIGHT_FLIP_ID = 16043102884
local LEFT_FLIP_ID = 16043110160

local NOT_URL = false

local player = Players.LocalPlayer

local canRun, canSlide = true, true
local isRunning, isSliding = false, false

local leftAnimation, rightAnimation = AnimationClass.new(LEFT_ID, NOT_URL, 0.3, 1, 2.7), AnimationClass.new(RIGHT_ID, NOT_URL, 0.3, 1, 2.7)
local slidingAnimation = AnimationClass.new(SLIDING_ID, NOT_URL, 0.3, 1, 1.7)
local upWallRunAnim = AnimationClass.new(UP_WALL_ID, NOT_URL, 0.2, 1, 3)
local backFlipAnim = AnimationClass.new(BACKFLIP_ID, NOT_URL, 0.2, 1, 3)
local leftFlipAnim = AnimationClass.new(LEFT_FLIP_ID, NOT_URL, 0.2, 1, 4)
local rightFlipAnim = AnimationClass.new(RIGHT_FLIP_ID, NOT_URL, 0.2, 1, 4)

local animation, result, forwardDirection, leftResult, rightResult

local function _setLinearVelocity(humanoid, rootPart, direction)
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	rootPart.AssemblyLinearVelocity = direction
end

local function _setLinearVelocityToFalse(humanoid, rootPart)
	humanoid.PlatformStand = false

	if humanoid:GetState() == Enum.HumanoidStateType.Physics then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function characterAdded(character)
    leftAnimation:setTrack(player, Enum.AnimationPriority.Action)
	rightAnimation:setTrack(player, Enum.AnimationPriority.Action)
	slidingAnimation:setTrack(player, Enum.AnimationPriority.Action)
	upWallRunAnim:setTrack(player, Enum.AnimationPriority.Action)
	backFlipAnim:setTrack(player, Enum.AnimationPriority.Action)
	rightFlipAnim:setTrack(player, Enum.AnimationPriority.Action)
	leftFlipAnim:setTrack(player, Enum.AnimationPriority.Action)
end
if player.Character then
	characterAdded(player.Character)
end
player.CharacterAdded:Connect(characterAdded)

UserInputService.JumpRequest:Connect(function()
	local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	local function handleJump(anim)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping, true)
		canRun = false
		canSlide = false

		anim:play()

		task.delay(0.4, function()
			canRun = true
			canSlide = true
		end)
	end

	local forceDirection, anim
	if isRunning then
		local rootCFrame = rootPart.CFrame
		local rightDirection = rootCFrame.RightVector
		local leftDirection = -rightDirection

		if result == rightResult then
			forceDirection = (leftDirection + Vector3.new(0, 1, 0)) * 65
			anim = leftFlipAnim
		else
			forceDirection = (rightDirection + Vector3.new(0, 1, 0)) * 65
			anim = rightFlipAnim
		end

		handleJump(anim)

	elseif isSliding then
		anim = backFlipAnim

		handleJump(anim)

		local characterLookVector = rootPart.CFrame.LookVector.Unit
		forceDirection = Vector3.new(-characterLookVector.x, 1, -characterLookVector.z) * 65
	end

	if forceDirection then
		rootPart.AssemblyLinearVelocity = forceDirection
	end
end)

game["Run Service"].Stepped:Connect(function(stepTime, step)
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	
	local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local characterLookVector = rootPart.CFrame.LookVector.Unit

	local rootCFrame = rootPart.CFrame
	local rightDirection = rootCFrame.RightVector
	local leftDirection = -rightDirection

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {player.Character}

	local downResult = workspace:Raycast(rootPart.Position, Vector3.new(0, -1 * 3, 0), raycastParams)
	leftResult = workspace:Raycast(rootPart.Position, leftDirection * 2, raycastParams)
	rightResult = workspace:Raycast(rootPart.Position, rightDirection * 2, raycastParams)
	local forwardResult = workspace:Raycast(rootPart.Position, characterLookVector * 2.5, raycastParams)

	result = leftResult or rightResult

	if not downResult then
		if forwardResult and canSlide and not result then
			if forwardResult.Instance:GetAttribute("Parkour") == nil then
				return warn("Result Instance:  ", forwardResult.Instance)
			end

			isSliding = true

			_setLinearVelocity(humanoid, rootPart, Vector3.new(0, 1, 0) * 30)

			if not upWallRunAnim:isPlaying() then
				upWallRunAnim:play()
			end
		elseif result and canRun then
			if result.Instance:GetAttribute("Parkour") == nil then
				return
			end

			isRunning = true

			forwardDirection = result.Normal:Cross(result.Instance.CFrame.UpVector).Unit

			local dotProduct = characterLookVector:Dot(forwardDirection)
			if dotProduct < 0 then
				forwardDirection = -forwardDirection
			end
			
			rootPart.AssemblyLinearVelocity = forwardDirection * 30
			
			if result == leftResult then
				animation = leftAnimation
			else
				animation = rightAnimation
			end

			if not animation:isPlaying() then
				animation:play()
			end
		end
	end

	if not canRun or not result then
		isRunning = false

		_setLinearVelocityToFalse(humanoid, rootPart)

		if animation then
			if animation:isPlaying() then
				animation:stop()
			end
		end
	end

	if not canSlide or not forwardResult then
		isSliding = false

		_setLinearVelocityToFalse(humanoid, rootPart)
	
		if upWallRunAnim:isPlaying() then
			upWallRunAnim:stop()
		end

		if slidingAnimation:isPlaying() then
			slidingAnimation:stop()
		end
	end
	
	--warn("Forward Direction:  ", forwardDirection)
	--warn("Down Result:  ", downResult)
	--warn("Left Reult:  ", leftResult)
	--warn("Right Result:  ", rightResult)
end)