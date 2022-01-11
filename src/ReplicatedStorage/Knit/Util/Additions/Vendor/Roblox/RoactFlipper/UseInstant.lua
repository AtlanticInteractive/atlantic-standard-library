local Flipper = require(script.Parent.Parent.Parent.Flipper)
local UseGoal = require(script.Parent.UseGoal)

local function UseInstant(Hooks, TargetValue)
	return UseGoal(Hooks, Flipper.Instant.new(TargetValue))
end

return UseInstant
