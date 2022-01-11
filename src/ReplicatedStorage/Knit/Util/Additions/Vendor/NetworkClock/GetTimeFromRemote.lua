local Promise = require(script.Parent.Parent.Parent.Parent.Promise)

local function GetTimeFromRemote(RemoteFunction: RemoteFunction)
	return Promise.new(function(Resolve)
		local TimerStart = os.clock()
		local ServerTime = RemoteFunction:InvokeServer()
		local TimerFinish = os.clock()
		local ElapsedTime = TimerFinish - TimerStart

		local ServerTimeAdjusted = ServerTime + ElapsedTime / 2
		Resolve({
			Accuracy = ElapsedTime;
			Offset = ServerTimeAdjusted - TimerFinish;
			Time = ServerTimeAdjusted;
		})
	end)
end

return GetTimeFromRemote
