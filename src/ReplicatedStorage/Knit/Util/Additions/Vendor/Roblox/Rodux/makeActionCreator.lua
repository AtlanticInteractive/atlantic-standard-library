--[[
	A helper function to define a Rodux action creator with an associated name.
]]
local function makeActionCreator(name, fn)
	assert(type(name) == "string", "Bad argument #1: Expected a string name for the action creator")
	assert(type(fn) == "function", "Bad argument #2: Expected a function that creates action objects")

	return setmetatable({
		name = name,
	}, {
		__call = function(_, ...)
			local result = fn(...)
			if type(result) ~= "table" then
				error("Invalid action: An action creator must return a table", 2)
			end

			result.type = name
			return result
		end,
	})
end

return makeActionCreator
