-- Knit just dies if you accidentally require it on team create, so this exists.
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

function Knit.GetService(_ServiceName: string)
	return {}
end

function Knit.GetController(_ControllerName: string)
	return {}
end

function Knit.AddControllers(_Parent: Instance)
	return {}
end

function Knit.AddControllersDeep(_Parent: Instance)
	return {}
end

function Knit.AddServices(_Parent: Instance)
	return {}
end

function Knit.AddServicesDeep(_Parent: Instance)
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
