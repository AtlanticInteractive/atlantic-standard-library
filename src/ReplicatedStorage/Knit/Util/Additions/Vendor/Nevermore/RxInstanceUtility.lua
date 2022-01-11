--[=[
	Utility functions to observe the state of Roblox. This is a very powerful way to query
	Roblox's state.

	:::tip
	Use RxInstanceUtility to program streaming enabled games, and make it easy to debug. This API surface
	lets you use Roblox as a source-of-truth which is very valuable.
	:::

	@class RxInstanceUtility
]=]

local Brio = require(script.Parent.Brio)
local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)
local Observable = require(script.Parent.Observable)
local Rx = require(script.Parent.Rx)

local RxInstanceUtility = {}

--[=[
	Observes an instance's property

	@param instance Instance
	@param propertyName string
	@return Observable<T>
]=]
function RxInstanceUtility.ObserveProperty(instance, propertyName)
	assert(typeof(instance) == "Instance", "Not an instance")
	assert(type(propertyName) == "string", "Bad propertyName")

	return Observable.new(function(sub)
		local janitor = Janitor.new()

		janitor:Add(instance:GetPropertyChangedSignal(propertyName):Connect(function()
			sub:Fire(instance[propertyName], instance)
		end), "Disconnect")

		sub:Fire(instance[propertyName], instance)

		return janitor
	end)
end

--[=[
	Observes an instance's ancestry

	@param instance Instance
	@return Observable<Instance>
]=]
function RxInstanceUtility.ObserveAncestry(instance)
	local startWithParent = Rx.Start(function()
		return instance, instance.Parent
	end)

	return startWithParent(Rx.FromSignal(instance.AncestryChanged))
end

--[=[
	Returns a brio of the property value

	@param instance Instance
	@param propertyName string
	@param predicate ((value: T) -> boolean)? -- Optional filter
	@return Observable<Brio<T>>
]=]
function RxInstanceUtility.ObservePropertyBrio(instance, property, predicate)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(property) == "string", "Bad property")
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return Observable.new(function(sub)
		local janitor = Janitor.new()

		local function handlePropertyChanged()
			janitor:Remove("_property")

			local propertyValue = instance[property]
			if not predicate or predicate(propertyValue) then
				sub:Fire(janitor:Add(Brio.new(instance[property]), "Destroy", "_property"))
			end
		end

		janitor:Add(instance:GetPropertyChangedSignal(property):Connect(handlePropertyChanged), "Disconnect")
		handlePropertyChanged()

		return janitor
	end)
end

--[=[
	Observes the last child with a specific name.

	@param parent Instance
	@param className string
	@param name string
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtility.ObserveLastNamedChildBrio(parent, className, name)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")
	assert(type(name) == "string", "Bad name")

	return Observable.new(function(sub)
		local topJanitor = Janitor.new()

		local function handleChild(child)
			if not child:IsA(className) then
				return
			end

			local janitor = Janitor.new()
			local function handleNameChanged()
				if child.Name == name then
					sub:Fire(topJanitor:Add(janitor:Add(Brio.new(child), "Destroy", "_brio"), "Destroy", "_lastBrio"))
				else
					janitor:Remove("_brio")
				end
			end

			janitor:Add(child:GetPropertyChangedSignal("Name"):Connect(handleNameChanged), "Disconnect")
			handleNameChanged()
			topJanitor:Add(janitor, "Destroy", child)
		end

		topJanitor:Add(parent.ChildAdded:Connect(handleChild), "Disconnect")
		topJanitor:Add(parent.ChildRemoved:Connect(function(child)
			topJanitor:Remove(child)
		end), "Disconnect")

		for _, child in ipairs(parent:GetChildren()) do
			handleChild(child)
		end

		return topJanitor
	end)
end

--[=[
	Observes all children of a specific class

	@param parent Instance
	@param className string
	@return Observable<Instance>
]=]
function RxInstanceUtility.ObserveChildrenOfClassBrio(parent, className)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")

	return RxInstanceUtility.ObserveChildrenBrio(parent, function(child)
		return child:IsA(className)
	end)
end

--[=[
	Observes all children

	@param parent Instance
	@param predicate ((value: Instance) -> boolean)? -- Optional filter
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtility.ObserveChildrenBrio(parent, predicate)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return Observable.new(function(sub)
		local janitor = Janitor.new()

		local function handleChild(child)
			if not predicate or predicate(child) then
				sub:Fire(janitor:Add(Brio.new(child), "Destroy", child))
			end
		end

		janitor:Add(parent.ChildAdded:Connect(handleChild), "Disconnect")
		janitor:Add(parent.ChildRemoved:Connect(function(child)
			janitor:Remove(child)
		end), "Disconnect")

		for _, child in ipairs(parent:GetChildren()) do
			handleChild(child)
		end

		return janitor
	end)
end

--[=[
	Observes all descendants that match a predicate

	@param parent Instance
	@param predicate ((value: Instance) -> boolean)? -- Optional filter
	@return Observable<Brio<Instance>>
]=]
function RxInstanceUtility.ObserveDescendants(parent, predicate)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(predicate) == "function" or predicate == nil, "Bad predicate")

	return Observable.new(function(sub)
		local janitor = Janitor.new()
		local added = {}

		local function handleDescendant(child)
			if not predicate or predicate(child) then
				added[child] = true
				sub:Fire(child, true)
			end
		end

		janitor:Add(parent.DescendantAdded:Connect(handleDescendant), "Disconnect")
		janitor:Add(parent.DescendantRemoving:Connect(function(child)
			if added[child] then
				added[child] = nil
				sub:Fire(child, false)
			end
		end), "Disconnect")

		for _, descendant in ipairs(parent:GetDescendants()) do
			handleDescendant(descendant)
		end

		return janitor
	end)
end

table.freeze(RxInstanceUtility)
return RxInstanceUtility
