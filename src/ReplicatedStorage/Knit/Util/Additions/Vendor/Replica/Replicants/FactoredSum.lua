local Replicant = require(script.Parent.Parent.Replicant)
local Signal = require(script.Parent.Parent.Parent.Parent.Parent.Signal)

local FactoredSum, Members, Super = Replicant.Extend()
local Metatable = {__index = Members}

function Members:Iterator()
	return next, self.Wrapped
end

function Members:Iterate()
	return next, self.Wrapped
end

function Members:Pairs()
	return next, self.Wrapped
end

function Members:_SetLocal(Key, Value)
	if type(Key) ~= "string" then
		error("FactoredSum Replicant keys must be strings")
	end

	if Value ~= nil and type(Value) ~= "number" then
		error("FactoredSum Replicant values must be numbers")
	end

	self.Wrapped[Key] = Value
end

function Members:Reset()
	self:Collate(function()
		for Key in next, self.Wrapped do
			self:Set(Key, false)
		end
	end)
end

function Members:ResolveState()
	local Sum = 0
	for _, Value in next, self.Wrapped do
		Sum += Value
	end

	return Sum
end

function Members:Destroy()
	Super.Destroy(self)
	self.StateChanged:Destroy()
	self.StateChanged = nil
end

FactoredSum.SerialType = "FactoredSumReplicant"
function FactoredSum:Constructor(InitialValues, ...)
	Replicant.Constructor(self, ...)

	if InitialValues ~= nil then
		for Key, Value in next, InitialValues do
			self:_SetLocal(Key, Value)
		end
	end

	self.StateChanged = Signal.new()
	self._StateConnections = {}

	self.LastState = self:ResolveState()
	self.OnUpdate:Connect(function()
		local NewState = self:ResolveState()
		if NewState ~= self.LastState then
			self.LastState = NewState
			self.StateChanged:Fire(NewState)
		end
	end)
end

function FactoredSum.new(...)
	local self = setmetatable({}, Metatable)
	FactoredSum.Constructor(self, ...)
	return self
end

function FactoredSum:__tostring()
	return "FactoredSum"
end

return FactoredSum
