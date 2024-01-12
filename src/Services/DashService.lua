local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("knit"))

local DASH_COOLDOWN_TIME = 0.4
local DASH_STOP_TIME = 0.215

local DashService = Knit.CreateService({
    Name = "DashService",
    Client = {
        TurnOffDash = Knit.CreateSignal(),
    },

    CooldownsPerPlayer = {},
	DashingTaskPerPlayer = {},
	CooldownTaskPerPlayer = {},

    Dashing = {},
})

function DashService:KnitInit()
    local function characterAdded(character)
        local rootPart = character:WaitForChild("HumanoidRootPart")
        local rootAtt = rootPart:WaitForChild("RootAttachment")

        local linearVelocity = Instance.new("LinearVelocity")
        linearVelocity.Name = "DashVelocity"
        linearVelocity.Attachment0 = rootAtt
        linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
        linearVelocity.Enabled = false
        linearVelocity.MaxForce = 250000

        local alignOri = Instance.new("AlignOrientation")
        alignOri.Enabled = false
        alignOri.Attachment0 = rootAtt
        alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.MaxTorque = math.huge
        alignOri.Responsiveness = 200

        linearVelocity.Parent = rootPart
        alignOri.Parent = rootPart
    end

    local function playerAdded(player)
        self.CooldownsPerPlayer[player] = {}
        self.CooldownTaskPerPlayer[player] = {}
        self.DashingTaskPerPlayer[player] = {}

        player.CharacterAdded:Connect(characterAdded)
    end

    local function playerRemoving(player)
        self.CooldownsPerPlayer[player] = nil
        self.CooldownTaskPerPlayer[player] = nil
        self.DashingTaskPerPlayer[player] = nil
    end

    for _, player in Players:GetPlayers() do
        task.spawn(playerAdded, player)
    end
    Players.PlayerAdded:Connect(playerAdded)
    Players.PlayerRemoving:Connect(playerRemoving)
end

function DashService:KnitStart()
    GearService = Knit.GetService("GearService")
end

function DashService:dash(player, keyCode)
    warn("Player Cooldowns:  ", self.CooldownsPerPlayer[player])

    if self.CooldownsPerPlayer[player][keyCode] or table.find(self.Dashing, player) then
        return
    end

    self.CooldownsPerPlayer[player][keyCode] = tick()
    table.insert(self.Dashing, player)

    local function cancelDash()
        self.CooldownsPerPlayer[player][keyCode] = nil
        table.remove(self.Dashing, table.find(self.Dashing, player))
    end

    local character = player.Character
    if not character then
        cancelDash()
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        cancelDash()
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        cancelDash()
        return
    end

    local equipped = GearService:getEquipped(player)
    local dashForce = 1
    if equipped == "SlotOne" then
        dashForce = 80
    elseif equipped == "SlotTwo" or equipped == "SlotThree" then
        dashForce = 40
    end

    local dashVelocity = rootPart:FindFirstChild("DashVelocity")
    local alignOri = rootPart:FindFirstChild("AlignOrientation")

    self.DashingTaskPerPlayer[player][keyCode] = task.delay(DASH_STOP_TIME, function()
        if table.find(self.Dashing, player) then
            table.remove(self.Dashing, table.find(self.Dashing, player))

            alignOri.Enabled = false
            dashVelocity.Enabled = false

            rootPart.Velocity = Vector3.zero

            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            humanoid.PlatformStand = false

            self.Client.TurnOffDash:Fire(player)
        end
    end)

    self.CooldownTaskPerPlayer[player][keyCode] = task.delay(DASH_COOLDOWN_TIME, function()
        if self.CooldownsPerPlayer[player][keyCode] then
            self.CooldownsPerPlayer[player][keyCode] = nil
        end
		
		if self.DashingTaskPerPlayer[player][keyCode] then
			self.DashingTaskPerPlayer[player][keyCode] = nil
		end
    end)

    local direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)

    alignOri.CFrame = CFrame.new(rootPart.Position, rootPart.Position + direction)
    dashVelocity.VectorVelocity =  direction * dashForce

    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    humanoid.PlatformStand = true

    alignOri.Enabled = true
    dashVelocity.Enabled = true

    return true, equipped
end

function DashService:cleanDash(player)
    table.remove(self.Dashing, table.find(self.Dashing, player))

    for keyCode, runningTask in self.DashingTaskPerPlayer[player] do
        task.cancel(runningTask)
        self.DashingTaskPerPlayer[player][keyCode] = nil
    end

    for keyCode, runningTask in self.CooldownTaskPerPlayer[player] do
        task.cancel(runningTask)
        self.CooldownTaskPerPlayer[player][keyCode] = nil
    end

    for keyCode, _notNeededTick in self.CooldownsPerPlayer[player] do
        self.CooldownsPerPlayer[player][keyCode] = nil
    end

    local character = player.Character
    if not character then
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        return
    end

    local dashVelocity = rootPart:FindFirstChild("DashVelocity")
    local alignOri = rootPart:FindFirstChild("AlignOrientation")

    alignOri.Enabled = false
    dashVelocity.Enabled = false

    rootPart.Velocity = Vector3.zero

    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    humanoid.PlatformStand = false
end

function DashService.Client:dash(player, keyCode)
    return self.Server:dash(player, keyCode)
end

return DashService