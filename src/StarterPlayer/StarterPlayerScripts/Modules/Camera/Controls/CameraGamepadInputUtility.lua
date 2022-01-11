--[=[
	@class CameraGamepadInputUtility
]=]

local CameraGamepadInputUtility = {}

-- K is a tunable parameter that changes the shape of the S-curve
-- the larger K is the more straight/linear the curve gets
local k = 0.35
local lowerK = 0.8
local function SCurveTransform(t)
	t = math.clamp(t, -1, 1)
	if t >= 0 then
		return (k * t) / (k - t + 1)
	end

	return -((lowerK * -t) / (lowerK + t + 1))
end

local DEADZONE = 0.1
local function toSCurveSpace(t)
	return (1 + DEADZONE) * (2 * math.abs(t) - 1) - DEADZONE
end

local function fromSCurveSpace(t)
	return t / 2 + 0.5
end

function CameraGamepadInputUtility.OutOfDeadZone(inputObject)
	local stickOffset = inputObject.Position
	return stickOffset.Magnitude >= DEADZONE
end

local function onAxis(axisValue)
	local sign = 1
	if axisValue < 0 then
		sign = -1
	end

	return math.clamp(fromSCurveSpace(SCurveTransform(toSCurveSpace(math.abs(axisValue)))) * sign, -1, 1)
end

function CameraGamepadInputUtility.GamepadLinearToCurve(thumbstickPosition)
	return Vector2.new(onAxis(thumbstickPosition.X), onAxis(thumbstickPosition.Y))
end

table.freeze(CameraGamepadInputUtility)
return CameraGamepadInputUtility
