local Promise = require(script.Parent.Parent.Parent.Parent.Promise)

local function GetTimeFromOsClock()
	return Promise.Resolve({
		Accuracy = 0;
		Offset = 0;
		Time = os.clock();
	})
end

return GetTimeFromOsClock
