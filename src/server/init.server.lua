local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage.Packages
local Services = ServerStorage.Services

local Knit = require(Packages.knit)

Knit.AddServices(Services)

local function disableShiftLock(player)
    player.DevEnableMouseLock = false
end

Players.PlayerAdded:Connect(disableShiftLock)
Knit.Start():andThen(function()
    -- print("Knit has started on the server.")
end)

for _, inst in workspace:WaitForChild("Buildings"):GetDescendants() do
	if inst:IsA("BasePart") or inst:IsA("MeshPart") or inst:IsA("Part") then
		inst:SetAttribute("Parkour", true)
	end
end