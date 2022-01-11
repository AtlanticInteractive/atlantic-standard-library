--- @typecheck mode: strict
local HeliumPractGlobalSystems = require(script.Parent.Parent.HeliumPractGlobalSystems)
local Symbols = require(script.Parent.Parent.Symbols)
local Types = require(script.Parent.Parent.Types)

local Symbols_ElementKind = Symbols.ElementKind
local Symbols_ElementKinds_Index = Symbols.ElementKinds.Index

if HeliumPractGlobalSystems.ENABLE_FREEZING then
	return function(Children: Types.ChildrenArgument?): Types.Element
		local Element = {
			[Symbols_ElementKind] = Symbols_ElementKinds_Index;
			Children = Children;
		}

		table.freeze(Element)
		return Element
	end
else
	return function(Children: Types.ChildrenArgument?): Types.Element
		return {
			[Symbols_ElementKind] = Symbols_ElementKinds_Index;
			Children = Children;
		}
	end
end
