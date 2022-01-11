--------------------------------------------------------------------------------
--               Batched Yield-Safe Signal Implementation                     --
-- This is a Signal class which has effectively identical behavior to a       --
-- normal RBXScriptSignal, with the only difference being a couple extra      --
-- stack frames at the bottom of the stack trace when an error is thrown.     --
-- This implementation caches runner coroutines, so the ability to yield in   --
-- the signal handlers comes at minimal extra cost over a naive signal        --
-- implementation that either always or never spawns a thread.                --
--                                                                            --
-- API:                                                                       --
--   local Signal = require(THIS MODULE)                                      --
--   local sig = Signal.new()                                                 --
--   local connection = sig:Connect(function(arg1, arg2, ...) ... end)        --
--   sig:Fire(arg1, arg2, ...)                                                --
--   connection:Disconnect()                                                  --
--   sig:DisconnectAll()                                                      --
--   local arg1, arg2, ... = sig:Wait()                                       --
--                                                                            --
-- Licence:                                                                   --
--   Licenced under the MIT licence.                                          --
--                                                                            --
-- Authors:                                                                   --
--   stravant - July 31st, 2021 - Created the file.                           --
--   sleitnick - August 3rd, 2021 - Modified for Knit.                        --
--------------------------------------------------------------------------------

local Promise = require(script.Parent.Promise)
local _Janitor = require(script.Parent.Janitor)

-- The currently idle thread to run the next handler on
local freeRunnerThread = nil

-- Function which acquires the currently idle handler runner thread, runs the
-- function fn on it, and then releases the thread, returning it to being the
-- currently idle one.
-- If there was a currently idle runner thread already, that's okay, that old
-- one will just get thrown and eventually GCed.
local function acquireRunnerThreadAndCallEventHandler(fn, ...)
	local acquiredRunnerThread = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	-- The handler finished running, this runner thread is free again.
	freeRunnerThread = acquiredRunnerThread
end

-- Coroutine runner that we create coroutines of. The coroutine can be
-- repeatedly resumed with functions to run followed by the argument to run
-- them with.
local function runEventHandlerInFreeThread(...)
	acquireRunnerThreadAndCallEventHandler(...)
	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

-- Connection class
local Connection = {}
Connection.ClassName = "Connection"
Connection.__index = Connection

function Connection.new(signal, fn)
	return setmetatable({
		Connected = true;
		_signal = signal;
		_fn = fn;
		_next = false;
	}, Connection)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end

	self.Connected = false

	-- Unhook the node, but DON'T clear it. That way any fire calls that are
	-- currently sitting on this node will be able to iterate forwards off of
	-- it, but any subsequent fire calls will not hit it, and it will be GCed
	-- when no more fire calls are sitting on it.
	if self._signal._handlerListHead == self then
		self._signal._handlerListHead = self._next
	else
		local prev = self._signal._handlerListHead
		while prev and prev._next ~= self do
			prev = prev._next
		end

		if prev then
			prev._next = self._next
		end
	end
end

Connection.Destroy = Connection.Disconnect

-- Signal class
local Signal = {}
Signal.ClassName = "Signal"
Signal.__index = Signal

function Signal.new(janitor: _Janitor.Janitor?)
	local self = setmetatable({
		Event = newproxy(true);
		_handlerListHead = false;
		_proxyHandler = nil;
	}, Signal)

	local Metatable = getmetatable(self.Event)
	function Metatable.__index(_, Index)
		if Index == "Connect" or Index == "connect" then
			return function(_, Function)
				return self:Connect(Function)
			end
		elseif Index == "Wait" or Index == "wait" then
			return function()
				return self:Wait()
			end
		else
			error("Invalid index " .. tostring(Index))
		end
	end

	if janitor then
		janitor:Add(self, "Destroy")
	end

	return self
end

function Signal.Wrap(rbxScriptSignal: RBXScriptSignal, janitor: _Janitor.Janitor?)
	assert(typeof(rbxScriptSignal) == "RBXScriptSignal", "Argument #1 to Signal.Wrap must be a RBXScriptSignal; got " .. typeof(rbxScriptSignal))
	local self = Signal.new(janitor)
	self._proxyHandler = rbxScriptSignal:Connect(function(...)
		self:Fire(...)
	end)

	return self
end

function Signal.Is(obj)
	return type(obj) == "table" and getmetatable(obj) == Signal
end

function Signal:Connect(fn)
	local connection = Connection.new(self, fn)
	if self._handlerListHead then
		connection._next = self._handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end

	return connection
end

function Signal:GetConnections()
	local items = {}
	local item = self._handlerListHead
	while item do
		table.insert(items, item)
		item = item._next
	end

	return items
end

-- Disconnect all handlers. Since we use a linked list it suffices to clear the
-- reference to the head handler.
function Signal:DisconnectAll()
	self._handlerListHead = false
end

-- Signal:Fire(...) implemented by running the handler functions on the
-- coRunnerThread, and any time the resulting thread yielded without returning
-- to us, that means that it yielded to the Roblox scheduler and has been taken
-- over by Roblox scheduling, meaning we have to make a new coroutine runner.
function Signal:Fire(...)
	local item = self._handlerListHead
	while item do
		if item.Connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
			end

			task.spawn(freeRunnerThread, item._fn, ...)
		end

		item = item._next
	end
end

-- Similar to Signal:Fire(...), but uses deferred. It does not reuse the
-- same coroutine like Fire.
function Signal:FireDeferred(...)
	local item = self._handlerListHead
	while item do
		task.defer(item._fn, ...)
		item = item._next
	end
end

-- Implement Signal:Wait() in terms of a temporary connection using
-- a Signal:Connect() which disconnects itself.
function Signal:Wait()
	local waitingCoroutine = coroutine.running()
	local cn
	cn = self:Connect(function(...)
		cn:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)

	return coroutine.yield()
end

-- Resolve a promise once the signal is fired once
function Signal:Promise(predicate)
	return Promise.FromEvent(self, predicate)
end

function Signal:Destroy()
	self._handlerListHead = false
	local proxyHandler = rawget(self, "_proxyHandler")
	if proxyHandler then
		proxyHandler:Disconnect()
	end

	setmetatable(self, nil)
end

export type Signal = typeof(Signal.new(nil))
table.freeze(Signal)
return Signal
