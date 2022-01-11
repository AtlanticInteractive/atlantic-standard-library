local FactoredOr = require(script.Parent.FactoredOr)
local FactoredNor, Members, Super = FactoredOr.Extend()
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

function Members:ResolveState()
	return not Super.ResolveState(self)
end

FactoredNor.SerialType = "FactoredNorReplicant"
function FactoredNor.new(...)
	local self = setmetatable({}, Metatable)
	FactoredNor.Constructor(self, ...)
	return self
end

function FactoredNor:__tostring()
	return "FactoredNor"
end

return FactoredNor
