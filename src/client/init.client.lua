local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = ReplicatedStorage:WaitForChild("Controllers")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("knit"))

Knit.AddControllers(Controllers)

Knit.Start():andThen(function()
    -- print("Knit has started on the client.")
end)