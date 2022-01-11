local Linear = {}
Linear.ClassName = "Linear"
Linear.__index = Linear

function Linear.new(TargetValue, Options)
	assert(TargetValue, "Missing argument #1: targetValue")
	Options = Options or {}

	return setmetatable({
		_TargetValue = TargetValue;
		_Velocity = Options.Velocity or 1;
	}, Linear)
end

function Linear:Step(State, DeltaTime)
	local Position = State.value
	local Velocity = self._Velocity -- Linear motion ignores the state's velocity
	local Goal = self._TargetValue

	local DeltaPosition = DeltaTime * Velocity
	local Complete = DeltaPosition >= math.abs(Goal - Position)
	Position += DeltaPosition * (Goal > Position and 1 or -1)
	if Complete then
		Position = self._TargetValue
		Velocity = 0
	end

	return {
		complete = Complete;
		value = Position;
		velocity = Velocity;
	}
end

return Linear
