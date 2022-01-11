--- @typecheck mode: strict
local HeliumPractGlobalSystems = require(script.Parent.Parent.HeliumPractGlobalSystems)
local Symbols = require(script.Parent.Parent.Symbols)
local Types = require(script.Parent.Parent.Types)

local Symbols_Children = Symbols.Children
local Symbols_ElementKind = Symbols.ElementKind
local Symbols_ElementKinds_Stamp = Symbols.ElementKinds.Stamp

if HeliumPractGlobalSystems.ENABLE_FREEZING then
	return function(Template: Instance, PossibleProperties: Types.PropertiesArgument?, Children: Types.ChildrenArgument?): Types.Element
		local Properties = PossibleProperties or {}
		if Children ~= nil then
			Properties[Symbols_Children] = Children
		end

		if not table.isfrozen(Properties) then
			table.freeze(Properties)
		end

		local Element = {
			[Symbols_ElementKind] = Symbols_ElementKinds_Stamp;
			Properties = Properties;
			Template = Template;
		}

		table.freeze(Element)
		return Element
	end
else
	return function(Template: Instance, PossibleProperties: Types.PropertiesArgument?, Children: Types.ChildrenArgument?): Types.Element
		local Properties = PossibleProperties or {}
		if Children ~= nil then
			Properties[Symbols_Children] = Children
		end

		return {
			[Symbols_ElementKind] = Symbols_ElementKinds_Stamp;
			Properties = Properties;
			Template = Template;
		}
	end
end
