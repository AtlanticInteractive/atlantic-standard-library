--[=[
	Utility methods to observe bound objects on instances. This is what makes the Rx library with
	binders really good.

	:::info
	Using this API, you can query most game-state in very efficient ways, and react to the world
	changing in real-time. This makes programming streaming and other APIs really nice.
	:::

	@class RxBinderUtility
]=]

local Binder = require(script.Parent.Parent.Parent.Classes.Binders.Binder)
local Brio = require(script.Parent.Brio)
local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)
local Observable = require(script.Parent.Observable)
local Rx = require(script.Parent.Rx)
local RxBrioUtility = require(script.Parent.RxBrioUtility)
local RxInstanceUtility = require(script.Parent.RxInstanceUtility)
local RxLinkUtility = require(script.Parent.RxLinkUtility)

local RxBinderUtility = {}

--[=[
	Observes a structure where a parent has object values with linked objects (for example), maybe
	an AI has a list of linked ObjectValue tasks to execute.

	@param linkName string
	@param parent Instance
	@param binder Binder<T>
	@return Observable<Brio<T>>
]=]
function RxBinderUtility.ObserveLinkedBoundClassBrio(LinkName: string, Parent: Instance, ObserveBinder)
	assert(type(LinkName) == "string", "Bad linkName")
	assert(typeof(Parent) == "Instance", "Bad parent")
	assert(Binder.Is(ObserveBinder), "Bad binder")

	return RxLinkUtility.ObserveValidLinksBrio(LinkName, Parent):Pipe({
		RxBrioUtility.FlatMapBrio(function(_, LinkValue)
			return RxBinderUtility.ObserveBoundClassBrio(ObserveBinder, LinkValue)
		end);
	})
end

--[=[
	Observes bound children classes.

	@param binder Binder<T>
	@param instance Instance
	@return Observable<Brio<T>>
]=]
function RxBinderUtility.ObserveBoundChildClassBrio(ObserveBinder, Object: Instance)
	assert(Binder.Is(ObserveBinder), "Bad binder")
	assert(typeof(Object) == "Instance", "Bad instance")

	return RxInstanceUtility.ObserveChildrenBrio(Object):Pipe({
		RxBrioUtility.FlatMapBrio(function(Child)
			return RxBinderUtility.ObserveBoundClassBrio(ObserveBinder, Child)
		end);
	})
end

--[=[
	Observes an instance's parent class that is bound.

	@param binder Binder<T>
	@param instance Instance
	@return Observable<Brio<T>>
]=]
function RxBinderUtility.ObserveBoundParentClassBrio(ObserveBinder, Object: Instance)
	assert(Binder.Is(ObserveBinder), "Bad binder")
	assert(typeof(Object) == "Instance", "Bad instance")

	return RxInstanceUtility.ObservePropertyBrio(Object, "Parent"):Pipe({
		RxBrioUtility.SwitchMapBrio(function(Child)
			if Child then
				return RxBinderUtility.ObserveBoundClassBrio(ObserveBinder, Child)
			else
				return Rx.EMPTY
			end
		end);
	})
end

--[=[
	Observes all bound classes that hit that list of binders

	@param binders { Binder<T> }
	@param instance Instance
	@return Observable<Brio<T>>
]=]
function RxBinderUtility.ObserveBoundChildClassesBrio(Binders, Object: Instance)
	assert(type(Binders) == "table", "Bad binders")
	assert(typeof(Object) == "Instance", "Bad instance")

	return RxInstanceUtility.ObserveChildrenBrio(Object):Pipe({
		RxBrioUtility.FlatMapBrio(function(Child)
			return RxBinderUtility.ObserveBoundClassesBrio(Binders, Child)
		end);
	})
end

--[=[
	Observes a bound class on a given instance.

	@param binder Binder<T>
	@param instance Instance
	@return Observable<T?>
]=]
function RxBinderUtility.ObserveBoundClass(ObserveBinder, Object: Instance)
	assert(type(ObserveBinder) == "table", "Bad binder")
	assert(typeof(Object) == "Instance", "Bad instance")

	return Observable.new(function(Subscription)
		local ObserveJanitor = Janitor.new()

		ObserveJanitor:Add(ObserveBinder:ObserveInstance(Object, function(...)
			Subscription:Fire(...)
		end), true)

		Subscription:Fire(ObserveBinder:Get(Object))
		return ObserveJanitor
	end)
end

--[=[
	Observes a bound class on a given instance.

	@param binder Binder<T>
	@param instance Instance
	@return Observable<Brio<T>>
]=]
function RxBinderUtility.ObserveBoundClassBrio(ObserveBinder, Object: Instance)
	assert(type(ObserveBinder) == "table", "Bad binder")
	assert(typeof(Object) == "Instance", "Bad instance")

	return Observable.new(function(Subscription)
		local ObserveJanitor = Janitor.new()

		local function HandleClassChanged(Class)
			if Class then
				Subscription:Fire(ObserveJanitor:Add(Brio.new(Class), "Destroy", "LastBrio"))
			else
				ObserveJanitor:Remove("LastBrio")
			end
		end

		ObserveJanitor:Add(ObserveBinder:ObserveInstance(Object, HandleClassChanged), true)
		HandleClassChanged(ObserveBinder:Get(Object))
		return ObserveJanitor
	end)
end

--[=[
	Observes all bound classes for a given binder.

	@param binders { Binder<T> }
	@param instance Instance
	@return Observable<Brio<T>>
]=]
function RxBinderUtility.ObserveBoundClassesBrio(Binders, Object: Instance)
	assert(type(Binders) == "table", "Bad binders")
	assert(typeof(Object) == "Instance", "Bad instance")

	local Observables = {}
	for _, ObserveBinder in ipairs(Binders) do
		table.insert(Observables, RxBinderUtility.ObserveBoundClassBrio(ObserveBinder, Object))
	end

	return Rx.Of(table.unpack(Observables)):Pipe({Rx.MergeAll()})
end

--[=[
	Observes all instances bound to a given binder.

	@param binder Binder
	@return Observable<Brio<T>>
]=]
function RxBinderUtility.ObserveAllBrio(ObserveBinder)
	assert(Binder.Is(ObserveBinder), "Bad binder")

	return Observable.new(function(Subscription)
		local ObserveJanitor = Janitor.new()

		local function HandleNewClass(Class)
			Subscription:Fire(ObserveJanitor:Add(Brio.new(Class), "Destroy", Class))
		end

		ObserveJanitor:Add(ObserveBinder:GetClassAddedSignal():Connect(HandleNewClass), "Disconnect")
		ObserveJanitor:Add(ObserveBinder:GetClassRemovingSignal():Connect(function(Class)
			ObserveJanitor:Remove(Class)
		end), "Disconnect")

		for Class in next, ObserveBinder:GetAllSet() do
			HandleNewClass(Class)
		end

		return ObserveJanitor
	end)
end

table.freeze(RxBinderUtility)
return RxBinderUtility
