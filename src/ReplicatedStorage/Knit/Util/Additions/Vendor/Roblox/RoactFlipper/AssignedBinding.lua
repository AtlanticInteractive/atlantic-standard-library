local AssignedBinding = newproxy(true)
local Metatable = getmetatable(AssignedBinding)

function Metatable:__tostring()
	return "Symbol(AssignedBinding)"
end

return AssignedBinding
