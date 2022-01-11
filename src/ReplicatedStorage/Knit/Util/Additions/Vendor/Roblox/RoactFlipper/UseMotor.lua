local Flipper = require(script.Parent.Parent.Parent.Flipper)

local function CreateMotor(InitialValue)
	local InitialValueType = type(InitialValue)
	if InitialValueType == "number" then
		return Flipper.SingleMotor.new(InitialValue)
	elseif InitialValueType == "table" then
		return Flipper.GroupMotor.new(InitialValue)
	else
		error(string.format("Invalid type for initialValue. Expected \"number\" or \"table\", got %q", InitialValueType))
	end
end

local function UseMotor(Hooks, InitialValue)
	return Hooks.UseValue(CreateMotor(InitialValue)).value
end

return UseMotor
