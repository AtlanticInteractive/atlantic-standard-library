--[=[
	To work like value objects in Roblox and track a single item,
	with `.Changed` events
	@class ValueObject
]=]

local Debug = require(script.Parent.Parent.Debugging.Debug)
local Janitor = require(script.Parent.Parent.Parent.Janitor)
local Observable = require(script.Parent.Parent.Vendor.Nevermore.Observable)
local Signal = require(script.Parent.Parent.Parent.Signal)

local ValueObject = {}
ValueObject.ClassName = "ValueObject"

--[=[
	Constructs a new value object
	@param InitialValue T?
	@return ValueObject<T>
]=]
function ValueObject.new<T>(InitialValue: T?)
	local self = {}
	self.Janitor = Janitor.new()
	self.Changed = Signal.new(self.Janitor)
	self._Value = InitialValue
	return setmetatable(self, ValueObject)
end

--[=[
	Returns whether the object is a ValueObject class
	@param Value any
	@return boolean
]=]
function ValueObject.Is(Value)
	return type(Value) == "table" and getmetatable(Value) == ValueObject
end

--[=[
	Observes the current value of the ValueObject
	@return Observable<T>
]=]
function ValueObject:Observe()
	return Observable.new(function(Subscription)
		if not self.Destroy then
			warn("[ValueObject.Observe] - Connecting to dead ValueObject")
			-- No firing, we're dead
			return Subscription:Complete()
		end

		local ObserveJanitor = Janitor.new()
		ObserveJanitor:Add(self.Changed:Connect(function()
			Subscription:Fire(self.Value)
		end), "Disconnect")

		Subscription:Fire(self.Value)
		return ObserveJanitor
	end)
end

--[=[
	Event fires when the value's object value change
	@prop Changed Signal<T> -- fires with oldValue, newValue
	@within ValueObject
]=]

--[=[
	The value of the ValueObject
	@prop Value T
	@within ValueObject
]=]
function ValueObject:__index(Index)
	if Index == "Value" then
		return self._Value
	elseif ValueObject[Index] then
		return ValueObject[Index]
	elseif Index == "_Value" then
		return nil
	else
		Debug.Error("%q is not a valid member of ValueObject", Index)
	end
end

function ValueObject:__newindex(Index, Value)
	if Index == "Value" then
		local Previous = rawget(self, "_Value")
		if Previous ~= Value then
			rawset(self, "_Value", Value)
			self.Changed:Fire(Value, Previous, self.Janitor:Add(Janitor.new(), "Destroy", "ValueJanitor"))
		end
	else
		Debug.Error("%q is not a valid member of ValueObject", Index)
	end
end

--[=[
	Forces the value to be nil on cleanup, cleans up the Janitor

	Does not fire the event since 3.5.0
]=]
function ValueObject:Destroy()
	-- self.Value = nil
	rawset(self, "_Value", nil)
	self.Janitor:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end

function ValueObject:__tostring()
	return string.format("ValueObject<%s>", tostring(self.Value))
end

export type ValueObject<T> = typeof(ValueObject.new(1))
table.freeze(ValueObject)
return ValueObject
