--[=[
	Utility functions involving brios and rx. Brios encapsulate the lifetime of resources,
	which could be expired by the time a subscription occurs. These functions allow us to
	manipulate the state of these at a higher order.

	@class RxBrioUtils
]=]

local Brio = require(script.Parent.Brio)
local BrioUtility = require(script.Parent.BrioUtility)
local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)
local Observable = require(script.Parent.Observable)
local Rx = require(script.Parent.Rx)
local StateStack = require(script.Parent.Parent.Parent.Classes.StateStack)

local RxBrioUtility = {}

--[=[
	Takes a result and converts it to a brio if it is not one.

	@return (source: Observable<Brio<T> | T>) -> Observable<Brio<T>>
]=]
function RxBrioUtility.ToBrio()
	return Rx.Map(function(Result)
		if Brio.Is(Result) then
			return Result
		end

		return Brio.new(Result)
	end)
end

--[=[
	Creates a state stack from the brio's value. The state stack holds the last
	value seen that is valid.

	@param observable Observable<Brio<T>>
	@return StateStack<T>
]=]
function RxBrioUtility.CreateStateStack(WithObservable)
	local NewStateStack = StateStack.new()

	NewStateStack.Janitor:Add(WithObservable:Subscribe(function(Value)
		assert(Brio.Is(Value), "Observable must emit brio")
		if Value:IsDead() then
			return
		end

		Value:ToJanitor():Add(NewStateStack:PushState(Value:GetValue()), true)
	end), "Destroy")

	return NewStateStack
end

--[=[
	Completes the observable on death

	@param brio Brio
	@param observable Observable<T>
	@return Observable<T>
]=]
function RxBrioUtility.CompleteOnDeath(CompleteBrio, WithObservable)
	assert(Brio.Is(CompleteBrio))
	assert(Observable.Is(WithObservable))

	return Observable.new(function(Subscription)
		if CompleteBrio:IsDead() then
			return Subscription:Complete()
		end

		local CompleteJanitor = CompleteBrio:ToJanitor()
		CompleteJanitor:Add(function()
			Subscription:Complete()
		end, true)

		CompleteJanitor:Add(WithObservable:Subscribe(Subscription:GetFireFailComplete()), "Destroy")
		return CompleteJanitor
	end)
end

--[=[
	Whenever all returned brios are dead, emits this value wrapped
	in a brio.

	@param valueToEmitWhileAllDead T
	@return (source: Observable<Brio<U>>) -> Observable<Brio<U | T>>
]=]
function RxBrioUtility.EmitWhileAllDead(valueToEmitWhileAllDead)
	return function(source)
		return Observable.new(function(sub)
			local topJanitor = Janitor.new()

			local subscribed = true
			topJanitor:Add(function()
				subscribed = false
			end, true)

			local aliveBrios = {}
			local fired = false

			local function updateBrios()
				if not subscribed then -- No work if we don't need to.
					return
				end

				aliveBrios = BrioUtility.AliveOnly(aliveBrios)
				if next(aliveBrios) then
					topJanitor:Remove("_lastBrio")
				else
					sub:Fire(topJanitor:Add(Brio.new(valueToEmitWhileAllDead), "Destroy", "_lastBrio"))
				end

				fired = true
			end

			local function handleNewBrio(brio)
				-- Could happen due to throttle or delay...
				if brio:IsDead() then
					return
				end

				local newJanitor = Janitor.new()
				topJanitor:Add(newJanitor, "Destroy", newJanitor)

				newJanitor:Add(function() -- GC properly
					topJanitor:Remove(newJanitor)
					updateBrios()
				end, true)

				newJanitor:Add(brio:GetDiedSignal():Connect(function()
					topJanitor:Remove(newJanitor)
				end), "Disconnect")

				table.insert(aliveBrios, brio)
				updateBrios()
			end

			topJanitor:Add(source:Subscribe(function(brio)
				if not Brio.Is(brio) then
					warn(string.format("[RxBrioUtils.emitWhileAllDead] - Not a brio, %q", tostring(brio)))
					topJanitor:Remove("_lastBrio")
					return sub:Fail("Not a brio")
				end

				handleNewBrio(brio)
			end, function(...)
				sub:Fail(...)
			end, function(...)
				sub:Complete(...)
			end), "Destroy")

			-- Make sure we emit an empty list if we discover nothing
			if not fired then
				updateBrios()
			end

			return topJanitor
		end)
	end
end

--[=[
	This can't be cheap. Consider deeply if you want this or not.

	@param selectFromBrio ((value: T) -> U)?
	@return (source: Observable<Brio<T>>) -> Observable<Brio{U}>
]=]
function RxBrioUtility.ReduceToAliveList(selectFromBrio)
	assert(type(selectFromBrio) == "function" or selectFromBrio == nil, "Bad selectFromBrio")

	return function(source)
		return Observable.new(function(sub)
			local topJanitor = Janitor.new()

			local subscribed = true
			topJanitor:Add(function()
				subscribed = false
			end, true)

			local aliveBrios = {}
			local fired = false

			local function updateBrios()
				if not subscribed then -- No work if we don't need to.
					return
				end

				aliveBrios = BrioUtility.AliveOnly(aliveBrios)
				local values = {}
				if selectFromBrio then
					for _, brio in ipairs(aliveBrios) do
						-- Hope for no side effects
						local value = assert(selectFromBrio(brio:GetValue()), "Bad value")
						table.insert(values, value)
					end
				else
					for _, brio in ipairs(aliveBrios) do
						local value = assert(brio:GetValue())
						table.insert(values, value)
					end
				end

				local newBrio = topJanitor:Add(BrioUtility.First(aliveBrios, values), "Destroy", "_lastBrio")
				fired = true
				sub:Fire(newBrio)
			end

			local function handleNewBrio(brio)
				-- Could happen due to throttle or delay...
				if brio:IsDead() then
					return
				end

				local janitor = Janitor.new()
				topJanitor:Add(janitor, "Destroy", janitor)

				janitor:Add(function() -- GC properly
					topJanitor:Remove(janitor)
					updateBrios()
				end, true)

				janitor:Add(brio:GetDiedSignal():Connect(function()
					topJanitor:Remove(janitor)
				end), "Disconnect")

				table.insert(aliveBrios, brio)
				updateBrios()
			end

			topJanitor:Add(source:Subscribe(function(brio)
				if not Brio.Is(brio) then
					warn(string.format("[RxBrioUtils.mergeToAliveList] - Not a brio, %q", tostring(brio)))
					topJanitor:Remove("_lastBrio")
					return sub:Fail("Not a brio")
				end

				handleNewBrio(brio)
			end, function(...)
				sub:Fail(...)
			end, function(...)
				sub:Complete(...)
			end), "Destroy")

			-- Make sure we emit an empty list if we discover nothing
			if not fired then
				updateBrios()
			end

			return topJanitor
		end)
	end
end

--[=[
	Whenever the last brio dies, reemit it as a dead brio

	@return (source Observable<Brio<T>>) -> Observable<Brio<T>>
]=]
function RxBrioUtility.ReemitLastBrioOnDeath()
	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			janitor:Add(source:Subscribe(function(brio)
				janitor:Remove("_conn")

				if not Brio.Is(brio) then
					warn(string.format("[RxBrioUtils.reemitLastBrioOnDeath] - Not a brio, %q", tostring(brio)))
					return sub:Fail("Not a brio")
				end

				if brio:IsDead() then
					sub:Fire(brio)
					return
				end

				-- Setup conn!
				janitor:Add(brio:GetDiedSignal():Connect(function()
					sub:Fire(brio)
				end), "Disconnect", "_conn")

				sub:Fire(brio)
			end, function(...)
				sub:Fail(...)
			end, function(...)
				sub:Complete(...)
			end), "Destroy")

			return janitor
		end)
	end
end

--[=[
	Unpacks the brio, and then repacks it. Ignored items
	still invalidate the previous brio

	@since 3.6.0
	@param predicate (T) -> boolean
	@return (source: Observable<Brio<T>>) -> Observable<Brio<T>>
]=]
function RxBrioUtility.Where(predicate)
	assert(type(predicate) == "function", "Bad predicate")

	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			janitor:Add(source:Subscribe(function(brio)
				janitor:Remove("_lastBrio")

				if Brio.Is(brio) then
					if brio:IsDead() then
						return
					end

					if predicate(brio:GetValue()) then
						sub:Fire(janitor:Add(BrioUtility.Clone(brio), "Destroy", "_lastBrio"))
					end
				else
					if predicate(brio) then
						sub:Fire(janitor:Add(Brio.new(brio), "Destroy", "_lastBrio"))
					end
				end
			end, sub:GetFailComplete()), "Destroy")

			return janitor
		end)
	end
end

--[=[
	Same as [RxBrioUtils.where]. Here to keep backwards compatability.

	@deprecated 3.6.0 -- This method does not wrap the resulting value in a Brio, which can sometimes lead to leaks.
	@function filter
	@param predicate (T) -> boolean
	@return (source: Observable<Brio<T>>) -> Observable<Brio<T>>
	@within RxBrioUtils
]=]
RxBrioUtility.Filter = RxBrioUtility.Where

--[=[
	Flattens all the brios in one brio and combines them. Note that this method leads to
	gaps in the lifetime of the brio.

	@deprecated 3.6.0 -- This method does not wrap the resulting value in a Brio, which can sometimes lead to leaks.
	@param observables { [any]: Observable<Brio<T>> | Observable<T> | T }
	@return Observable<Brio<{ [any]: T }>>
]=]
function RxBrioUtility.CombineLatest(observables)
	assert(type(observables) == "table", "Bad observables")

	warn("[RxBrioUtils.combineLatest] - Deprecated since 3.6.0. Use RxBrioUtils.flatCombineLatest")

	return Rx.CombineLatest(observables):Pipe({
		Rx.Map(BrioUtility.Flatten);
		RxBrioUtility.OnlyLastBrioSurvives();
	})
end

--[=[
	Flat map equivalent for brios. The resulting observables will
	be disconnected at the end of the brio.

	@deprecated 3.6.0 -- This method does not wrap the resulting value in a Brio, which can sometimes lead to leaks.
	@param project (value: TBrio) -> TProject
	@param resultSelector ((initial TBrio, value: TProject) -> TResult)?
	@return (source: Observable<Brio<TBrio>> -> Observable<TResult>)
]=]
function RxBrioUtility.FlatMap(project, resultSelector)
	assert(type(project) == "function", "Bad project")

	warn("[RxBrioUtils.flatMap] - Deprecated since 3.6.0. Use RxBrioUtils.flatMapBrio")

	return Rx.FlatMap(RxBrioUtility.MapBrio(project), resultSelector)
end

--[=[
	Flat map equivalent for brios. The resulting observables will
	be disconnected at the end of the brio.

	Like [RxBrioUtils.flatMap], but emitted values are wrapped in brios.
	The lifetime of this brio is limited by the lifetime of the
	input brios, which are unwrapped and repackaged.

	@since 3.6.0
	@param project (value: TBrio) -> TProject | Brio<TProject>
	@return (source: Observable<Brio<TBrio>> -> Observable<Brio<TResult>>)
]=]
function RxBrioUtility.FlatMapBrio(project)
	return Rx.FlatMap(RxBrioUtility.MapBrioBrio(project))
end

--[=[
	Switch map but for brios. The resulting observable will be
	disconnected on the end of the brio's life.

	@deprecated 3.6.0 -- This method does not wrap the resulting value in a Brio, which can sometimes lead to leaks.
	@param project (value: TBrio) -> TProject
	@return (source: Observable<Brio<TBrio>>) -> Observable<TResult>
]=]
function RxBrioUtility.SwitchMap(project)
	assert(type(project) == "function", "Bad project")

	warn("[RxBrioUtils.switchMap] - Deprecated since 3.6.0. Use RxBrioUtils.switchMapBrio")

	return Rx.SwitchMap(RxBrioUtility.MapBrio(project))
end

--[=[
	Switch map but for brios. The resulting observable will be
	disconnected on the end of the brio's life.

	Like [RxBrioUtils.switchMap] but emitted values are wrapped in brios.
	The lifetime of this brio is limited by the lifetime of the
	input brios, which are unwrapped and repackaged.

	@since 3.6.0
	@param project (value: TBrio) -> TProject | Brio<TProject>
	@return (source: Observable<Brio<TBrio>>) -> Observable<Brio<TResult>>
]=]
function RxBrioUtility.SwitchMapBrio(project)
	assert(type(project) == "function", "Bad project")

	return Rx.SwitchMap(RxBrioUtility.MapBrioBrio(project))
end

--[=[
	Works line combineLatest, but allow the transformation of a brio into an observable
	that emits the value, and then nil, on death.

	The issue here is this:

	1. Resources are found with combineLatest()
	2. One resource dies
	3. All resources are invalidated
	4. We still wanted to be able to use most of the resources

	With this method we are able to do this, as we'll re-emit a table with all resoruces
	except the invalidated one.

	@since 3.6.0
	@param observables { [any]: Observable<Brio<T>> | Observable<T> | T }
	@return Observable<{ [any]: T? }>
]=]
function RxBrioUtility.FlatCombineLatest(observables)
	assert(type(observables) == "table", "Bad observables")

	local newObservables = {}
	for key, observable in next, observables do
		if Observable.Is(observable) then
			newObservables[key] = RxBrioUtility.FlattenToValueAndNil(observable)
		else
			newObservables[key] = observable
		end
	end

	return Rx.CombineLatest(newObservables)
end

--[=[
	Takes in a brio and returns an observable that emits the brio, and then completes
	on death.

	@deprecated 3.6.0 -- This method does not wrap the resulting value in a Brio, which can sometimes lead to leaks.
	@param project (value: TBrio) -> TProject
	@return (brio<TBrio>) -> TProject
]=]
function RxBrioUtility.MapBrio(project)
	assert(type(project) == "function", "Bad project")

	warn("[RxBrioUtils.mapBrio] - Deprecated since 3.6.0. Use RxBrioUtils.mapBrioBrio")

	return function(brio)
		assert(Brio.Is(brio), "Not a brio")

		if brio:IsDead() then
			return Rx.EMPTY
		end

		local observable = project(brio:GetValue())
		assert(Observable.Is(observable), "Not an observable")

		return RxBrioUtility.CompleteOnDeath(brio, observable)
	end
end

--[=[
	Prepends the value onto the emitted brio
	@since 3.6.0
	@param ... T
	@return (source: Observable<Brio<U>>) -> Observable<Brio<U | T>>
]=]
function RxBrioUtility.Prepend(...)
	local args = table.pack(...)

	return Rx.Map(function(brio)
		assert(Brio.Is(brio), "Bad brio")

		return BrioUtility.Prepend(brio, table.unpack(args, 1, args.n))
	end)
end

--[=[
	Extends the value onto the emitted brio
	@since 3.6.0
	@param ... T
	@return (source: Observable<Brio<U>>) -> Observable<Brio<U | T>>
]=]
function RxBrioUtility.Extend(...)
	local args = table.pack(...)

	return Rx.Map(function(brio)
		assert(Brio.Is(brio), "Bad brio")

		return BrioUtility.Extend(brio, table.unpack(args, 1, args.n))
	end)
end

--[=[
	Maps the input brios to the output observables
	@since 3.6.0
	@param project project (Brio<T> | T) -> Brio<U> | U
	@return (source: Observable<Brio<T> | T>) -> Observable<Brio<U>>
]=]
function RxBrioUtility.Map(project)
	return Rx.Map(function(...)
		local n = select("#", ...)
		local brios = {}
		local args

		if n == 1 then
			if Brio.Is(...) then
				table.insert(brios, (...))
				args = (...):GetPackedValues()
			else
				args = {[1] = ...}
			end
		else
			args = {}
			for index, item in next, {...} do
				if Brio.Is(item) then
					table.insert(brios, item)
					args[index] = item:GetValue() -- we lose data here, but I think this is fine
				else
					args[index] = item
				end
			end

			args.n = n
		end

		local results = table.pack(project(table.unpack(args, 1, args.n)))
		if results.n == 1 then
			if Brio.Is(results[1]) then
				table.insert(brios, results[1])
				return BrioUtility.First(brios, results:GetValue())
			else
				return BrioUtility.WithOtherValues(brios, results[1])
			end
		else
			local transformedResults = {}
			for i = 1, results.n do
				local item = results[i]
				if Brio.Is(item) then
					table.insert(brios, item) -- add all subsequent brios into this table...
					transformedResults[i] = item:GetValue()
				else
					transformedResults[i] = item
				end
			end

			return BrioUtility.First(brios, table.unpack(transformedResults, 1, transformedResults.n))
		end
	end)
end

local function MapResult(brio)
	return function(...)
		local n = select("#", ...)
		if n == 0 then
			return BrioUtility.WithOtherValues(brio)
		elseif n == 1 then
			if Brio.Is(...) then
				return BrioUtility.First({brio, (...)}, (...):GetValue())
			else
				return BrioUtility.WithOtherValues(brio, ...)
			end
		else
			local brios = {brio}
			local args = {}

			for index, item in next, {...} do
				if Brio.Is(item) then
					table.insert(brios, item)
					args[index] = item:GetValue() -- we lose data here, but I think this is fine
				else
					args[index] = item
				end
			end

			return BrioUtility.First(brios, table.unpack(args, 1, n))
		end
	end
end

--[=[
	Takes in a brio and returns an observable that emits the brio, and then completes
	on death.

	@since 3.6.0
	@param project (value: TBrio) -> TProject | Brio<TProject>
	@return (brio<TBrio>) -> Brio<TProject>
]=]
function RxBrioUtility.MapBrioBrio(project)
	assert(type(project) == "function", "Bad project")

	return function(brio)
		assert(Brio.Is(brio), "Not a brio")

		if brio:IsDead() then
			return Rx.EMPTY
		end

		local observable = project(brio:GetValue())
		assert(Observable.Is(observable), "Not an observable")

		return RxBrioUtility.CompleteOnDeath(brio, observable):Pipe({
			Rx.Map(MapResult(brio));
		})
	end
end

--[=[
	Transforms the brio into an observable that emits the initial value of the brio, and then another value on death
	@param brio Brio<T> | T
	@param emitOnDeathValue U
	@return Observable<T | U>
]=]
function RxBrioUtility.ToEmitOnDeathObservable(brio, emitOnDeathValue)
	if not Brio.Is(brio) then
		return Rx.Of(brio)
	else
		return Observable.new(function(sub)
			if brio:IsDead() then
				sub:Fire(emitOnDeathValue)
				sub:Complete()
			else
				sub:Fire(brio:GetValue())

				return brio:GetDiedSignal():Connect(function()
					sub:Fire(emitOnDeathValue)
					sub:Complete()
				end)
			end
		end)
	end
end

--[=[
	Returns a mapping function that emits the given value.

	@param emitOnDeathValue U
	@return (brio: Brio<T> | T) -> Observable<T | U>
]=]
function RxBrioUtility.MapBrioToEmitOnDeathObservable(emitOnDeathValue)
	return function(brio)
		return RxBrioUtility.ToEmitOnDeathObservable(brio, emitOnDeathValue)
	end
end

--[=[
	Takes in an observable of brios and returns an observable of the inner values that will also output
	nil if there is no other value for the brio.

	@param emitOnDeathValue U
	@return (source: Observable<Brio<T> | T>) -> Observable<T | U>
]=]
function RxBrioUtility.EmitOnDeath(emitOnDeathValue)
	return Rx.SwitchMap(RxBrioUtility.MapBrioToEmitOnDeathObservable(emitOnDeathValue))
end

--[=[
	Flattens the observable to nil and the value

	@function flattenToValueAndNil
	@param source Observable<Brio<T> | T>
	@return T | nil
	@within RxBrioUtils
]=]
RxBrioUtility.FlattenToValueAndNil = RxBrioUtility.EmitOnDeath(nil)

--[=[
	Ensures only the last brio survives.

	@return (source Observable<Brio<T>>) -> Observable<Brio<T>>
]=]
function RxBrioUtility.OnlyLastBrioSurvives()
	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			janitor:Add(source:Subscribe(function(brio)
				if not Brio.Is(brio) then
					warn(string.format("[RxBrioUtils.onlyLastBrioSurvives] - Not a brio, %q", tostring(brio)))
					janitor:Remove("_lastBrio")
					return sub:Fail("Not a brio")
				end

				sub:Fire(janitor:Add(BrioUtility.Clone(brio), "Destroy", "_lastBrio"))
			end, sub:GetFailComplete()), "Destroy")

			return janitor
		end)
	end
end

--[=[
	Switches the result to a brio, and ensures only the last brio lives.

	@since 3.6.0
	@function switchToBrio
	@return (source: Observable<T>) -> Observable<Brio<T>>
	@within RxBrioUtils
]=]
RxBrioUtility.SwitchToBrio = Rx.Pipe({
	RxBrioUtility.ToBrio();
	RxBrioUtility.OnlyLastBrioSurvives();
})

return RxBrioUtility
