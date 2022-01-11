local function createUseValue(component)
	return function(defaultValue)
		local hookCount = component.hookCounter + 1
		component.hookCounter = hookCount

		local values = component.values

		if values == nil then
			values = {}
			component.values = values
		end

		if values[hookCount] == nil then
			values[hookCount] = {value = defaultValue}
		end

		return values[hookCount]
	end
end

return createUseValue
