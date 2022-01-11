--- @typecheck mode: strict
local HeliumPractGlobalSystems = require(script.Parent.Parent.HeliumPractGlobalSystems)
local Symbols = require(script.Parent.Parent.Symbols)
local Types = require(script.Parent.Parent.Types)

local ENABLE_FREEZING = HeliumPractGlobalSystems.ENABLE_FREEZING

local Symbols_ElementKind = Symbols.ElementKind
local Symbols_ElementKinds_SignalComponent = Symbols.ElementKinds.SignalComponent

local function WithSignal(Signal: RBXScriptSignal, WrappedComponent: Types.Component): Types.Component
	return if ENABLE_FREEZING then function(Properties: Types.PropertiesArgument)
		local Element = {
			[Symbols_ElementKind] = Symbols_ElementKinds_SignalComponent;
			Properties = Properties;
			Render = WrappedComponent;
			Signal = Signal;
		}

		table.freeze(Element)
		return Element
	end else function(Properties: Types.PropertiesArgument)
		return {
			[Symbols_ElementKind] = Symbols_ElementKinds_SignalComponent;
			Properties = Properties;
			Render = WrappedComponent;
			Signal = Signal;
		}
	end
end

return WithSignal
