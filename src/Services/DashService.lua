local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("knit"))

local DASH_COOLDOWN_TIME = 0.45
local DASH_STOP_TIME = 0.14

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
        
    end

    local function playerAdded(player)
        self.CooldownsPerPlayer[player] = {}
        self.CooldownTaskPerPlayer[player] = {}
        self.DashingTaskPerPlayer[player] = {}

        local dashBool = Instance.new("BoolValue", player)
        dashBool.Name = "DashBool"
        dashBool.Value = false

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
    -- warn("Player Cooldowns:  ", self.CooldownsPerPlayer[player])

    if GearService:getHealth(player) <= 0 then
        return false
    end

    if self.CooldownsPerPlayer[player][keyCode] or table.find(self.Dashing, player) or  next(self.CooldownsPerPlayer[player]) then
        return false
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
        return false
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        cancelDash()
        return false
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        cancelDash()
        return false
    end

    local equipped = GearService:getEquipped(player)
    local dashForce = 1
    if equipped == "SlotOne" then
        dashForce = 80
    elseif equipped == "SlotTwo" or equipped == "SlotThree" then
        dashForce = 40
    end

    player:FindFirstChild("DashBool").Value = true

    self.DashingTaskPerPlayer[player][keyCode] = task.delay(DASH_STOP_TIME, function()
        if table.find(self.Dashing, player) then
            table.remove(self.Dashing, table.find(self.Dashing, player))

            self.Client.TurnOffDash:Fire(player)
        end

        player:FindFirstChild("DashBool").Value = false
    end)

    self.CooldownTaskPerPlayer[player][keyCode] = task.delay(DASH_COOLDOWN_TIME, function()
        if self.CooldownsPerPlayer[player][keyCode] then
            self.CooldownsPerPlayer[player][keyCode] = nil
        end
		
		if self.DashingTaskPerPlayer[player][keyCode] then
			self.DashingTaskPerPlayer[player][keyCode] = nil
		end
    end)

    return true, equipped
end

function DashService:cleanDash(player)
    for keyCode, runningTask in self.CooldownTaskPerPlayer[player] do
        task.cancel(runningTask)
        self.CooldownTaskPerPlayer[player][keyCode] = nil
    end

    for keyCode, _notNeededTick in self.CooldownsPerPlayer[player] do
        self.CooldownsPerPlayer[player][keyCode] = nil
    end

    print("successfully cleaned dash.")
end

function DashService:getDashing(player)
    return table.find(self.Dashing, player)
end

function DashService:getCooldownTask(player)
    return self.CooldownTaskPerPlayer[player]
end

function DashService.Client:dash(player, keyCode)
    return self.Server:dash(player, keyCode)
end

return DashService