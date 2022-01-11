local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Knit)

local CooldownTrackerController = Knit.CreateController({
	Name = "CooldownTrackerController";
})

function CooldownTrackerController:KnitStart() end

function CooldownTrackerController:KnitInit() end

return CooldownTrackerController
