--[[
	A limited, simple implementation of a Signal.

	Handlers are fired in order, and (dis)connections are properly handled when
	executing an event.
]]
local function immutableAppend(list, ...)
	local len = #list
	local varLen = select("#", ...)
	local new = table.move(list, 1, len, 1, table.create(varLen + len))

	for index = 1, varLen do
		new[len + index] = select(index, ...)
	end

	return new
end

local function immutableRemoveValue(list, removeValue)
	local new = {}

	for _, value in ipairs(list) do
		if value ~= removeValue then
			table.insert(new, value)
		end
	end

	return new
end

local Signal = {}
Signal.ClassName = "Signal"
Signal.__index = Signal

function Signal.new(store)
	return setmetatable({
		_listeners = {};
		_store = store;
	}, Signal)
end

function Signal:connect(callback)
	if type(callback) ~= "function" then
		error("Expected the listener to be a function.")
	end

	if self._store and self._store._isDispatching then
		error("You may not call store.changed:connect() while the reducer is executing. If you would like to be notified after the store has been updated, subscribe from a component and invoke store:getState() in the callback to access the latest state.")
	end

	local listener = {
		callback = callback;
		disconnected = false;
		connectTraceback = debug.traceback();
		disconnectTraceback = nil;
	}

	self._listeners = immutableAppend(self._listeners, listener)

	local function disconnect()
		if listener.disconnected then
			error(string.format("Listener connected at: \n%s\nwas already disconnected at: \n%s\n", tostring(listener.connectTraceback), tostring(listener.disconnectTraceback)))
		end

		if self._store and self._store._isDispatching then
			error("You may not unsubscribe from a store listener while the reducer is executing.")
		end

		listener.disconnected = true
		listener.disconnectTraceback = debug.traceback()
		self._listeners = immutableRemoveValue(self._listeners, listener)
	end

	return {
		disconnect = disconnect;
	}
end

function Signal:fire(...)
	for _, listener in ipairs(self._listeners) do
		if not listener.disconnected then
			listener.callback(...)
		end
	end
end

return Signal
