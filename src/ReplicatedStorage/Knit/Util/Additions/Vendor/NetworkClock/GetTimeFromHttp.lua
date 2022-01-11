local HttpService = game:GetService("HttpService")
local Promise = require(script.Parent.Parent.Parent.Parent.Promise)

local HTTP_DISABLED_STRING = "http requests are not enabled"

local MonthLookup = {Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12}

local function UnixTimeFromDateHeader(DateString: string) --> unixTime: number
	local Day, MonthString, Year, Hour, Minute, Seconds = string.match(DateString, "%w+, (%d+) (%w+) (%d+) (%d+):(%d+):(%d+)")
	return os.time({year = Year, month = MonthLookup[MonthString], day = Day, hour = Hour, min = Minute, sec = Seconds} :: any)
end

local function RequestAsync(RequestDictionary)
	return HttpService:RequestAsync(RequestDictionary)
end

local function GetUnixTimeFromUrl(Url) --> Promise<{timestamp: number, rtt: number, accuracy: number}>
	return Promise.new(function(Resolve)
		local TimerStart = os.clock()
		local ResponseDictionary = RequestAsync({
			Url = Url .. "/?nocache=" .. HttpService:GenerateGUID();
		})

		local ElapsedTime = os.clock() - TimerStart
		local Date = ResponseDictionary.Headers.date
		local Timestamp = UnixTimeFromDateHeader(Date)

		Resolve({
			Accuracy = 1.5 + ElapsedTime;
			ElapsedTime = ElapsedTime;
			Timestamp = Timestamp;
		})
	end)
end

local function GetModeResultWithMinAccuracy(Results)
	local TimestampCounts = {}
	local TimestampResultMinAccuracy = {}
	for _, Result in ipairs(Results) do
		TimestampCounts[Result.Timestamp] = (TimestampCounts[Result.Timestamp] or 0) + 1
		if not TimestampResultMinAccuracy[Result.Timestamp] or Result.Accuracy < TimestampResultMinAccuracy[Result.Timestamp].Accuracy then
			TimestampResultMinAccuracy[Result.Timestamp] = Result
		end
	end

	local MostCommonTimestamp
	local MostCommonTimestampCount = 0
	for Timestamp, Count in next, TimestampCounts do
		if Count > MostCommonTimestampCount then
			MostCommonTimestamp = Timestamp
		end
	end

	return TimestampResultMinAccuracy[MostCommonTimestamp]
end

local function GetTimeFromHttp(Urls, Timeout, MinResults) --> Promise<{time: number, accuracy: number, offset: number}>
	Timeout = Timeout or 10
	MinResults = math.max(1, MinResults or 3)

	return Promise.new(function(Resolve, Reject)
		local Promises = {}
		local Results = {}
		for _, Url in ipairs(Urls) do
			table.insert(Promises, GetUnixTimeFromUrl(Url):Timeout(Timeout):Then(function(Result)
				table.insert(Results, Result)
			end, function(Error)
				if Promise.Error.isKind(Error, Promise.Error.Kind.TimedOut) then
					warn("[NetworkClock] Request to " .. Url .. " timed out (" .. Timeout .. "s)")
				elseif string.find(string.lower(tostring(Error)), HTTP_DISABLED_STRING) then
					warn("[NetworkClock] Http requests are disabled!")
				else
					warn("[NetworkClock] Request to " .. Url .. " failed: " .. tostring(Error))
				end
			end))
		end

		Promise.AllSettled(Promises):Wait()

		if #Results < MinResults then
			return Reject("TooFewResults")
		end

		local ModeResult = GetModeResultWithMinAccuracy(Results)
		local UnixTime = ModeResult.Timestamp + ModeResult.ElapsedTime / 2
		local CurrentTime = os.clock()
		Resolve({
			Accuracy = ModeResult.Accuracy;
			Offset = UnixTime - CurrentTime;
			Time = UnixTime;
		})
	end)
end

return GetTimeFromHttp
