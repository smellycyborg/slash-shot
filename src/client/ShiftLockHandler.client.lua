local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MAX_LENGTH = 900000
local ENABLED_OFFSET = CFrame.new(4, 0, 0)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local shiftLockOff = false

local function _makeLockCurrentPosition()
    if not shiftLockOff then
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCurrentPosition then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        end
    else
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end
end

local function _getUpdatedCameraCFrame()
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart", 5)
    if not rootPart then
        return
    end

	return CFrame.new(
		rootPart.Position,
		Vector3.new(camera.CFrame.LookVector.X * MAX_LENGTH,
		rootPart.Position.Y,
		camera.CFrame.LookVector.Z * MAX_LENGTH)
	)
end

local function _updateCharacterRotation()
    local character = player.Character
    if character then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = _getUpdatedCameraCFrame()
        end
    end
end

local function _updateCamera()
    camera.CFrame *= ENABLED_OFFSET
end

local function renderStepped()
    _makeLockCurrentPosition()
    _updateCharacterRotation()
    _updateCamera()
end

local function inputBegan(input, gameProcessedEvent)
    if input.KeyCode == Enum.KeyCode.V then
        shiftLockOff = not shiftLockOff
    end
end

RunService.RenderStepped:Connect(renderStepped)
UserInputService.InputBegan:Connect(inputBegan)