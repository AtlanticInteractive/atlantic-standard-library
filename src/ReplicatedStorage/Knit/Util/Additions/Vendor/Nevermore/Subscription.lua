--[=[
	Subscriptions are used in the callback for an [Observable](/api/Observable). Standard usage
	is as follows.

	```lua
	-- Constructs an observable which will emit a, b, c via a subscription
	Observable.new(function(Subscription)
		Subscription:Fire("a")
		Subscription:Fire("b")
		Subscription:Fire("c")
		Subscription:Complete() -- ends stream
	end)
	```

	@class Subscription
]=]

local _Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)

local Subscription = {}
Subscription.ClassName = "Subscription"
Subscription.__index = Subscription

local StateTypes = {
	PENDING = "pending";
	FAILED = "failed";
	COMPLETE = "complete";
	CANCELLED = "cancelled";
}

local function DoTask(Job)
	if type(Job) == "function" then
		Job()
	elseif typeof(Job) == "RBXScriptConnection" then
		Job:Disconnect()
	elseif type(Job) == "table" and type(Job.Destroy) == "function" then
		Job:Destroy()
	else
		error("Bad job")
	end
end

function Subscription.new(fireCallback, failCallback, completeCallback, onSubscribe)
	assert(type(fireCallback) == "function" or fireCallback == nil, "Bad fireCallback")
	assert(type(failCallback) == "function" or failCallback == nil, "Bad failCallback")
	assert(type(completeCallback) == "function" or completeCallback == nil, "Bad completeCallback")

	return setmetatable({
		_state = StateTypes.PENDING;
		_fireCallback = fireCallback;
		_failCallback = failCallback;
		_completeCallback = completeCallback;
		_onSubscribe = onSubscribe;
	}, Subscription)
end

function Subscription:LinkToInstance(Janitor: _Janitor.Janitor, Object: Instance, AllowMultiple: boolean?)
	Janitor:Add(self, "Destroy")
	return Janitor:LinkToInstance(Object, AllowMultiple)
end

function Subscription:Fire(...)
	if self._state == StateTypes.PENDING and self._fireCallback then
		self._fireCallback(...)
	elseif self._state == StateTypes.CANCELLED then
		warn("[Subscription.Fire] - We are cancelled, but events are still being pushed")
	end
end

function Subscription:Fail()
	if self._state ~= StateTypes.PENDING then
		return
	end

	self._state = StateTypes.FAILED

	if self._failCallback then
		self._failCallback()
	end

	self:_doCleanup()
end

function Subscription:GetFireFailComplete()
	return function(...)
		self:Fire(...)
	end, function(...)
		self:Fail(...)
	end, function(...)
		self:Complete(...)
	end
end

function Subscription:GetFailComplete()
	return function(...)
		self:Fail(...)
	end, function(...)
		self:Complete(...)
	end
end

function Subscription:Complete()
	if self._state ~= StateTypes.PENDING then
		return
	end

	self._state = StateTypes.COMPLETE
	if self._completeCallback then
		self._completeCallback()
	end

	self:_doCleanup()
end

function Subscription:_GiveCleanup(task)
	assert(task, "Bad task")
	assert(not self._cleanupTask, "Already have _cleanupTask")

	if self._state ~= StateTypes.PENDING then
		DoTask(task)
		return
	end

	self._cleanupTask = task
end

function Subscription:_doCleanup()
	if self._cleanupTask then
		DoTask(self._cleanupTask)
		self._cleanupTask = nil
	end
end

function Subscription:Destroy()
	if self._state == StateTypes.PENDING then
		self._state = StateTypes.CANCELLED
	end

	self:_doCleanup()
end

function Subscription:__tostring()
	return "Subscription"
end

export type Subscription<T> = typeof(Subscription.new())
table.freeze(Subscription)
return Subscription
