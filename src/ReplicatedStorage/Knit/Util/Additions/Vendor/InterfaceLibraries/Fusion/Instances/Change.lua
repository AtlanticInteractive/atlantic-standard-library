local OnChange = require(script.Parent.OnChange)

local Metatable = {}
function Metatable:__index(Index)
	local Value = OnChange(Index)
	self[Index] = Value
	return Value
end

return setmetatable({}, Metatable)
