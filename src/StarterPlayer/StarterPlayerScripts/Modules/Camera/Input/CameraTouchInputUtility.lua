--[=[
	Utility methods involving touch input and cameras.
	@class CameraTouchInputUtility
]=]

local CameraTouchInputUtility = {}

-- Note: DotProduct check in CoordinateFrame::lookAt() prevents using values within about
-- 8.11 degrees of the +/- Y axis, that's why these limits are currently 80 degrees
local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)

local TOUCH_ADJUST_AREA_UP = math.rad(30)
local TOUCH_ADJUST_AREA_DOWN = math.rad(-15)

local TOUCH_SENSITIVITY_ADJUST_MAX_Y = 2.1
local TOUCH_SENSITIVITY_ADJUST_MIN_Y = 0.5

--[=[
	Adjusts the camera Y touch Sensitivity when moving away from the center and in the TOUCH_SENSITIVITY_ADJUST_AREA
	Straight from Roblox's code

	@param currPitchAngle number
	@param sensitivity Vector2
	@param delta Vector2
	Return Vector2
]=]
function CameraTouchInputUtility.adjustTouchSensitivity(currentPitchAngle, sensitivity, delta)
	local multiplierY = TOUCH_SENSITIVITY_ADJUST_MAX_Y
	if currentPitchAngle > TOUCH_ADJUST_AREA_UP and delta.Y < 0 then
		local fractionAdjust = (currentPitchAngle - TOUCH_ADJUST_AREA_UP) / (MAX_Y - TOUCH_ADJUST_AREA_UP)
		fractionAdjust = 1 - (1 - fractionAdjust) ^ 3
		multiplierY = TOUCH_SENSITIVITY_ADJUST_MAX_Y - fractionAdjust * (TOUCH_SENSITIVITY_ADJUST_MAX_Y - TOUCH_SENSITIVITY_ADJUST_MIN_Y)
	elseif currentPitchAngle < TOUCH_ADJUST_AREA_DOWN and delta.Y > 0 then
		local fractionAdjust = (currentPitchAngle - TOUCH_ADJUST_AREA_DOWN) / (MIN_Y - TOUCH_ADJUST_AREA_DOWN)
		fractionAdjust = 1 - (1 - fractionAdjust) ^ 3
		multiplierY = TOUCH_SENSITIVITY_ADJUST_MAX_Y - fractionAdjust * (TOUCH_SENSITIVITY_ADJUST_MAX_Y - TOUCH_SENSITIVITY_ADJUST_MIN_Y)
	end

	return Vector2.new(sensitivity.X, sensitivity.Y * multiplierY)
end

table.freeze(CameraTouchInputUtility)
return CameraTouchInputUtility
