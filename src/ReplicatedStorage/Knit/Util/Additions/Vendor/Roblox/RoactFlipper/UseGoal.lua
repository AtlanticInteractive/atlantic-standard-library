local GetBinding = require(script.Parent.GetBinding)
local UseMotor = require(script.Parent.UseMotor)

local function GetInitialValue(Goal)
	if Goal.Step then
		return Goal._TargetValue
	else
		local InitialValues = {}
		for Key, Motor in next, Goal do
			InitialValues[Key] = GetInitialValue(Motor)
		end

		return InitialValues
	end
end

local function UseGoal(Hooks, Goal)
	local Motor = UseMotor(Hooks, GetInitialValue(Goal))
	Motor:SetGoal(Goal)
	return GetBinding(Motor), Motor
end

return UseGoal
