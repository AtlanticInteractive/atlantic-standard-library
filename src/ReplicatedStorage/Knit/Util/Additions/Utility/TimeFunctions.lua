local RunService = game:GetService("RunService")

local TimeFunctions = {}
TimeFunctions.TimeFunction = RunService:IsRunning() and time or os.clock

TimeFunctions.OsTime = function()
	return DateTime.now().UnixTimestamp
end or os.time

TimeFunctions.Tick = function()
	return DateTime.now().UnixTimestampMillis / 1_000
end or tick

TimeFunctions.GetUnixTime = TimeFunctions.Tick

table.freeze(TimeFunctions)
return TimeFunctions
