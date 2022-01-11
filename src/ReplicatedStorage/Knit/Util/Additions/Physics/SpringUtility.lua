--[=[
	Utility functions that are related to the Spring object
	@class SpringUtility
]=]

local LinearValue = require(script.Parent.LinearValue)
local EPSILON = 1E-6

local SpringUtility = {}

--[=[
	Utility function that returns whether or not a spring is animating based upon
	velocity and closeness to target, and as the second value, the value that should be
	used.

	@param spring Spring<T>
	@param epsilon number? -- Optional epsilon
	@return boolean, T
]=]
function SpringUtility.Animating(Spring, Epsilon)
	Epsilon = Epsilon or EPSILON

	local Position = Spring:GetPosition()
	local Target = Spring.Target

	local Animating
	if type(Target) == "number" then
		Animating = math.abs(Position - Target) > Epsilon or math.abs(Spring:GetVelocity()) > Epsilon
	else
		local RobloxType = typeof(Target)
		if RobloxType == "Vector3" or RobloxType == "Vector2" or LinearValue.Is(Target) then
			Animating = (Position - Target).Magnitude > Epsilon or Spring:GetVelocity().Magnitude > Epsilon
		else
			error("Unknown type")
		end
	end

	if Animating then
		return true, Position
	else
		-- We need to return the target so we use the actual target value (i.e. pretend like the spring is asleep)
		return false, Target
	end
end

--[=[
	Add to spring position to adjust for velocity of target. May have to set clock to time().

	@param velocity T
	@param dampen number
	@param speed number
	@return T
]=]
function SpringUtility.GetVelocityAdjustment(Velocity, Dampen, Speed)
	return assert(Velocity, "Bad velocity") * (2 * assert(Dampen, "Bad dampen") / assert(Speed, "Bad speed"))
end

--[=[
	Converts an arbitrary value to a LinearValue if Roblox has not defined this value
	for multiplication and addition.

	@param value T
	@return LinearValue<T> | T
]=]
function SpringUtility.ToLinearIfNeeded(Value)
	if typeof(Value) == "Color3" then
		return LinearValue.new(Color3.new, {Value.R, Value.G, Value.B})
	elseif typeof(Value) == "UDim2" then
		return LinearValue.new(UDim2.new, {Value.X.Scale, Value.X.Offset, Value.Y.Scale, Value.Y.Offset})
	elseif typeof(Value) == "UDim" then
		return LinearValue.new(UDim.new, {Value.Scale, Value.Offset})
	else
		return Value
	end
end

--[=[
	Extracts the base value out of a packed linear value if needed.

	@param value LinearValue<T> | any
	@return T | any
]=]
function SpringUtility.FromLinearIfNeeded(Value)
	if LinearValue.Is(Value) then
		return Value:ToBaseValue()
	else
		return Value
	end
end

table.freeze(SpringUtility)
return SpringUtility
