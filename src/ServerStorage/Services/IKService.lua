--[=[
	Handles the replication of inverse kinematics (IK) from clients to servers

	* Supports animation playback on top of existing animations
	* Battle-tested code
	* Handles streaming enabled
	* Supports NPCs
	* Client-side animations scale with distance
	* Client-side animations keep thinks silky

	@server
	@class IKService
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Knit)
local HumanoidTracker = require(ReplicatedStorage.Knit.Util.Additions.Classes.HumanoidTracker)
local IKBinders = require(ServerStorage.Modules.IK.IKBinders)
local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)

local SERVER_UPDATE_RATE = 1 / 10

local IKService = Knit.CreateService({
	Client = {};
	Name = "IKService";
})

--[=[
	Retrieves an IKRig. Binds the rig if it isn't already bound.
	@param humanoid Humanoid
	@return IKRig?
]=]
function IKService:GetRig(Humanoid: Humanoid)
	return self.IkBinders.IKRig:Bind(Humanoid)
end

--[=[
	Retrieves an IKRig. Binds the rig if it isn't already bound.
	@param humanoid Humanoid
	@return Promise<IKRig>
]=]
function IKService:PromiseRig(Humanoid: Humanoid)
	assert(typeof(Humanoid) == "Instance", "Bad humanoid")
	self.IkBinders.IKRig:Bind(Humanoid)
	return self.IkBinders.IKRig:Promise(Humanoid)
end

--[=[
	Unbinds the rig from the humanoid.
	@param humanoid Humanoid
]=]
function IKService:RemoveRig(Humanoid: Humanoid)
	assert(typeof(Humanoid) == "Instance" and Humanoid:IsA("Humanoid"), "Bad humanoid")
	self.IkBinders.IKRig:Unbind(Humanoid)
end

--[=[
	Updates the ServerIKRig target for an NPC

	```lua
	local IKService = require("IKService")

	-- Make the NPC look at a target
	serviceBag:GetService(IKService):UpdateServerRigTarget(workspace.NPC.Humanoid, Vector3.new(0, 0, 0))
	```

	@param humanoid Humanoid
	@param target Vector3?
]=]
function IKService:UpdateServerRigTarget(Humanoid: Humanoid, Target: Vector3)
	assert(typeof(Humanoid) == "Instance" and Humanoid:IsA("Humanoid"), "Bad humanoid")
	assert(typeof(Target) == "Vector3", "Bad target")

	local ServerRig = self.IkBinders.IKRig:Bind(Humanoid)
	if not ServerRig then
		return warn("[IKService.UpdateServerRigTarget] - No serverRig")
	end

	ServerRig:SetRigTarget(Target)
end

function IKService:KnitStart()
	self.IkBinders:Start()

	local function PlayerAdded(Player: Player)
		local PlayerJanitor = self.Janitor:Add(Janitor.new(), "Destroy", Player)
		local PlayerTracker = PlayerJanitor:Add(HumanoidTracker.new(Player), "Destroy")

		PlayerJanitor:Add(PlayerTracker.AliveHumanoid.Changed:Connect(function(New, Old)
			if Old then
				self.IkBinders.IKRig:Unbind(Old)
			end

			if New then
				self.IkBinders.IKRig:Bind(New)
			end
		end), "Disconnect")

		if PlayerTracker.AliveHumanoid.Value then
			self.IkBinders.IKRig:Bind(PlayerTracker.AliveHumanoid.Value)
		end
	end

	local function OnStepped()
		debug.profilebegin("IKUpdateServer")

		for _, Rig in ipairs(self.IkBinders.IKRig:GetAll()) do
			debug.profilebegin("RigUpdateServer")

			local LastUpdateTime = Rig:GetLastUpdateTime()
			if os.clock() - LastUpdateTime >= SERVER_UPDATE_RATE then
				Rig:Update() -- Update actual rig
			else
				Rig:UpdateTransformOnly()
			end

			debug.profileend()
		end

		debug.profileend()
	end

	self.Janitor:Add(Players.PlayerAdded:Connect(PlayerAdded), "Disconnect")
	self.Janitor:Add(Players.PlayerRemoving:Connect(function(Player)
		self.Janitor:Remove(Player)
	end), "Disconnect")

	for _, Player in ipairs(Players:GetPlayers()) do
		PlayerAdded(Player)
	end

	self.Janitor:Add(RunService.Stepped:Connect(OnStepped), "Disconnect")
end

function IKService:KnitInit()
	self.Janitor = Janitor.new()
	self.IkBinders = IKBinders:Initialize()
end

return IKService
