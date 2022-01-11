local Memoize = require(script.Parent.Parent.Utility.Memoize)

local CatchFactory = Memoize(function(FunctionName: string)
	return function(Error)
		warn(string.format("[CatchFactory] - Error in function %s: %s", FunctionName, tostring(Error)))
	end
end)

return CatchFactory
