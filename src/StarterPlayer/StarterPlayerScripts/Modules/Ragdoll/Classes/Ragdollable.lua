--[=[
	Should be bound via [RagdollBindersClient].

	@client
	@class RagdollableClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local CatchFactory = require(ReplicatedStorage.Knit.Util.Additions.Promises.CatchFactory)
local CharacterUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CharacterUtility)
local Constants = require(ReplicatedStorage.Knit.Util.Additions.KnitConstants)
local FastRequire = require(ReplicatedStorage.Knit.Util.Additions.Utility.FastRequire)
local HumanoidAnimatorUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.HumanoidAnimatorUtility)
local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)
local RagdollBinders = FastRequire(script.Parent.Parent.RagdollBinders)
local RagdollRigging = require(ReplicatedStorage.Knit.Util.Additions.Ragdoll.RagdollRigging)
local RagdollUtility = require(ReplicatedStorage.Knit.Util.Additions.Ragdoll.RagdollUtility)

local RagdollableClient = setmetatable({}, BaseObject)
RagdollableClient.ClassName = "RagdollableClient"
RagdollableClient.__index = RagdollableClient

require(StarterPlayerScripts:WaitForChild("Modules"):WaitForChild("PromiseRemoteEventMixin")):Add(RagdollableClient, Constants.RAGDOLL_CONSTANTS.REMOTE_EVENT_NAME)

--[=[
	Constructs a new RagdollableClient. Should be done via [Binder]. See [RagdollBindersClient].
	@param humanoid Humanoid
	@return RagdollableClient
]=]
function RagdollableClient.new(Humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(Humanoid), RagdollableClient)
	self.RagdollBinder = RagdollBinders.Ragdoll

	CharacterUtility.GetPlayerFromCharacter(self.Object):Match({
		None = function()
			self.Player = nil
			self:SetupLocal()
		end;

		Some = function(Player: Player)
			self.Player = Player
			if Player == Players.LocalPlayer then
				self:PromiseRemoteEvent():Then(function(RemoteEvent: RemoteEvent)
					self.LocalPlayerRemoteEvent = RemoteEvent or error("No RemoteEvent!")
					self:SetupLocal()
				end):Catch(CatchFactory("RagdollableClient.PromiseRemoteEvent"))
			end
		end;
	})

	return self
end

function RagdollableClient:SetupLocal()
	self.Janitor:Add(self.RagdollBinder:ObserveInstance(self.Object, function()
		self:OnRagdollChanged()
	end), true)

	self:OnRagdollChanged()
end

function RagdollableClient:OnRagdollChanged()
	if self.RagdollBinder:Get(self.Object) then
		self.Janitor:Add(self:RagdollLocal(), "Destroy", "Ragdoll")
		if self.LocalPlayerRemoteEvent then
			self.LocalPlayerRemoteEvent:FireServer(true)
		end
	else
		self.Janitor:Remove("Ragdoll")
		if self.LocalPlayerRemoteEvent then
			self.LocalPlayerRemoteEvent:FireServer(false)
		end
	end
end

function RagdollableClient:RagdollLocal()
	local RagdollJanitor = Janitor.new()
	RagdollRigging.CreateRagdollJoints(self.Object.Parent, self.Object.RigType)

	RagdollJanitor:Add(RagdollUtility.SetupState(self.Object), "Destroy")
	RagdollJanitor:Add(RagdollUtility.SetupMotors(self.Object), "Destroy")
	RagdollJanitor:Add(RagdollUtility.SetupHead(self.Object), false)
	HumanoidAnimatorUtility.StopAnimations(self.Object, 0)

	RagdollJanitor:Add(self.Object.AnimationPlayed:Connect(function(AnimationTrack)
		AnimationTrack:Stop(0)
	end), "Disconnect")

	RagdollJanitor:Add(RagdollUtility.PreventAnimationTransformLoop(self.Object), "Destroy")
	return RagdollJanitor
end

function RagdollableClient:__tostring()
	return "Ragdollable"
end

table.freeze(RagdollableClient)
return RagdollableClient
