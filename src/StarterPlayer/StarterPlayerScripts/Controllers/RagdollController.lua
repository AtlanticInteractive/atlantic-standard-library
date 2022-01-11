local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local Knit = require(ReplicatedStorage.Knit)
local RagdollBinders = require(StarterPlayerScripts:WaitForChild("Modules"):WaitForChild("Ragdoll"):WaitForChild("RagdollBinders"))
local Rx = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.Rx)
local RxBinderUtility = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.RxBinderUtility)
local RxBrioUtility = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.RxBrioUtility)
local RxInstanceUtility = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.RxInstanceUtility)

local RagdollController = Knit.CreateController({
	Name = "RagdollController";
})

local function ObserveLocalPlayerRagdolled()
	return RxInstanceUtility.ObserveProperty(Players.LocalPlayer, "Character"):Pipe({
		Rx.SwitchMap(function(Character: Model)
			if Character then
				return RxBrioUtility.FlattenToValueAndNil(RxInstanceUtility.ObserveChildrenOfClassBrio(Character, "Humanoid"))
			else
				return Rx.Of(nil)
			end
		end);

		Rx.SwitchMap(function(Humanoid: Humanoid)
			if Humanoid then
				return RxBinderUtility.ObserveBoundClass(RagdollController.RagdollsBinders.Ragdoll, Humanoid)
			else
				return Rx.Of(nil)
			end
		end);
	})
end

function RagdollController:KnitStart()
	self.RagdollBinders:Start()

	ObserveLocalPlayerRagdolled():Subscribe(function(RagdollClass)
		if RagdollClass then
			print("Ragdolled!")
		else
			print("Unragdolled!")
		end
	end)
end

function RagdollController:KnitInit()
	self.RagdollBinders = RagdollBinders:Initialize()
end

return RagdollController
