-- Todo:  weapon swap animation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")
local Classes = ReplicatedStorage:WaitForChild("Classes")
local Guis = ReplicatedStorage:WaitForChild("Guis")

local Knit = require(Packages:WaitForChild("knit"))
local Roact = require(Packages:WaitForChild("roact"))
local RoactTemplate = require(Packages:WaitForChild("roact-template"))
local AnimationClass = require(Classes:WaitForChild("AnimationClass"))

local HealthMain = RoactTemplate.fromInstance(Roact, Guis:WaitForChild("HealthMain"))
local KillFeedNotifications = RoactTemplate.fromInstance(Roact, Guis:WaitForChild("KillFeedNotifications"))
local KillFeedLabel = RoactTemplate.fromInstance(Roact, Guis:WaitForChild("KillFeedLabel"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local ATTACK_ID = 16008835993
local BLOCK_ID = 16043291327
local SWAP_ID = 16043358646

local MAX_SHIELD = 100
local MAX_HEALTH = 100
local MAX_BULLET_DISTANCE = 100

local attackAnim = AnimationClass.new(ATTACK_ID, false, 0, 1, 2)
local blockAnim = AnimationClass.new(BLOCK_ID, false, 0.2, 1, 1)
local swapAnim = AnimationClass.new(SWAP_ID, false, 0.1, 1, 2)

local playerShield, playerHealth = 100, 100
local killFeed = {}

local GearController = Knit.CreateController({
    Name = "GearController",
    PlayersAttacking = {},
    Registered = {},
    DamageGuis = {},
    DeathGuis = {},
})

local function _createHitPart(position, color, size)
    if not workspace:FindFirstChild("TestParts") then
		local folder = Instance.new("Folder", workspace)
		folder.Name = "Testparts"
	end

    local part = Instance.new("Part")
    part.Name = "HitPart"
    part.Position = position
    part.Size = size
    part.Shape = Enum.PartType.Ball
    part.Color = color
    part.CanCollide = false
    part.Anchored = true
    part.Parent = workspace.Testparts
end

local function _playSoundInWorkspace(soundName, part)
    local clone = Sounds:FindFirstChild(soundName):Clone()
    clone.Parent = part
    clone.Ended:Connect(function()
        clone:Destroy()
    end)

    clone:Play()
end

local function _performRaycastForBullets(attackingUserId, originPosition, ...)
    local attackingPlayer = Players:GetPlayerByUserId(attackingUserId)
    if not attackingPlayer then
        return false
    end
    local attackingCharacter = attackingPlayer.Character
    if not attackingCharacter then
        return false
    end

    local function _getRayResult(direction)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {attackingCharacter}

        for i = 1, MAX_BULLET_DISTANCE do
            local result = workspace:Raycast(originPosition, direction * i, raycastParams)
            if result then
                -- warn("Result Instance:  ", result.Instance)
                -- warn("Instance Parent:  ", result.Instance.Parent)
                -- warn("Direction:  ", direction)

                -- _createHitPart(result.Position, Color3.new(0.949019, 0.219607, 1), Vector3.new(1, 1, 1))

                if result.Instance.Parent and Players:GetPlayerFromCharacter(result.Instance.Parent) then
                    local userId = Players:GetPlayerFromCharacter(result.Instance.Parent).UserId
                    return userId, result.Instance.Name
                else
                    return false
                end

            else
                continue
            end
        end
        return false
    end

    for _, direction in {...} do
        local userId, bodyPartName = _getRayResult(direction)
        if userId then
            GearService:registerBulletForInvolved(attackingUserId, userId, bodyPartName):andThen(function(hasRegistered)
                if hasRegistered then
                    print("Successfuly registered bullet on server.")
                end
            end)
        end
    end
end

local function _performRaycastOnSword(plr, sword)
    local start = sword.Handle.Position -- base of the sword
    local tip = sword.Tip.Position -- tip of the sword

    local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {plr.Character, sword}

    local result = workspace:Blockcast(sword.Handle.CFrame, Vector3.new(1, 1, 1), (tip - start).Unit * 5, raycastParams)

    if result then
        if result.Instance.Parent and Players:GetPlayerFromCharacter(result.Instance.Parent) then
            local userId = Players:GetPlayerFromCharacter(result.Instance.Parent).UserId
            return userId
        else
            return false
        end
    else
        return false
    end
end

local function _handleGunParticles(gun)
    local gunparticles = gun:FindFirstChild("GunParticles")

    for _, inst in gunparticles:GetChildren() do
        task.spawn(function()
            if inst:IsA("ParticleEmitter") then
                inst:Emit(inst.Rate)
            elseif inst:IsA("Pointlight") then
                inst.Enabled = true

                task.delay(0.2, function()
                    inst.Enabled = false
                end)
            end
        end)
    end
end

local function _getPlayerHeadshot(UserID: number): string
	local success, result = pcall(function()
		return Players:GetUserThumbnailAsync(UserID, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	end)

	if success then
		return result
	else
		return "rbxassetid://753015086", warn("unsuccesful getting player image.")
	end
end

function GearController:KnitInit()
    GearService = Knit.GetService("GearService")

    local function killFeedMain(props)
        local notifications = props.notifications

        local killFeedNotifications = {}
        for _, notification in notifications do
            killFeedNotifications[#killFeedNotifications+1] = Roact.createElement(KillFeedLabel, {
                TextLabel = {
                    Text = notification
                }
            })
        end

        return Roact.createElement("ScreenGui", {
            ResetOnSpawn = false,
        }, {
            KillFeed = Roact.createElement(KillFeedNotifications, {
                [RoactTemplate.Root] = {
                    [Roact.Children] = {
                        UIListLayout = Roact.createElement("UIListLayout", {
    
                        }),
                        KillNotifications = Roact.createFragment(killFeedNotifications),
                    }
                },
            })
        })
    end

    local function healthMain(props)
        local shieldX = props.shield / MAX_SHIELD
        local healthX = props.health / MAX_HEALTH
        local playerImage = _getPlayerHeadshot(player.UserId)
    
        return Roact.createElement("ScreenGui", {
            ResetOnSpawn = false,
        }, {
            Frame = Roact.createElement("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.fromScale(0.2, 0.575),
                SizeConstraint = Enum.SizeConstraint.RelativeXX,
            }, {
                UISizeConstraint = Roact.createElement("UISizeConstraint", {
                    MaxSize = Vector2.new(200, 600),
                }),
                Holder = Roact.createElement(HealthMain, {
                    ShieldBar = {
                        Size = UDim2.fromScale(shieldX, 0.5),
                    },
                    HealthBar = {
                        Size = UDim2.fromScale(healthX, 0.5),
                    },
                    ShieldLabel = {
                        Text = playerShield .. "%",
                    },
                    HealthLabel = {
                        Text = playerHealth .. "%",
                    },
                    NameLabel = {
                        Text = player.DisplayName,
                    },
                    PlayerImage = {
                        Image = playerImage,
                    }
                })
            })
        })
    end

    local killFeedHandle = Roact.mount(Roact.createElement(killFeedMain, {
        notifications = killFeed,
    }), playerGui, "KillFeed")
    self.updateKillFeed = function()
        Roact.update(killFeedHandle, Roact.createElement(killFeedMain, {
            notifications = killFeed,
        }), playerGui, "KillFeed")
    end

    local healthHandle = Roact.mount(Roact.createElement(healthMain, {
        shield = playerShield,
        health = playerHealth,
    }), playerGui, "HealthMain")
    self.updateHealth = function()
        Roact.update(healthHandle, Roact.createElement(healthMain, {
            shield = playerShield,
            health = playerHealth,
        }), playerGui, "HealthMain")
    end

    local function characterAdded(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.HealthDisplayDistance = 0

        attackAnim:setTrack(player, Enum.AnimationPriority.Action4)
        blockAnim:setTrack(player, Enum.AnimationPriority.Action4)
        swapAnim:setTrack(player, Enum.AnimationPriority.Action4)
    end

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

        GearService:changeSlot(slotName):andThen(function(couldChange, equipped)
            if couldChange then
                if swapAnim:isPlaying() then
                    swapAnim:stop()
                end

                if not swapAnim:isPlaying() then
                    swapAnim:play()
                end

                local soundName = nil
                if equipped == "SlotOne" then
                    soundName = "SwordSwap"
                elseif equipped == "SlotTwo" or equipped == "SlotThree" then
                    soundName = "GunSwap"
                end

                local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if soundName and rootPart then
                    _playSoundInWorkspace(soundName, rootPart)
                end

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

        -- local screenToWorldRay = camera:ViewportPointToRay(0.5, 0.5)
        -- local directionVector = screenToWorldRay.Direction
        -- local originPosition = screenToWorldRay.Origin
        
        local direction = camera.CFrame.LookVector
        local screenToWorldRay = Ray.new(camera.CFrame.Position, direction)
        
        GearService:attack(screenToWorldRay.Origin, screenToWorldRay.Direction):andThen(function(canAtack, equipped)
            if canAtack then
                local soundName = nil
                if equipped == "SlotOne" then
                    soundName = "Sword"
                elseif equipped == "SlotTwo" then
                    _handleGunParticles(player.Character:FindFirstChild("Right Arm"):FindFirstChild("Henry"))
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
                -- print("you cannot attack atm.")
            end
        end)
    end

    local function handleBlock(_actionName, inputState, input)
        if inputState == Enum.UserInputState.Begin then
            GearService:block():andThen(function(canBlock)
                if canBlock then
                    if not blockAnim:isPlaying() then
                        blockAnim:play()
                    end
                    -- print("player has started blocking.")
                end
            end)
        elseif inputState == Enum.UserInputState.End then
            GearService:unblock():andThen(function(unblockSuccess)
                if unblockSuccess then
                    if blockAnim:isPlaying() then
                        blockAnim:stop()
                    end
                    -- print("player has unblocked themselves.")
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

                -- print("player can reload.")
            else
                -- print("player cannot reload.")
            end
        end)
    end

    if player.Character then
        characterAdded(player.Character)
    end
    player.CharacterAdded:Connect(characterAdded)

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

    RunService.Stepped:Connect(function(_stepTime, step)
        for _, attackingUserId in self.PlayersAttacking do
            local plr = Players:GetPlayerByUserId(attackingUserId)
            local character = plr.Character
            if not character then
                continue
            end

            local sword = character:FindFirstChild("Right Arm"):FindFirstChild("Samurai")
            local hitUserId = _performRaycastOnSword(plr, sword)
            if hitUserId then
                if not self.Registered[attackingUserId] then
                    self.Registered[attackingUserId] = {}
                else
                    if table.find(self.Registered[attackingUserId], hitUserId) then
                        continue
                    end
                end

                table.insert(self.Registered[attackingUserId], hitUserId)

                GearService:registerHitForInvolved(attackingUserId, hitUserId):andThen(function(hasRegistered)
                    print(hasRegistered)
                end)
            end
        end
    end)

    RunService.Stepped:Connect(function(_stepTime, step)
        for key, tab in self.DamageGuis do
            for index, info in tab do
                local gui = info.gui
                local timeStamp = info.timeStamp
                local y = info.y

                gui.StudsOffset += Vector3.new(0, y, 0)

                self.DamageGuis[key][index].y -= 0.0025

                if tick() - timeStamp >= 1.25 then
                    gui:Destroy()
                    table.remove(self.DamageGuis[key], index)
                end
            end
        end

        for key, tab in self.DeathGuis do
            for index, info in tab do
                local gui = info.gui
                local timeStamp = info.timeStamp
                
                gui.StudsOffset += Vector3.new(0, 0.0025, 0)

                if tick() - timeStamp >= 16 then
                    gui:Destroy()
                    table.remove(self.DeathGuis[key], index)
                end
            end
        end
    end)
end

function GearController:KnitStart()
    local function sendBullets(attackingUserId, equipped, originPosition, ...)
        -- warn("Equipped:  ", equipped)
        -- warn("Origin Position:  ", originPosition)
        -- warn("Direction Vector:  ", directionVector)

        if equipped == "SlotTwo" or equipped == "SlotThree" then
            _performRaycastForBullets(attackingUserId, originPosition, ...)
        end
    end

    local function updateHealthGuis(healthStatsPerUserId)
        local function _getDescendantByName(instance, name)
            for _, inst in instance:GetDescendants() do
                if inst.Name == name then
                    return inst
                end
            end
        end

        for _, info in healthStatsPerUserId do
            local userId = info.userId
            local shield = info.shield
            local health = info.health

            local plr = Players:GetPlayerByUserId(userId)
            if not plr then
                continue
            end

            if plr == player then
                task.spawn(function()
                    playerShield, playerHealth = shield, health

                    self.updateHealth()

                    return playerShield, playerHealth
                end)

                continue
            end
            
            local name = plr.Name

            local healthGui = playerGui:FindFirstChild(name .. "_Health")
            if not healthGui then
                healthGui = Guis:WaitForChild("HealthGui"):Clone()
                healthGui.Name = name .. "_Health"
                healthGui.Parent = playerGui
            end

            healthGui.Adornee = plr.Character:FindFirstChild("HumanoidRootPart")

            local shieldBar, healthBar = _getDescendantByName(healthGui, "ShieldBar"), _getDescendantByName(healthGui, "HealthBar")
            shieldBar.Size = UDim2.fromScale(shield / MAX_SHIELD, 0.5)
            healthBar.Size = UDim2.fromScale(health / MAX_HEALTH, 0.5)
        end
    end

    local function hasAttacked()
        attackAnim:play()
    end

    local function updateAttacking(newAttacking)
        self.PlayersAttacking = newAttacking

        for attackingUserId, _ in self.Registered do
            if not table.find(self.PlayersAttacking, attackingUserId) then
                self.Registered[attackingUserId] = nil
            end
        end
    end

    local function showKillFeed(killerName, killerRootPart, killedName, killedPosition)
        task.spawn(function()
            local notification = killerName .. " killed " .. killedName

            local index = #killFeed+1
            table.insert(killFeed, index, notification)

            self.updateKillFeed()

            local wingsGuiForKiller = playerGui:FindFirstChild(killerName .. "_Wings")
            if not wingsGuiForKiller then
                wingsGuiForKiller = Guis.WingsGui:Clone()
                wingsGuiForKiller.Name = killerName .. "_Wings"
                wingsGuiForKiller.Frame.TextLabel.Text = killerName
                wingsGuiForKiller.Parent = playerGui
            end

            wingsGuiForKiller.Adornee = killerRootPart
            wingsGuiForKiller.Enabled = true

            task.delay(6, function()
                table.remove(killFeed, table.find(killFeed, notification))

                wingsGuiForKiller.Adornee = nil
                wingsGuiForKiller.Enabled = false

                self.updateKillFeed()
            end)
        end)

        if killerName == player.DisplayName then
            Sounds:FindFirstChild("KillConfirmed"):Play()
        else
            Sounds:FindFirstChild("Bell"):Play()
        end

        local killedHealthGui = playerGui:FindFirstChild(killedName .. "_Health")
        if killedHealthGui then
            killedHealthGui:Destroy()
        end

        local part = Instance.new("Part")
        part.Anchored = true
        part.Transparency = 1
        part.CanCollide = false
        part.Position = killedPosition
        part.Parent = workspace

        local deathGui = Guis.DeathGui:Clone()
        deathGui.Adornee = part

        deathGui.Frame.TextLabel.Text = killedName

        deathGui.Parent = playerGui

        local info = {
            gui = deathGui,
            timeStamp = tick(),
        }

        if not self.DeathGuis[killedName] then
            self.DeathGuis[killedName] = {}
        end

        table.insert(self.DeathGuis[killedName], #self.DeathGuis[killedName]+1, info)

        local healthGui = playerGui:FindFirstChild(killedName)
        if healthGui then
            healthGui.Adornee = nil
        end
    end
    
    local function showKillForPlayer()

    end

    local function showDamage(characterHit, damage, isShield)
        local playerHit = Players:GetPlayerFromCharacter(characterHit)
        local hitRootPart = characterHit:FindFirstChild("HumanoidRootPart")
        local gui = isShield and "ShieldGui" or "DamageGui"

        if hitRootPart then
            local clone = Guis[gui]:Clone()
            clone.TextLabel.Text = damage
            clone.Parent = hitRootPart

            local sound = not isShield and "Damage" or "ShieldHit"
            local soundClone = Sounds:FindFirstChild(sound):Clone()
            soundClone.Ended:Connect(function()
                soundClone:Destroy()
            end)
            soundClone.Parent = hitRootPart
            soundClone:Play()

            if not self.DamageGuis[playerHit] then
                self.DamageGuis[playerHit] = {}
            end

            local info = {
                gui = clone,
                y = 0.1,
                timeStamp = tick()
            }

            table.insert(self.DamageGuis[playerHit], #self.DamageGuis[playerHit]+1, info)
        end

        -- warn("Character Hit:  ", characterHit)
        -- warn("Damage:  ", damage)
        -- warn("Is Shield:  ", isShield)
    end

    GearService.SendBullets:Connect(sendBullets)
    GearService.UpdateHealthGuis:Connect(updateHealthGuis)
    GearService.HasAttacked:Connect(hasAttacked)
    GearService.UpdateAttacking:Connect(updateAttacking)
    GearService.ShowKillFeed:Connect(showKillFeed)
    GearService.ShowKillForPlayer:Connect(showKillForPlayer)
    GearService.ShowDamage:Connect(showDamage)
end

return GearController