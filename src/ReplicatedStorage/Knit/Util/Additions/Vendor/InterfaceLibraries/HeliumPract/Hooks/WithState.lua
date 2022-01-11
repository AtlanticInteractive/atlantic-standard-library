--- @typecheck mode: strict
local HeliumPractGlobalSystems = require(script.Parent.Parent.HeliumPractGlobalSystems)
local Symbols = require(script.Parent.Parent.Symbols)
local Types = require(script.Parent.Parent.Types)

local ENABLE_FREEZING = HeliumPractGlobalSystems.ENABLE_FREEZING

-- stylua: ignore
type MakeClosureFunction = (
	GetState: () -> any,
	SetState: (any) -> (),
	SubscribeState: (() -> ()) -> (() -> ())
) -> Types.Component

local Symbols_ElementKind = Symbols.ElementKind
local Symbols_ElementKinds_StateComponent = Symbols.ElementKinds.StateComponent

local function WithState(MakeClosureFunction: MakeClosureFunction): Types.Component
	return if ENABLE_FREEZING then function(Properties: Types.PropertiesArgument)
		local Element = {
			[Symbols_ElementKind] = Symbols_ElementKinds_StateComponent;
			Deferred = false;
			MakeStateClosure = MakeClosureFunction;
			Properties = Properties;
		}

		table.freeze(Element)
		return Element
	end else function(Properties: Types.PropertiesArgument)
		return {
			[Symbols_ElementKind] = Symbols_ElementKinds_StateComponent;
			Deferred = false;
			MakeStateClosure = MakeClosureFunction;
			Properties = Properties;
		}
	end
end

return WithState
