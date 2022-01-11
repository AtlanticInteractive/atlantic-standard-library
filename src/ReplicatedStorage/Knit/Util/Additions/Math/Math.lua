--[=[
	Holds utility math functions not available on Roblox's math library.
	@class Math
]=]

local Math = {}

--[=[
	Maps a number from one range to another.

	:::note
	Note the mapped value can be outside of the initial range,
	which is very useful for linear interpolation.
	:::

	```lua
	print(Math.Map(0.1, 0, 1, 1, 0)) --> 0.9
	```

	@param Number number
	@param Min0 number
	@param Max0 number
	@param Min1 number
	@param Max1 number
	@return number
]=]
function Math.Map(Number: number, Min0: number, Max0: number, Min1: number, Max1: number): number
	if Max0 == Min0 then
		error("Range of zero")
	end

	return (Number - Min0) * (Max1 - Min1) / (Max0 - Min0) + Min1
end

--[=[
	Interpolates between two numbers, given an percent. The percent is
	a number in the range that will be used to define how interpolated
	it is between num0 and num1.

	```lua
	print(Math.Lerp(-1000, 1000, 0.75)) --> 500
	```

	@param Start number -- Number
	@param Finish number -- Second number
	@param Alpha number -- The percent
	@return number -- The interpolated
]=]
function Math.Lerp(Start: number, Finish: number, Alpha: number): number
	return (1 - Alpha) * Start + Alpha * Finish
end

--[=[
	Solving for angle across from c

	@param A number
	@param B number
	@param C number
	@return number? -- Returns nil if this cannot be solved for
]=]
function Math.LawOfCosines(A: number, B: number, C: number): number?
	local Angle = math.acos((A * A + B * B - C * C) / (2 * A * B))
	if Angle ~= Angle then
		return nil
	end

	return Angle
end

--[=[
	Round the given number to given precision

	```lua
	print(Math.Round(72.1, 5)) --> 75
	```

	@param Number number
	@param Precision number? -- Defaults to 1
	@return number
]=]
function Math.Round(Number: number, Precision: number?): number
	if Precision then
		return math.floor((Number / Precision :: number) + 0.5) * Precision :: number
	else
		return math.floor(Number + 0.5)
	end
end

--[=[
	Rounds up to the given precision

	@param Number number
	@param Precision number
	@return number
]=]
function Math.RoundUp(Number: number, Precision: number): number
	return math.ceil(Number / Precision) * Precision
end

--[=[
	Rounds down to the given precision

	@param Number number
	@param Precision number
	@return number
]=]
function Math.RoundDown(Number: number, Precision: number): number
	return math.floor(Number / Precision) * Precision
end

table.freeze(Math)
return Math
