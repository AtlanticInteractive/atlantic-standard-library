local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VRService = game:GetService("VRService")

local Knit = require(ReplicatedStorage.Knit)
local GetController = require(ReplicatedStorage.Knit.Util.GetController)
local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)
local StateStack = require(ReplicatedStorage.Knit.Util.Additions.Classes.StateStack)
local TimeFunctions = require(ReplicatedStorage.Knit.Util.Additions.Utility.TimeFunctions)

local IdleController = Knit.CreateController({
	Name = "IdleController";
})

IdleController.Janitor = Janitor.new()
IdleController.DisabledStack = IdleController.Janitor:Add(StateStack.new(), "Destroy")
IdleController.HumanoidTracker = nil
IdleController.Enabled = IdleController.Janitor:Add(Instance.new("BoolValue"), "Destroy") :: BoolValue
IdleController.Enabled.Value = true

IdleController.ShowIdleUI = IdleController.Janitor:Add(Instance.new("BoolValue"), "Destroy") :: BoolValue
IdleController.HumanoidIdle = IdleController.Janitor:Add(Instance.new("BoolValue"), "Destroy") :: BoolValue

local STANDING_TIME_REQUIRED = 0.5

local function UpdateShowIdleUI()
	IdleController.ShowIdleUI.Value = IdleController.HumanoidIdle.Value and IdleController.Enabled.Value and not VRService.VREnabled
end

local function HandleAliveHumanoidChanged()
	local Humanoid = IdleController.HumanoidTracker.AliveHumanoid.Value
	if not Humanoid then
		IdleController.Janitor:Remove("HumanoidJanitor")
	else
		local HumanoidJanitor = IdleController.Janitor:Add(Janitor.new(), "Destroy", "HumanoidJanitor")
		local LastMove = TimeFunctions.TimeFunction()

		HumanoidJanitor:Add(function()
			IdleController.HumanoidIdle.Value = false
		end, true)

		HumanoidJanitor:Add(IdleController.Enabled.Changed:Connect(function()
			LastMove = TimeFunctions.TimeFunction()
		end), "Disconnect")

		HumanoidJanitor:Add(RunService.Stepped:Connect(function()
			local RootPart = Humanoid.RootPart
			if RootPart and RootPart.AssemblyLinearVelocity.Magnitude > 2.5 then
				LastMove = TimeFunctions.TimeFunction()
			end

			IdleController.HumanoidIdle.Value = TimeFunctions.TimeFunction() - LastMove >= STANDING_TIME_REQUIRED
		end), "Disconnect")
	end
end

function IdleController:IsHumanoidIdle()
	return self.HumanoidIdle.Value
end

function IdleController:DoShowIdleUI()
	return self.ShowIdleUI.Value
end

function IdleController:GetShowIdleUI()
	return self.ShowIdleUI
end

function IdleController:PushDisable()
	if RunService:IsRunning() then
		return self.DisabledStack:PushState()
	else
		return function() end
	end
end

function IdleController:KnitStart()
	GetController.Option("HumanoidTrackerController"):Match({
		Some = function(HumanoidTrackerController)
			self.HumanoidTracker = HumanoidTrackerController:GetHumanoidTracker()
			self.Janitor:Add(self.HumanoidIdle.Changed:Connect(UpdateShowIdleUI), "Disconnect")
			self.Janitor:Add(self.Enabled.Changed:Connect(UpdateShowIdleUI), "Disconnect")
			self.Janitor:Add(self.HumanoidTracker.AliveHumanoid.Changed:Connect(HandleAliveHumanoidChanged), "Disconnect")
			self.Janitor:Add(self.DisabledStack.Changed:Connect(function()
				self.Enabled.Value = not self.DisabledStack:GetState()
			end), "Disconnect")

			if self.HumanoidTracker.AliveHumanoid.Value then
				HandleAliveHumanoidChanged()
			end

			UpdateShowIdleUI()
		end;

		None = function()
			warn("[IdleController.KnitStart] - Couldn't get HumanoidTrackerController!")
		end;
	})
end

return IdleController
