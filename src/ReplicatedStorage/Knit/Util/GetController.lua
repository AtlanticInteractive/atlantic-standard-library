local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Knit)
local Option = require(script.Parent.Option)

local GetController = {}
local ControllerCache = {}

function GetController.Default(ControllerName: string)
	local Controller = ControllerCache[ControllerName]
	if not Controller then
		Controller = Knit.GetController(ControllerName)
		ControllerCache[ControllerName] = Controller
	end

	return Controller
end

function GetController.Option(ControllerName: string)
	local Controller = ControllerCache[ControllerName]
	if not Controller then
		Controller = Knit.GetController(ControllerName)
		ControllerCache[ControllerName] = Controller
	end

	return Option.Wrap(Controller)
end

return setmetatable(GetController, {
	__call = function(_, ControllerName: string)
		return GetController.Default(ControllerName)
	end;
})
