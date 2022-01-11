local Spring = require(script.Spring)

local VELOCITY_THRESHOLD = 0.001
local POSITION_THRESHOLD = 0.001

local ImpulseSpring = {}
ImpulseSpring.ClassName = "ImpulseSpring"
ImpulseSpring.__index = ImpulseSpring

export type Options = {
	Damper: number,
	Position: number,
	Speed: number,
	Velocity: number,
}

function ImpulseSpring.new(TargetValue, PossibleOptions: Options?)
	assert(TargetValue, "Missing argument #1: targetValue")
	local Options = PossibleOptions or {}

	return setmetatable({
		_Spring = Spring.new(TargetValue):SetTarget(TargetValue, 0):SetDamper(Options.Damper or 1, 0):SetPosition(TargetValue, 0):SetSpeed(Options.Speed or 1, 0):SetVelocity((Options.Velocity or 0) * 0, 0);
		_TargetValue = TargetValue;
	}, ImpulseSpring)
end

function ImpulseSpring:Step(State, DeltaTime)
	local StepSpring = self._Spring:Impulse(State.velocity or 0, DeltaTime)

	local Goal = StepSpring:GetTarget(DeltaTime)
	local Velocity1 = StepSpring:GetVelocity(DeltaTime)
	local Position1 = StepSpring:GetPosition(DeltaTime)
	local Complete = math.abs(Velocity1) < VELOCITY_THRESHOLD and math.abs(Position1 - Goal) < POSITION_THRESHOLD

	return {
		complete = Complete;
		value = Complete and Goal or Position1;
		velocity = Velocity1;
	}
end

return ImpulseSpring
