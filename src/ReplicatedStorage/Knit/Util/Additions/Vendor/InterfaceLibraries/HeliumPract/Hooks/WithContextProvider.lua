--- @typecheck mode: strict
local HeliumPractGlobalSystems = require(script.Parent.Parent.HeliumPractGlobalSystems)
local Symbols = require(script.Parent.Parent.Symbols)
local Types = require(script.Parent.Parent.Types)

local ENABLE_FREEZING = HeliumPractGlobalSystems.ENABLE_FREEZING

type MakeClosureFunction = (Provide: (Key: string, Object: any) -> (() -> ())) -> Types.Component

local Symbols_ElementKind = Symbols.ElementKind
local Symbols_ElementKinds_ContextProvider = Symbols.ElementKinds.ContextProvider

local function WithContextProvider(MakeClosureFunction: MakeClosureFunction): Types.Component
	return if ENABLE_FREEZING then function(Properties: Types.PropertiesArgument)
		local Element = {
			[Symbols_ElementKind] = Symbols_ElementKinds_ContextProvider;
			MakeClosure = MakeClosureFunction;
			Properties = Properties;
		}

		table.freeze(Element)
		return Element
	end else function(Properties: Types.PropertiesArgument)
		return {
			[Symbols_ElementKind] = Symbols_ElementKinds_ContextProvider;
			MakeClosure = MakeClosureFunction;
			Properties = Properties;
		}
	end
end

return WithContextProvider
