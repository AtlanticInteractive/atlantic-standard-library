--[=[
	@class CameraInputUtility
]=]

local Workspace = game:GetService("Workspace")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local CameraInputUtility = {}

function CameraInputUtility.GetPanBy(panDelta, sensitivity)
	local viewportSize = Workspace.CurrentCamera.ViewportSize
	local aspectRatio = CameraInputUtility.GetCappedAspectRatio(viewportSize)
	local inversionVector = CameraInputUtility.GetInversionVector(UserGameSettings)

	if CameraInputUtility.IsPortraitMode(aspectRatio) then
		sensitivity = CameraInputUtility.InvertSensitivity(sensitivity)
	end

	return inversionVector * sensitivity * panDelta
end

function CameraInputUtility.ConvertToPanDelta(vector3)
	return Vector2.new(vector3.X, vector3.Y)
end

function CameraInputUtility.GetInversionVector(userGameSettings)
	return Vector2.new(1, userGameSettings:GetCameraYInvertValue())
end

function CameraInputUtility.InvertSensitivity(sensitivity)
	return Vector2.new(sensitivity.Y, sensitivity.X)
end

function CameraInputUtility.IsPortraitMode(aspectRatio)
	return aspectRatio < 1
end

function CameraInputUtility.GetCappedAspectRatio(viewportSize)
	local x = math.clamp(viewportSize.X, 0, 1920)
	local y = math.clamp(viewportSize.Y, 0, 1080)
	return x / y
end

table.freeze(CameraInputUtility)
return CameraInputUtility
