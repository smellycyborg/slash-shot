-- Todo:  fix context action service overriding roblox default sometimes
-- Todo:  dash animation

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputState = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")
local Classes = ReplicatedStorage:WaitForChild("Classes")

local Knit = require(Packages:WaitForChild("knit"))
local AnimationClass = require(Classes:WaitForChild("AnimationClass"))

local TIME_FOR_DASH = 0.4
local BACK_DASH_ID = 16043509504
local RIGHT_DASH_ID = 16043414233
local LEFT_DASH_ID = 16043419549
local FORWARD_DASH_ID = 16043511940

local DashParticles = ReplicatedStorage:WaitForChild("DashParticles")

local backDashAnim = AnimationClass.new(BACK_DASH_ID, false, 0.1, 1, 1)
local rightDashAnim = AnimationClass.new(RIGHT_DASH_ID, false, 0.1, 1, 1)
local leftDashAnim = AnimationClass.new(LEFT_DASH_ID, false, 0.1, 1, 1)
local forwardDashAnim = AnimationClass.new(FORWARD_DASH_ID, false, 0.175, 1, 1)

local keyPressed = nil
local timeStamp = nil

local dashRequest, isDashing = false, false

local currentDashAnimation

local player = Players.LocalPlayer

local DashController = Knit.CreateController({
    Name = "DashController",
})

local function _handleDashParticles(particleFace)
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")

    for _, inst in rootPart:GetChildren() do
        task.spawn(function()
            if inst:IsA("ParticleEmitter") then
                inst.EmissionDirection = particleFace
                inst:Emit(inst.Rate)
            elseif inst:IsA("PointLight") then
                inst.Enabled = true

                task.delay(0.2, function()
                    inst.Enabled = false
                end)
            end
        end)
    end
end

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

    local alignAtt = rootAtt:FindFirstChild("AlignAtt")
    if not alignAtt then
        alignAtt = Instance.new("Attachment")
        alignAtt.Name = "AlignAtt"
        alignAtt.Parent = rootPart
    end

    local alignOri = rootPart:FindFirstChild("AlignOrientation")
    if not alignOri then
        alignOri = Instance.new("AlignOrientation")
        alignOri.Enabled = false
        alignOri.Attachment0 = alignAtt
        alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.MaxTorque = math.huge
        alignOri.Responsiveness = 200
        alignOri.Parent = rootPart
    end

    return linearVelocity, alignOri
end

local function _playAnimation(anim)
    if not anim:isPlaying() then
        anim:play()
    end
end

local function _dash(equipped, key)
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        isDashing = false
        return
    end

    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        isDashing = false
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

    local direction, particleFace
    local dashVelocity, alignOri = _getConstraints(player.Character)
    local flatSurfaceNormal = Vector3.new(0, 1, 0)

    local cameraCFrame = workspace.CurrentCamera.CFrame
    local forwardDirection = cameraCFrame.LookVector

    local projectedForwardDirection = forwardDirection - (forwardDirection:Dot(flatSurfaceNormal) * flatSurfaceNormal)

    local leftDirection = -projectedForwardDirection:Cross(flatSurfaceNormal)
    local rightDirection = projectedForwardDirection:Cross(flatSurfaceNormal)
    local backDirection = -projectedForwardDirection

    if key == Enum.KeyCode.A then
        currentDashAnimation = leftDashAnim
        direction = leftDirection
        particleFace = Enum.NormalId.Right
    elseif key == Enum.KeyCode.D then
        currentDashAnimation = rightDashAnim
        direction = rightDirection
        particleFace = Enum.NormalId.Left
    elseif key == Enum.KeyCode.W then
        currentDashAnimation = forwardDashAnim
        direction = projectedForwardDirection
        particleFace = Enum.NormalId.Back
    elseif key == Enum.KeyCode.S then
        currentDashAnimation = backDashAnim
        direction = backDirection
        particleFace = Enum.NormalId.Front
    end

    humanoid.PlatformStand = true
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    alignOri.CFrame = CFrame.new(rootPart.Position, rootPart.Position + direction)
    dashVelocity.VectorVelocity =  direction * dashForce

    alignOri.Enabled = true
    dashVelocity.Enabled = true

    if equipped == "SlotOne" then
        _handleDashParticles(particleFace)
    end

    if currentDashAnimation then
        _playAnimation(currentDashAnimation)
    end

    if soundName then
        _playSoundInWorkspace(soundName, rootPart)
    end

    -- print("DashController:  dashing.")
end

local function _turnOffDash()
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        isDashing = false
        return
    end

    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        isDashing = false
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

    if currentDashAnimation and currentDashAnimation:isPlaying() then
        currentDashAnimation:stop()
    end

    humanoid.PlatformStand = false
    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

    isDashing = false

    -- print("DashController:  turning off dash.")
end

function DashController:KnitInit()
    DashService = Knit.GetService("DashService")

    local function characterAdded(character)
        backDashAnim:setTrack(player, Enum.AnimationPriority.Action3)
        rightDashAnim:setTrack(player, Enum.AnimationPriority.Action3)
        leftDashAnim:setTrack(player, Enum.AnimationPriority.Action3)
        forwardDashAnim:setTrack(player, Enum.AnimationPriority.Action3)

        for _, inst in DashParticles:GetChildren() do
            local clone = inst:Clone()
            clone.Parent = player.Character:FindFirstChild("HumanoidRootPart")
        end
    end

    local function handleAction(_actionName, inputState, input)
        if dashRequest then
            return
        end

        dashRequest = true

        if inputState ~= Enum.UserInputState.Begin then
            dashRequest = false
            return
        end
        
        local function _setKeyPressed()
            keyPressed = input.KeyCode

            timeStamp = tick()

            task.wait()
            dashRequest = false

            -- return print("set keyPressed to:  ", keyPressed, "  set timeStamp.")
        end

        -- warn("KeyCode:  ", input.KeyCode)
        -- warn("InputState:  ", inputState)

        local character = player.Character
        if not character then
            dashRequest = false
            return
        end

        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            dashRequest = false
            return
        end

        -- local moveDirection = character.HumanoidRootPart.CFrame.LookVector
        -- humanoid:MoveTo(character.HumanoidRootPart.Position + moveDirection * 5)

        if not keyPressed then
            _setKeyPressed()
        elseif keyPressed ~= input.KeyCode then
            _setKeyPressed()
        elseif keyPressed == input.KeyCode then
            -- print("keyPressed matches input Keycode.")

            local currentTime = tick() - timeStamp
            if currentTime < TIME_FOR_DASH then
                DashService:dash(input.KeyCode.Name):andThen(function(canDash, equipped)
                    if canDash then
                        if not isDashing then
                            isDashing = true

                            _dash(equipped, keyPressed)
                        end

                        -- print("supposed to be dashing.")
                    else
                        -- print("player cannot dash.")
                    end

                    timeStamp = nil
                    keyPressed = nil

                    dashRequest = false
                end)
            else
                _setKeyPressed()
            end
        end
    end

    if player.Character then
        characterAdded(player.Character)
    end
    player.CharacterAdded:Connect(characterAdded)

    ContextActionService:BindActionAtPriority(
        "Dash", handleAction, false, 2,
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.S
    )
end

function DashController:KnitStart()
    local function onTurnOffDash()
        _turnOffDash()
    end

    DashService.TurnOffDash:Connect(onTurnOffDash)
end

return DashController