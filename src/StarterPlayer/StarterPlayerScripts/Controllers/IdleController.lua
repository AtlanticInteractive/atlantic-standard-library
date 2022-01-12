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

local ControllerJanitor = Janitor.new()
local DisabledStack = ControllerJanitor:Add(StateStack.new(), "Destroy")
local HumanoidTracker = nil
local Enabled = ControllerJanitor:Add(Instance.new("BoolValue"), "Destroy") :: BoolValue
Enabled.Value = true

local ShowIdleUI = ControllerJanitor:Add(Instance.new("BoolValue"), "Destroy") :: BoolValue
local HumanoidIdle = ControllerJanitor:Add(Instance.new("BoolValue"), "Destroy") :: BoolValue

local STANDING_TIME_REQUIRED = 0.5

local function UpdateShowIdleUI()
	ShowIdleUI.Value = HumanoidIdle.Value and Enabled.Value and not VRService.VREnabled
end

local function HandleAliveHumanoidChanged()
	local Humanoid = HumanoidTracker.AliveHumanoid.Value
	if not Humanoid then
		ControllerJanitor:Remove("HumanoidJanitor")
	else
		local HumanoidJanitor = ControllerJanitor:Add(Janitor.new(), "Destroy", "HumanoidJanitor")
		local LastMove = TimeFunctions.TimeFunction()

		HumanoidJanitor:Add(function()
			HumanoidIdle.Value = false
		end, true)

		HumanoidJanitor:Add(Enabled.Changed:Connect(function()
			LastMove = TimeFunctions.TimeFunction()
		end), "Disconnect")

		HumanoidJanitor:Add(RunService.Stepped:Connect(function()
			local RootPart = Humanoid.RootPart
			if IdleController.RagdollBinders.Ragdoll:Get(Humanoid) then
				LastMove = TimeFunctions.TimeFunction()
			elseif RootPart then
				if RootPart.AssemblyLinearVelocity.Magnitude > 2.5 then
					LastMove = TimeFunctions.TimeFunction()
				end
			end

			HumanoidIdle.Value = TimeFunctions.TimeFunction() - LastMove >= STANDING_TIME_REQUIRED
		end), "Disconnect")
	end
end

function IdleController:IsHumanoidIdle()
	return HumanoidIdle.Value
end

function IdleController:DoShowIdleUI()
	return ShowIdleUI.Value
end

function IdleController:GetShowIdleUI()
	return ShowIdleUI
end

function IdleController:PushDisable()
	if RunService:IsRunning() then
		return DisabledStack:PushState()
	else
		return function() end
	end
end

function IdleController:KnitStart()
	GetController.Option("HumanoidTrackerController"):Match({
		None = function()
			warn("[IdleController.KnitStart] - Couldn't get HumanoidTrackerController!")
		end;

		Some = function(HumanoidTrackerController)
			GetController.Option("RagdollController"):Match({
				None = function()
					warn("[IdleController.KnitStart] - Couldn't get RagdollController!")
				end;

				Some = function(RagdollController)
					self.RagdollBinders = RagdollController.RagdollBinders
					HumanoidTracker = HumanoidTrackerController:GetHumanoidTracker()
					ControllerJanitor:Add(HumanoidIdle.Changed:Connect(UpdateShowIdleUI), "Disconnect")
					ControllerJanitor:Add(Enabled.Changed:Connect(UpdateShowIdleUI), "Disconnect")
					ControllerJanitor:Add(HumanoidTracker.AliveHumanoid.Changed:Connect(HandleAliveHumanoidChanged), "Disconnect")
					ControllerJanitor:Add(DisabledStack.Changed:Connect(function()
						Enabled.Value = not DisabledStack:GetState()
					end), "Disconnect")

					if HumanoidTracker.AliveHumanoid.Value then
						HandleAliveHumanoidChanged()
					end

					UpdateShowIdleUI()
				end;
			})
		end;
	})
end

return IdleController
