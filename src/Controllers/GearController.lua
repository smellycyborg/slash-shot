-- Todo:  weapon swap animation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")

local Knit = require(Packages:WaitForChild("knit"))

local player = Players.LocalPlayer

local GearController = Knit.CreateController({
    Name = "GearController"
})

local function _playSoundInWorkspace(soundName, part)
    local clone = Sounds:FindFirstChild(soundName):Clone()
    clone.Parent = part
    clone.Ended:Connect(function()
        clone:Destroy()
    end)

    clone:Play()
end

function GearController:KnitInit()
    GearService = Knit.GetService("GearService")

    local function changeSlot(_actionName, inputState, input)
        if inputState ~= Enum.UserInputState.Begin then
            return
        end

        local slotName = ""

        if input.KeyCode == Enum.KeyCode.One then
            slotName = "SlotOne"
        elseif input.KeyCode == Enum.KeyCode.Two then
            slotName = "SlotTwo"
        elseif input.KeyCode == Enum.KeyCode.Three then
            slotName = "SlotThree"
        end

        GearService:changeSlot(slotName):andThen(function(couldChange)
            if couldChange then
                print("could change slot.")
            else
                print("could not change slot.")
            end
        end)
    end

    local function attack(_actionName, inputState, input)
        if inputState ~= Enum.UserInputState.Begin then
            return
        end
        
        GearService:attack():andThen(function(canAtack, equipped)
            if canAtack then
                local soundName = nil
                if equipped == "SlotOne" then
                    soundName = "Sword"
                elseif equipped == "SlotTwo" then
                    soundName = "Rifle"
                elseif equipped == "SlotThree" then
                    soundName = "Sawed"
                end

                local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if soundName and rootPart then
                    _playSoundInWorkspace(soundName, rootPart)
                end

                print("you're successfully attacking.")
            else
                print("you cannot attack atm.")
            end
        end)
    end

    local function handleBlock(_actionName, inputState, input)
        if inputState == Enum.UserInputState.Begin then
            GearService:block():andThen(function(canBlock)
                if canBlock then
                    print("player has started blocking.")
                end
            end)
        elseif inputState == Enum.UserInputState.End then
            GearService:unblock():andThen(function(unblockSuccess)
                if unblockSuccess then
                    print("player has unblocked themselves.")
                end
            end)
        end
    end

    local function handleReload(_actionName, inputState, input)
        if inputState ~= Enum.UserInputState.Begin then
            return
        end

        GearService:reload():andThen(function(canReload)
            if canReload then
                local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    _playSoundInWorkspace("Reload", rootPart)
                end

                print("player can reload.")
            else
                print("player cannot reload.")
            end
        end)
    end

    ContextActionService:BindAction("ChangeSlot", changeSlot, false,
        Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three
    )
    ContextActionService:BindAction("Attack", attack, false, 
        Enum.UserInputType.MouseButton1
    )
    ContextActionService:BindAction("Block", handleBlock, false,
        Enum.KeyCode.Q
    )
    ContextActionService:BindAction("Reload", handleReload, false,
        Enum.KeyCode.R
    )
end

function GearController:KnitStart()

end

return GearController