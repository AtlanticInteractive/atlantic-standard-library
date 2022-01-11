--- @typecheck mode: strict
local Symbols = require(script.Parent.Parent.Symbols)
local Symbols_None = Symbols.None

local function Join(...)
	local New = {}
	for Index = 1, select("#", ...) do
		local Dictionary = select(Index, ...)
		if Dictionary then
			for Key, Value in next, Dictionary do
				if Value == Symbols_None then
					New[Key] = nil
				else
					New[Key] = Value
				end
			end
		end
	end

	return New
end

return Join
