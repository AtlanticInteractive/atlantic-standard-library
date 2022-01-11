--!nonstrict
--[[
	A 'Symbol' is an opaque marker type.

	Symbols have the type 'userdata', but when printed to the console, the name
	of the symbol is shown.
]]

local Symbol = {}

--[[
	Creates a Symbol with the given name.

	When printed or coerced to a string, the symbol will turn into the string
	given as its name.
]]
function Symbol.named(name)
	assert(type(name) == "string", "Symbols must be created using a string name!")

	local self = newproxy(true)
	local metatable = getmetatable(self)

	local wrappedName = string.format("Symbol(%s)", name)

	function metatable.__tostring()
		return wrappedName
	end

	return self
end

return Symbol
