local Promise = require(script.Parent.Parent.Parent.Promise)

local function PromisePropertyValue(Object: Instance, PropertyName: string)
	local LocalObject = Object :: any
	local Value = LocalObject[PropertyName]
	if Value then
		return Promise.Resolve(Value)
	end

	local PromiseObject = Promise.new()
	local Connection
	PromiseObject:Finally(function()
		if Connection then
			Connection:Disconnect()
		end
	end)

	Connection = Object:GetPropertyChangedSignal(PropertyName):Connect(function()
		if LocalObject[PropertyName] then
			Promise:Resolve(LocalObject[PropertyName])
		end
	end)

	return PromiseObject
end

return PromisePropertyValue
