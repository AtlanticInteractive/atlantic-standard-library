local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Knit)

local GetService = require(ReplicatedStorage.Knit.Util.GetService)
local Signal = require(ReplicatedStorage.Knit.Util.Signal)
local TimeFunctions = require(ReplicatedStorage.Knit.Util.Additions.Utility.TimeFunctions)

local TimeSyncController = Knit.CreateController({
	Name = "TimeSyncController";
	Offset = -1;
	OneWayDelay = nil;
	SyncedEvent = Signal.new();
})

function TimeSyncController:IsSynced()
	return self.Offset ~= -1
end

function TimeSyncController:TickToSyncedTime(SyncedTime: number)
	return SyncedTime - self.Offset
end

function TimeSyncController:GetTime()
	if not self:IsSynced() then
		error("[TimeSyncController.GetTime] - Client clock is not yet synced")
	end

	return TimeFunctions.Tick() - self.Offset
end

function TimeSyncController:KnitStart()
	GetService.Option("TimeSyncService"):Match({
		Some = function(TimeSyncService)
			TimeSyncService.SyncTime:Connect(function(TimeOne: number)
				local TimeTwo = TimeFunctions.Tick()
				local ServerClientDifference = TimeTwo - TimeOne

				local TimeThree = TimeFunctions.Tick()
				local ClientServerDifference = TimeSyncService:RequestTime(TimeThree)

				local Offset = (ServerClientDifference - ClientServerDifference) / 2
				local OneWayDelay = (ServerClientDifference + ClientServerDifference) / 2

				self.Offset = Offset
				self.OneWayDelay = OneWayDelay

				self.SyncedEvent:Fire()
			end)

			TimeSyncService.SyncTime:Fire()
		end;

		None = function()
			warn("[TimeSyncController.KnitStart] - TimeSyncService is not available!")
		end;
	})
end

return TimeSyncController
