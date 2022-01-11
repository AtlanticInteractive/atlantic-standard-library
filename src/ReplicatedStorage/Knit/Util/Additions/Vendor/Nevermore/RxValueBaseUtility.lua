--[=[
	@class RxValueBaseUtility
]=]

local RxBrioUtility = require(script.Parent.RxBrioUtility)
local RxInstanceUtility = require(script.Parent.RxInstanceUtility)

local RxValueBaseUtility = {}

--[=[
	:::warning
	This caches the last value seen, and may memory leak.
	:::

	@param parent Instance
	@param className string
	@param name string
	@return Observable<any>
	:::
]=]
function RxValueBaseUtility.Observe(Parent: Instance, ClassName: string, Name: string)
	return RxInstanceUtility.ObserveLastNamedChildBrio(Parent, ClassName, Name):Pipe({
		RxBrioUtility.SwitchMap(RxValueBaseUtility.ObserveValue);
	})
end

--[=[
	Observes a value base underneath a parent (last named child).

	@param parent Instance
	@param className string
	@param name string
	@return Observable<Brio<any>>
]=]
function RxValueBaseUtility.ObserveBrio(Parent: Instance, ClassName: string, Name: string)
	return RxInstanceUtility.ObserveLastNamedChildBrio(Parent, ClassName, Name):Pipe({
		RxBrioUtility.SwitchMapBrio(RxValueBaseUtility.ObserveValue);
	})
end

--[=[
	Observables a given value object's value
	@param valueObject Instance
	@return Observable<T>
]=]
function RxValueBaseUtility.ObserveValue(valueObject)
	return RxInstanceUtility.ObserveProperty(valueObject, "Value")
end

return RxValueBaseUtility
