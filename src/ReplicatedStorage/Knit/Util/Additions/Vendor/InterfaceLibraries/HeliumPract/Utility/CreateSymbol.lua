--- @typecheck mode: strict
-- A symbol is a userdata object that is used internally as unique object reference for indexing
-- a table.
local Types = require(script.Parent.Parent.Types)

local function CreateSymbol(Name: string, Proxy: any?): Types.Symbol
	local Symbol, Metatable
	if Proxy then
		Metatable = {}
		Symbol = setmetatable(Proxy, Metatable)
	else
		Symbol = newproxy(true)
		Metatable = getmetatable(Symbol :: any)
	end

	local WrappedName = "@@" .. Name :: any;
	(Metatable :: any).__tostring = function()
		return WrappedName
	end

	return Symbol :: Types.Symbol
end

return CreateSymbol
