local function createUseMemo(useValue)
	return function(createValue, dependencies)
		local currentValue = useValue(nil)

		local needToRecalculate = false

		if currentValue.value == nil then
			-- Defers calling of `createValue()` unless it is necessary.
			needToRecalculate = true
		else
			local localDependencies = currentValue.value.dependencies
			for index, dependency in ipairs(dependencies) do
				if dependency ~= localDependencies[index] then
					needToRecalculate = true
					break
				end
			end
		end

		if needToRecalculate then
			currentValue.value = {
				dependencies = dependencies,
				memoizedValue = {createValue()},
			}
		end

		return table.unpack(currentValue.value.memoizedValue)
	end
end

return createUseMemo
