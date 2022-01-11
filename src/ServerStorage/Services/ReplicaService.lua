local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Knit)
local BaseReplicaService = require(ServerStorage.Modules.Vendor.ReplicaService)
local Signal = require(ReplicatedStorage.Knit.Util.Signal)
local ServerTypes = require(ServerStorage.Modules.ServerTypes)

local ReplicaService = Knit.CreateService({
	Client = {};
	Name = "ReplicaService";
})

ReplicaService.ActivePlayers = BaseReplicaService.ActivePlayers.Value
ReplicaService.NewActivePlayerSignal = Signal.new()
ReplicaService.RemovedActivePlayerSignal = Signal.new()
ReplicaService.PlayerRequestedData = Signal.new()
ReplicaService.Temporary = BaseReplicaService.Temporary

export type Replica<Value> = ServerTypes.Replica<Value>
export type ClassToken = ServerTypes.ClassToken
export type ReplicaParameters = ServerTypes.ReplicaParameters

function ReplicaService:NewClassToken(ClassName: string): ClassToken
	return BaseReplicaService.NewClassToken(ClassName)
end

function ReplicaService:CreateClassToken(ClassName: string): ClassToken
	return BaseReplicaService.NewClassToken(ClassName)
end

-- function ReplicaService:NewReplica<T>(ReplicaParameters: ReplicaParameters): Replica<T>
-- 	return BaseReplicaService.NewReplica(ReplicaParameters)
-- end

function ReplicaService:NewReplica(ReplicaParameters: ReplicaParameters)
	return BaseReplicaService.NewReplica(ReplicaParameters)
end

function ReplicaService:CreateReplica(ReplicaParameters: ReplicaParameters)
	return BaseReplicaService.NewReplica(ReplicaParameters)
end

function ReplicaService:CheckWriteLib(ModuleScript: ModuleScript)
	return BaseReplicaService.CheckWriteLib(ModuleScript)
end

function ReplicaService:KnitInit()
	BaseReplicaService.ActivePlayers.Changed:Connect(function(Value)
		self.ActivePlayers = Value
	end)

	BaseReplicaService.NewActivePlayerSignal:Connect(function(...)
		self.NewActivePlayerSignal:Fire(...)
	end)

	BaseReplicaService.RemovedActivePlayerSignal:Connect(function(...)
		self.RemovedActivePlayerSignal:Fire(...)
	end)

	BaseReplicaService.PlayerRequestedData:Connect(function(...)
		self.PlayerRequestedData:Fire(...)
	end)
end

return ReplicaService
