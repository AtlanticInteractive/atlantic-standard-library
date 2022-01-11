--- Provides utilities for working with valuesbase objects, like IntValue or ObjectValue in Roblox.
-- @module ValueBaseUtils
-- @author Quenty

local ValueBaseUtils = {}

function ValueBaseUtils.IsValueBase(instance)
	return typeof(instance) == "Instance" and string.sub(instance.ClassName, -#"Value") == "Value"
end

function ValueBaseUtils.GetOrCreateValue(parent, instanceType, name, defaultValue)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if not foundChild:IsA(instanceType) then
			warn(string.format("[ValueBaseUtils.getOrCreateValue] - Value of type %q of name %q is of type %q in %s instead", instanceType, name, foundChild.ClassName, foundChild:GetFullName()))
		end

		return foundChild
	else
		local newChild = Instance.new(instanceType)
		newChild.Name = name
		newChild.Value = defaultValue
		newChild.Parent = parent

		return newChild
	end
end

function ValueBaseUtils.SetValue(parent, instanceType, name, value)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if not foundChild:IsA(instanceType) then
			warn(string.format("[ValueBaseUtils.setValue] - Value of type %q of name %q is of type %q in %s instead", instanceType, name, foundChild.ClassName, foundChild:GetFullName()))
		end

		foundChild.Value = value
	else
		local newChild = Instance.new(instanceType)
		newChild.Name = name
		newChild.Value = value
		newChild.Parent = parent
	end
end

function ValueBaseUtils.GetValue(parent, instanceType, name, default)
	assert(typeof(parent) == "Instance", "Bad argument 'parent'")
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	local foundChild = parent:FindFirstChild(name)
	if foundChild then
		if foundChild:IsA(instanceType) then
			return foundChild.Value
		else
			warn(string.format("[ValueBaseUtils.getValue] - Value of type %q of name %q is of type %q in %s instead", instanceType, name, foundChild.ClassName, foundChild:GetFullName()))
			return nil
		end
	else
		return default
	end
end

function ValueBaseUtils.CreateGetSet(instanceType, name)
	assert(type(instanceType) == "string", "Bad argument 'instanceType'")
	assert(type(name) == "string", "Bad argument 'name'")

	return function(parent, defaultValue)
		assert(typeof(parent) == "Instance", "Bad argument 'parent'")

		return ValueBaseUtils.GetValue(parent, instanceType, name, defaultValue)
	end, function(parent, value)
		assert(typeof(parent) == "Instance", "Bad argument 'parent'")

		return ValueBaseUtils.SetValue(parent, instanceType, name, value)
	end, function(parent, defaultValue)
		return ValueBaseUtils.GetOrCreateValue(parent, instanceType, name, defaultValue)
	end
end

return ValueBaseUtils
