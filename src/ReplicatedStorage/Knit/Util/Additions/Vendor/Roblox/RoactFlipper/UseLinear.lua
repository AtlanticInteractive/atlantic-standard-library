local Flipper = require(script.Parent.Parent.Parent.Flipper)
local UseGoal = require(script.Parent.UseGoal)

local function UseLinear(Hooks, TargetValue, Options)
	return UseGoal(Hooks, Flipper.Linear.new(TargetValue, Options))
end

return UseLinear
