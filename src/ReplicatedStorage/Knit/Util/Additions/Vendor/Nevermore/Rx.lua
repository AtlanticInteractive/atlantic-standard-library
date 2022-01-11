---
-- @module Rx
-- @author Quenty

local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)
local Observable = require(script.Parent.Observable)
local Promise = require(script.Parent.Parent.Parent.Parent.Promise)
local Symbol = require(script.Parent.Parent.Parent.Parent.Symbol)
local Llama = require(script.Parent.Parent.Llama)
local ThrottledFunction = require(script.Parent.ThrottledFunction)

local UNSET_VALUE = Symbol.new("unsetValue")

local Rx = {}
Rx.EMPTY = Observable.new(function(sub)
	sub:Complete()
end)

Rx.NEVER = Observable.new(function() end)

-- https://rxjs-dev.firebaseapp.com/api/index/function/pipe
function Rx.Pipe(transformers)
	assert(type(transformers) == "table", "Bad transformers")
	for index, transformer in ipairs(transformers) do
		if type(transformer) ~= "function" then
			error(string.format("[Rx.pipe] Bad pipe value of type %q at index %q, expected function", type(transformer), tostring(index)))
		end
	end

	return function(source)
		assert(source, "Bad source")

		local current = source
		for key, transformer in ipairs(transformers) do
			current = transformer(current)

			if not (type(current) == "table" and current.ClassName == "Observable") then
				error(string.format("[Rx.pipe] - Failed to transform %q in pipe, made %q (%s)", tostring(key), tostring(current), tostring(type(current) == "table" and current.ClassName or "")))
			end
		end

		return current
	end
end

-- http://reactivex.io/documentation/operators/just.html
function Rx.Of(...)
	local args = table.pack(...)

	return Observable.new(function(sub)
		for i = 1, args.n do
			sub:Fire(args[i])
		end

		sub:Complete()
	end)
end

-- http://reactivex.io/documentation/operators/from.html
function Rx.From(item)
	if Promise.Is(item) then
		return Rx.FromPromise(item)
	elseif type(item) == "table" then
		return Rx.Of(table.unpack(item))
	else
		-- TODO: Iterator?
		error("[Rx.from] - cannot convert")
	end
end

-- https://rxjs-dev.firebaseapp.com/api/operators/merge
function Rx.Merge(observables)
	assert(type(observables) == "table", "Bad observables")

	for _, item in ipairs(observables) do
		assert(Observable.Is(item), "Not an observable")
	end

	return Observable.new(function(sub)
		local janitor = Janitor.new()

		for _, observable in ipairs(observables) do
			janitor:Add(observable:Subscribe(sub:GetFireFailComplete()), "Destroy")
		end

		return janitor
	end)
end

-- https://rxjs-dev.firebaseapp.com/api/index/function/fromEvent
function Rx.FromSignal(event)
	return Observable.new(function(sub)
		-- This stream never completes or fails!
		return event:Connect(function(...)
			sub:Fire(...)
		end)
	end)
end

-- https://rxjs-dev.firebaseapp.com/api/index/function/from
function Rx.FromPromise(promise)
	assert(Promise.Is(promise))

	return Observable.new(function(sub)
		if promise.Status == Promise.Status.Resolved then
			sub:Fire(promise:Expect())
			sub:Complete()
			return nil
		end

		local janitor = Janitor.new()

		local pending = true
		janitor:Add(function()
			pending = false
		end, true)

		promise:Then(function(...)
			if pending then
				sub:Fire(...)
				sub:Complete()
			end
		end, function(...)
			if pending then
				sub:Fail(...)
				sub:Complete()
			end
		end)

		return janitor
	end)
end

-- https://rxjs-dev.firebaseapp.com/api/operators/tap
function Rx.Tap(onFire, onError, onComplete)
	assert(type(onFire) == "function" or onFire == nil, "Bad onFire")
	assert(type(onError) == "function" or onError == nil, "Bad onError")
	assert(type(onComplete) == "function" or onComplete == nil, "Bad onComplete")

	return function(source)
		return Observable.new(function(sub)
			return source:Subscribe(function(...)
				if onFire then
					onFire(...)
				end

				sub:Fire(...)
			end, function(...)
				if onError then
					onError(...)
				end

				error(...)
			end, function(...)
				if onComplete then
					onComplete(...)
				end

				onComplete(...)
			end)
		end)
	end
end

-- http://reactivex.io/documentation/operators/start.html
function Rx.Start(callback)
	return function(source)
		return Observable.new(function(sub)
			sub:Fire(callback())

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

-- Like start, but also from (list!)
function Rx.StartFrom(callback)
	assert(type(callback) == "function", "Bad callback")
	return function(source)
		return Observable.new(function(sub)
			for _, value in ipairs(callback()) do
				sub:Fire(value)
			end

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

-- https://rxjs-dev.firebaseapp.com/api/operators/startWith
function Rx.StartWith(values)
	assert(type(values) == "table", "Bad values")

	return function(source)
		return Observable.new(function(sub)
			for _, item in ipairs(values) do
				sub:Fire(item)
			end

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

function Rx.DefaultsTo(value)
	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			local fired = false

			janitor:Add(source:Subscribe(function(...)
				fired = true
				sub:Fire(...)
			end, sub:GetFailComplete()), "Destroy")

			if not fired then
				sub:Fire(value)
			end

			return janitor
		end)
	end
end

Rx.DefaultsToNil = Rx.DefaultsTo(nil)

-- https://www.learnrxjs.io/learn-rxjs/operators/combination/endwith
function Rx.EndWith(values)
	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			janitor:Add(source:Subscribe(function(...)
				sub:Fire(...)
			end, function(...)
				for _, item in ipairs(values) do
					sub:Fire(item)
				end

				sub:Fail(...)
			end, function()
				for _, item in ipairs(values) do
					sub:Fire(item)
				end

				sub:Complete()
			end), "Destroy")

			return janitor
		end)
	end
end

-- http://reactivex.io/documentation/operators/filter.html
function Rx.Where(predicate)
	assert(type(predicate) == "function", "Bad predicate callback")

	return function(source)
		return Observable.new(function(sub)
			return source:Subscribe(function(...)
				if predicate(...) then
					sub:Fire(...)
				end
			end, sub:GetFailComplete())
		end)
	end
end

-- http://reactivex.io/documentation/operators/distinct.html
function Rx.Distinct()
	return function(source)
		return Observable.new(function(sub)
			local last = UNSET_VALUE

			return source:Subscribe(function(value)
				-- TODO: Support tuples
				if last == value then
					return
				end

				last = value
				sub:Fire(last)
			end, sub:GetFailComplete())
		end)
	end
end

-- https://rxjs.dev/api/operators/mapTo
function Rx.MapTo(...)
	local args = table.pack(...)
	return function(source)
		return Observable.new(function(sub)
			return source:Subscribe(function()
				sub:Fire(table.unpack(args, 1, args.n))
			end, sub:GetFailComplete())
		end)
	end
end

-- http://reactivex.io/documentation/operators/map.html
function Rx.Map(project)
	assert(type(project) == "function", "Bad project callback")

	return function(source)
		return Observable.new(function(sub)
			return source:Subscribe(function(...)
				sub:Fire(project(...))
			end, sub:GetFailComplete())
		end)
	end
end

-- Merges higher order observables together
function Rx.MergeAll()
	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			local pendingCount = 0
			local topComplete = false

			janitor:Add(source:Subscribe(function(observable)
				assert(Observable.Is(observable), "Not an observable")

				pendingCount = pendingCount + 1

				local innerJanitor = Janitor.new()

				innerJanitor:Add(observable:Subscribe(function(...)
					-- Merge each inner observable
					sub:Fire(...)
				end, function(...)
					-- Emit failure automatically
					sub:Fail(...)
				end, function()
					innerJanitor:Cleanup()
					pendingCount = pendingCount - 1
					if pendingCount == 0 and topComplete then
						sub:Complete()
						janitor:Cleanup()
					end
				end), "Destroy")

				local key = newproxy(false)
				janitor:Add(innerJanitor, "Destroy", key)

				-- Cleanup
				innerJanitor:Add(function()
					janitor:Remove(key)
				end, true)
			end, function(...)
				sub:Fail(...) -- Also reflect failures up to the top!
				janitor:Cleanup()
			end, function()
				topComplete = true
				if pendingCount == 0 then
					sub:Complete()
					janitor:Cleanup()
				end
			end), "Destroy")

			return janitor
		end)
	end
end

-- Merges higher order observables together
-- https://rxjs.dev/api/operators/switchAll
function Rx.SwitchAll()
	return function(source)
		return Observable.new(function(sub)
			local outerJanitor = Janitor.new()
			local topComplete = false
			local insideComplete = false
			local currentInside = nil

			outerJanitor:Add(source:Subscribe(function(observable)
				assert(Observable.Is(observable))

				insideComplete = false
				currentInside = observable
				outerJanitor:Remove("_current")

				outerJanitor:Add(Janitor.new(), "Destroy", "_current"):Add(observable:Subscribe(
					function(...)
						sub:Fire(...)
					end, -- Merge each inner observable
					function(...)
						if currentInside == observable then
							sub:Fail(...)
						end
					end, -- Emit failure automatically
					function()
						if currentInside == observable then
							insideComplete = true
							if insideComplete and topComplete then
								sub:Complete()
								outerJanitor:Cleanup()
							end
						end
					end
				), "Destroy")
			end, function(...)
				sub:Fail(...) -- Also reflect failures up to the top!
				outerJanitor:Cleanup()
			end, function()
				topComplete = true
				if insideComplete and topComplete then
					sub:Complete()
					outerJanitor:Cleanup()
				end
			end), "Destroy")

			return outerJanitor
		end)
	end
end

-- Sort of equivalent of promise.then()
function Rx.FlatMap(project, resultSelector)
	assert(type(project) == "function", "Bad project")

	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			local pendingCount = 0
			local topComplete = false

			janitor:Add(source:Subscribe(function(...)
				local outerValue = ...

				local observable = project(...)
				assert(Observable.Is(observable), "Bad observable from project")

				pendingCount = pendingCount + 1

				local innerJanitor = Janitor.new()

				innerJanitor:Add(observable:Subscribe(function(...)
					-- Merge each inner observable
					if resultSelector then
						sub:Fire(resultSelector(outerValue, ...))
					else
						sub:Fire(...)
					end
				end, function(...)
					sub:Fail(...) -- Emit failure automatically
				end, function()
					innerJanitor:Cleanup()
					pendingCount = pendingCount - 1
					if pendingCount == 0 and topComplete then
						sub:Complete()
						janitor:Cleanup()
					end
				end), "Destroy")

				local key = newproxy(false)
				janitor:Add(innerJanitor, "Destroy", key)
				-- Cleanup
				innerJanitor:Add(function()
					janitor:Remove(key)
				end, true)
			end, function(...)
				sub:Fail(...) -- Also reflect failures up to the top!
				janitor:Cleanup()
			end, function()
				topComplete = true
				if pendingCount == 0 then
					sub:Complete()
					janitor:Cleanup()
				end
			end), "Destroy")

			return janitor
		end)
	end
end

function Rx.SwitchMap(project)
	return Rx.Pipe({
		Rx.Map(project);
		Rx.SwitchAll();
	})
end

function Rx.TakeUntil(notifier)
	assert(Observable.Is(notifier))

	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()
			local cancelled = false

			local function cancel()
				janitor:Cleanup()
				cancelled = true
			end

			-- Any value emitted will cancel (complete without any values allows all values to pass)
			janitor:Add(notifier:Subscribe(cancel, cancel, nil), "Destroy")

			-- Cancelled immediately? Oh boy.
			if cancelled then
				janitor:Cleanup()
				return nil
			end

			-- Subscribe!
			janitor:Add(source:Subscribe(sub:GetFireFailComplete()), "Destroy")
			return janitor
		end)
	end
end

function Rx.Packed(...)
	local args = table.pack(...)

	return Observable.new(function(sub)
		sub:Fire(table.unpack(args, 1, args.n))
		sub:Complete()
	end)
end

function Rx.Unpacked(observable)
	assert(Observable.Is(observable))

	return Observable.new(function(sub)
		return observable:Subscribe(function(value)
			if type(value) == "table" then
				sub:Fire(table.unpack(value))
			else
				warn(string.format("[Rx.unpacked] - Observable didn't return a table got type %q", type(value)))
			end
		end, sub:GetFailComplete())
	end)
end

-- http://reactivex.io/documentation/operators/do.html
-- https://rxjs-dev.firebaseapp.com/api/operators/finalize
-- https://github.com/ReactiveX/rxjs/blob/master/src/internal/operators/finalize.ts
function Rx.Finalize(finalizerCallback)
	assert(type(finalizerCallback) == "function", "Bad finalizerCallback")

	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()
			janitor:Add(source:Subscribe(sub:GetFireFailComplete()), "Destroy")
			janitor:Add(finalizerCallback, true)

			return janitor
		end)
	end
end

-- https://rxjs.dev/api/operators/combineLatestAll
function Rx.CombineLatestAll()
	return function(source)
		return Observable.new(function(sub)
			local observables = {}
			local janitor = Janitor.new()

			local alive = true
			janitor:Add(function()
				alive = false
			end, true)

			janitor:Add(source:Subscribe(function(value)
				assert(Observable.Is(value))
				table.insert(observables, value)
			end, function(...)
				sub:Fail(...)
			end), function()
				if not alive then
					return
				end

				janitor:Add(Rx.CombineLatest(observables)):Subscribe(sub:GetFireFailComplete(), "Destroy")
			end)

			return janitor
		end)
	end
end

-- This is for backwards compatability, and is deprecated
Rx.CombineAll = Rx.CombineLatestAll

-- NOTE: Untested
function Rx.CatchError(callback)
	assert(type(callback) == "function", "Bad callback")

	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			-- Yikes, let's hope event ordering is good
			local alive = true
			janitor:Add(function()
				alive = false
			end, true)

			janitor:Add(source:Subscribe(function(...)
				sub:Fire(...)
			end, function(...)
				if not alive then
					-- if we failed because maid was cancelled, then we'll get called here?
					-- I think.
					return
				end

				-- at this point, we can only have one error, so we need to subscribe to the result
				-- and continue the observiable
				local observable = callback(...)
				assert(Observable.Is(observable))

				janitor:Add(observable:Subscribe(sub:GetFireFailComplete()), "Destroy")
			end, function()
				sub:Complete()
			end), "Destroy")

			return janitor
		end)
	end
end

function Rx.CombineLatest(observables)
	assert(type(observables) == "table", "Bad observables")

	return Observable.new(function(sub)
		local pending = 0

		local latest = {}
		for key, value in ipairs(observables) do
			if Observable.Is(value) then
				pending = pending + 1
				latest[key] = UNSET_VALUE
			else
				latest[key] = value
			end
		end

		if pending == 0 then
			sub:Fire(latest)
			return sub:Complete()
		end

		local janitor = Janitor.new()

		local function fireIfAllSet()
			for _, value in ipairs(latest) do
				if value == UNSET_VALUE then
					return
				end
			end

			sub:Fire(Llama.Dictionary.copy(latest))
		end

		for key, observer in ipairs(observables) do
			if Observable.Is(observer) then
				janitor:Add(observer:Subscribe(function(value)
					latest[key] = value
					fireIfAllSet()
				end, function(...)
					pending = pending - 1
					sub:Fail(...)
				end, function()
					pending = pending - 1
					if pending == 0 then
						sub:Complete()
					end
				end), "Destroy")
			end
		end

		return janitor
	end)
end

-- http://reactivex.io/documentation/operators/using.html
function Rx.Using(resourceFactory, observableFactory)
	return Observable.new(function(sub)
		local janitor = Janitor.new()

		local resource = resourceFactory()
		janitor:Add(resource, false)

		local observable = observableFactory(resource)
		assert(Observable.Is(observable))

		janitor:Add(observable:Subscribe(sub:GetFireFailComplete()), "Destroy")

		return janitor
	end)
end

-- https://rxjs.dev/api/operators/take
function Rx.Take(number)
	assert(type(number) == "number", "Bad number")
	assert(number >= 0, "Bad number")

	return function(source)
		return Observable.new(function(sub)
			if number == 0 then
				sub:Complete()
				return nil
			end

			local taken = 0
			local janitor = Janitor.new()

			janitor:Add(source:Subscribe(function(...)
				if taken >= number then
					warn("[Rx.take] - Still getting values past subscription")
					return
				end

				taken += 1
				sub:Fire(...)

				if taken == number then
					sub:Complete()
				end
			end, sub:GetFailComplete()), "Destroy")

			return janitor
		end)
	end
end

-- https://rxjs-dev.firebaseapp.com/api/index/function/defer
-- https://netbasal.com/getting-to-know-the-defer-observable-in-rxjs-a16f092d8c09
function Rx.Defer(observableFactory)
	return Observable.new(function(sub)
		local observable
		local ok, err = pcall(function()
			observable = observableFactory()
		end)

		if not ok then
			return sub:Fail(err)
		end

		if not Observable.Is(observable) then
			return sub:Fail("Not an observable")
		end

		return observable:Subscribe(sub:GetFireFailComplete())
	end)
end

-- https://rxjs-dev.firebaseapp.com/api/operators/withLatestFrom
-- https://medium.com/js-in-action/rxjs-nosy-combinelatest-vs-selfish-withlatestfrom-a957e1af42bf
function Rx.WithLatestFrom(inputObservables)
	assert(inputObservables, "Bad inputObservables")

	for _, observable in ipairs(inputObservables) do
		assert(Observable.Is(observable))
	end

	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			local latest = {}

			for key, observable in ipairs(inputObservables) do
				latest[key] = UNSET_VALUE

				janitor:Add(observable:Subscribe(function(value)
					latest[key] = value
				end, nil, nil), "Destroy")
			end

			janitor:Add(source:Subscribe(function(value)
				for _, item in ipairs(latest) do
					if item == UNSET_VALUE then
						return
					end
				end

				sub:Fire({value, table.unpack(latest)})
			end, sub:GetFailComplete()), "Destroy")

			return janitor
		end)
	end
end

-- https://rxjs-dev.firebaseapp.com/api/operators/scan
function Rx.Scan(accumulator, seed)
	assert(type(accumulator) == "function", "Bad accumulator")

	return function(source)
		return Observable.new(function(sub)
			local current = seed

			return source:Subscribe(function(value)
				current = accumulator(current, value)
				sub:Fire(current)
			end, sub:GetFailComplete())
		end)
	end
end

-- https://rxjs-dev.firebaseapp.com/api/operators/debounceTime
-- @param throttleConfig { leading = true; trailing = true; }
-- Note that on complete, the last item is not included, for now, unlike the existing version in rxjs.
function Rx.ThrottleTime(duration, throttleConfig)
	assert(type(duration) == "number", "Bad duration")
	assert(type(throttleConfig) == "table" or throttleConfig == nil, "Bad throttleConfig")

	return function(source)
		return Observable.new(function(sub)
			local janitor = Janitor.new()

			local throttledFunction = janitor:Add(ThrottledFunction.new(duration, function(...)
				sub:Fire(...)
			end, throttleConfig), "Destroy")

			janitor:Add(source:Subscribe(function(...)
				throttledFunction:Call(...)
			end, sub:GetFailComplete()), "Destroy")

			return janitor
		end)
	end
end

return Rx
