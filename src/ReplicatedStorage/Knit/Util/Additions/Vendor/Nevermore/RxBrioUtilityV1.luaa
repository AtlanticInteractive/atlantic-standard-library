---
-- @module RxBrioUtils
-- @author Quenty

local Brio = require(script.Parent.Brio)
local BrioUtils = require(script.Parent.BrioUtility)
local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)
local Observable = require(script.Parent.Observable)
local Rx = require(script.Parent.Rx)

local RxBrioUtils = {}

function RxBrioUtils.ToBrio()
	return Rx.Map(function(result)
		if Brio.Is(result) then
			return result
		end

		return Brio.new(result)
	end)
end

function RxBrioUtils.CompleteOnDeath(brio, observable)
	assert(Brio.Is(brio))
	assert(Observable.Is(observable))

	return Observable.new(function(sub)
		if brio:IsDead() then
			sub:Complete()
			return
		end

		local janitor = brio:ToJanitor()

		janitor:Add(function()
			sub:Complete()
		end, true)

		janitor:Add(observable:Subscribe(sub:GetFireFailComplete()), "Destroy")
		return janitor
	end)
end

function RxBrioUtils.EmitWhileAllDead(valueToEmitWhileAllDead)
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

				aliveBrios = BrioUtils.AliveOnly(aliveBrios)
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
					warn(string.format("[RxBrioUtils.emitWhileAllDead] - Not a brio, %q", tostring(brio)))
					topJanitor:Remove("_lastBrio")
					sub:Fail("Not a brio")
					return
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

-- This can't be cheap. Consider deeply if you want this or not.
function RxBrioUtils.ReduceToAliveList(selectFromBrio)
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

				aliveBrios = BrioUtils.AliveOnly(aliveBrios)
				local values = {}
				if selectFromBrio then
					for _, brio in pairs(aliveBrios) do
						-- Hope for no side effects
						local value = assert(selectFromBrio(brio:GetValue()), "Bad value")
						table.insert(values, value)
					end
				else
					for _, brio in pairs(aliveBrios) do
						local value = assert(brio:GetValue())
						table.insert(values, value)
					end
				end

				local newBrio = topJanitor:Add(BrioUtils.First(aliveBrios, values), "Destroy", "_lastBrio")

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
					sub:Fail("Not a brio")
					return
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

function RxBrioUtils.ReemitLastBrioOnDeath()
	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			janitor:Add(source:Subscribe(function(brio)
				janitor:Remove("_conn")

				if not Brio.Is(brio) then
					warn(string.format("[RxBrioUtils.reemitLastBrioOnDeath] - Not a brio, %q", tostring(brio)))
					sub:Fail("Not a brio")
					return
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

-- Unpacks the brio, and then repacks it. Ignored items
-- still invalidate the previous brio
function RxBrioUtils.Filter(predicate)
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
						sub:Fire(janitor:Add(BrioUtils.Clone(brio), "Destroy", "_lastBrio"))
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

-- Flattens all the brios in one brio and combines them. Note that this method leads to
-- gaps in the lifetime of the brio.
function RxBrioUtils.CombineLatest(observables)
	assert(type(observables) == "table", "Bad observables")

	return Rx.CombineLatest(observables):Pipe({
		Rx.Map(BrioUtils.Flatten);
		RxBrioUtils.OnlyLastBrioSurvives();
	})
end

function RxBrioUtils.FlatMap(project, resultSelector)
	assert(type(project) == "function", "Bad project")

	return Rx.FlatMap(RxBrioUtils.MapBrio(project), resultSelector)
end

function RxBrioUtils.SwitchMap(project, resultSelector)
	assert(type(project) == "function", "Bad project")

	return Rx.SwitchMap(RxBrioUtils.MapBrio(project), resultSelector)
end

--[[
Works line combineLatest, but allow the transformation of a brio into an observable
that emits the value, and then nil, on death.

The issue here is this:

1. Resources are found with combineLatest()
2. One resource dies
3. All resources are invalidated
4. We still wanted to be able to use most of the resources

With this method we are able to do this, as we'll re-emit a table with all resoruces
except the invalidated one.
]]
function RxBrioUtils.FlatCombineLatest(observables)
	assert(type(observables) == "table", "Bad observables")

	local newObservables = {}
	for key, observable in pairs(observables) do
		if Observable.Is(observable) then
			newObservables[key] = RxBrioUtils.FlattenToValueAndNil(observable)
		else
			newObservables[key] = observable
		end
	end

	return Rx.CombineLatest(newObservables)
end

-- Takes in a brio and returns an observable that completes ony
function RxBrioUtils.MapBrio(project)
	assert(type(project) == "function", "Bad project")

	return function(brio)
		assert(Brio.Is(brio), "Not a brio")

		if brio:IsDead() then
			return Rx.EMPTY
		end

		local observable = project(brio:GetValue())
		assert(Observable.Is(observable), "Not an observable")

		return RxBrioUtils.CompleteOnDeath(brio, observable)
	end
end

-- Transforms the brio into an observable that emits the initial value of the brio, and then another value on death
function RxBrioUtils.ToEmitOnDeathObservable(brio, emitOnDeathValue)
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

function RxBrioUtils.MapBrioToEmitOnDeathObservable(emitOnDeathValue)
	return function(brio)
		return RxBrioUtils.ToEmitOnDeathObservable(brio, emitOnDeathValue)
	end
end

--- Takes in an observable of brios and returns an observable of the inner values that will also output
-- nil if there is no other value for the brio
function RxBrioUtils.EmitOnDeath(emitOnDeathValue)
	return Rx.SwitchMap(RxBrioUtils.MapBrioToEmitOnDeathObservable(emitOnDeathValue))
end

RxBrioUtils.FlattenToValueAndNil = RxBrioUtils.EmitOnDeath(nil)

function RxBrioUtils.OnlyLastBrioSurvives()
	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			janitor:Add(source:Subscribe(function(brio)
				if not Brio.Is(brio) then
					warn(string.format("[RxBrioUtils.onlyLastBrioSurvives] - Not a brio, %q", tostring(brio)))
					janitor:Remove("_lastBrio")
					sub:Fail("Not a brio")
					return
				end

				sub:Fire(janitor:Add(BrioUtils.Clone(brio), "Destroy", "_lastBrio"))
			end, sub:GetFailComplete()), "Destroy")

			return janitor
		end)
	end
end

return RxBrioUtils
