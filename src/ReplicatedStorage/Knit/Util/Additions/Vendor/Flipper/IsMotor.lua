local function IsMotor(Value)
	local MotorType = string.match(tostring(Value), "^Motor%((.+)%)$")

	if MotorType then
		return true, MotorType
	else
		return false
	end
end

return IsMotor
