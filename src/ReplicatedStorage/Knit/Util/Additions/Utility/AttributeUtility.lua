--[=[
	Provides utility functions to work with attributes in Roblox
	@class AttributeUtility
]=]

local RunService = game:GetService("RunService")
local Janitor = require(script.Parent.Parent.Parent.Janitor)

local AttributeUtility = {}

--[=[
	Whenever the attribute is true, the binder will be bound, and when the
	binder is bound, the attribute will be true.

	@param instance Instance
	@param attributeName string
	@param binder Binder<T>
	@return Janitor
]=]
function AttributeUtility.BindToBinder(Object: Instance, AttributeName: string, Binder)
	assert(Binder, "Bad binder")
	assert(typeof(Object) == "Instance", "Bad instance")
	assert(type(AttributeName) == "string", "Bad attributeName")

	local BindJanitor = Janitor.new()

	BindJanitor:Add(Object:GetAttributeChangedSignal(AttributeName):Connect(function()
		if Object:GetAttribute(AttributeName) then
			if RunService:IsClient() then
				Binder:BindClient(Object)
			else
				Binder:Bind(Object)
			end
		else
			if RunService:IsClient() then
				Binder:UnbindClient(Object)
			else
				Binder:Unbind(Object)
			end
		end
	end), "Disconnect")

	BindJanitor:Add(Binder:ObserveInstance(Object, function()
		if Binder:Get(Object) then
			Object:SetAttribute(AttributeName, true)
		else
			Object:SetAttribute(AttributeName, false)
		end
	end), true)

	if Binder:Get(Object) or Object:GetAttribute(AttributeName) then
		Object:SetAttribute(AttributeName, true)
		if RunService:IsClient() then
			Binder:BindClient(Object)
		else
			Binder:Bind(Object)
		end
	else
		Object:SetAttribute(AttributeName, false)
	end

	BindJanitor:Add(function()
		BindJanitor:Cleanup()
		Object:SetAttribute(AttributeName, nil)
	end, true)

	return BindJanitor
end

--[=[
	Initializes an attribute for a given instance

	@param instance Instance
	@param attributeName string
	@param default any
	@return any? -- The value of the attribute
]=]
function AttributeUtility.InitializeAttribute(Object: Instance, AttributeName: string, Default: any?)
	local Value = Object:GetAttribute(AttributeName)
	if Value == nil then
		Object:SetAttribute(AttributeName, Default)
		Value = Default
	end

	return Value
end

table.freeze(AttributeUtility)
return AttributeUtility
