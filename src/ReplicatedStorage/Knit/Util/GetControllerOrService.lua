local RunService = game:GetService("RunService")
local GetController = require(script.Parent.GetController)
local GetService = require(script.Parent.GetService)

local IS_CLIENT = RunService:IsClient()

local GetControllerOrService = {}
function GetControllerOrService.Default(Name: string)
	if IS_CLIENT then
		return GetController.Default(Name .. "Controller")
	else
		return GetService.Default(Name .. "Service")
	end
end

function GetControllerOrService.Option(Name: string)
	if IS_CLIENT then
		return GetController.Option(Name .. "Controller")
	else
		return GetService.Option(Name .. "Service")
	end
end

return setmetatable(GetControllerOrService, {
	__call = function(_, Name: string)
		return GetControllerOrService.Default(Name)
	end;
})
