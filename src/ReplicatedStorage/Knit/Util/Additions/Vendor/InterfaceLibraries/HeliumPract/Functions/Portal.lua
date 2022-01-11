--- @typecheck mode: strict
local HeliumPractGlobalSystems = require(script.Parent.Parent.HeliumPractGlobalSystems)
local Symbols = require(script.Parent.Parent.Symbols)
local Types = require(script.Parent.Parent.Types)

local Symbols_ElementKind = Symbols.ElementKind
local Symbols_ElementKinds_Portal = Symbols.ElementKinds.Portal

if HeliumPractGlobalSystems.ENABLE_FREEZING then
	return function(HostParent: Instance, Children: Types.ChildrenArgument?): Types.Element
		local Element = {
			[Symbols_ElementKind] = Symbols_ElementKinds_Portal;
			Children = Children;
			HostParent = HostParent;
		}

		table.freeze(Element)
		return Element
	end
else
	return function(HostParent: Instance, Children: Types.ChildrenArgument?): Types.Element
		return {
			[Symbols_ElementKind] = Symbols_ElementKinds_Portal;
			Children = Children;
			HostParent = HostParent;
		}
	end
end
