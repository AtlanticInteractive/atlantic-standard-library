local function createUseEffect(component)
	return function(callback, dependsOn)
		if type(callback) ~= "function" then
			error("useEffect callback is not a function", 2)
		end

		local hookCount = component.hookCounter + 1
		component.hookCounter = hookCount

		-- TODO: This mutates the component in the middle of render. That's bad, right?
		-- It's idempotent, so it shouldn't matter.
		-- Is there a way to do this that keeps `render` truly pure?
		component.effects[hookCount] = {callback, dependsOn}
	end
end

return createUseEffect
