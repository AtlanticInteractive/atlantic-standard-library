local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = {}

Knit.Shared = ReplicatedStorage:WaitForChild("Shared")
Knit.Player = Players.LocalPlayer
Knit.Controllers = {}
Knit.Util = script.Parent:WaitForChild("Util")
Knit.Modules = ({} :: any) :: Instance
Knit.Services = {}

function Knit.CreateController(ControllerDefinition)
	return ControllerDefinition
end

function Knit.CreateService(ServiceDefinition)
	return ServiceDefinition
end

function Knit.GetService(ServiceName: string)
	return {}
end

function Knit.GetController(ControllerName: string)
	return {}
end

function Knit.AddControllers(Parent: Instance)
	return {}
end

function Knit.AddControllersDeep(Parent: Instance)
	return {}
end

function Knit.AddServices(Parent: Instance)
	return {}
end

function Knit.AddServicesDeep(Parent: Instance)
	return {}
end

function Knit.Start()
	return {}
end

function Knit.IsService()
	return true
end

function Knit.OnStart()
	return {}
end

return Knit
