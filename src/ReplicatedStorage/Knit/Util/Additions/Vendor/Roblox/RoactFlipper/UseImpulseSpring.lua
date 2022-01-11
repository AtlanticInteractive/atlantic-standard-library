local Flipper = require(script.Parent.Parent.Parent.Flipper)
local UseGoal = require(script.Parent.UseGoal)

local function UseImpulseSpring(Hooks, TargetValue, Options)
	return UseGoal(Hooks, Flipper.ImpulseSpring.new(TargetValue, Options))
end

return UseImpulseSpring
