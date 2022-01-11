--[=[
	Handles IK rigging for a humanoid
	@class IKRigClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local CatchFactory = require(ReplicatedStorage.Knit.Util.Additions.Promises.CatchFactory)
local Constants = require(ReplicatedStorage.Knit.Util.Additions.KnitConstants)
local IKRigAimerLocalPlayer = require(script.Parent.IKRigAimerLocalPlayer)
local IKRigBase = require(ReplicatedStorage.Knit.Util.Additions.IK.Rig.IKRigBase)

local IKRigClient = setmetatable({}, IKRigBase)
IKRigClient.ClassName = "IKRigClient"
IKRigClient.__index = IKRigClient

require(StarterPlayerScripts:WaitForChild("Modules"):WaitForChild("PromiseRemoteEventMixin")):Add(IKRigClient, Constants.IK_CONSTANTS.REMOTE_EVENT_NAME)

function IKRigClient.new(Humanoid: Humanoid)
	local self = setmetatable(IKRigBase.new(Humanoid), IKRigClient)

	self:PromiseRemoteEvent():Then(function(RemoteEvent: RemoteEvent)
		self.RemoteEvent = RemoteEvent or error("No remoteEvent")
		self.Janitor:Add(self.RemoteEvent.OnClientEvent:Connect(function(...)
			self:_HandleRemoteEventClient(...)
		end), "Disconnect")

		self:GetPlayer():Match({
			None = function() end;
			Some = function(Player)
				if Player == Players.LocalPlayer then
					self:_SetupLocalPlayer(self.RemoteEvent)
				end
			end;
		})
	end):Catch(CatchFactory("IKRigClient.PromiseRemoteEvent"))

	return self
end

--[=[
	Retrieves where the IK rig's position is, if it exists

	@return Vector3?
]=]
function IKRigClient:GetPositionOrNil()
	local RootPart = self.Object.RootPart
	if not RootPart then
		return nil
	end

	return RootPart.Position
end

--[=[
	Retrieves the local player aimer if it exists

	@return IKRigAimerLocalPlayer?
]=]
function IKRigClient:GetLocalPlayerAimer()
	return self.Aimer
end

function IKRigClient:_HandleRemoteEventClient(NewTarget)
	assert(typeof(NewTarget) == "Vector3" or NewTarget == nil, "Bad newTarget")

	local Torso = self:GetTorso()
	if Torso then
		Torso:Point(NewTarget)
	end
end

function IKRigClient:_SetupLocalPlayer(RemoteEvent: RemoteEvent)
	self.Aimer = self.Janitor:Add(IKRigAimerLocalPlayer.new(self, RemoteEvent), "Destroy")
end

function IKRigClient:__tostring()
	return "IKRigClient"
end

table.freeze(IKRigClient)
return IKRigClient
