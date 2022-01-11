local Replicant = require(script.Parent.Parent.Replicant)
local Signal = require(script.Parent.Parent.Parent.Parent.Parent.Signal)

local FactoredOr, Members, Super = Replicant.Extend()
local Metatable = {__index = Members}

function Members:Iterate()
	return next, self.Wrapped
end

function Members:Iterator()
	return next, self.Wrapped
end

function Members:Pairs()
	return next, self.Wrapped
end

function Members:_SetLocal(Key, Value)
	if type(Key) ~= "string" then
		error("FactoredOr Replicant keys must be strings")
	end

	self.Wrapped[Key] = Value
end

function Members:Set(Key, Value)
	if type(Value) ~= "boolean" then
		error("FactoredOr Replicant values must be boolean")
	end

	if Value == true then
		Super.Set(self, Key, true)
	else
		Super.Set(self, Key, nil)
	end
end

function Members:Reset()
	self:Collate(function()
		for Key in next, self.Wrapped do
			self:Set(Key, false)
		end
	end)
end

function Members:Toggle(Key)
	if self.Wrapped[Key] then
		self:Set(Key, false)
	else
		self:Set(Key, true)
	end
end

function Members:ResolveState()
	return next(self.Wrapped) ~= nil
end

function Members:Destroy()
	Super.Destroy(self)
	self.StateChanged:Destroy()
	self.StateChanged = nil
end

FactoredOr.SerialType = "FactoredOrReplicant"
function FactoredOr:Constructor(InitialValues, ...)
	Replicant.Constructor(self, ...)

	if InitialValues ~= nil then
		for Key, Value in next, InitialValues do
			if type(Value) ~= "boolean" then
				error("FactoredOr Replicant values must be boolean")
			end

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

function FactoredOr.new(...)
	local self = setmetatable({}, Metatable)
	FactoredOr.Constructor(self, ...)
	return self
end

function FactoredOr.Extend()
	local SubclassStatics, SubclassMembers = setmetatable({}, {__index = FactoredOr}), setmetatable({}, {__index = Members})
	SubclassMembers._Class = SubclassStatics
	return SubclassStatics, SubclassMembers, Members
end

function FactoredOr:__tostring()
	return "FactoredOr"
end

return FactoredOr
