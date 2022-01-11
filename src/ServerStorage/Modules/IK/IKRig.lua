--[=[
	Serverside implementation of IKRig
	@server
	@class IKRig
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Knit.Util.Additions.KnitConstants)
local CharacterUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CharacterUtility)
local IKRigBase = require(ReplicatedStorage.Knit.Util.Additions.IK.Rig.IKRigBase)

local IKRig = setmetatable({}, IKRigBase)
IKRig.ClassName = "IKRig"
IKRig.__index = IKRig

-- type Option<T> = Option.Option<T>

function IKRig.new(Humanoid: Humanoid)
	local self = setmetatable(IKRigBase.new(Humanoid), IKRig)

	self.RemoteEvent = self.Janitor:Add(Instance.new("RemoteEvent"), "Destroy")
	self.RemoteEvent.Name = Constants.IK_CONSTANTS.REMOTE_EVENT_NAME
	self.RemoteEvent.Parent = self.Object

	self.Janitor:Add(self.RemoteEvent.OnServerEvent:Connect(function(...)
		self:_OnServerEvent(...)
	end), "Disconnect")

	self.Target = nil
	return self
end

--[=[
	Returns where the rig is looking at

	@return Vector3?
]=]
function IKRig:GetTarget()
	return self.Target
end

--[=[
	Sets the IK Rig target and replicates it to the client

	@param target Vector3?
]=]
function IKRig:SetRigTarget(Target)
	assert(Target == nil or typeof(Target) == "Vector3", "Bad target")
	self.Target = Target

	local Torso = self:GetTorso()
	if Torso then
		Torso:Point(self.Target)
	end

	self.RemoteEvent:FireAllClients(Target)
end

function IKRig:_OnServerEvent(Player, Target)
	CharacterUtility.GetPlayerFromCharacter(self.Object):Match({
		None = function()
			error("Bad player.")
		end;

		Some = function(LocalPlayer)
			assert(Player == LocalPlayer, "Bad player.")
		end;
	})

	assert(Target == nil or typeof(Target) == "Vector3", "Bad target")
	if Target ~= Target then
		return
	end

	self.Target = Target

	local Torso = self:GetTorso()
	if Torso then
		Torso:Point(self.Target)
	end

	-- Do replication
	for _, Other in ipairs(Players:GetPlayers()) do
		if Other ~= Player then
			self.RemoteEvent:FireClient(Other, Target) -- target may nil
		end
	end
end

function IKRig:__tostring()
	return "IKRig"
end

table.freeze(IKRig)
return IKRig
