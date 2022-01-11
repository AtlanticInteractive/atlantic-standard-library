local Signal = require(script:FindFirstAncestor("Util").Signal)

local YieldPayload = {}
local ResumeSignal = Signal.new()

local SafeThread = {}
SafeThread.Running = coroutine.running

function SafeThread.Resume(Thread, ...)
	ResumeSignal:Fire(Thread, table.pack(...))

	local Returns = YieldPayload[Thread]
	YieldPayload[Thread] = nil

	if Returns ~= nil then
		return table.unpack(Returns, 1, Returns.n)
	end
end

function SafeThread.Yield(...)
	local Thread = coroutine.running()
	YieldPayload[Thread] = table.pack(...)

	while true do
		local ResumedThread, Returns = ResumeSignal:Wait()
		if ResumedThread == Thread then
			return table.unpack(Returns, 1, Returns.n)
		end
	end
end

table.freeze(SafeThread)
return SafeThread
