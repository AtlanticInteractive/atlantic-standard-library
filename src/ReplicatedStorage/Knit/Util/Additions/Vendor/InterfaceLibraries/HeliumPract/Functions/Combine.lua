--- @typecheck mode: strict
local HeliumPractGlobalSystems = require(script.Parent.Parent.HeliumPractGlobalSystems)
local Symbols = require(script.Parent.Parent.Symbols)
local Types = require(script.Parent.Parent.Types)

local Symbols_ElementKind = Symbols.ElementKind
local Symbols_ElementKinds_SiblingCluster = Symbols.ElementKinds.SiblingCluster

if HeliumPractGlobalSystems.ENABLE_FREEZING then
	return function(...: Types.Element): Types.Element
		local Element = {
			[Symbols_ElementKind] = Symbols_ElementKinds_SiblingCluster;
			Elements = {...};
		}

		table.freeze(Element)
		return Element
	end
else
	return function(...: Types.Element): Types.Element
		return {
			[Symbols_ElementKind] = Symbols_ElementKinds_SiblingCluster;
			Elements = {...};
		}
	end
end
