local Flipper = require(script.Parent.Parent.Parent.Flipper)
local UseGoal = require(script.Parent.UseGoal)

local function UseSpring(Hooks, TargetValue, Options)
	return UseGoal(Hooks, Flipper.Spring.new(TargetValue, Options))
end

return UseSpring
