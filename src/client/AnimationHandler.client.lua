local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Classes = ReplicatedStorage:WaitForChild("Classes")

local AnimationClass = require(Classes:WaitForChild("AnimationClass"))

local WALKING_BACK_ID = 16001594529
local LEFT_WALK_ID = 16002282672
local IDLE_ID = 16001688566
local RIGHT_WALK_ID = 16002332424
local FRONT_WALK_ID = 16008389034

local NOT_URL = false

local player = Players.LocalPlayer

local walkingBackAnim = AnimationClass.new(WALKING_BACK_ID, NOT_URL, 0.3, 1, 1.7)
local idleAnim = AnimationClass.new(IDLE_ID, NOT_URL, 0.3, 1, 1.7)
local leftWalkAnim = AnimationClass.new(LEFT_WALK_ID, NOT_URL, 0.3, 1, 1.7)
local rightWalkAnim = AnimationClass.new(RIGHT_WALK_ID, NOT_URL, 0.3, 1, 1.7)
local frontWalkAnim = AnimationClass.new(FRONT_WALK_ID, NOT_URL, 0.3, 1, 1.7)

local keysPressed = {}

local stateChanged

local function characterAdded(character)
    walkingBackAnim:setTrack(player, Enum.AnimationPriority.Movement)
    idleAnim:setTrack(player, Enum.AnimationPriority.Movement)
    leftWalkAnim:setTrack(player, Enum.AnimationPriority.Movement)
    rightWalkAnim:setTrack(player, Enum.AnimationPriority.Movement)
    frontWalkAnim:setTrack(player, Enum.AnimationPriority.Movement)

    local humanoid = character.Humanoid

    if stateChanged then
        stateChanged:Disconnect()
    end

    stateChanged = humanoid.StateChanged:Connect(function(oldState, newState)

    end)
end

if player.Character then
    characterAdded(player.Character)
end
player.CharacterAdded:Connect(characterAdded)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if input.KeyCode == Enum.KeyCode.W
    or input.KeyCode == Enum.KeyCode.A
    or input.KeyCode == Enum.KeyCode.S
    or input.KeyCode == Enum.KeyCode.D then
        keysPressed[#keysPressed+1] = input.KeyCode.Name
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
    table.remove(keysPressed, table.find(keysPressed, input.KeyCode.Name))
end)

RunService.Stepped:Connect(function(_stepTIme, step)
    local character = player.Character
    if not character then
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    local dashBool = player:FindFirstChild("DashBool")
    if not dashBool then
        return
    end

    if next(keysPressed) ~= nil and dashBool.Value == false then
        local keyName = keysPressed[#keysPressed]
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCurrentPosition then
            rightWalkAnim:stop()
            leftWalkAnim:stop()
            walkingBackAnim:stop()

            if not frontWalkAnim:isPlaying() then
                frontWalkAnim:play()
            end
        elseif UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
            if keyName == "W" then
                rightWalkAnim:stop()
                leftWalkAnim:stop()
                walkingBackAnim:stop()

                if not frontWalkAnim:isPlaying() then
                    frontWalkAnim:play()
                end
            elseif keyName == "A" then
                rightWalkAnim:stop()
                frontWalkAnim:stop()
                walkingBackAnim:stop()

                if not leftWalkAnim:isPlaying() then
                    leftWalkAnim:play()
                end
            elseif keyName == "S" then
                rightWalkAnim:stop()
                leftWalkAnim:stop()
                frontWalkAnim:stop()

                if not walkingBackAnim:isPlaying() then
                    walkingBackAnim:play()
                end
            elseif keyName == "D" then
                frontWalkAnim:stop()
                leftWalkAnim:stop()
                walkingBackAnim:stop()

                if not rightWalkAnim:isPlaying() then
                    rightWalkAnim:play()
                end
            end
        end
    else
        if walkingBackAnim:isPlaying() then
            walkingBackAnim:stop()
        end

        if leftWalkAnim:isPlaying() then
            leftWalkAnim:stop()
        end

        if rightWalkAnim:isPlaying() then
            rightWalkAnim:stop()
        end

        if frontWalkAnim:isPlaying() then
            frontWalkAnim:stop()
        end
    end
    
    if rootPart.Velocity.Magnitude < 0.1 and dashBool.Value == false then
        if not idleAnim:isPlaying() then
            idleAnim:play()
        end
    else
        if idleAnim:isPlaying() then
            idleAnim:stop()
        end
    end
end)

player:WaitForChild("DashBool"):GetPropertyChangedSignal("Value"):Connect(function()
    if player:FindFirstChild("DashBool").Value == true then
        frontWalkAnim:stop()
        walkingBackAnim:stop()
        rightWalkAnim:stop()
        leftWalkAnim:stop()
        idleAnim:stop()
    end
end)
