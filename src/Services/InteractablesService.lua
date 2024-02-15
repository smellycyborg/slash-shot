local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("knit"))

local MAX_AMOUNT = 6
local MAX_SHIELD = 100
local MAX_HEALTH = 100

local interactableTypes = { "armor", "health" }

local InteractablesService = Knit.CreateService({
    Name = "InteractablesService",
    Client = {
        GenerateInteractable = Knit.CreateSignal(),
        DestroyInteractableGui = Knit.CreateSignal(),
    },
    Interactables = {},
})

function InteractablesService:KnitInit()
    task.spawn(function()
        while task.wait(10) do
            if #self.Interactables >= MAX_AMOUNT then
                continue
            end

            local randomType = interactableTypes[math.random(1, #interactableTypes)]
            local key = HttpService:GenerateGUID()
            self.Interactables[key] = randomType

            self.Client.GenerateInteractable:FireAll(key, randomType)
        end
    end)
end

function InteractablesService:KnitStart()
    GearService = Knit.GetService("GearService")
end

function InteractablesService:pickUp(player, key)
    if not self.Interactables[key] then
        return false
    end

    if self.Interactables[key] == "armor" and GearService:getShield(player) < MAX_SHIELD then
        GearService:restoreShield(player)
    elseif self.Interactables[key] == "health" and GearService:getHealth(player) < MAX_HEALTH then
        GearService:restoreHealth(player)
    else
        return false
    end

    self.Interactables[key] = nil

    self.Client.DestroyInteractableGui:FireAll(key)

    return true
end

function InteractablesService.Client:pickUp(player, key)
    return self.Server:pickUp(player, key)
end

return InteractablesService