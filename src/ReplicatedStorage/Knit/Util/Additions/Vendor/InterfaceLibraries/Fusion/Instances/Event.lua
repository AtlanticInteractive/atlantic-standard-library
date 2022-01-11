local OnEvent = require(script.Parent.OnEvent)

local Metatable = {}
function Metatable:__index(Index)
	local Value = OnEvent(Index)
	self[Index] = Value
	return Value
end

return setmetatable({}, Metatable)
