--[=[
	Provides a means to, with both a continuous position and velocity,
	accelerate from its current position to a target position in minimum time
	given a maximum acceleration.

	Author: TreyReynolds/AxisAngles

	@class AccelTween
]=]

local TimeFunctions = require(script.Parent.Parent.Utility.TimeFunctions)

local AccelTween = {}
AccelTween.ClassName = "AccelTween"
AccelTween.__index = AccelTween

--[=[
	@within AccelTween
	@prop MaxAcceleration number
	@readonly
	The maximum acceleration of the AccelTween object.

	Defaults to `1`.
]=]

--[=[
	@within AccelTween
	@prop Target number
	@readonly
	The target position of the AccelTween object.
]=]

--[=[
	Creates a new AccelTween object.
	@param MaxAcceleration number? -- The maximum acceleration applied to reach its target. Defaults to 1.
	@return AccelTween
]=]
function AccelTween.new(MaxAcceleration: number?)
	return setmetatable({
		MaxAcceleration = MaxAcceleration or 1;
		T0 = 0;
		Y0 = 0;
		A0 = 0;

		T1 = 0;
		Target = 0;
		A1 = 0;
	}, AccelTween)
end

local function GetState(self, Time)
	local T0 = self.T0
	local T1 = self.T1

	if Time < (T0 + T1) / 2 then
		local A0 = self.A0
		local DeltaTime = Time - T0

		return self.Y0 + DeltaTime * DeltaTime / 2 * A0, DeltaTime * A0
	elseif Time < T1 then
		local A1 = self.A1
		local DeltaTime = Time - T1

		return self.Target + DeltaTime * DeltaTime / 2 * A1, DeltaTime * A1
	else
		return self.Target, 0
	end
end

local function SetState(self, NewPosition, NewVelocity, NewAcceleration, NewTarget)
	local Time = TimeFunctions.TimeFunction()
	local Position, Velocity = GetState(self, Time)
	Position = NewPosition or Position
	Velocity = NewVelocity or Velocity
	self.MaxAcceleration = NewAcceleration or self.MaxAcceleration

	local Target = NewTarget or self.Target

	local Acceleration = self.MaxAcceleration

	if Acceleration * Acceleration < 1E-8 then
		self.T0, self.Y0, self.A0 = 0, Position, 0
		self.T1, self.Target, self.A1 = math.huge, Target, 0
	else
		local CondA = Target < Position
		local CondB = Velocity < 0
		local CondC = Position - Velocity * Velocity / (2 * Acceleration) < Target
		local CondD = Position + Velocity * Velocity / (2 * Acceleration) < Target
		if CondA and CondB and CondC or not CondA and (CondB or not CondB and CondD) then
			self.A0 = Acceleration
			self.T1 = Time + (math.sqrt(2 * Velocity * Velocity + 4 * Acceleration * (Target - Position)) - Velocity) / Acceleration
		else
			self.A0 = -Acceleration
			self.T1 = Time + (math.sqrt(2 * Velocity * Velocity - 4 * Acceleration * (Target - Position)) + Velocity) / Acceleration
		end

		self.T0 = Time - Velocity / self.A0
		self.Y0 = Position - Velocity * Velocity / (2 * self.A0)
		self.Target = Target
		self.A1 = -self.A0
	end
end

--[=[
	Gets the current position.
	@return number -- The current position.
]=]
function AccelTween:GetPosition(): number
	return GetState(self, TimeFunctions.TimeFunction())
end

--[=[
	Gets the current velocity.
	@return number -- The current velocity.
]=]
function AccelTween:GetVelocity(): number
	local _, Velocity = GetState(self, TimeFunctions.TimeFunction())
	return Velocity
end

--[=[
	Gets the maximum acceleration.
	@deprecated V2 -- Use the `.MaxAcceleration` property instead.
	@return number -- The maximum acceleration.
]=]
function AccelTween:GetAcceleration(): number
	return self.MaxAcceleration
end

--[=[
	Gets the target position.
	@deprecated V2 -- Use the `.Target` property instead.
	@return number -- The target position.
]=]
function AccelTween:GetTarget(): number
	return self.Target
end

--[=[
	Returns the remaining time before the AccelTween attains the target.
	@return number -- The remaining time.
]=]
function AccelTween:GetRemainingTime(): number
	local Time = TimeFunctions.TimeFunction()
	local T1 = self.T1
	return Time < T1 and T1 - Time or 0
end

--[=[
	Sets the current position.
	@param Value number -- The new position.
	@return AccelTween
]=]
function AccelTween:SetPosition(Value: number)
	SetState(self, Value, nil, nil, nil)
	return self
end

--[=[
	Sets the current velocity.
	@param Value number -- The new velocity.
	@return AccelTween
]=]
function AccelTween:SetVelocity(Value: number)
	SetState(self, nil, Value, nil, nil)
	return self
end

--[=[
	Sets the maximum acceleration.
	@param Value number -- The new maximum acceleration.
	@return AccelTween
]=]
function AccelTween:SetAcceleration(Value: number)
	SetState(self, nil, nil, Value, nil)
	return self
end

--[=[
	Sets the target position.
	@param Value number -- The new target position.
	@return AccelTween
]=]
function AccelTween:SetTarget(Value: number)
	SetState(self, nil, nil, nil, Value)
	return self
end

--[=[
	Sets the current and target position, and sets the velocity to 0.
	@param Value number -- The new value.
	@return AccelTween
]=]
function AccelTween:SetPositionTarget(Value: number)
	SetState(self, Value, 0, nil, Value)
	return self
end

function AccelTween:__tostring()
	return "AccelTween"
end

export type AccelTween = typeof(AccelTween.new(1))
table.freeze(AccelTween)
return AccelTween
