--[=[
	When a humanoid is tagged with this, it will unragdoll automatically.
	@server
	@class UnragdollAutomatically
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local FastRequire = require(ReplicatedStorage.Knit.Util.Additions.Utility.FastRequire)
local RagdollBinders = FastRequire(script.Parent.Parent.RagdollBinders)

local UnragdollAutomatically = setmetatable({}, BaseObject)
UnragdollAutomatically.ClassName = "UnragdollAutomatically"
UnragdollAutomatically.__index = UnragdollAutomatically

local UNRAGDOLL_AUTOMATIC_TIME = 2

--[=[
	Constructs a new UnragdollAutomatically. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@return UnragdollAutomatically
]=]
function UnragdollAutomatically.new(Humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(Humanoid), UnragdollAutomatically)
	self.RagdollBinders = RagdollBinders
	self.Janitor:Add(self.RagdollBinders.Ragdoll:ObserveInstance(self.Object, function()
		self:HandleRagdollChanged()
	end), true)

	self:HandleRagdollChanged()
	return self
end

function UnragdollAutomatically:HandleRagdollChanged()
	if self.RagdollBinders.Ragdoll:Get(self.Object) then
		self.RagdollTime = os.clock()
		self.Janitor:Add(RunService.Stepped:Connect(function()
			if os.clock() - self.RagdollTime >= UNRAGDOLL_AUTOMATIC_TIME and self.Object.Health > 0 then
				self.RagdollBinders.Ragdoll:Unbind(self.Object)
			end
		end), "Disconnect", "Connection")
	else
		self.Janitor:Remove("Connection")
	end
end

function UnragdollAutomatically:__tostring()
	return "UnragdollAutomatically"
end

table.freeze(UnragdollAutomatically)
return UnragdollAutomatically
