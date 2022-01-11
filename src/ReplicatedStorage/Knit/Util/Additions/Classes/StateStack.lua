local BaseObject = require(script.Parent.BaseObject)

local StateStack = setmetatable({}, BaseObject)
StateStack.ClassName = "StateStack"
StateStack.__index = StateStack

function StateStack.new()
	local self = setmetatable(BaseObject.new(), StateStack)

	--- @type BoolValue
	self.State = self.Janitor:Add(Instance.new("BoolValue"), "Destroy")
	self.StateStack = {}

	self.Changed = self.State.Changed -- :Fire(NewState)

	return self
end

function StateStack:GetState()
	return self.State.Value
end

function StateStack:PushState()
	local Data = {}
	table.insert(self.StateStack, Data)

	self:UpdateState()

	return function()
		if self.Destroy then
			self:PopState(Data)
		end
	end
end

-- Private
function StateStack:PopState(Data)
	local Index = table.find(self.StateStack, Data)
	if Index then
		table.remove(self.StateStack, Index)
		self:UpdateState()
	else
		warn("[StateStack] - Failed to find index")
	end
end

function StateStack:UpdateState()
	self.State.Value = next(self.StateStack) ~= nil
end

function StateStack:__tostring()
	return "StateStack"
end

table.freeze(StateStack)
return StateStack
