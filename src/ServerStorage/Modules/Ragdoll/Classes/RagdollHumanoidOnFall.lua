--[=[
	When a humanoid is bound with this, it will ragdoll upon falling. Recommended that you use
	[UnragdollAutomatically] in conjunction with this.

	@server
	@class RagdollHumanoidOnFall
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local BindableRagdollHumanoidOnFall = require(ReplicatedStorage.Knit.Util.Additions.Ragdoll.Classes.BindableRagdollHumanoidOnFall)
local CharacterUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CharacterUtility)
local FastRequire = require(ReplicatedStorage.Knit.Util.Additions.Utility.FastRequire)
local RagdollBinders = FastRequire(script.Parent.Parent.RagdollBinders)
local RagdollHumanoidOnFallConstants = require(ReplicatedStorage.Knit.Util.Additions.Ragdoll.Classes.RagdollHumanoidOnFallConstants)

local RagdollHumanoidOnFall = setmetatable({}, BaseObject)
RagdollHumanoidOnFall.ClassName = "RagdollHumanoidOnFall"
RagdollHumanoidOnFall.__index = RagdollHumanoidOnFall

--[=[
	Constructs a new RagdollHumanoidOnFall. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@return RagdollHumanoidOnFall
]=]
function RagdollHumanoidOnFall.new(Humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(Humanoid), RagdollHumanoidOnFall)

	self.RagdollBinder = RagdollBinders.Ragdoll

	CharacterUtility.GetPlayerFromCharacter(self.Object):Match({
		None = function()
			self.RagdollLogic = self.Janitor:Add(BindableRagdollHumanoidOnFall.new(self.Object, self.RagdollBinder), "Destroy")
			self.Janitor:Add(self.RagdollLogic.ShouldRagdoll.Changed:Connect(function()
				self:Update()
			end), "Disconnect")
		end;

		Some = function(Player: Player)
			self.Player = Player

			--- @type RemoteEvent
			self.RemoteEvent = self.Janitor:Add(Instance.new("RemoteEvent"), "Destroy")
			self.RemoteEvent.Name = RagdollHumanoidOnFallConstants.REMOTE_EVENT_NAME
			self.RemoteEvent.Parent = self.Object

			self.Janitor:Add(self.RemoteEvent.OnServerEvent:Connect(function(...)
				self:HandleServerEvent(...)
			end), "Disconnect")
		end;
	})

	return self
end

function RagdollHumanoidOnFall:HandleServerEvent(Player, Value)
	assert(Player == self.Player, "Bad player")
	assert(typeof(Value) == "boolean", "Bad value")

	if Value then
		self.RagdollBinder:Bind(self.Object)
	else
		self.RagdollBinder:Unbind(self.Object)
	end
end

function RagdollHumanoidOnFall:Update()
	if self.RagdollLogic.ShouldRagdoll.Value then
		self.RagdollBinder:Bind(self.Object)
	else
		if self.Object.Health > 0 then
			self.RagdollBinder:Unbind(self.Object)
		end
	end
end

function RagdollHumanoidOnFall:__tostring()
	return "RagdollHumanoidOnFall"
end

table.freeze(RagdollHumanoidOnFall)
return RagdollHumanoidOnFall
