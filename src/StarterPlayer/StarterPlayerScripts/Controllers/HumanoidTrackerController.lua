local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Knit)
local HumanoidTracker = require(ReplicatedStorage.Knit.Util.Additions.Classes.HumanoidTracker)

local HumanoidTrackerController = Knit.CreateController({
	Name = "HumanoidTrackerController";
})

HumanoidTrackerController.HumanoidTracker = nil

function HumanoidTrackerController:GetHumanoidTracker()
	return self.HumanoidTracker
end

function HumanoidTrackerController:KnitInit()
	self.HumanoidTracker = HumanoidTracker.new(Players.LocalPlayer)
end

return HumanoidTrackerController
