--[=[
	Ragdolls the humanoid on death.
	@server
	@class RagdollHumanoidOnDeath
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local FastRequire = require(ReplicatedStorage.Knit.Util.Additions.Utility.FastRequire)
local RagdollBinders = FastRequire(script.Parent.Parent.RagdollBinders)

local RagdollHumanoidOnDeath = setmetatable({}, BaseObject)
RagdollHumanoidOnDeath.ClassName = "RagdollHumanoidOnDeath"
RagdollHumanoidOnDeath.__index = RagdollHumanoidOnDeath

--[=[
	Constructs a new RagdollHumanoidOnDeath. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@return RagdollHumanoidOnDeath
]=]
function RagdollHumanoidOnDeath.new(Humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(Humanoid), RagdollHumanoidOnDeath)
	self.RagdollBinder = RagdollBinders.Ragdoll

	self.Janitor:Add(self.Object:GetPropertyChangedSignal("Health"):Connect(function()
		if self.Object.Health <= 0 then
			self.RagdollBinder:Bind(self.Object)
		end
	end), "Disconnect")

	return self
end

function RagdollHumanoidOnDeath:__tostring()
	return "RagdollHumanoidOnDeath"
end

table.freeze(RagdollHumanoidOnDeath)
return RagdollHumanoidOnDeath
