--[=[
	A physical model of a spring, useful in many applications.

	A spring is an object that will compute based upon Hooke's law. Properties only evaluate
	upon index making this model good for lazy applications.

	```lua
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")

	local SpringObject = Spring.new(Vector3.zero)
	RunService.Heartbeat:Connect(function()
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			SpringObject:SetTarget(Vector3.zAxis)
		else
			SpringObject:SetTarget(Vector3.zero)
		end

		print(SpringObject:GetPosition()) -- A smoothed out version of the input keycode W
	end)
	```

	A good visualization can be fond here, provided by Defaultio:
	https://www.desmos.com/calculator/hn2i9shxbz

	@class Spring
]=]

local TimeFunctions = require(script.Parent.Parent.Utility.TimeFunctions)
type TimeFunction = () -> number

local Spring = {}
Spring.ClassName = "Spring"
Spring.__index = Spring

--[=[
	@within Spring
	@prop Clock () -> number
	@readonly
	The current clock object to synchronize the spring against.

	Defaults to `time` during runtime, and `os.clock` otherwise.
]=]

--[=[
	@within Spring
	@prop Damper number
	@readonly
	The current damper. At 1 the spring is critically damped. At less than 1, it will be under-damped, and thus, bounce, and at over 1, it will be critically damped.

	Defaults to `1`.
]=]

--[=[
	@within Spring
	@prop Speed number
	@readonly
	The speed, defaults to 1, but should be between [0, infinity).

	Defaults to `1`.
]=]

--[=[
	@within Spring
	@prop Target T
	@readonly
	The current target.
]=]

--[=[
	Constructs a new Spring at the position and target specified, of type T.

	```lua
	-- Linear spring
	local LinearSpring = Spring.new(0)

	-- Vector2 spring
	local Vector2Spring = Spring.new(Vector2.zero)

	-- Vector3 spring
	local Vector3Spring = Spring.new(Vector3.zero)
	```

	@param InitialValue T? -- The initial parameter is a number or Vector3 (anything with * number and addition/subtraction). Defaults to `0`.
	@param TimeFunction? () -> number -- The clock function is optional, and is used to update the spring. Defaults to `time` during runtime, and `os.clock` otherwise.
	@return Spring<T>
]=]
function Spring.new<T>(InitialValue: T?, TimeFunction: TimeFunction?)
	local Target = InitialValue or 0
	local ClockFunction = TimeFunction or TimeFunctions.TimeFunction

	return setmetatable({
		Clock = ClockFunction;
		Damper = 1;
		Speed = 1;
		Target = Target;

		_Position0 = Target;
		_Time0 = ClockFunction();
		_Velocity0 = 0 * Target;
	}, Spring)
end

local function PositionVelocity(self, CurrentTime)
	local Damper = self.Damper
	local Position0 = self._Position0
	local Position1 = self.Target
	local Speed = self.Speed
	local Velocity0 = self._Velocity0

	local Time = Speed * (CurrentTime - self._Time0)
	local DamperSquared = Damper * Damper

	local ValueH, SineValue, CosineValue
	if DamperSquared < 1 then
		ValueH = math.sqrt(1 - DamperSquared)
		local ExponentialValue = math.exp(-Damper * Time) / ValueH
		CosineValue, SineValue = ExponentialValue * math.cos(ValueH * Time), ExponentialValue * math.sin(ValueH * Time)
	elseif DamperSquared == 1 then
		ValueH = 1
		local ExponentialValue = math.exp(-Damper * Time) / ValueH
		CosineValue, SineValue = ExponentialValue, ExponentialValue * Time
	else
		ValueH = math.sqrt(DamperSquared - 1)
		local TwoMulValueH = 2 * ValueH
		local ValueU = math.exp((-Damper + ValueH) * Time) / TwoMulValueH
		local ValueV = math.exp((-Damper - ValueH) * Time) / TwoMulValueH
		CosineValue, SineValue = ValueU + ValueV, ValueU - ValueV
	end

	local A0 = ValueH * CosineValue + Damper * SineValue
	local A1 = 1 - (ValueH * CosineValue + Damper * SineValue)
	local A2 = SineValue / Speed

	local B0 = -Speed * SineValue
	local B1 = Speed * SineValue
	local B2 = ValueH * CosineValue - Damper * SineValue

	return A0 * Position0 + A1 * Position1 + A2 * Velocity0, B0 * Position0 + B1 * Position1 + B2 * Velocity0
end

--[=[
	Impulses the spring, increasing velocity by the amount given. This is useful to make something shake, like a Mac password box failing.

	@param Velocity T -- The velocity to impulse with.
	@return Spring<T>
]=]
function Spring:Impulse(Velocity)
	return self:SetVelocity(self:GetVelocity() + Velocity)
end

--[=[
	Instantly skips the spring forwards by that amount time.
	@param DeltaTime number -- Time to skip forwards.
	@return Spring<T>
]=]
function Spring:TimeSkip(DeltaTime: number)
	local CurrentTime = self.Clock()
	self._Position0, self._Velocity0 = PositionVelocity(self, CurrentTime + DeltaTime)
	self._Time0 = CurrentTime
	return self
end

--[=[
	The current position at the given clock time. Assigning the position will change the spring to have that position.

	```lua
	local SpringObject = Spring.new(0)
	print(SpringObject:GetPosition()) --> 0
	```

	@return T -- The current position.
]=]
function Spring:GetPosition()
	return (PositionVelocity(self, self.Clock()))
end

Spring.GetValue = Spring.GetPosition

--[=[
	The current velocity. Assigning the velocity will change the spring to have that velocity.

	```lua
	local SpringObject = Spring.new(0)
	print(SpringObject:GetVelocity()) --> 0
	```

	@return T -- The current velocity.
]=]
function Spring:GetVelocity()
	local _, Velocity = PositionVelocity(self, self.Clock())
	return Velocity
end

--[=[
	Gets the current target.
	@deprecated V2 -- Use the `.Target` property instead.
	@return T -- The current target.
]=]
function Spring:GetTarget()
	return self.Target
end

--[=[
	Gets the current damper.
	@deprecated V2 -- Use the `.Damper` property instead.
	@return number -- The current damper.
]=]
function Spring:GetDamper(): number
	return self.Damper
end

--[=[
	Gets the current speed.
	@deprecated V2 -- Use the `.Speed` property instead.
	@return number -- The current speed.
]=]
function Spring:GetSpeed(): number
	return self.Speed
end

--[=[
	Gets the current clock object to synchronize the spring against.
	@deprecated V2 -- Use the `.Clock` property instead.
	@return TimeFunction -- The current clock function.
]=]
function Spring:GetClock(): TimeFunction
	return self.Clock
end

--[=[
	Sets the position which will change the spring to have that position.

	```lua
	local SpringObject = Spring.new(0)
	print(SpringObject:GetPosition()) --> 0
	print(SpringObject:SetPosition(1):GetPosition()) --> ~1
	```

	@param Value T -- The new position.
	@return Spring<T>
]=]
function Spring:SetPosition(Value)
	local CurrentTime = self.Clock()
	local _, Velocity = PositionVelocity(self, CurrentTime)
	self._Position0 = Value
	self._Velocity0 = Velocity
	self._Time0 = CurrentTime
	return self
end

Spring.SetValue = Spring.SetPosition

--[=[
	Assigning the velocity will change the spring to have that velocity.

	```lua
	local SpringObject = Spring.new(0)
	print(SpringObject:GetVelocity()) --> 0
	print(SpringObject:SetVelocity(1):GetVelocity()) --> ~1
	```

	@param Value T -- The new velocity.
	@return Spring<T>
]=]
function Spring:SetVelocity(Value)
	local CurrentTime = self.Clock()
	self._Position0 = PositionVelocity(self, CurrentTime)
	self._Velocity0 = Value
	self._Time0 = CurrentTime
	return self
end

--[=[
	Assigning the target will change the spring to have that target.

	```lua
	local SpringObject = Spring.new(0)
	print(SpringObject.Target) --> 0
	print(SpringObject:SetTarget(1).Target) --> 1
	```

	@param Value T -- The new target.
	@return Spring<T>
]=]
function Spring:SetTarget(Value)
	local CurrentTime = self.Clock()
	self._Position0, self._Velocity0 = PositionVelocity(self, CurrentTime)
	self.Target = Value
	self._Time0 = CurrentTime
	return self
end

--[=[
	Sets the damper of the spring.
	@param Value number -- The new damper.
	@return Spring<T>
]=]
function Spring:SetDamper(Value: number)
	local CurrentTime = self.Clock()
	self._Position0, self._Velocity0 = PositionVelocity(self, CurrentTime)
	self.Damper = math.clamp(Value, 0, 1)
	self._Time0 = CurrentTime
	return self
end

--[=[
	Sets the speed of the spring.
	@param Value number -- The new speed.
	@return Spring<T>
]=]
function Spring:SetSpeed(Value: number)
	local CurrentTime = self.Clock()
	self._Position0, self._Velocity0 = PositionVelocity(self, CurrentTime)
	self.Speed = Value < 0 and 0 or Value
	self._Time0 = CurrentTime
	return self
end

--[=[
	Sets the clock function of the spring.
	@param Value () -> number -- The new clock function.
	@return Spring<T>
]=]
function Spring:SetClock(Value: TimeFunction)
	local CurrentTime = self.Clock()
	self._Position0, self._Velocity0 = PositionVelocity(self, CurrentTime)
	self.Clock = Value
	self._Time0 = Value()
	return self
end

function Spring:__tostring()
	return "Spring"
end

export type Spring = typeof(Spring.new(1))
table.freeze(Spring)
return Spring
