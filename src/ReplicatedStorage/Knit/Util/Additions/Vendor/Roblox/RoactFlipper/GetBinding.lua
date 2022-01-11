local AssignedBinding = require(script.Parent.AssignedBinding)
local Flipper = require(script.Parent.Parent.Parent.Flipper)
local Roact = require(script.Parent.Parent.Roact)

local function GetBinding(Motor)
	local IsMotor = Flipper.IsMotor(assert(Motor, "Missing argument #1: motor"))
	if not IsMotor then
		error("Provided value is not a motor!", 2)
	end

	if Motor[AssignedBinding] then
		return Motor[AssignedBinding]
	end

	local Binding, SetBindingValue = Roact.createBinding(Motor:GetValue())
	Motor:OnStep(SetBindingValue)

	Motor[AssignedBinding] = Binding
	return Binding
end

return GetBinding
