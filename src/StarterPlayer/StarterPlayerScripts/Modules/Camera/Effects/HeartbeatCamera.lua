--[=[
	Update on heartbeat, must GC this camera state, unlike others. This
	allows for camera effects to run on heartbeat and cache information once instead
	of potentially going deeep into a tree and getting invoked multiple times

	@class HeartbeatCamera
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)
local SummedCamera = require(script.Parent.SummedCamera)

local HeartbeatCamera = {}
HeartbeatCamera.ClassName = "HeartbeatCamera"
HeartbeatCamera.ProfileName = "HeartbeatCamera"

function HeartbeatCamera.new(camera)
	local self = setmetatable({}, HeartbeatCamera)

	self._camera = camera or error("No camera")
	self._janitor = Janitor.new()

	self._currentStateCache = self._camera.CameraState or error("Camera state returned null")
	self._janitor:Add(RunService.Heartbeat:Connect(function()
		debug.profilebegin(self.ProfileName)
		self._currentStateCache = self._camera.CameraState or error("Camera state returned null")
		debug.profileend()
	end), "Disconnect")

	return self
end

function HeartbeatCamera:__add(other)
	return SummedCamera.new(self, other)
end

function HeartbeatCamera:ForceUpdateCache()
	self._currentStateCache = self._camera.CameraState
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within DefaultCamera
]=]
function HeartbeatCamera:__index(index)
	if index == "CameraState" then
		return self._currentStateCache
	else
		return HeartbeatCamera[index]
	end
end

function HeartbeatCamera:Destroy()
	self._janitor:Destroy()
end

function HeartbeatCamera:__tostring()
	return "HeartbeatCamera"
end

table.freeze(HeartbeatCamera)
return HeartbeatCamera
