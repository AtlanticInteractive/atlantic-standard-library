local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Knit)
local TimeFunctions = require(ReplicatedStorage.Knit.Util.Additions.Utility.TimeFunctions)
local Timer = require(ReplicatedStorage.Knit.Util.Timer)

local TimeSyncService = Knit.CreateService({
	Client = {};
	Name = "TimeSyncService";
})

TimeSyncService.Client.SyncTime = Knit.CreateSignal()

function TimeSyncService:IsSynced()
	if not RunService:IsRunning() then
		return true
	end
end

function TimeSyncService:GetTime()
	return TimeFunctions.Tick()
end

function TimeSyncService:RequestTime(_, ClientTime: number)
	return TimeFunctions.Tick() - ClientTime
end

function TimeSyncService.Client:RequestTime(Player: Player, ClientTime: number)
	return self.Server:RequestTime(Player, ClientTime)
end

function TimeSyncService:KnitInit()
	local SyncTimer = Timer.new(5)
	SyncTimer.Tick:Connect(function()
		self.Client.SyncTime:FireAll(TimeFunctions.Tick())
	end)

	self.Client.SyncTime:Connect(function(Player: Player)
		self.Client.SyncTime:Fire(Player, TimeFunctions.Tick())
	end)

	SyncTimer:Start()
end

return TimeSyncService
