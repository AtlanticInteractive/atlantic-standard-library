-- This is a wrapper for ReplicaService's ReplicaController.
-- This works for Knit specifically.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Knit)
local BaseReplicaController = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Madwork.ReplicaController)
local Signal = require(ReplicatedStorage.Knit.Util.Signal)

local ReplicaController = Knit.CreateController({
	Name = "ReplicaController";
})

ReplicaController.NewReplicaSignal = Signal.new()
ReplicaController.InitialDataReceivedSignal = Signal.new()
ReplicaController.InitialDataReceived = BaseReplicaController.InitialDataReceived.Value

function ReplicaController:GetReplicaById(ReplicaId)
	return BaseReplicaController.GetReplicaById(ReplicaId)
end

function ReplicaController:ReplicaOfClassCreated(ReplicaClass, Listener)
	return BaseReplicaController.ReplicaOfClassCreated(ReplicaClass, Listener)
end

function ReplicaController:RequestData()
	return BaseReplicaController.RequestData()
end

function ReplicaController:KnitInit()
	BaseReplicaController.InitialDataReceived.Changed:Connect(function(Value)
		self.InitialDataReceived = Value
	end)

	BaseReplicaController.NewReplicaSignal:Connect(function(...)
		self.NewReplicaSignal:Fire(...)
	end)

	BaseReplicaController.InitialDataReceivedSignal:Connect(function(...)
		self.InitialDataReceivedSignal:Fire(...)
	end)
end

return ReplicaController
