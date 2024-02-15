local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")
local Classes = ReplicatedStorage:WaitForChild("Classes")
local Guis = ReplicatedStorage:WaitForChild("Guis")

local Knit = require(Packages:WaitForChild("knit"))
local AnimationClass = require(Classes:WaitForChild("AnimationClass"))

local TOTAL_COUNT = 6

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local InteractablesFolder = workspace:WaitForChild("Interactables")

local InteractablesController = Knit.CreateController({
    Name = "InteractablesController",
    Current = {}
})

function InteractablesController:KnitInit()
    local function pickUp(key)
        InteractablesService:pickUp(key):andThen(function(hasTook)
            if hasTook then
                local sound = hasTook == "armor" and "Armor" or "Medkit"
                Sounds:FindFirstChild(sound):Play()
            end
        end)
    end

    repeat
        task.wait()

        Interactables = InteractablesFolder:GetChildren()
    until #Interactables == TOTAL_COUNT

    for _, part in Interactables do
        part.Transparency = 1
        part.Touched:Connect(function(otherPart)
            local character = otherPart.Parent
            if not character and character ~= player.Character then
                return
            end

            for key, value in self.Current do
                if value == part then
                    pickUp(key)
                end
            end
        end)
    end
end

function InteractablesController:KnitStart()
    InteractablesService = Knit.GetService("InteractablesService")

    local function generateInteractable(key, interactableType)
        local randomPart, foundInteractable
        repeat
            task.wait()

            randomPart = Interactables[math.random(1, #Interactables)]
            for _key, value in self.Current do
                if value == randomPart then
                    foundInteractable = true
                end
            end
        until randomPart and not foundInteractable

        self.Current[key] = randomPart

        local gui = interactableType == "armor" and "ArmorGui" or "MedkitGui"
        local guiClone = Guis:FindFirstChild(gui):Clone()
        guiClone.Name = key
        guiClone.Adornee = randomPart
        guiClone.Parent = playerGui
    end

    local function destroyInteractableGui(key)
        self.Current[key] = nil

        local foundGui = playerGui:FindFirstChild(key)
        if foundGui then
            foundGui:Destroy()
        end
    end

    InteractablesService.GenerateInteractable:Connect(generateInteractable)
    InteractablesService.DestroyInteractableGui:Connect(destroyInteractableGui)
end

return InteractablesController