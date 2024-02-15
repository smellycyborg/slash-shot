local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("knit"))

local DataService = Knit.CreateService({
    Name = "DataService",
    Client = {},
})

local values = {"Kills"}

function DataService:KnitInit()
    local function playerAdded(player)
        for _, value in values do
            local inst = Instance.new("IntValue", player)
            inst.Name = value
            inst.Value = 0
        end
    end

    for _, player in Players:GetPlayers() do
        task.spawn(playerAdded, player)
    end
    Players.PlayerAdded:Connect(playerAdded)
end

function DataService:KnitStart()

end

return DataService