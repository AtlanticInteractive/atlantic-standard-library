--[=[
	Utility methods for cameras. These are great for viewport frames.

	```lua
	-- Sample viewport frame fitting of a model
	local viewportFrame = ...
	local camera = viewportFrame.CurrentCamera
	local model = viewportFrame:FindFirstChildWhichIsA("Model")

	RunService.RenderStepped:Connect(function()
		local cframe, size = model:GetBoundingBox()
		local size = viewportFrame.AbsoluteSize
		local aspectRatio = size.x/size.y
		local dist = CameraUtility.fitBoundingBoxToCamera(size, camera.FieldOfView, aspectRatio)
		camera.CFrame = cframe.p + CFrame.Angles(0, math.pi*os.clock() % math.pi, -math.pi/8)
			:vectorToWorldSpace(Vector3.new(0, 0, -dist))
	end)
	```

	@class CameraUtility
]=]

local CameraUtility = {}

--[=[
	Computes the diameter of a cubeid

	@param size Vector3
	@return number
]=]
function CameraUtility.GetCubeoidDiameter(size)
	return math.sqrt(size.X^2 + size.Y^2 + size.Z^2)
end

--[=[
	Use spherical bounding box to calculate how far back to move a camera
	See: https://community.khronos.org/t/zoom-to-fit-screen/59857/12

	@param size Vector3 -- Size of the bounding box
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@return number -- Distance to move the camera back from the bounding box
]=]
function CameraUtility.FitBoundingBoxToCamera(size, fovDeg, aspectRatio)
	local radius = CameraUtility.GetCubeoidDiameter(size)/2
	return CameraUtility.FitSphereToCamera(radius, fovDeg, aspectRatio)
end

--[=[
	Fits a sphere to the camera, computing how far back to zoom the camera from
	the center of the sphere.

	@param radius number -- Radius of the sphere
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@return number -- Distance to move the camera back from the bounding box
]=]
function CameraUtility.FitSphereToCamera(radius, fovDeg, aspectRatio)
	local halfFov = 0.5 * math.rad(fovDeg)
	if aspectRatio < 1 then
		halfFov = math.atan(aspectRatio * math.tan(halfFov))
	end

	return radius / math.sin(halfFov)
end

--[=[
	Checks if a position is on screen on a camera

	@param camera Camera
	@param position Vector3
	@return boolean
]=]
function CameraUtility.IsOnScreen(camera, position)
	local _, onScreen = camera:WorldToScreenPoint(position)
	return onScreen
end

table.freeze(CameraUtility)
return CameraUtility