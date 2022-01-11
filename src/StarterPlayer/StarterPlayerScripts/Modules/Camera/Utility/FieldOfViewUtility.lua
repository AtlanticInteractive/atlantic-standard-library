--[=[
	Utility functions involving field of view.
	@class FieldOfViewUtility
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Math = require(ReplicatedStorage.Knit.Util.Additions.Math.Math)

local FieldOfViewUtility = {}

--[=[
	Converts field of view to height
	@param fov number
	@return number
]=]
function FieldOfViewUtility.FovToHeight(fov)
    return 2*math.tan(math.rad(fov)/2)
end

--[=[
	Converts height to field of view
	@param height number
	@return number
]=]
function FieldOfViewUtility.HeightToFov(height)
    return 2*math.deg(math.atan(height/2))
end

--[=[
	Linear way to log a value so we don't get floating point errors or infinite values
	@param height number
	@param linearAt number
	@return number
]=]
function FieldOfViewUtility.SafeLog(height, linearAt)
	if height < linearAt then
		local slope = 1/linearAt
		return slope*(height - linearAt) + math.log(linearAt)
	else
		return math.log(height)
	end
end

--[=[
	Linear way to exponentiate field of view so we don't get floating point errors or
	infinite values.
	@param logHeight number
	@param linearAt number
	@return number
]=]
function FieldOfViewUtility.SafeExp(logHeight, linearAt)
	local transitionAt = math.log(linearAt)

	if logHeight <= transitionAt then
		return linearAt*(logHeight - transitionAt) + linearAt
	else
		return math.exp(logHeight)
	end
end

local linearAt = FieldOfViewUtility.FovToHeight(1)

--[=[
	Interpolates field of view in height space, instead of degrees.
	@param fov0 number
	@param fov1 number
	@param percent number
	@return number -- Fov in degrees
]=]
function FieldOfViewUtility.LerpInHeightSpace(fov0, fov1, percent)
	local height0 = FieldOfViewUtility.FovToHeight(fov0)
	local height1 = FieldOfViewUtility.FovToHeight(fov1)

	local logHeight0 = FieldOfViewUtility.SafeLog(height0, linearAt)
	local logHeight1 = FieldOfViewUtility.SafeLog(height1, linearAt)

	local newLogHeight = Math.Lerp(logHeight0, logHeight1, percent)

	return FieldOfViewUtility.HeightToFov(FieldOfViewUtility.SafeExp(newLogHeight, linearAt))
end

table.freeze(FieldOfViewUtility)
return FieldOfViewUtility
