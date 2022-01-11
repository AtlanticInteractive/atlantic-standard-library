local FastEvent = {}
FastEvent.ClassName = "FastEvent"
FastEvent.__index = FastEvent

function FastEvent.new()
	return setmetatable({}, FastEvent)
end

function FastEvent.Is(Value)
	return type(Value) == "table" and getmetatable(Value) == FastEvent
end

function FastEvent:Fire(...)
	for _, Function in ipairs(self) do
		task.spawn(Function, ...)
	end
end

function FastEvent:FireDeferred(...)
	for _, Function in ipairs(self) do
		task.defer(Function, ...)
	end
end

function FastEvent:Wait()
	local Thread = coroutine.running()

	local function Yield(...)
		local Index = table.find(self, Yield)
		if Index then
			local Length = #self
			self[Index] = self[Length]
			self[Length] = nil
		end

		task.spawn(Thread, ...)
	end

	table.insert(self, Yield)
	return coroutine.yield()
end

function FastEvent:Connect(Function)
	table.insert(self, Function)
end

function FastEvent:Disconnect(Function)
	local Index = table.find(self, Function)
	if Index then
		local Length = #self
		self[Index] = self[Length]
		self[Length] = nil
	end
end

function FastEvent:FireAndDestroy(...)
	self:Fire(...)
	self:Destroy()
end

function FastEvent:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end

function FastEvent:__tostring()
	return "FastEvent"
end

export type FastEvent = typeof(FastEvent.new())
table.freeze(FastEvent)
return FastEvent
