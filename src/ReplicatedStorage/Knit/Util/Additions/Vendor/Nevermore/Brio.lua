--[=[
	Brios wrap a value (or tuple of values) and are used to convey the lifetime of that
	object. The brio is better than a janitor, by providing the following constraints:

	- Can be in 2 states, dead or alive.
	- While alive, can retrieve values.
	- While dead, retrieving values is forbidden.
	- Died will fire once upon death.

	Brios encapsulate the "lifetime" of a valid resource. Unlike a maid, they
	- Can only die once, ensuring duplicate calls never occur.
	- Have less memory leaks. Memory leaks in maids can occur when use of the maid occurs after the cleanup of the maid has occurred, in certain race conditions.
	- Cannot be reentered, i.e. cannot retrieve values after death.

	:::info
	Calling `brio:Destroy()` or `brio:Kill()` after death does nothing. Brios cannot
	be resurrected.
	:::

	Brios are useful for downstream events where you want to emit a resource. Typically
	brios should be killed when their source is killed. Brios are intended to be merged
	with downstream brios so create a chain of reliable resources.

	```lua
	local brio = Brio.new("a", "b")
	print(brio:GetValue()) --> a b
	print(brio:IsDead()) --> false

	brio:GetDiedSignal():Connect(function()
		print("Hello from signal!")
	end)

	brio:ToJanitor():Add(function()
		print("Hello from janitor cleanup!")
	end, true)

	brio:Kill()
	--> Hello from signal!
	--> Hello from janitor cleanup!

	print(brio:IsDead()) --> true
	print(brio:GetValue()) --> ERROR: Brio is dead
	```

	## Design philosophy

	Brios are designed to solve this issue where we emit an object with a lifetime associated with it from an
	Observable stream. This resource is only valid for some amount of time (for example, while the object is
	in the Roblox data model).

	In order to know how long we can keep this object/use it, we wrap the object with a Brio, which denotes the lifetime of the object.

	Modeling this with pure observables is very tricky because the subscriber will have to also monitor/emit
	a similar object with less clear conventions. For example  an observable that emits the object, and then nil on death.

	@class Brio
]=]

local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)
local Signal = require(script.Parent.Parent.Parent.Parent.Signal)

local Brio = {}
Brio.ClassName = "Brio"
Brio.__index = Brio

--[=[
	Constructs a new Brio.

	```lua
	local ExampleBrio = Brio.new("a", "b")
	print(ExampleBrio:GetValue()) --> a b
	```

	@param ... T -- Brio values
	@return Brio<T>
]=]
function Brio.new<T>(...: T) -- Wrap
	return setmetatable({
		_DiedEvent = nil;
		_Values = table.pack(...);
	}, Brio)
end

--[=[
	Returns whether a value is a Brio.

	```lua
	print(Brio.Is("yes")) --> false
	```

	@param Value any
	@return boolean
]=]
function Brio.Is(Value)
	return type(Value) == "table" and getmetatable(Value) == Brio
end

--[=[
	Constructs a new brio that will cleanup after the set amount of time

	@since 3.6.0
	@param Time number
	@param ... T -- Brio values
	@return Brio<T>
]=]
function Brio.Delayed<T>(Time: number, ...: T)
	local DelayedBrio = Brio.new(...)
	task.delay(Time, function()
		DelayedBrio:Destroy()
	end)

	return DelayedBrio
end

--[=[
	Gets a signal that will fire when the Brio dies. If the brio is already dead
	calling this method will error.

	:::info
	Calling this while the brio is already dead will throw a error.
	:::

	```lua
	local ExampleBrio = Brio.new("a", "b")
	ExampleBrio:GetDiedSignal():Connect(function()
		print("Brio died")
	end)

	ExampleBrio:Destroy() --> Brio died
	ExampleBrio:Destroy() -- no output
	```

	@return Signal
]=]
function Brio:GetDiedSignal()
	if self:IsDead() then
		error("Already dead")
	end

	if self._DiedEvent then
		return self._DiedEvent
	end

	self._DiedEvent = Signal.new()
	return self._DiedEvent
end

--[=[
	Returns true is the brio is dead.

	```lua
	local ExampleBrio = Brio.new("a", "b")
	print(ExampleBrio:IsDead()) --> false

	ExampleBrio:Destroy()

	print(ExampleBrio:IsDead()) --> true
	```

	@return boolean
]=]
function Brio:IsDead()
	return self._Values == nil
end

--[=[
	Throws an error if the Brio is dead.

	```lua
	Brio.DEAD:ErrorIfDead() --> ERROR: [Brio.ErrorIfDead] - Brio is dead
	```
]=]
function Brio:ErrorIfDead()
	if not self._Values then
		error("[Brio.ErrorIfDead] - Brio is dead")
	end
end

--[=[
	Constructs a new Janitor which will clean up when the brio dies.
	Will error if the Brio is dead.

	:::info
	Calling this while the brio is already dead will throw a error.
	:::

	```lua
	local ExampleBrio = Brio.new("a")
	ExampleBrio:ToJanitor():Add(function()
		print("Cleaning up!")
	end, true)

	ExampleBrio:Destroy() --> Cleaning up!
	```

	@return Janitor
]=]
function Brio:ToJanitor()
	assert(self._Values ~= nil, "Dead")
	local BrioJanitor = Janitor.new()
	BrioJanitor:Add(self:GetDiedSignal():Connect(function()
		BrioJanitor:Cleanup()
	end), "Disconnect")

	return BrioJanitor
end

--[=[
	If the brio is not dead, will return the values unpacked from the brio.

	:::info
	Calling this while the brio is already dead will throw a error. Values should
	not be used past the lifetime of the brio, and can be considered invalid.
	:::

	```lua
	local ExampleBrio = Brio.new("a", 1, 2)
	print(ExampleBrio:GetValue()) --> "a" 1 2
	ExampleBrio:Destroy()

	print(ExampleBrio:GetValue()) --> ERROR: Brio is dead
	```

	@return ... T
]=]
function Brio:GetValue()
	local Values = assert(self._Values, "Brio is dead")
	return table.unpack(Values, 1, Values.n)
end

--[=[
	Returns the packed values from table.pack() format

	@since 3.6.0
	@return {n: number, ... T}
]=]
function Brio:GetPackedValues()
	return assert(self._Values, "Brio is dead")
end

--[=[
	Kills the Brio.

	:::info
	You can call this multiple times and it will not error if the brio is dead.
	:::

	```lua
	local ExampleBrio = Brio.new("hi")
	print(ExampleBrio:GetValue()) --> "hi"
	ExampleBrio:Destroy()

	print(ExampleBrio:GetValue()) --> ERROR: Brio is dead
	```
]=]
function Brio:Destroy()
	if not self._Values then
		return
	end

	self._Values = nil

	if self._DiedEvent then
		self._DiedEvent:Fire()
		self._DiedEvent:Destroy()
		self._DiedEvent = nil
	end
end

--[=[
	Alias for Destroy.
	@method Kill
	@within Brio
]=]
Brio.Kill = Brio.Destroy

--[=[
	An already dead brio which may be used for identity purposes.

	```lua
	print(Brio.DEAD:IsDead()) --> true
	```

	@prop DEAD Brio
	@within Brio
]=]
Brio.DEAD = Brio.new()
Brio.DEAD:Destroy()

function Brio:__tostring()
	return "Brio"
end

export type Brio<T> = typeof(Brio.new(1))
table.freeze(Brio)
return Brio
