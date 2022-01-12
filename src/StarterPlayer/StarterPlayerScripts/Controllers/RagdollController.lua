--[=[
	Handles ragdolling on the client.

	@client
	@class RagdollController
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local Knit = require(ReplicatedStorage.Knit)
local GetService = require(ReplicatedStorage.Knit.Util.GetService)
local RagdollBinders = require(StarterPlayerScripts:WaitForChild("Modules"):WaitForChild("Ragdoll"):WaitForChild("RagdollBinders"))
local Rx = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.Rx)
local RxBinderUtility = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.RxBinderUtility)
local RxBrioUtility = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.RxBrioUtility)
local RxInstanceUtility = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.RxInstanceUtility)

local RagdollController = Knit.CreateController({
	Name = "RagdollController";
})

function RagdollController:ObserveLocalPlayerRagdolled()
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
				return RxBinderUtility.ObserveBoundClass(self.RagdollBinders.Ragdoll, Humanoid)
			else
				return Rx.Of(nil)
			end
		end);
	})
end

--[=[
	Sets if a specific humanoid is ragdollable.
	@param Humanoid Humanoid
	@param IsRagdollable boolean
	@return RagdollController
]=]
function RagdollController:SetRagdollableHumanoid(Humanoid: Humanoid, IsRagdollable: boolean)
	local Ragdollable = self.RagdollBinders.Ragdollable
	if IsRagdollable then
		if not Ragdollable:Get(Humanoid) then
			Ragdollable:Bind(Humanoid)
		end
	else
		if Ragdollable:Get(Humanoid) then
			Ragdollable:Unbind(Humanoid)
		end
	end

	return self
end

--[=[
	Sets if a specific humanoid is ragdolled.
	@param Humanoid Humanoid
	@param DoRagdollHumanoid boolean
	@return RagdollController
]=]
function RagdollController:SetRagdollHumanoid(Humanoid: Humanoid, DoRagdollHumanoid: boolean)
	local Ragdoll = self.RagdollBinders.Ragdoll
	if DoRagdollHumanoid then
		if not Ragdoll:Get(Humanoid) then
			Ragdoll:Bind(Humanoid)
		end
	else
		if Ragdoll:Get(Humanoid) then
			Ragdoll:Unbind(Humanoid)
		end
	end

	return self
end

--[=[
	Sets if a specific humanoid is ragdolled when they die.
	@param Humanoid Humanoid
	@param DoRagdollHumanoidOnDeath boolean
	@return RagdollController
]=]
function RagdollController:SetRagdollHumanoidOnDeath(Humanoid: Humanoid, DoRagdollHumanoidOnDeath: boolean)
	local RagdollHumanoidOnDeath = self.RagdollBinders.RagdollHumanoidOnDeath
	if DoRagdollHumanoidOnDeath then
		if not RagdollHumanoidOnDeath:Get(Humanoid) then
			RagdollHumanoidOnDeath:Bind(Humanoid)
		end
	else
		if RagdollHumanoidOnDeath:Get(Humanoid) then
			RagdollHumanoidOnDeath:Unbind(Humanoid)
		end
	end

	return self
end

--[=[
	Sets if a specific humanoid is ragdolled when they fall.
	@param Humanoid Humanoid
	@param DoRagdollHumanoidOnFall boolean
	@return RagdollController
]=]
function RagdollController:SetRagdollHumanoidOnFall(Humanoid: Humanoid, DoRagdollHumanoidOnFall: boolean)
	local RagdollHumanoidOnFall = self.RagdollBinders.RagdollHumanoidOnFall
	if DoRagdollHumanoidOnFall then
		if not RagdollHumanoidOnFall:Get(Humanoid) then
			RagdollHumanoidOnFall:Bind(Humanoid)
		end
	else
		if RagdollHumanoidOnFall:Get(Humanoid) then
			RagdollHumanoidOnFall:Unbind(Humanoid)
		end
	end

	return self
end

local UPDATE_FUNCTIONS = {
	Ragdollable = function(Humanoid: Humanoid, IsRagdollable: boolean)
		RagdollController:SetRagdollableHumanoid(Humanoid, IsRagdollable)
	end;

	Ragdoll = function(Humanoid: Humanoid, IsRagdollable: boolean)
		RagdollController:SetRagdollHumanoid(Humanoid, IsRagdollable)
	end;

	RagdollHumanoidOnDeath = function(Humanoid: Humanoid, IsRagdollable: boolean)
		RagdollController:SetRagdollHumanoidOnDeath(Humanoid, IsRagdollable)
	end;

	RagdollHumanoidOnFall = function(Humanoid: Humanoid, IsRagdollable: boolean)
		RagdollController:SetRagdollHumanoidOnFall(Humanoid, IsRagdollable)
	end;
}

function RagdollController:KnitStart()
	self.RagdollBinders:Start()

	GetService.Option("RagdollService"):Match({
		None = function()
			warn("[RagdollController.KnitStart] - Couldn't get RagdollService!")
		end;

		Some = function(RagdollService)
			RagdollService.SetGlobalRagdollBehavior:Connect(function(BehaviorName, ...)
				local UpdateFunction = UPDATE_FUNCTIONS[BehaviorName]
				if UpdateFunction then
					UpdateFunction(...)
				end
			end)
		end;
	})

	-- self:ObserveLocalPlayerRagdolled():Subscribe(function(RagdollClass)
	-- 	if RagdollClass then
	-- 		print("Ragdolled!")
	-- 	else
	-- 		print("Unragdolled!")
	-- 	end
	-- end)
end

function RagdollController:KnitInit()
	self.RagdollBinders = RagdollBinders:Initialize()
end

return RagdollController
