local function createUseToggle(useCallback, useState)
	return function(initialState)
		if initialState == nil then
			initialState = false
		end

		local state, setState = useState(initialState)
		return state, useCallback(function()
			setState(not state)
		end, {})
	end
end

return createUseToggle
