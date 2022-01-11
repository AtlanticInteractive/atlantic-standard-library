--[=[
	Observables are like a Signal, except they do not execute code
	until the observable is subscribed to. This follows the standard
	Rx API surface for an observable.

	Observables use a [Subscription](/api/Subscription) to emit values.

	```lua
	-- Constructs an observable which will emit a, b, c via a subscription
	local TestObservable = Observable.new(function(Subscription)
		print("Connected")
		Subscription:Fire("a")
		Subscription:Fire("b")
		Subscription:Fire("c")
		Subscription:Complete() -- ends stream
	end)

	TestObservable:Subscribe() --> Connected
	TestObservable:Subscribe() --> Connected
	TestObservable:Subscribe() --> Connected
	```

	Note that emitted values may be observed like this

	```lua
	TestObservable:Subscribe(function(Value)
		print("Got", Value)
	end)

	--> Got a
	--> Got b
	--> Got c
	```

	Note that also, observables return a JanitorTask which
	should be used to clean up the resulting subscription.

	```lua
	Janitor:Add(Observable:Subscribe(function(Value)
		-- do work here!
	end), "Destroy")
	```

	Observables over signals are nice because observables may be chained and manipulated
	via the Pipe operation.

	:::tip
	You should always clean up the subscription using a Janitor, otherwise
	you may memory leak.
	:::

	@class Observable
]=]

local Subscription = require(script.Parent.Subscription)

local ENABLE_STACK_TRACING = false

type Subscription<T> = Subscription.Subscription<T>

local Observable = {}
Observable.ClassName = "Observable"
Observable.__index = Observable

--[=[
	Constructs a new Observable

	```lua
	local function ObserveAllChildren(Parent: Instance)
		return Observable.new(function(Subscription)
			local ObserveJanitor = Janitor.new()

			for _, Child in ipairs(Parent:GetChildren()) do
				Subscription:Fire(Child)
			end

			ObserveJanitor:Add(Parent.ChildAdded:Connect(function(Child)
				Subscription:Fire(Child)
			end), "Disconnect")

			return ObserveJanitor
		end)
	end

	-- Prints out all current children, and whenever a new
	-- child is added to workspace
	local ObserveJanitor = Janitor.new()
	ObserveJanitor:Add(ObserveAllChildren(workspace):Subscribe(print), "Destroy")
	```

	@param OnSubscribe (Subscription: Subscription<T>) -> MaidTask
	@return Observable<T>
]=]
function Observable.new<T>(OnSubscribe: (Subscription: Subscription<T>) -> any)
	assert(type(OnSubscribe) == "function", "Bad onSubscribe")

	return setmetatable({
		_OnSubscribe = OnSubscribe;
		_Source = ENABLE_STACK_TRACING and debug.traceback() or "";
	}, Observable)
end

--[=[
	Returns whether or not a value is an observable.
	@param Value any
	@return boolean
]=]
function Observable.Is(Value)
	return type(Value) == "table" and getmetatable(Value) == Observable
end

--[=[
	Transforms the observable with the following transformers

	```lua
	Rx.Of(1, 2, 3):Pipe({
		Rx.Map(function(Result)
			return result + 1
		end);

		Rx.Map(function(Value)
			return string.format("%0.2f", Value)
		end);
	}):Subscribe(print)

	--> 2.00
	--> 3.00
	--> 4.00
	```

	@param Transformers { (observable: Observable<T>) -> Observable<T> }
	@return Observable<T>
]=]
function Observable:Pipe(Transformers: {(Observable: Observable<T>) -> Observable<T>})
	assert(type(Transformers) == "table", "Bad transformers")

	local Current = self
	for _, Transformer in ipairs(Transformers) do
		assert(type(Transformer) == "function", "Bad transformer")
		Current = Transformer(Current)
		assert(Observable.Is(Current))
	end

	return Current
end

--[=[
	Subscribes immediately, fireCallback may return a janitor (or a task a janitor can handle) to clean up

	@param FireFunction function?
	@param FailFunction function?
	@param CompleteFunction function?
	@return JanitorTask
]=]
function Observable:Subscribe(FireFunction, FailFunction, CompleteFunction)
	local ObservableSubscription = Subscription.new(FireFunction, FailFunction, CompleteFunction)
	local Cleanup = self._OnSubscribe(ObservableSubscription)

	if Cleanup then
		ObservableSubscription:_GiveCleanup(Cleanup)
	end

	return ObservableSubscription
end

function Observable:__tostring()
	return "Observable"
end

export type Observable<T> = typeof(Observable.new(function() end))
table.freeze(Observable)
return Observable
