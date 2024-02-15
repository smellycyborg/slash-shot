--[[

    Reload Shot) shoot, reload, switch, shoot

    Todo:  set up individual ids per bullet 

]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("knit"))

local TIME_UNTIL_RELOAD = 0.7
local TIME_UNTIL_NEXT_ATTACK = 0.4

local SWORD_DAMAGE = 40

local IS_SHIELD = true
local NOT_IS_SHIELD = false

local damagePerBodyPart = {
    ["Right Arm"] = 20,
    ["Left Arm"] = 20,
    ["Left Leg"] = 27,
    ["Right Leg"] = 27,
    ["Head"] = 80,
    ["Torso"] = 57,
    ["HumanoidRootPart"] = 67,
}

local GearService = Knit.CreateService({
    Name = "GearService",

    Client = {
        ShowDamage = Knit.CreateSignal(),
        ShowKillForPlayer = Knit.CreateSignal(),
        ShowKillFeed = Knit.CreateSignal(),
        HasAttacked = Knit.CreateSignal(),
        UpdateAttacking = Knit.CreateSignal(),
        UpdateHealthGuis = Knit.CreateSignal(),
        SendBullets = Knit.CreateSignal(),
    },

    EquippedPerPlayer = {},
    
    ShieldPerPlayer = {},
    HealthPerPlayer = {},

    ReloadTaskPerPlayer = {},
    AttackTaskPerPlayer = {},
    
    PlayersBlocking = {},
    PlayersWithAmmo = {},
    PlayersAttacking = {},

    Registrations = {},
    BulletRegistrations = {},

    Connections = {},
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

local function _getLengthOfRegistrations(tab)
    local count = 0

    for _, _ in tab do
        count+=1
    end

    return count
end

local function _getRandomBullets(direction)
    local directions = {}

    for i = 1, 4 do
        local offsetX = math.random(-6, 6) / 10
        local offsetY = math.random(-6, 6) / 10
        local offsetZ = math.random(-6, 6) / 10
        local offsetVector = Vector3.new(offsetX, offsetY, offsetZ)

        directions[#directions+1] = direction + (offsetVector * 0.1)
    end

    return directions
end

local function _setHealthStatsByUserIds()
    local tab = {}

    for playerKey, shield in GearService.ShieldPerPlayer do
        table.insert(tab, {
            userId = playerKey.UserId,
            shield = shield,
            health = GearService.HealthPerPlayer[playerKey]
        })
    end

    return tab
end

function GearService:KnitInit()
    local function characterAdded(character)
        local player = Players:GetPlayerFromCharacter(character)

        self.ShieldPerPlayer[player] = 100
        self.HealthPerPlayer[player] = 100

        self.EquippedPerPlayer[player] = "SlotOne"

        self.Client.UpdateHealthGuis:FireAll(_setHealthStatsByUserIds())

        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            humanoid.BreakJointsOnDeath = false
            humanoid.NameOcclusion = Enum.NameOcclusion.NoOcclusion
            humanoid.NameDisplayDistance = 0
        end

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
    if self.HealthPerPlayer[player] <= 0 then
        return false
    end

    if self.EquippedPerPlayer[player] ~= slotName then
        self:unblock(player)
        -- self:cleanAttack(player)

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
                            if part.Name == "Handle" or part.Name == "GunParticles" then
                                continue
                            end
                            part.Transparency = transparency
                        end
                    else
                        item.Transparency = transparency
                    end
                end
            end

            return true, self.EquippedPerPlayer[player]
        end
    else
        return false
    end
end

function GearService:attack(player, originPosition, directionVector)
    if self.HealthPerPlayer[player] <= 0 then
        return false
    end
    local equipped = self.EquippedPerPlayer[player]
    if table.find(self.PlayersBlocking, player) then
        return false
    end

    local character = player.Character
    if not character then
        return false
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return false
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        return false
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {player.Character}

    local downCastResult = workspace:Raycast(rootPart.Position, Vector3.new(0, -1 * 3, 0), raycastParams)

    -- Todo:  set up clean dash based on if a player as attacked and blocked with 0.2 (i think?) seconds
    if equipped == "SlotOne" then
        if table.find(self.PlayersAttacking, player) then
            return false
        end

        local function _updateUserIdsForClients()
            local attackingUserIds = {}
            for _, plr in self.PlayersAttacking do
                table.insert(attackingUserIds, plr.UserId)
            end
            self.Client.UpdateAttacking:FireAll(attackingUserIds)
        end

        if downCastResult == nil then
            if self.Connections[player] then
                self.Connections[player]:Disconnect()
            end

            self.Connections[player] = humanoid.StateChanged:Connect(function(oldState, newState)
                if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Freefall then            
                    DashService:cleanDash(player)

                    self.Connections[player]:Disconnect()
                    self.Connections[player] = nil
                end
            end)
        end

        table.insert(self.PlayersAttacking, player)
        self.AttackTaskPerPlayer[player] = task.delay(TIME_UNTIL_NEXT_ATTACK, function()
            if table.find(self.PlayersAttacking, player) then
                table.remove(self.PlayersAttacking, table.find(self.PlayersAttacking, player))
            end

            _updateUserIdsForClients()
        end)

        _updateUserIdsForClients()
        self.Client.HasAttacked:Fire(player)

        -- Todo:  handle raycasts for sword slash

        return true, equipped
    elseif equipped == "SlotTwo" or equipped == "SlotThree" then
        if table.find(self.PlayersWithAmmo, player)
        or next(DashService:getCooldownTask(player)) and table.find(self.PlayersAttacking, player) then
            if table.find(self.PlayersWithAmmo, player) then
                table.remove(self.PlayersWithAmmo, table.find(self.PlayersWithAmmo, player))
            end

            self.BulletRegistrations[player] = {}

            if equipped == "SlotTwo" then
                self.Client.SendBullets:FireAll(player.UserId, equipped, originPosition, directionVector)
            elseif equipped == "SlotThree" then
                local directions = _getRandomBullets(directionVector)
                self.Client.SendBullets:FireAll(player.UserId, equipped, originPosition, table.unpack(directions))
            end

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
    if self.HealthPerPlayer[player] <= 0 then
        return false
    end
    
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
    if self.HealthPerPlayer[player] <= 0 then
        return false
    end

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

function GearService:registerHitForInvolved(playerRegitering, attackingUserId, hitUserId)
    local attackingPlayer = Players:GetPlayerByUserId(attackingUserId)
    local hitPlayer = Players:GetPlayerByUserId(hitUserId)

    if not table.find(self.PlayersAttacking, attackingPlayer) then
        return false, warn("Player was not attacking.")
    end

    if not self.Registrations[hitPlayer] then
        self.Registrations[hitPlayer] = {}
    end

    if not self.Registrations[hitPlayer][attackingPlayer] then
        self.Registrations[hitPlayer][attackingPlayer] = {}
    end

    if table.find(self.Registrations[hitPlayer][attackingPlayer], playerRegitering) then
        return false, warn("Player has already registered hit.")
    end

    table.insert(self.Registrations[hitPlayer][attackingPlayer], playerRegitering)

    local registrationsLength = _getLengthOfRegistrations(self.Registrations[hitPlayer][attackingPlayer])
    if registrationsLength >= 0.5 * #Players:GetPlayers() then
        -- Todo:  register hit

        self:dealDamage(attackingPlayer, hitPlayer.Character, SWORD_DAMAGE)
        self.Registrations[hitPlayer][attackingPlayer] = nil

        print("Successfull registered hit on server.")
    end

    return true, print("Successfully registered hit for single player.")
end

function GearService:registerBulletForInvolved(playerRegitering, attackingUserId, hitUserId, bodyPartName)
    local attackingPlayer = Players:GetPlayerByUserId(attackingUserId)
    if not attackingPlayer then
        return false, warn("There was no attacking player")
    end

    if not self.BulletRegistrations[attackingPlayer] then
        return false, warn("Attacking player reported does not have any bullets pending.")
    end

    if table.find(self.BulletRegistrations[attackingPlayer], playerRegitering) then
        return false, warn("Player haas alread registered bullet.")
    end

    table.insert(self.BulletRegistrations[attackingPlayer], playerRegitering)

    local playerHit = Players:GetPlayerByUserId(hitUserId)
    local characterHit = playerHit.Character
    if not characterHit then
        self.BulletRegistrations[attackingPlayer] = nil

        return false, warn("Character hit did not exist.")
    end

    if #self.BulletRegistrations[attackingPlayer] >= 0.5 * #Players:GetPlayers() then
        local damageAmount = damagePerBodyPart[bodyPartName]
        self:dealDamage(attackingPlayer, characterHit, damageAmount)

        self.BulletRegistrations[attackingPlayer] = nil
    end

    return true
end

function GearService:dealDamage(playerAttacking, characterHit, damageAmount)
    local humanoidHit = characterHit:FindFirstChild("Humanoid")
    if not humanoidHit or humanoidHit.Health <= 0 then
        return
    end

    local playerHit = Players:GetPlayerFromCharacter(characterHit)

    if table.find(self.PlayersBlocking, playerHit) then
        damageAmount *= 0.825
        math.floor(damageAmount)
    end

    local playerHitShield = self.ShieldPerPlayer[playerHit]
    local playerHitHealth = self.HealthPerPlayer[playerHit]

    local otherDamage, damageHolding

    if playerHitShield > 0 then
        if playerHitShield >= damageAmount then
            self.ShieldPerPlayer[playerHit] -= damageAmount

            self.Client.ShowDamage:FireAll(characterHit, damageAmount, IS_SHIELD)
        else
            otherDamage = damageAmount - playerHitShield
            damageHolding = playerHitShield

            self.ShieldPerPlayer[playerHit] -= playerHitShield
            self.HealthPerPlayer[playerHit] -= otherDamage

            self.Client.ShowDamage:FireAll(characterHit, damageHolding, IS_SHIELD)
            self.Client.ShowDamage:FireAll(characterHit, otherDamage, NOT_IS_SHIELD)
        end
    else
        if playerHitHealth < damageAmount then
            damageHolding = playerHitHealth

            self.HealthPerPlayer[playerHit] = 0

            self.Client.ShowDamage:FireAll(characterHit, damageHolding, NOT_IS_SHIELD)
        else
            self.HealthPerPlayer[playerHit] -= damageAmount

            self.Client.ShowDamage:FireAll(characterHit, damageAmount, NOT_IS_SHIELD)
        end
    end

    self.Client.UpdateHealthGuis:FireAll(_setHealthStatsByUserIds())

    if self.HealthPerPlayer[playerHit] <= 0 then
        self:killPlayer(playerAttacking, playerHit)
    end

    print("Successfully damaged player.")
end

function GearService:killPlayer(playerAttacking, playerHit)
    -- Todo:  reset character and simulate death

    local humanoidHit = playerHit.Character and playerHit.Character:FindFirstChild("Humanoid")
    humanoidHit.Health = - 16

    local rootPartHit = playerHit.Character and playerHit.Character:FindFirstChild("HumanoidRootPart")
    local attackingRootPart = playerAttacking.Character and playerAttacking.Character:FindFirstChild("HumanoidRootPart")

    playerAttacking:FindFirstChild("Kills").Value += 1

    self.Client.ShowKillForPlayer:Fire(playerAttacking)
    self.Client.ShowKillFeed:FireAll(playerAttacking.DisplayName, attackingRootPart, playerHit.DisplayName, rootPartHit.Position)
end

function GearService:restoreShield(player)
    self.ShieldPerPlayer[player] = 100
    self.Client.UpdateHealthGuis:FireAll(_setHealthStatsByUserIds())
end

function GearService:restoreHealth(player)
    self.HealthPerPlayer[player] = 100
    self.Client.UpdateHealthGuis:FireAll(_setHealthStatsByUserIds())
end

function GearService:getEquipped(player)
    return self.EquippedPerPlayer[player]
end

function GearService:getShield(player)
    return self.ShieldPerPlayer[player]
end

function GearService:getHealth(player)
    return self.HealthPerPlayer[player]
end

function GearService.Client:registerHitForInvolved(playerRegitering, attackingUserId, hitUserId)
    return self.Server:registerHitForInvolved(playerRegitering, attackingUserId, hitUserId)
end

function GearService.Client:registerBulletForInvolved(playerRegitering, attackingUserId, hitUserId, bodyPartName)
    return self.Server:registerBulletForInvolved(playerRegitering, attackingUserId, hitUserId, bodyPartName)
end

function GearService.Client:changeSlot(player, slotName)
    return self.Server:changeSlot(player, slotName)
end

function GearService.Client:attack(player, originPosition, directionVector)
    return self.Server:attack(player, originPosition, directionVector)
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