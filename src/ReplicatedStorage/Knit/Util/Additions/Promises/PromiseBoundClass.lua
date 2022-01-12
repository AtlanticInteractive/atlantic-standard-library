--[=[
	Utility function to promise a bound class on an object
	@class promiseBoundClass
]=]

local Debug = require(script.Parent.Parent.Debugging.Debug)
local Janitor = require(script.Parent.Parent.Parent.Janitor)
local Promise = require(script.Parent.Parent.Parent.Promise)

--[=[
	Returns a promise that resolves when the class is bound to the instance.
	@param binder Binder<T>
	@param inst Instance
	@return Promise<T>
	@function promiseBoundClass
	@within promiseBoundClass
]=]
return function(Binder, Object)
	assert(type(Binder) == "table", "'binder' must be table")
	assert(typeof(Object) == "Instance", "'inst' must be instance")

	local Class = Binder:Get(Object)
	if Class then
		return Promise.Resolve(Class)
	end

	local JanitorObject = Janitor.new()
	local PromiseObject = Promise.new()

	JanitorObject:Add(Binder:ObserveInstance(Object, function(ClassAdded)
		if ClassAdded then
			PromiseObject:Resolve(ClassAdded)
		end
	end), true)

	task.delay(5, function()
		if PromiseObject.Status == Promise.Status.Started then
			Debug.Warn("[PromiseBoundClass] - Infinite yield possible on %q for binder %q\n", Object, Binder:GetTag())
		end
	end)

	PromiseObject:Finally(function()
		JanitorObject:Destroy()
	end)

	return PromiseObject
end
