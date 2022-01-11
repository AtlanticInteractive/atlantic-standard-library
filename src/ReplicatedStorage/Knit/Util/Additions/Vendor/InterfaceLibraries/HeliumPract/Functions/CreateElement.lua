--- @typecheck mode: strict
local Debug = require(script.Parent.Parent.Utility.Debug)
local HeliumPractGlobalSystems = require(script.Parent.Parent.HeliumPractGlobalSystems)
local Symbols = require(script.Parent.Parent.Symbols)
local Types = require(script.Parent.Parent.Types)

local Symbols_Children = Symbols.Children
local Symbols_ElementKind = Symbols.ElementKind
local Symbols_ElementKinds_CreateInstance = Symbols.ElementKinds.CreateInstance
local Symbols_ElementKinds_RenderComponent = Symbols.ElementKinds.RenderComponent

local HandleByType = setmetatable({
	["function"] = function(Component: Types.Component, Properties)
		return {
			[Symbols_ElementKind] = Symbols_ElementKinds_RenderComponent;
			Component = Component;
			Properties = Properties;
		}
	end;

	string = function(ClassName: string, Properties)
		return {
			[Symbols_ElementKind] = Symbols_ElementKinds_CreateInstance;
			ClassName = ClassName;
			Properties = Properties;
		}
	end;
}, {
	__index = function(_, ArgumentType)
		Debug.Error("invalid argument #1 to HeliumPract.CreateElement (string or HeliumPract.Component expected, got %q)", ArgumentType)
	end;
})

if HeliumPractGlobalSystems.ENABLE_FREEZING then
	return function(ClassNameOrComponent: string | Types.Component, PossibleProperties: Types.PropertiesArgument?, Children: Types.ChildrenArgument?): Types.Element
		local Properties = if PossibleProperties then PossibleProperties else {}
		if Children ~= nil then
			Properties[Symbols_Children] = Children
		end

		if not table.isfrozen(Properties) then
			table.freeze(Properties)
		end

		local Element = HandleByType[typeof(ClassNameOrComponent)](ClassNameOrComponent, Properties)
		table.freeze(Element)
		return Element
	end
else
	return function(ClassNameOrComponent: string | Types.Component, PossibleProperties: Types.PropertiesArgument?, Children: Types.ChildrenArgument?): Types.Element
		local Properties = if PossibleProperties then PossibleProperties else {}
		if Children ~= nil then
			Properties[Symbols_Children] = Children
		end

		return HandleByType[typeof(ClassNameOrComponent)](ClassNameOrComponent, Properties)
	end
end
