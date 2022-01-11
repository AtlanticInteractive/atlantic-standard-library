local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Knit)
local Option = require(script.Parent.Option)

local GetService = {}
local ServiceCache = {}

function GetService.Default(ServiceName: string)
	local Service = ServiceCache[ServiceName]
	if not Service then
		Service = Knit.GetService(ServiceName)
		ServiceCache[ServiceName] = Service
	end

	return Service
end

function GetService.Option(ServiceName: string)
	local Service = ServiceCache[ServiceName]
	if not Service then
		Service = Knit.GetService(ServiceName)
		ServiceCache[ServiceName] = Service
	end

	return Option.Wrap(Service)
end

return setmetatable(GetService, {
	__call = function(_, ServiceName: string)
		return GetService.Default(ServiceName)
	end;
})
