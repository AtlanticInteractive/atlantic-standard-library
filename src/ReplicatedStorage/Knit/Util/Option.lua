-- Option
-- Stephen Leitnick
-- August 28, 2020

--[[
	MatchTable {
		Some: (value: any) -> any
		None: () -> any
	}

	CONSTRUCTORS:
		Option.Some(anyNonNilValue): Option<any>
		Option.Wrap(anyValue): Option<any>

	STATIC FIELDS:
		Option.None: Option<None>

	STATIC METHODS:
		Option.Is(obj): boolean

	METHODS:
		opt:Match(): (matches: MatchTable) -> any
		opt:IsSome(): boolean
		opt:IsNone(): boolean
		opt:Unwrap(): any
		opt:Expect(errMsg: string): any
		opt:ExpectNone(errMsg: string): void
		opt:UnwrapOr(default: any): any
		opt:UnwrapOrElse(default: () -> any): any
		opt:And(opt2: Option<any>): Option<any>
		opt:AndThen(predicate: (unwrapped: any) -> Option<any>): Option<any>
		opt:Or(opt2: Option<any>): Option<any>
		opt:OrElse(orElseFunc: () -> Option<any>): Option<any>
		opt:XOr(opt2: Option<any>): Option<any>
		opt:Contains(value: any): boolean

	--------------------------------------------------------------------

	Options are useful for handling nil-value cases. Any time that an
	operation might return nil, it is useful to instead return an
	Option, which will indicate that the value might be nil, and should
	be explicitly checked before using the value. This will help
	prevent common bugs caused by nil values that can fail silently.

	Example:

	local result1 = Option.Some(32)
	local result2 = Option.Some(nil)
	local result3 = Option.Some("Hi")
	local result4 = Option.Some(nil)
	local result5 = Option.None

	-- Use 'Match' to match if the value is Some or None:
	result1:Match {
		Some = function(value) print(value) end;
		None = function() print("No value") end;
	}

	-- Raw check:
	if result2:IsSome() then
		local value = result2:Unwrap() -- Explicitly call Unwrap
		print("Value of result2:", value)
	end

	if result3:IsNone() then
		print("No result for result3")
	end

	-- Bad, will throw error bc result4 is none:
	local value = result4:Unwrap()
--]]

local CLASS_NAME = "Option"

--[=[
	@class Option

	Represents an optional value in Lua. This is useful to avoid `nil` bugs, which can
	go silently undetected within code and cause hidden or hard-to-find bugs.
]=]
local Option = {}
Option.__index = Option

function Option._new(Value)
	return setmetatable({
		ClassName = CLASS_NAME;
		_IsSome = Value ~= nil;
		_Value = Value;
	}, Option)
end

--[=[
	@param value T
	@return Option<T>

	Creates an Option instance with the given value. Throws an error
	if the given value is `nil`.
]=]
function Option.Some(Value)
	assert(Value ~= nil, "Option.Some() value cannot be nil")
	return Option._new(Value)
end

--[=[
	@param value T
	@return Option<T> | Option<None>

	Safely wraps the given value as an option. If the
	value is `nil`, returns `Option.None`, otherwise
	returns `Option.Some(value)`.
]=]
function Option.Wrap(Value)
	if Value == nil then
		return Option.None
	else
		return Option.Some(Value)
	end
end

--[=[
	@param obj any
	@return boolean
	Returns `true` if `obj` is an Option.
]=]
function Option.Is(Object)
	return type(Object) == "table" and getmetatable(Object) == Option
end

--[=[
	@param obj any
	Throws an error if `obj` is not an Option.
]=]
function Option.Assert(Object)
	assert(type(Object) == "table" and getmetatable(Object) == Option, "Result was not of type Option")
	return Object
end

--[=[
	@param data table
	@return Option
	Deserializes the data into an Option. This data should have come from
	the `option:Serialize()` method.
]=]
function Option.Deserialize(Data) -- type data = {ClassName: string, Value: any}
	assert(type(Data) == "table" and Data.ClassName == CLASS_NAME, "Invalid data for deserializing Option")
	return Data.Value == nil and Option.None or Option.Some(Data.Value)
end

--[=[
	@return table
	Returns a serialized version of the option.
]=]
function Option:Serialize()
	return {
		ClassName = self.ClassName;
		Value = self._Value;
	}
end

type Matches = {
	Some: (Value: any) -> any,
	None: () -> any,
}

--[=[
	@param matches {Some: (value: any) -> any, None: () -> any}
	@return any

	Matches against the option.

	```lua
	local opt = Option.Some(32)
	opt:Match {
		Some = function(num) print("Number", num) end,
		None = function() print("No value") end,
	}
	```
]=]
function Option:Match(Matches: Matches)
	local OnSome = Matches.Some
	local OnNone = Matches.None
	assert(type(OnSome) == "function", "Missing 'Some' match")
	assert(type(OnNone) == "function", "Missing 'None' match")

	if self._IsSome then
		return OnSome(self:Unwrap())
	else
		return OnNone()
	end
end

--[=[
	@return boolean
	Returns `true` if the option has a value.
]=]
function Option:IsSome()
	return self._IsSome
end

--[=[
	@return boolean
	Returns `true` if the option is None.
]=]
function Option:IsNone()
	return not self._IsSome
end

--[=[
	@param msg string
	@return value: any
	Unwraps the value in the option, otherwise throws an error with `msg` as the error message.
	```lua
	local opt = Option.Some(10)
	print(opt:Expect("No number")) -> 10
	print(Option.None:Expect("No number")) -- Throws an error "No number"
	```
]=]
function Option:Expect(Message: string?)
	assert(self._IsSome, Message)
	return self._Value
end

--[=[
	@param msg string
	Throws an error with `msg` as the error message if the value is _not_ None.
]=]
function Option:ExpectNone(Message: string?)
	assert(not self._IsSome, Message)
end

--[=[
	@return value: any
	Returns the value in the option, or throws an error if the option is None.
]=]
function Option:Unwrap()
	return self:Expect("Cannot unwrap option of None type")
end

--[=[
	@param default any
	@return value: any
	If the option holds a value, returns the value. Otherwise, returns `default`.
]=]
function Option:UnwrapOr(Default)
	if self._IsSome then
		return self:Unwrap()
	else
		return Default
	end
end

--[=[
	@param defaultFn () -> any
	@return value: any
	If the option holds a value, returns the value. Otherwise, returns the
	result of the `defaultFn` function.
]=]
function Option:UnwrapOrElse(DefaultFunction)
	if self._IsSome then
		return self:Unwrap()
	else
		return DefaultFunction()
	end
end

--[=[
	@param optionB Option
	@return Option
	Returns `optionB` if the calling option has a value,
	otherwise returns None.

	```lua
	local optionA = Option.Some(32)
	local optionB = Option.Some(64)
	local opt = optionA:And(optionB)
	-- opt == optionB

	local optionA = Option.None
	local optionB = Option.Some(64)
	local opt = optionA:And(optionB)
	-- opt == Option.None
	```
]=]
function Option:And(OptionB)
	if self._IsSome then
		return OptionB
	else
		return Option.None
	end
end

--[=[
	@param andThenFn (value: any) -> Option
	@return value: Option
	If the option holds a value, then the `andThenFn`
	function is called with the held value of the option,
	and then the resultant Option returned by the `andThenFn`
	is returned. Otherwise, None is returned.

	```lua
	local optA = Option.Some(32)
	local optB = optA:AndThen(function(num)
		return Option.Some(num * 2)
	end)
	print(optB:Expect("Expected number")) --> 64
	```
]=]
function Option:AndThen(ThenFunction)
	if self._IsSome then
		return Option.Assert(ThenFunction(self:Unwrap()))
	else
		return Option.None
	end
end

function Option:Then(ThenFunction)
	if self._IsSome then
		return Option.Assert(ThenFunction(self:Unwrap()))
	else
		return Option.None
	end
end

--[=[
	@param optionB Option
	@return Option
	If caller has a value, returns itself. Otherwise, returns `optionB`.
]=]
function Option:Or(OptionB)
	if self._IsSome then
		return self
	else
		return OptionB
	end
end

--[=[
	@param orElseFn () -> Option
	@return Option
	If caller has a value, returns itself. Otherwise, returns the
	option generated by the `orElseFn` function.
]=]
function Option:OrElse(OrElseFunction)
	if self._IsSome then
		return self
	else
		return Option.Assert(OrElseFunction())
	end
end

--[=[
	@param optionB Option
	@return Option
	If both `self` and `optionB` have values _or_ both don't have a value,
	then this returns None. Otherwise, it returns the option that does have
	a value.
]=]
function Option:XOr(OptionB)
	local SomeOptionA = self._IsSome
	local SomeOptionB = OptionB._IsSome
	if SomeOptionA == SomeOptionB then
		return Option.None
	elseif SomeOptionA then
		return self
	else
		return OptionB
	end
end

--[=[
	@param predicate (value: any) -> boolean
	@return Option
	Returns `self` if this option has a value and the predicate returns `true.
	Otherwise, returns None.
]=]
function Option:Filter(Predicate)
	if not self._IsSome or not Predicate(self._Value) then
		return Option.None
	else
		return self
	end
end

--[=[
	@param value: any
	@return boolean
	Returns `true` if this option contains `value`.
]=]
function Option:Contains(Value)
	return self._IsSome and self._Value == Value
end

--[=[
	@return string
	Metamethod to transform the option into a string.
	```lua
	local optA = Option.Some(64)
	local optB = Option.None
	print(optA) --> Option<number>
	print(optB) --> Option<None>
	```
]=]
function Option:__tostring()
	if self._IsSome then
		return "Option<" .. typeof(self._Value) .. ">"
	else
		return "Option<None>"
	end
end

--[=[
	@return boolean
	Metamethod to check equality between two options. Returns `true` if both
	options hold the same value _or_ both options are None.
	```lua
	local o1 = Option.Some(32)
	local o2 = Option.Some(32)
	local o3 = Option.Some(64)
	local o4 = Option.None
	local o5 = Option.None

	print(o1 == o2) --> true
	print(o1 == o3) --> false
	print(o1 == o4) --> false
	print(o4 == o5) --> true
	```
]=]
function Option:__eq(Other)
	if Option.Is(Other) then
		if self._IsSome and Other._IsSome then
			return self:Unwrap() == Other:Unwrap()
		elseif not self._IsSome and not Other._IsSome then
			return true
		end
	end

	return false
end

--[=[
	@prop None Option<None>
	@within Option
	Represents no value.
]=]
Option.None = Option._new()

export type Option<Value> = typeof(Option._new(1))
table.freeze(Option)
return Option
