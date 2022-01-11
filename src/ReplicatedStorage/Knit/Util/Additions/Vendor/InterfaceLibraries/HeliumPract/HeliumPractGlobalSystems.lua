--- @typecheck mode: strict
local RunService = game:GetService("RunService")
local HeliumPractGlobalSystems = {}

HeliumPractGlobalSystems.HeartbeatFrameCount = 0
HeliumPractGlobalSystems.HeartbeatSignal = RunService.Heartbeat

HeliumPractGlobalSystems.ENABLE_FREEZING = false
HeliumPractGlobalSystems.ON_CHILD_TIMEOUT_INTERVAL = 10

local Connections = {}
local Running = false
function HeliumPractGlobalSystems.Run()
	if Running then
		return
	end

	Running = true
	table.insert(Connections, HeliumPractGlobalSystems.HeartbeatSignal:Connect(function()
		HeliumPractGlobalSystems.HeartbeatFrameCount += 1
	end))
end

function HeliumPractGlobalSystems.Stop()
	if not Running then
		return
	end

	Running = false
	for _, Connection in ipairs(Connections) do
		Connection:Disconnect()
	end

	Connections = {}
end

return HeliumPractGlobalSystems
