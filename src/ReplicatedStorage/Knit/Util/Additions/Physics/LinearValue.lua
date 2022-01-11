--[=[
	Represents a value that can operate in linear space

	@class LinearValue
]=]
local LinearValue = {}
LinearValue.ClassName = "LinearValue"
LinearValue.__index = LinearValue

--[=[
	Constructs a new LinearValue object.

	@param constructor (number ...) -> T
	@param values ({ number })
	@return LinearValue<T>
]=]
function LinearValue.new(Constructor, Values)
	return setmetatable({
		_Constructor = Constructor;
		_Values = Values;
	}, LinearValue)
end

--[=[
	Returns whether or not a value is a LinearValue object.

	@param value any -- A value to check
	@return boolean -- True if a linear value, false otherwise
]=]
function LinearValue.Is(Value)
	return type(Value) == "table" and getmetatable(Value) == LinearValue
end

--[=[
	Converts the value back to the base value

	@return T
]=]
function LinearValue:ToBaseValue()
	return self._constructor(table.unpack(self._Values))
end

local function Operation(Function)
	return function(A, B)
		if LinearValue.Is(A) and LinearValue.Is(B) then
			assert(A._Constructor == B._Constructor, "a is not the same type of linearValue as b")
			local Length = #A._Values
			local Values = table.create(Length)
			for Index, Value in ipairs(A._Values) do
				Values[Index] = Function(Value, B._Values[Index])
			end

			return LinearValue.new(A._Constructor, Values)
		elseif LinearValue.Is(A) then
			if type(B) == "number" then
				local Length = #A._Values
				local Values = table.create(Length)
				for Index, Value in ipairs(A._Values) do
					Values[Index] = Function(Value, B)
				end

				return LinearValue.new(A._Constructor, Values)
			else
				error("Bad type (b)")
			end
		elseif LinearValue.Is(B) then
			if type(A) == "number" then
				local Length = #B._Values
				local Values = table.create(Length)
				for Index, Value in ipairs(B._Values) do
					Values[Index] = Function(A, Value)
				end

				return LinearValue.new(B._Constructor, Values)
			else
				error("Bad type (a)")
			end
		else
			error("Neither value is a linearValue")
		end
	end
end

--[=[
	Returns the magnitude of the linear value.

	@return number -- The magnitude of the linear value.
]=]
function LinearValue:GetMagnitude()
	local Dot = 0
	for _, Value in ipairs(self._Values) do
		Dot += Value * Value
	end

	return math.sqrt(Dot)
end

--[=[
	Returns the magnitude of the linear value.

	@prop magnitude number
	@readonly
	@within LinearValue
]=]
function LinearValue:__index(Index)
	if LinearValue[Index] then
		return LinearValue[Index]
	elseif Index == "Magnitude" then
		return self:GetMagnitude()
	else
		return nil
	end
end

LinearValue.__add = Operation(function(A, B)
	return A + B
end)

LinearValue.__sub = Operation(function(A, B)
	return A - B
end)

LinearValue.__mul = Operation(function(A, B)
	return A * B
end)

LinearValue.__div = Operation(function(A, B)
	return A / B
end)

function LinearValue:__eq(A, B)
	if LinearValue.Is(A) and LinearValue.Is(B) then
		if #A._values ~= #B._values then
			return false
		end

		for index, value in ipairs(A._values) do
			if value ~= B._values[index] then
				return false
			end
		end

		return true
	else
		return false
	end
end

function LinearValue:__tostring()
	return "LinearValue"
end

export type LinearValue = typeof(LinearValue.new(Vector3.new, {1, 2, 3}))
table.freeze(LinearValue)
return LinearValue
