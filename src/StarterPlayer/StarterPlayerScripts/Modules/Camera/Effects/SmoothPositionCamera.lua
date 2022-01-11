--[=[
	Lags the camera smoothly behind the position maintaining other components
	@class SmoothPositionCamera
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraFrame = require(script.Parent.Parent.Utility.CameraFrame)
local CameraState = require(script.Parent.Parent.CameraState)
local QFrame = require(ReplicatedStorage.Knit.Util.Additions.Vendor.QFrame)
local Spring = require(ReplicatedStorage.Knit.Util.Additions.Physics.Spring)
local SummedCamera = require(script.Parent.SummedCamera)

local SmoothPositionCamera = {}
SmoothPositionCamera.ClassName = "SmoothPositionCamera"

function SmoothPositionCamera.new(baseCamera)
	local self = setmetatable({}, SmoothPositionCamera)

	self.Spring = Spring.new(Vector3.new())
	self.BaseCamera = baseCamera or error("Must have BaseCamera")
	self.Speed = 10

	return self
end

function SmoothPositionCamera:__add(other)
	return SummedCamera.new(self, other)
end

function SmoothPositionCamera:__newindex(index, value)
	if index == "BaseCamera" then
		rawset(self, "_" .. index, value)
		local target = self.BaseCamera.CameraState.Position
		self.Spring:SetTarget(target):SetPosition(target):SetVelocity(Vector3.new())
	elseif index == "_lastUpdateTime" or index == "Spring" then
		rawset(self, index, value)
	elseif index == "Speed" or index == "Damper" or index == "Velocity" or index == "Position" then
		self:_internalUpdate()
		local setter = self.Spring["Set" .. index]
		setter(self.Spring, value)
	else
		error(index .. " is not a valid member of SmoothPositionCamera")
	end
end

function SmoothPositionCamera:__index(index)
	if index == "CameraState" then
		local baseCameraState = self.BaseCamera.CameraState
		local baseCameraFrame = baseCameraState.CameraFrame
		local baseCameraFrameDerivative = baseCameraState.CameraFrameDerivative

		local cameraFrame = CameraFrame.new(QFrame.FromVector3(self.Position, baseCameraFrame.QFrame), baseCameraFrame.FieldOfView)
		local cameraFrameDerivative = CameraFrame.new(QFrame.FromVector3(self.Velocity, baseCameraFrameDerivative.QFrame), baseCameraFrameDerivative.FieldOfView)

		return CameraState.new(cameraFrame, cameraFrameDerivative)
	elseif index == "Position" then
		self:_internalUpdate()
		return self.Spring:GetPosition()
	elseif index == "Speed" or index == "Damper" or index == "Velocity" then
		local getter = self.Spring["Get" .. index]
		return getter(self.Spring)
	elseif index == "Target" then
		return self.BaseCamera.CameraState.Position
	elseif index == "BaseCamera" then
		return rawget(self, "_" .. index) or error("Internal error: index does not exist")
	else
		return SmoothPositionCamera[index]
	end
end

function SmoothPositionCamera:_internalUpdate()
	local delta
	if self._lastUpdateTime then
		delta = os.clock() - self._lastUpdateTime
	end

	self._lastUpdateTime = os.clock()
	self.Spring:SetTarget(self.BaseCamera.CameraState.Position)

	if delta then
		self.Spring:TimeSkip(delta)
	end
end

function SmoothPositionCamera:__tostring()
	return "SmoothPositionCamera"
end

table.freeze(SmoothPositionCamera)
return SmoothPositionCamera
