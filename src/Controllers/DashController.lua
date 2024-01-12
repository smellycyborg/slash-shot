-- Todo:  fix context action service overriding roblox default sometimes
-- Todo:  dash animation

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")

local Knit = require(Packages:WaitForChild("knit"))

local TIME_FOR_DASH = 0.4

local keyPressed = nil
local timeStamp = nil

local player = Players.LocalPlayer

local DashController = Knit.CreateController({
    Name = "DashController",
})

local function _playSoundInWorkspace(soundName, part)
    local clone = Sounds:FindFirstChild(soundName):Clone()
    clone.Parent = part
    clone.Ended:Connect(function()
        clone:Destroy()
    end)

    clone:Play()
end

local function _getConstraints(character)
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local rootAtt = rootPart:WaitForChild("RootAttachment")

    local linearVelocity = rootAtt:FindFirstChild("DashVelocity")
    if not linearVelocity then
        linearVelocity = Instance.new("LinearVelocity")
        linearVelocity.Name = "DashVelocity"
        linearVelocity.Attachment0 = rootAtt
        linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
        linearVelocity.Enabled = false
        linearVelocity.MaxForce = 250000
        linearVelocity.Parent = rootPart
    end

    local alignOri = rootPart:FindFirstChild("AlignOrientation")
    if not alignOri then
        alignOri = Instance.new("AlignOrientation")
        alignOri.Enabled = false
        alignOri.Attachment0 = rootAtt
        alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.MaxTorque = math.huge
        alignOri.Responsiveness = 200
        alignOri.Parent = rootPart
    end

    return linearVelocity, alignOri
end

local function _dash(equipped)
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        return
    end

    local soundName, dashForce = nil, 1
    if equipped == "SlotOne" then
        soundName = "DashOne"
        dashForce = 80
    elseif equipped == "SlotTwo" or equipped == "SlotThree" then
        soundName = "DashTwo"
        dashForce = 40
    end

    -- local dashVelocity, alignOri = _getConstraints(player.Character)

    -- local direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)

    -- humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    -- humanoid.PlatformStand = true

    -- alignOri.CFrame = CFrame.new(rootPart.Position, rootPart.Position + direction)
    -- dashVelocity.VectorVelocity =  direction * dashForce

    -- alignOri.Enabled = true
    -- dashVelocity.Enabled = true

    if soundName then
        _playSoundInWorkspace(soundName, rootPart)
    end
end

local function _turnOffDash()
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        return
    end

    local dashVelocity = rootPart:FindFirstChild("DashVelocity")
    if dashVelocity then
        dashVelocity:Destroy()
    end
    local alignOri = rootPart:FindFirstChild("AlignOrientation")
    if alignOri then
        alignOri:Destroy()
    end

    rootPart.Velocity = Vector3.zero

    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    humanoid.PlatformStand = false
end

function DashController:KnitInit()
    DashService = Knit.GetService("DashService")

    local function handleAction(_actionName, inputState, input)
        if inputState ~= Enum.UserInputState.Begin then
            return
        end
        
        local function _setKeyPressed()
            keyPressed = input.KeyCode

            timeStamp = tick()

            print("set keyPressed to:  ", keyPressed, "  set timeStamp.")
        end

        warn("KeyCode:  ", input.KeyCode)
        warn("InputState:  ", inputState)

        local character = player.Character
        if not character then
            return
        end

        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            return
        end

        local moveDirection = character.HumanoidRootPart.CFrame.LookVector
        humanoid:MoveTo(character.HumanoidRootPart.Position + moveDirection * 5)

        if not keyPressed then
            _setKeyPressed()
        elseif keyPressed ~= input.KeyCode then
            _setKeyPressed()
        elseif keyPressed == input.KeyCode then
            print("keyPressed matches input Keycode.")

            local currentTime = tick() - timeStamp
            if currentTime < TIME_FOR_DASH then
                
                DashService:dash(input.KeyCode.Name):andThen(function(canDash, equipped)
                    if canDash then
                        _dash(equipped)

                        print("supposed to be dashing.")
                    else
                        print("player cannot dash.")
                    end

                    timeStamp = nil
                    keyPressed = nil
                end)
            else
                _setKeyPressed()
            end
        end
    end

    ContextActionService:BindActionAtPriority(
        "Dash", handleAction, false, 2,
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.S
    )
end

function DashController:KnitStart()
    local function onTurnOffDash()
        -- _turnOffDash()
    end

    DashService.TurnOffDash:Connect(onTurnOffDash)
end

return DashController