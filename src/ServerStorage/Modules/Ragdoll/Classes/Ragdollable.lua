--[=[
	Should be bound to any humanoid that is ragdollable. See [RagdollBindersServer].
	@server
	@class Ragdollable
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local CharacterUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CharacterUtility)
local Constants = require(ReplicatedStorage.Knit.Util.Additions.KnitConstants)
local FastRequire = require(ReplicatedStorage.Knit.Util.Additions.Utility.FastRequire)
local HumanoidAnimatorUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.HumanoidAnimatorUtility)
local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)
local RagdollBinders = FastRequire(script.Parent.Parent.RagdollBinders)
local RagdollRigging = require(ReplicatedStorage.Knit.Util.Additions.Ragdoll.RagdollRigging)
local RagdollUtility = require(ReplicatedStorage.Knit.Util.Additions.Ragdoll.RagdollUtility)

local Ragdollable = setmetatable({}, BaseObject)
Ragdollable.ClassName = "Ragdollable"
Ragdollable.__index = Ragdollable

--[=[
	Constructs a new Ragdollable. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@return Ragdollable
]=]
function Ragdollable.new(Humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(Humanoid), Ragdollable)

	self.RagdollBinder = RagdollBinders.Ragdoll

	self.Object.BreakJointsOnDeath = false
	RagdollRigging.CreateRagdollJoints(self.Object.Parent, Humanoid.RigType)

	CharacterUtility.GetPlayerFromCharacter(self.Object):Match({
		None = function()
			self.Janitor:Add(self.RagdollBinder:ObserveInstance(self.Object, function()
				self:OnRagdollChangedForNPC()
			end), true)

			self:OnRagdollChangedForNPC()
		end;

		Some = function(Player: Player)
			self.Player = Player

			--- @type RemoteEvent
			self.RemoteEvent = self.Janitor:Add(Instance.new("RemoteEvent"), "Destroy")
			self.RemoteEvent.Name = Constants.RAGDOLL_CONSTANTS.REMOTE_EVENT_NAME
			self.RemoteEvent.Parent = self.Object

			self.Janitor:Add(self.RemoteEvent.OnServerEvent:Connect(function(...)
				self:HandleServerEvent(...)
			end), "Disconnect")
		end;
	})

	return self
end

function Ragdollable:OnRagdollChangedForNPC()
	if self.RagdollBinder:Get(self.Object) then
		self:SetRagdollEnabled(true)
	else
		self:SetRagdollEnabled(false)
	end
end

function Ragdollable:HandleServerEvent(Player, State)
	assert(self.Player == Player, "Bad player")

	if State then
		self.RagdollBinder:Bind(self.Object)
	else
		self.RagdollBinder:Unbind(self.Object)
	end

	self:SetRagdollEnabled(State)
end

function Ragdollable:SetRagdollEnabled(IsEnabled)
	if IsEnabled then
		if self.Janitor:Get("Ragdoll") then
			return
		end

		self.Janitor:Add(self:EnableServer(), "Destroy", "Ragdoll")
	else
		self.Janitor:Remove("Ragdoll")
	end
end

function Ragdollable:EnableServer()
	local RagdollJanitor = Janitor.new()

	-- This will reset friction too
	RagdollRigging.CreateRagdollJoints(self.Object.Parent, self.Object.RigType)

	RagdollJanitor:Add(RagdollUtility.SetupState(self.Object), "Destroy")
	RagdollJanitor:Add(RagdollUtility.SetupMotors(self.Object), "Destroy")
	RagdollJanitor:Add(RagdollUtility.SetupHead(self.Object), false)
	RagdollJanitor:Add(RagdollUtility.PreventAnimationTransformLoop(self.Object), "Destroy")

	-- Do this after we setup motors
	HumanoidAnimatorUtility.StopAnimations(self.Object, 0)

	RagdollJanitor:Add(self.Object.AnimationPlayed:Connect(function(AnimationTrack)
		AnimationTrack:Stop(0)
	end), "Disconnect")

	return RagdollJanitor
end

function Ragdollable:__tostring()
	return "Ragdollable"
end

table.freeze(Ragdollable)
return Ragdollable
