--[[

    Reload Shot) shoot, reload, switch, shoot

]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("knit"))

local TIME_UNTIL_RELOAD = 0.7
local TIME_UNTIL_NEXT_ATTACK = 0.6

local GearService = Knit.CreateService({
    Name = "GearService",
    Client = {},
    EquippedPerPlayer = {},

    ReloadTaskPerPlayer = {},
    AttackTaskPerPlayer = {},
    
    PlayersBlocking = {},
    PlayersWithAmmo = {},
    PlayersAttacking = {},
})

local function _weldToPart(player, itemName, partName, transparency, slot)
    if string.len(itemName) <= 0 then
        return
    end
    
    local character = player.Character or player.CharacterAdded:Wait()
    local characterPart = character:WaitForChild(partName)

    local noneModelCFrame = CFrame.new(characterPart.CFrame.Position + Vector3.new(0, -1, -1.5)) * CFrame.Angles(math.rad(0), math.rad(-180), math.rad(90))
    local modelCFrame = CFrame.new(characterPart.CFrame.Position + Vector3.new(0, -1, -0.5)) * CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0))
    
    local item = game.ReplicatedStorage.Items:FindFirstChild(itemName):Clone()
    item.Parent = characterPart
    item:SetAttribute("Item", slot)

    if item.ClassName ~= "Model" then
        item.Transparency = transparency
        item.CFrame = noneModelCFrame
    else
        item:SetPrimaryPartCFrame(modelCFrame)

        for _, part in item:GetChildren() do
            if part.Name == "Handle" then
                continue
            end
            part.Transparency = transparency
        end
    end
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = characterPart
    weld.Part1 = item.ClassName ~= "Model" and item or item.PrimaryPart
    weld.Parent = item.ClassName ~= "Model" and item or item.PrimaryPart
end

function GearService:KnitInit()
    local function characterAdded(character)
        local player = Players:GetPlayerFromCharacter(character)

        _weldToPart(player, "Samurai", "Right Arm", 0, "SlotOne")
        _weldToPart(player, "Henry", "Right Arm", 1, "SlotTwo")
        _weldToPart(player, "Sawed", "Right Arm", 1, "SlotThree")
    end

    local function playerAdded(player)
        self.EquippedPerPlayer[player] = "SlotOne"

        player.CharacterAdded:Connect(characterAdded)
    end

    for _, player in Players:GetPlayers() do
        task.spawn(playerAdded, player)
    end
    Players.PlayerAdded:Connect(playerAdded)
end

function GearService:KnitStart()
    DashService = Knit.GetService("DashService")
end

function GearService:changeSlot(player, slotName)
    if self.EquippedPerPlayer[player] ~= slotName then
        self:unblock(player)
        self:cleanAttack(player)

        if self.ReloadTaskPerPlayer[player] then
            self:cleanReload(player)
        end
        
        self.EquippedPerPlayer[player] = slotName

        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then

            for _, item in player.Character:FindFirstChild("Right Arm"):GetChildren() do
                if item:GetAttribute("Item") then

                    local transparency = 0
                    if item:GetAttribute("Item") ~= slotName then
                        transparency = 1
                    else
                        transparency = 0
                    end

                    if item.ClassName == "Model" then
                        for _, part in item:GetChildren() do
                            if part.Name == "Handle" then
                                continue
                            end
                            part.Transparency = transparency
                        end
                    else
                        item.Transparency = transparency
                    end
                end
            end

            return true
        end
    else
        return false
    end
end

function GearService:attack(player)
    local equipped = self.EquippedPerPlayer[player]

    -- Todo:  set up clean dash based on if a player as attacked and blocked with 0.2 (i think?) seconds
    if equipped == "SlotOne" then
        if table.find(self.PlayersAttacking, player) then
            return false
        end

        table.insert(self.PlayersAttacking, player)
        self.AttackTaskPerPlayer[player] = task.delay(TIME_UNTIL_NEXT_ATTACK, function()
            if table.find(self.PlayersAttacking, player) then
                table.remove(self.PlayersAttacking, table.find(self.PlayersAttacking, player))
            end
        end)

        -- Todo:  handle raycasts for sword slash

        return true, equipped
    elseif equipped == "SlotTwo" or equipped == "SlotThree" then
        if table.find(self.PlayersWithAmmo, player) then
            table.remove(self.PlayersWithAmmo, table.find(self.PlayersWithAmmo, player))

            -- Todo:  shoot raycast bullets depending on gun equipped

            return true, equipped
        elseif not table.find(self.PlayersWithAmmo, player) then
            return false
        end
    end
end


function GearService:cleanReload(player)
    if self.ReloadTaskPerPlayer[player] then
        task.cancel(self.ReloadTaskPerPlayer[player])
        self.ReloadTaskPerPlayer[player] = nil
    end

    if not table.find(self.PlayersWithAmmo, player) then
        table.insert(self.PlayersWithAmmo, player)
    end
end

function GearService:cleanAttack(player)
    if self.AttackTaskPerPlayer[player] then
        task.cancel(self.AttackTaskPerPlayer[player])
        self.AttackTaskPerPlayer[player] = nil
    end

    if table.find(self.PlayersAttacking, player) then
        table.remove(self.PlayersAttacking, table.find(self.PlayersAttacking, player))
    end
end

function GearService:reload(player)
    local equipped = self.EquippedPerPlayer[player]
    if equipped == "SlotOne" then
        return false
    end

    if not table.find(self.PlayersWithAmmo, player) and not self.ReloadTaskPerPlayer[player] then
        self.ReloadTaskPerPlayer[player] = task.delay(TIME_UNTIL_RELOAD, function()
            table.insert(self.PlayersWithAmmo, player)
            self.ReloadTaskPerPlayer[player] = nil
        end)

        return true
    else
        return false
    end
end

function GearService:block(player)
    local equipped = self.EquippedPerPlayer[player]

    if equipped ~= "SlotOne" then
        return false
    end

    if not table.find(self.PlayersBlocking, player) then
        table.insert(self.PlayersBlocking, player)

        if table.find(self.PlayersAttacking, player) then
            self:cleanAttack(player)
    
            DashService:cleanDash(player)
        end

        return true
    else
        return false
    end
end

function GearService:unblock(player)
    if table.find(self.PlayersBlocking, player) then
        table.remove(self.PlayersBlocking, table.find(self.PlayersBlocking, player))

        return true
    else
        return false
    end
end

function GearService:getEquipped(player)
    return self.EquippedPerPlayer[player]
end

function GearService.Client:changeSlot(player, slotName)
    return self.Server:changeSlot(player, slotName)
end

function GearService.Client:attack(player)
    return self.Server:attack(player)
end

function GearService.Client:block(player)
    return self.Server:block(player)
end

function GearService.Client:unblock(player)
    return self.Server:unblock(player)
end

function GearService.Client:reload(player)
    return self.Server:reload(player)
end

return GearService